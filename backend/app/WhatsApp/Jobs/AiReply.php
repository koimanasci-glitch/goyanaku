<?php
namespace App\WhatsApp\Jobs;

use App\Models\Business;
use App\Support\AiBilling;
use App\WhatsApp\{Chatbot, Devices, Inbound, Phone, Replies};
use App\WhatsApp\Chatku\ChatkuException;
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\{Cache, Crypt, DB};

/**
 * Chatbot AI lewat CHATKU (tanpa simpan data di CHATKU). GOYANA mengirim harga, knowledge, data pesanan pelanggan itu, dan daftar media;
 * biaya (biaya asli × kurs +2% + untung 25%) dipotong dari saldo AI laundry di GOYANA dan juga di CHATKU.
 * Jawaban yang menyebut harga di luar data tidak dikirim ("admin akan cek") — AI tidak boleh mengarang harga.
 */
final class AiReply implements ShouldQueue {
    use Queueable, WaQueue;
    public int $tries = 4;
    public int $timeout = 90;

    public function __construct(public int $eventId, public string $deviceId, public string $from, public string $text) { $this->viaWaQueue(); }
    public function backoff(): array { return [10, 30, 60]; }

    public function handle(Devices $devices, Replies $replies, ChatkuGateway $gateway): void {
        if (!config('whatsapp.enabled') || !$gateway instanceof ChatkuExtras) return;
        $d = DB::table('wa_devices')->where('id', $this->deviceId)->first();
        if (!$d || $d->status !== 'connected') return;
        $from = Crypt::decryptString($this->from); $text = Crypt::decryptString($this->text);
        $contact = Chatbot::contact($d->id, $from);
        // Pesan beruntun: hanya pesan terakhir yang dijawab (riwayat membawa pesan sebelumnya).
        if ((int) Cache::get('wa-ai-last:'.$d->id.':'.$contact, $this->eventId) !== $this->eventId) { $this->mark('merged'); return; }
        if (DB::table('wa_outbox')->where('event_id', $this->eventId)->exists()) return;
        $s = Chatbot::settings((int) $d->business_id, (int) $d->outlet_id);
        if (!$s['ai_enabled'] || !Chatbot::allows((int) $d->business_id, 'ai') || !$devices->allowed($d, 'connection') || Chatbot::paused($d, $contact)) { $this->mark('ignored'); return; }
        $business = Business::find($d->business_id);
        if (!$business) return;
        if ((int) $business->ai_balance <= 0) { $this->handover($d, $from, $contact, $replies, 'saldo'); return; }

        $media = DB::table('wa_media')->where(['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id])->orderBy('created_at')->get();
        $history = Chatbot::history($d, $contact, 9);
        if ($history && end($history)['from'] === 'customer' && end($history)['text'] === $text) array_pop($history);
        $payload = self::payload($d, $business, $s, $text, $history, $from, $replies);

        // Jawaban AI disimpan sebentar: bila langkah sesudahnya gagal dan job diulang, AI tidak dipanggil (dan dibayar) dua kali.
        $cacheKey = 'wa-ai-result:'.$this->eventId;
        $r = Cache::get($cacheKey);
        if (!is_array($r)) {
            try {
                $r = $gateway->ai((int) $d->business_id, $payload);
            } catch (ChatkuException $e) {
                if ($e->codeName === 'saldo_habis') { $this->handover($d, $from, $contact, $replies, 'saldo'); return; }
                // Diulang hanya bila CHATKU pasti belum memproses (sibuk/batas). Waktu habis/putus = mungkin sudah ditagih → serahkan ke admin.
                if (in_array($e->codeName, ['ai_busy', 'rate_limited', 'engine_unavailable'], true) && $this->attempts() < $this->tries) { $this->release($e->retryAfter ?? 15); return; }
                $this->handover($d, $from, $contact, $replies, 'error'); return;
            }
            Cache::put($cacheKey, $r, now()->addHour());
        }
        $cost = (int) ($r['cost'] ?? 0);
        if ($cost > 0) AiBilling::debitRupiah($business, $cost, (string) ($r['model'] ?? 'chatku'), 'chatku-ai:'.$this->eventId);

        $answer = trim((string) ($r['answer'] ?? ''));
        if (!empty($r['unverified_prices'])) $answer = 'Untuk harga pastinya, admin kami cek dulu ya Kak 🙏 Mohon ditunggu sebentar.';
        elseif (!empty($r['handover']) || $answer === '') { $this->handover($d, $from, $contact, $replies, 'ai', $answer); return; }
        $mediaId = is_string($r['media_id'] ?? null) && $media->contains('id', $r['media_id']) ? $r['media_id'] : null;
        DB::transaction(function () use ($d, $from, $contact, $answer, $mediaId) {
            if (DB::table('wa_outbox')->where('event_id', $this->eventId)->lockForUpdate()->exists()) return;
            Chatbot::log($d, $contact, 'me', $answer);
            Inbound::queue($this->eventId, $d, 'ai', $from, mb_substr($answer, 0, 3900), $mediaId);
        });
    }

    /** Bahan untuk AI (dipakai juga uji jawaban di aplikasi): harga resmi, pengetahuan, data pesanan pengirim, media cabang. */
    public static function payload(object $d, Business $business, array $s, string $text, array $history, ?string $from, Replies $replies): array {
        $media = DB::table('wa_media')->where(['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id])->orderBy('created_at')->get();
        return array_filter([
            'question' => $text, 'purpose' => 'reply', 'business_name' => mb_substr($business->name, 0, 120),
            'instructions' => mb_substr(trim($s['ai_instructions'])."\nNama kamu: {$s['ai_name']}. Kamu admin chat laundry {$replies->outletName($d)}. Jawab singkat dalam bahasa Indonesia yang ramah.", 0, 3000),
            'prices' => $s['ai_prices'] ? mb_substr(self::prices($d), 0, 8000) : null,
            'knowledge' => mb_substr(trim($s['knowledge']."\n".self::faq($d)."\n".$replies->hours($d)), 0, 20000) ?: null,
            'data' => $s['ai_status'] && $from ? mb_substr(self::orders($d, $from, $replies), 0, 6000) : null,
            'history' => array_slice($history, -8),
            'media' => $media->map(fn ($m) => ['id' => $m->id, 'name' => $m->name, 'description' => $m->kind === 'pdf' ? 'dokumen PDF' : 'foto'])->all(),
            'max_tokens' => 400,
        ], fn ($v) => $v !== null && $v !== []);
    }

    /** Teruskan ke admin manusia: kirim kalimat penghubung sekali per 3 jam per kontak; bot diam sebentar supaya admin bisa menjawab. */
    private function handover(object $d, string $from, string $contact, Replies $replies, string $why, string $answer = ''): void {
        $this->mark('handover:'.$why);
        if (!Cache::add('wa-handover:'.$d->id.':'.$contact, 1, now()->addHours(3))) return;
        $body = $answer !== '' && $why === 'ai' ? $answer : $replies->render('handover');
        if ($body === '') return;
        DB::transaction(function () use ($d, $from, $contact, $body, $why) {
            if (DB::table('wa_outbox')->where('event_id', $this->eventId)->lockForUpdate()->exists()) return;
            Chatbot::log($d, $contact, 'me', $body);
            Inbound::queue($this->eventId, $d, 'handover', $from, $body);
            // Kabari pemilik lewat chat ke nomor WhatsApp outlet sendiri ("Pesan ke diri sendiri").
            $reason = ['saldo' => 'saldo AI habis', 'error' => 'AI sedang bermasalah', 'ai' => 'AI tidak yakin'][$why] ?? 'perlu admin';
            $question = mb_substr(trim(Crypt::decryptString($this->text)), 0, 300);
            $note = '🔔 Pelanggan '.Chatbot::masked($from)." perlu dibalas admin ($reason).\n\"$question\"\nBot diam untuk chat ini. Ketik #bot di chat pelanggan untuk melanjutkan.";
            $notify = DB::table('wa_events')->insertGetId(['device_id' => $d->id, 'provider_id' => mb_substr('notify:'.$this->eventId, 0, 160), 'state' => 'notify', 'created_at' => now(), 'updated_at' => now()]);
            Inbound::queue($notify, $d, 'handover', $d->phone, $note);
        });
        Chatbot::pause($d, $contact, max(10, Chatbot::settings((int) $d->business_id, (int) $d->outlet_id)['takeover_minutes']));
    }

    private function mark(string $state): void {
        DB::table('wa_events')->where('id', $this->eventId)->where('state', 'ai')->update(['state' => mb_substr($state, 0, 20), 'updated_at' => now()]);
    }

    /** Daftar harga resmi dari katalog yang tersinkron (satu-satunya sumber harga untuk AI). */
    private static function prices(object $d): string {
        $out = [];
        $rows = DB::table('sync_records')->where(['business_id' => $d->business_id, 'collection' => 'services', 'deleted' => false])
            ->where(fn ($q) => $q->whereNull('outlet_id')->orWhere('outlet_id', $d->outlet_id))->limit(150)->get();
        foreach ($rows as $r) {
            $s = json_decode((string) $r->data, true);
            if (!is_array($s) || ($s['active'] ?? true) === false || trim((string) ($s['name'] ?? '')) === '') continue;
            $p = [];
            foreach ((array) ($s['prices'] ?? []) as $type => $price) if (($s['enabled'][$type] ?? true) !== false && is_numeric($price) && $price > 0) $p[] = $type.' '.Replies::rp((float) $price);
            if ($p) $out[] = trim((string) $s['name']).': '.implode(', ', $p).' /'.($s['unit'] ?? '');
        }
        return implode("\n", $out);
    }

    /** Balasan cepat pemilik sebagai tanya-jawab (AI boleh memakai isinya). */
    private static function faq(object $d): string {
        return DB::table('wa_quick_replies')->where(['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id, 'enabled' => true])->orderBy('position')->limit(40)->get()
            ->filter(fn ($q) => trim((string) $q->reply) !== '')->map(fn ($q) => 'T: '.$q->keys."\nJ: ".$q->reply)->implode("\n");
    }

    /** Hanya pesanan milik nomor pengirim di cabang ini. */
    private static function orders(object $d, string $from, Replies $replies): string {
        $orders = DB::table('order_index')->where(['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id, 'customer_key' => 'phone:'.Phone::normalize($from), 'deleted' => false])
            ->orderByDesc('ordered_at')->limit(5)->get();
        if ($orders->isEmpty()) return 'Nomor ini belum punya pesanan di cabang ini.';
        return 'Pesanan pelanggan ini:'."\n".$orders->map(fn ($o) => '- '.$o->record_key.': '.(Replies::LABELS[$o->status] ?? $o->status).', perkiraan selesai '.$replies->estimate($d, $o->due_at)
            .', total '.Replies::rp((int) $o->total).', dibayar '.Replies::rp((int) $o->paid).($o->delivery ? ', diantar kurir' : ''))->implode("\n");
    }
}
