<?php
namespace App\WhatsApp;
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use App\WhatsApp\Jobs\{AiReply, SendReply};
use Illuminate\Support\Facades\{Cache, Crypt, DB, RateLimiter};

/**
 * Pesan WhatsApp masuk (sudah diverifikasi adapter). Urutan jawaban per cabang (keputusan Paduka 10 Okt 2026):
 *   pemilik ambil alih? → STOP/MULAI promo → Balasan Cepat → status/tagihan/nota → harga → jam & alamat / antar-jemput → Chatbot AI (CHATKU) → diam (dicatat topik).
 * Event lama/kosong/grup dijawab "diterima" tanpa tindakan supaya CHATKU tidak mengulang kiriman.
 */
final class Inbound {
    public function __construct(private Devices $devices, private Replies $replies) {}

    /** Receives ONLY an authenticated, provider-normalized event from ChatkuGateway. */
    public function receive(array $e): void {
        if (($e['group'] ?? false) || trim((string) ($e['text'] ?? '')) === '') return;
        $e['text'] = mb_substr((string) $e['text'], 0, 2000); // pesan sangat panjang tetap diterima (bukan 422 → CHATKU mengulang)
        if (!is_string($e['from'] ?? null) || !is_string($e['device'] ?? null) || !is_string($e['id'] ?? null) || $e['id'] === '') return;
        validator($e, ['id'=>'required|string|max:160','device'=>'required|string|max:255','from'=>'required|string|max:40','text'=>'required|string|max:4000','occurred_at'=>'required|date','from_me'=>'required|boolean','group'=>'required|boolean'])->validate();
        $time=\Carbon\CarbonImmutable::parse($e['occurred_at']);
        if ($time->isAfter(now()->addSeconds(30)) || $time->isBefore(now()->subSeconds(config('whatsapp.event_max_age_seconds',300)))) return; // kedaluwarsa: tidak dibalas
        try { $from=Phone::normalize($e['from']); } catch(\InvalidArgumentException) { return; }
        $device=DB::table('wa_devices')->where('remote_id',$e['device'])->first();
        if (!$device) return;
        if ($e['from_me']) { if ($device->status === 'connected') Chatbot::ownerMessage($device, $from, (string) $e['text'], (bool) ($e['self'] ?? false)); return; }
        $throttle='wa-in:'.hash('sha256',$device->id.':'.$from);
        if (RateLimiter::tooManyAttempts($throttle,10)) return;
        RateLimiter::hit($throttle,60);
        $text = mb_substr((string) $e['text'], 0, 2000);
        DB::transaction(function()use($e,$device,$from,$text){
            // Serialize settings/removal, duplicate webhooks, and admission per business.
            \App\Models\Business::whereKey($device->business_id)->lockForUpdate()->firstOrFail();
            $d=DB::table('wa_devices')->where('id',$device->id)->first();
            if(!$d || $d->status!=='connected') return;
            if(DB::table('wa_events')->where(['device_id'=>$d->id,'provider_id'=>$e['id']])->exists()) return;
            $event=DB::table('wa_events')->insertGetId(['device_id'=>$d->id,'provider_id'=>$e['id'],'state'=>'ignored','created_at'=>now(),'updated_at'=>now()]);
            $settings = Chatbot::settings((int) $d->business_id, (int) $d->outlet_id);
            $contact = Chatbot::contact($d->id, $from);
            $aiOn = $settings['ai_enabled'] && Chatbot::allows((int) $d->business_id, 'ai');
            if ($aiOn) Chatbot::log($d, $contact, 'customer', $text);
            if (Chatbot::paused($d, $contact)) {
                // STOP promo tetap dicatat walau bot sedang diambil alih (tanpa balasan).
                Chatbot::optCommand($d, $from, $text);
                DB::table('wa_events')->where('id',$event)->update(['state'=>'paused']); return;
            }

            [$feature, $reply, $media] = $this->decide($d, $from, $text, $settings);
            if ($feature === null && $aiOn && $this->devices->allowed($d, 'connection') && app(ChatkuGateway::class) instanceof ChatkuExtras) {
                // AI dijawab di antrean (tidak menahan webhook); pesan beruntun digabung: hanya pesan terakhir yang dijawab.
                Cache::put('wa-ai-last:'.$d->id.':'.$contact, $event, now()->addMinutes(10));
                DB::table('wa_events')->where('id',$event)->update(['state'=>'ai']);
                AiReply::dispatch($event, $d->id, Crypt::encryptString($from), Crypt::encryptString($text))->delay(now()->addSeconds(4))->afterCommit();
                return;
            }
            if ($feature === null) { TopicStats::record($text); return; }
            if ($reply === '' && !$media) return;
            if ($aiOn) Chatbot::log($d, $contact, 'me', $reply);
            self::queue($event, $d, $feature, $from, $reply, $media);
        });
    }

    /** @return array{0:?string,1:string,2:?string} [fitur, balasan, media_id] — fitur null = tidak ada balasan tanpa AI */
    private function decide(object $d, string $from, string $text, array $settings): array {
        if (($opt = Chatbot::optCommand($d, $from, $text)) !== null) return ['optout', $opt, null];
        $quick = $settings['quick_enabled'] && $this->devices->allowed($d, 'connection') && Chatbot::allows((int) $d->business_id, 'quick');
        if ($quick && ($rule = Chatbot::quickMatch($d, $text))) {
            $media = $rule->media_id && DB::table('wa_media')->where(['id' => $rule->media_id, 'business_id' => $d->business_id])->exists() ? $rule->media_id : null;
            return ['quick', trim((string) $rule->reply), $media];
        }
        $intent = Intent::of($text);
        if (!$intent) return [null, '', null];
        $feature = Intent::feature($intent);
        if ($feature === 'quick') {
            if (!$quick) return [null, '', null];
            $reply = $intent === 'hours' ? $this->replies->hours($d) : $this->replies->pickupInfo($d);
            return $reply === '' ? [null, '', null] : ['quick', $reply, null];
        }
        if (!$d->{'reply_'.$feature} || !$this->devices->allowed($d, $feature)) return [null, '', null];
        $reply = match ($intent) {
            'status', 'bill' => $this->replies->status($d, $from, $text, $intent),
            'receipt' => $this->replies->receipt($d, $from, $text),
            default => $this->replies->services($d, $text),
        };
        if ($feature === 'services' && $reply === $this->replies->render('unknown_service')) TopicStats::record($text);
        return [$feature, $reply, null];
    }

    public static function queue(int $event, object $d, string $feature, string $to, string $body, ?string $media = null): int {
        $outbox=DB::table('wa_outbox')->insertGetId(['event_id'=>$event,'device_id'=>$d->id,'device_version'=>$d->version,'feature'=>$feature,'recipient'=>Crypt::encryptString($to),
            'body'=>Crypt::encryptString($body),'media_id'=>$media,'state'=>'pending','created_at'=>now(),'updated_at'=>now()]);
        DB::table('wa_events')->where('id',$event)->update(['state'=>'queued','updated_at'=>now()]);
        SendReply::dispatch($outbox)->afterCommit();
        return $outbox;
    }
}
