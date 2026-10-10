<?php
namespace App\WhatsApp;

use App\Models\{Business, User};
use App\WhatsApp\Chatku\ChatkuException;
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * WhatsApp Blast laundry (paket Platinum). GOYANA memilih penerima dari data pelanggan (tanpa yang berhenti promo) dan
 * mempersonalisasi teks; pengiriman bergilir + anti-blokir dikerjakan mesin campaign CHATKU. Nomor tidak disimpan utuh di GOYANA
 * (hanya hash + nomor tersamar untuk laporan).
 */
final class Blasts {
    public const MAX = 5000;

    public function __construct(private ChatkuGateway $gateway) {}

    public static function ref(string $id): string { return 'goyana-blast-'.$id; }

    /** Calon penerima: pelanggan bernomor WA valid, belum berhenti promo, opsional hanya pelanggan cabang ini / aktif N hari. */
    public function audience(int $businessId, int $outletId, string $scope = 'outlet', ?int $days = null): array {
        $keys = null;
        if ($scope === 'outlet' || $days) {
            $q = DB::table('order_index')->where(['business_id' => $businessId, 'deleted' => false])->where('customer_key', 'like', 'phone:%');
            if ($scope === 'outlet') $q->where('outlet_id', $outletId);
            if ($days) $q->where('ordered_at', '>=', now()->subDays($days));
            $keys = $q->distinct()->pluck('customer_key')->flip();
        }
        $out = [];
        $rows = DB::table('sync_records')->where(['business_id' => $businessId, 'collection' => 'customers', 'deleted' => false])->cursor();
        foreach ($rows as $r) {
            $c = json_decode((string) $r->data, true);
            if (!is_array($c) || trim((string) ($c['phone'] ?? '')) === '') continue;
            try { $phone = Phone::normalize((string) $c['phone']); } catch (\InvalidArgumentException) { continue; }
            if (isset($out[$phone]) || ($keys !== null && !isset($keys['phone:'.$phone])) || Chatbot::optedOut($businessId, $phone)) continue;
            if (($c['promo'] ?? true) === false) continue; // pelanggan yang di aplikasi ditandai tidak mau promo
            $out[$phone] = ['to' => $phone, 'name' => mb_substr(trim((string) ($c['name'] ?? '')), 0, 80)];
            if (count($out) >= self::MAX) break;
        }
        return array_values($out);
    }

    public static function personalize(string $body, string $name): string {
        $first = trim(Replies::firstName($name));
        return str_replace(['{nama}', '{{nama}}'], $first !== '' ? $first : 'Kak', $body);
    }

    public function create(User $user, Business $b, array $v): object {
        abort_unless(Chatbot::allows($b, 'blast'), 403, 'WhatsApp Blast membutuhkan paket Platinum.');
        abort_unless($this->gateway instanceof ChatkuExtras, 503, 'WhatsApp belum terhubung ke server pengirim.');
        $d = DB::table('wa_devices')->where(['id' => $v['device_id'], 'business_id' => $b->id])->first() ?? abort(404, 'Perangkat tidak ditemukan.');
        abort_unless($d->status === 'connected' && app(Devices::class)->allowed($d, 'connection'), 409, 'WhatsApp cabang ini belum tersambung.');
        $media = !empty($v['media_id']) ? Media::find($b->id, $v['media_id']) : null;
        abort_if($media && (int) $media->outlet_id !== (int) $d->outlet_id, 422, 'Media milik cabang lain.');
        $list = $this->audience($b->id, (int) $d->outlet_id, $v['audience'] ?? 'outlet', $v['days'] ?? null);
        if (!$list) throw ValidationException::withMessages(['audience' => 'Belum ada pelanggan bernomor WhatsApp yang bisa dikirimi promo.']);
        // Ulang setelah jaringan putus: pakai blast "creating" yang sama (ref sama → CHATKU tidak membuat blast kedua).
        $pending = DB::table('wa_blasts')->where(['business_id' => $b->id, 'device_id' => $d->id, 'name' => $v['name'], 'body' => $v['body'], 'status' => 'creating'])
            ->where('created_at', '>', now()->subDay())->value('id');
        $id = $pending ?: (string) Str::uuid();
        if (!$pending) DB::transaction(function () use ($id, $b, $d, $v, $media, $list, $user) {
            DB::table('wa_blasts')->insert(['id' => $id, 'business_id' => $b->id, 'outlet_id' => $d->outlet_id, 'device_id' => $d->id, 'name' => $v['name'],
                'body' => $v['body'], 'media_id' => $media?->id, 'status' => 'creating', 'total' => count($list), 'schedule_at' => $v['schedule_at'] ?? null,
                'created_by' => $user->id, 'created_at' => now(), 'updated_at' => now()]);
            foreach (array_chunk($list, 500) as $chunk) DB::table('wa_blast_recipients')->insert(array_map(fn ($r) => ['blast_id' => $id,
                'contact' => Chatbot::contact('biz'.$b->id, $r['to']), 'masked' => Chatbot::masked($r['to']), 'name' => $r['name'] ?: null, 'status' => 'queued', 'updated_at' => now()], $chunk));
        });
        $tz = \App\Models\Outlet::zoneOf((int) $d->outlet_id);
        $payload = array_filter([
            'ref' => self::ref($id), 'name' => mb_substr($v['name'], 0, 80),
            'recipients' => array_map(fn ($r) => ['to' => $r['to'], 'text' => mb_substr(self::personalize($v['body'], $r['name'])."\n\nBalas STOP bila tidak ingin menerima promo.", 0, 3900),
                'ref' => Chatbot::contact('biz'.$b->id, $r['to'])], $list),
            'media' => $media ? Media::forChatku($media) : null,
            'schedule_at' => !empty($v['schedule_at']) ? \Carbon\CarbonImmutable::parse($v['schedule_at'], $tz)->toIso8601String() : null,
            'send_from' => $v['send_from'] ?? '08:00', 'send_until' => $v['send_until'] ?? '20:00',
        ]);
        try {
            $res = $this->gateway->blast($d->remote_id, $payload);
            DB::table('wa_blasts')->where('id', $id)->update(['status' => (string) ($res['status'] ?? 'queued'), 'skipped' => (int) ($res['skipped'] ?? 0), 'updated_at' => now()]);
        } catch (ChatkuException $e) {
            if ($e->temporary()) abort(503, 'Server WhatsApp belum menjawab. Coba kirim lagi — blast yang sama tidak akan terkirim dua kali.');
            DB::table('wa_blasts')->where('id', $id)->update(['status' => 'failed', 'reason' => mb_substr($e->getMessage(), 0, 200), 'updated_at' => now()]);
            abort(422, 'Blast ditolak: '.$e->getMessage());
        }
        return DB::table('wa_blasts')->where('id', $id)->first();
    }

    /** Blast yang tertahan "creating" (jaringan putus saat dibuat): tanyakan CHATKU; tidak ada = gagal. */
    public function settle(): int {
        if (!$this->gateway instanceof ChatkuExtras) return 0;
        $n = 0;
        foreach (DB::table('wa_blasts')->where('status', 'creating')->where('created_at', '<', now()->subMinutes(10))->limit(50)->get() as $x) {
            try { $res = $this->gateway->blastStatus(self::ref($x->id)); $status = (string) ($res['status'] ?? 'queued'); $reason = null; }
            catch (ChatkuException $e) { if ($e->status !== 404) continue; $status = 'failed'; $reason = 'Blast tidak sampai ke server WhatsApp. Buat ulang.'; }
            DB::table('wa_blasts')->where('id', $x->id)->update(['status' => $status, 'reason' => $reason, 'updated_at' => now()]); $n++;
        }
        return $n;
    }

    public function cancel(Business $b, string $id): object {
        $blast = DB::table('wa_blasts')->where(['id' => $id, 'business_id' => $b->id])->first() ?? abort(404);
        if ($this->gateway instanceof ChatkuExtras && !in_array($blast->status, ['failed', 'cancelled', 'done', 'completed'], true)) {
            try { $res = $this->gateway->cancelBlast(self::ref($id)); $status = (string) ($res['status'] ?? 'cancelled'); }
            catch (ChatkuException $e) { abort($e->temporary() ? 503 : 422, $e->getMessage()); }
            DB::table('wa_blasts')->where('id', $id)->update(['status' => $status, 'updated_at' => now()]);
        }
        return DB::table('wa_blasts')->where('id', $id)->first();
    }

    /** Event webhook blast.message / blast.status dari CHATKU. */
    public function event(string $type, array $data): void {
        $ref = (string) ($type === 'blast.message' ? ($data['blast_ref'] ?? '') : ($data['ref'] ?? ''));
        if (!str_starts_with($ref, 'goyana-blast-')) return;
        $id = substr($ref, strlen('goyana-blast-'));
        $blast = DB::table('wa_blasts')->where('id', $id)->first();
        if (!$blast) return;
        if ($type === 'blast.message') {
            $st = (string) ($data['status'] ?? '');
            if (!in_array($st, ['sent', 'failed', 'skipped', 'delivered', 'read'], true)) return;
            DB::table('wa_blast_recipients')->where(['blast_id' => $id, 'contact' => (string) ($data['ref'] ?? '')])
                ->update(['status' => $st, 'error' => isset($data['error']) ? mb_substr((string) $data['error'], 0, 120) : null, 'updated_at' => now()]);
            $c = DB::table('wa_blast_recipients')->where('blast_id', $id)->selectRaw("sum(case when status in ('sent','delivered','read') then 1 else 0 end) s, sum(case when status='failed' then 1 else 0 end) f, sum(case when status='skipped' then 1 else 0 end) k")->first();
            DB::table('wa_blasts')->where('id', $id)->update(['sent' => (int) $c->s, 'failed' => (int) $c->f, 'skipped' => (int) $c->k, 'updated_at' => now()]);
            return;
        }
        DB::table('wa_blasts')->where('id', $id)->update(array_filter(['status' => mb_substr((string) ($data['status'] ?? $blast->status), 0, 16),
            'reason' => isset($data['reason']) ? mb_substr((string) $data['reason'], 0, 200) : null, 'sent' => isset($data['sent']) ? (int) $data['sent'] : null,
            'failed' => isset($data['failed']) ? (int) $data['failed'] : null, 'skipped' => isset($data['skipped']) ? (int) $data['skipped'] : null], fn ($v) => $v !== null) + ['updated_at' => now()]);
    }

    public static function present(object $b, bool $recipients = false): array {
        $out = ['id' => $b->id, 'outlet_id' => (int) $b->outlet_id, 'device_id' => $b->device_id, 'name' => $b->name, 'body' => $b->body, 'media_id' => $b->media_id,
            'status' => $b->status, 'reason' => $b->reason, 'total' => (int) $b->total, 'sent' => (int) $b->sent, 'failed' => (int) $b->failed, 'skipped' => (int) $b->skipped,
            'schedule_at' => $b->schedule_at, 'created_at' => (string) $b->created_at];
        if ($recipients) $out['recipients'] = DB::table('wa_blast_recipients')->where('blast_id', $b->id)->orderBy('id')->limit(500)->get(['masked', 'name', 'status', 'error'])->all();
        return $out;
    }
}
