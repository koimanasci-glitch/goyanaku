<?php
namespace App\WhatsApp;

use Illuminate\Support\Facades\DB;

/**
 * Pesan otomatis ke pelanggan (paket Gold+, sakelar per cabang): link nota saat pesanan dibuat, kabar "siap diambil/diantar",
 * dan pengingat "belum diambil" setelah N hari. Dibaca dari order_index (bukan dari HP) tiap 5 menit; tiap jenis hanya sekali
 * per nota (wa_auto_sent). Tidak dikirim di jam tenang cabang (default 21:00–07:00, zona WIB/WITA/WIT cabang).
 */
final class AutoMessages {
    public function __construct(private Replies $replies, private Devices $devices) {}

    public function run(int $perDevice = 200): int {
        $sent = 0;
        $devices = DB::table('wa_devices')->where('status', 'connected')->whereNotNull('remote_id')->orderBy('created_at')->get();
        $seenOutlet = [];
        foreach ($devices as $d) {
            if (isset($seenOutlet[$d->outlet_id])) continue; // satu perangkat pengirim per cabang
            $seenOutlet[$d->outlet_id] = true;
            $s = Chatbot::settings((int) $d->business_id, (int) $d->outlet_id);
            if (!($s['auto_nota'] || $s['auto_ready'] || $s['auto_late'])) continue;
            if (!Chatbot::allows((int) $d->business_id, 'messages') || !$this->devices->allowed($d, 'connection')) continue;
            if ($this->quiet($d, $s)) continue;
            $sent += $this->forDevice($d, $s, $perDevice);
        }
        return $sent;
    }

    public function quiet(object $d, array $s): bool {
        $now = now()->timezone(\App\Models\Outlet::zoneOf((int) $d->outlet_id))->format('H:i');
        [$from, $until] = [$s['quiet_from'], $s['quiet_until']];
        if ($from === $until) return false;
        return $from < $until ? ($now >= $from && $now < $until) : ($now >= $from || $now < $until);
    }

    private function forDevice(object $d, array $s, int $limit): int {
        $n = 0;
        $base = fn () => DB::table('order_index')->where(['business_id' => $d->business_id, 'outlet_id' => $d->outlet_id, 'deleted' => false])
            ->where('customer_key', 'like', 'phone:%');
        $jobs = [];
        if ($s['auto_nota']) $jobs['nota'] = $base()->where('ordered_at', '>=', now()->subHours(12))->whereNotIn('status', ['batal', 'diambil'])->orderBy('ordered_at')->limit($limit)->get();
        if ($s['auto_ready']) $jobs['ready'] = $base()->where('status', 'siap')->where('ready_at', '>=', now()->subDay())->orderBy('ready_at')->limit($limit)->get();
        if ($s['auto_late']) $jobs['late'] = $base()->whereIn('status', ['siap', 'telat'])->whereNotNull('ready_at')
            ->where('ready_at', '<=', now()->subDays(max(1, $s['late_days'])))->where('ready_at', '>=', now()->subDays(max(1, $s['late_days']) + 30))->orderBy('ready_at')->limit($limit)->get();
        foreach ($jobs as $kind => $orders) {
            foreach ($orders as $o) {
                if ($n >= $limit) return $n;
                if (DB::table('wa_auto_sent')->where(['business_id' => $d->business_id, 'record_key' => $o->record_key, 'kind' => $kind])->exists()) continue;
                $to = substr((string) $o->customer_key, 6);
                try { $to = Phone::normalize($to); } catch (\InvalidArgumentException) { continue; }
                $values = $this->replies->values($d, $o);
                if ($kind === 'late') $values['estimasi'] = $this->replies->estimate($d, $o->ready_at);
                if ($kind === 'ready' && $o->delivery) $values['pengambilan'] = "Pesanan akan segera diantar kurir ke alamat Kakak 🛵\n";
                $body = $this->replies->render($kind, $values);
                if ($body === '') continue;
                $ok = DB::transaction(function () use ($d, $o, $kind, $to, $body) {
                    try {
                        DB::table('wa_auto_sent')->insert(['business_id' => $d->business_id, 'record_key' => $o->record_key, 'kind' => $kind, 'created_at' => now()]);
                    } catch (\Illuminate\Database\UniqueConstraintViolationException) { return false; }
                    $event = DB::table('wa_events')->insertGetId(['device_id' => $d->id, 'provider_id' => mb_substr('auto:'.$kind.':'.$o->record_key, 0, 160), 'state' => 'auto', 'created_at' => now(), 'updated_at' => now()]);
                    Inbound::queue($event, $d, 'auto', $to, $body);
                    return true;
                });
                if ($ok) $n++;
            }
        }
        return $n;
    }
}
