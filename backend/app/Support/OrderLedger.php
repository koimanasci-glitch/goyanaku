<?php
namespace App\Support;

use App\Models\{Business, User};
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Catatan milik server untuk setiap pesanan yang diterima lewat sinkronisasi:
 * - order_index: ringkasan terkini untuk monitoring owner.
 * - order_events: siapa memajukan, melompati, memundurkan, membatalkan, menimbang, atau menerima pembayaran.
 * - courier_ledger: tunai yang diterima kurir di lokasi ("dipegang kurir" sampai disetor).
 * Dicatat dari sisi server, sehingga tidak bisa diubah dari HP.
 */
final class OrderLedger {
    public function __construct(private Business $business, private OrderGuard $guard) {}

    public function record(User $user, int $outletId, string $key, mixed $old, mixed $new, ?string $device): void {
        if (!OrderData::isOrder($new)) return;
        $oldOrder = OrderData::isOrder($old) ? $old : null;
        $now = now();
        $index = DB::table('order_index')->where('business_id', $this->business->id)->where('record_key', $key)->first();
        $mode = $user->orderMode();
        $status = OrderData::status($new);
        $row = [
            'outlet_id' => $outletId, 'status' => $status, 'total' => max(0, OrderData::total($new)), 'paid' => max(0, OrderData::paid($new)),
            'discount' => max(0, (int) ($new['card']['dataset']['disc'] ?? 0)), 'delivery' => OrderData::delivery($new),
            'customer' => mb_substr(OrderData::customer($new), 0, 160) ?: null, 'customer_key' => OrderData::customerKey($new),
            'courier_key' => OrderData::courier($new) ?: null,
            'ordered_at' => $this->time($new['card']['dataset']['created177'] ?? ($new['detail']['masuk'] ?? null)) ?? ($index->ordered_at ?? $now),
            'due_at' => $this->time($new['detail']['due'] ?? null), 'deleted' => false, 'updated_at' => $now,
        ];
        $event = fn (string $kind, array $extra = []) => DB::table('order_events')->insert($extra + [
            'business_id' => $this->business->id, 'outlet_id' => $outletId, 'record_key' => $key, 'kind' => $kind,
            'user_id' => $user->id, 'role' => $user->role, 'device_uuid' => $device, 'created_at' => $now,
            'item_index' => null, 'from_status' => null, 'to_status' => null, 'details' => null,
        ]);

        if (!$index) {
            $row += ['business_id' => $this->business->id, 'record_key' => $key, 'created_by' => $user->id, 'created_role' => $user->role,
                'weigh_status' => $mode === 'courier' ? 'pending' : null, 'created_at' => $now,
                'ready_at' => in_array($status, ['siap', 'telat'], true) ? $now : null];
            DB::table('order_index')->insert($row);
            $event('buat', ['to_status' => $status]);
            $this->payment($user, $outletId, $key, 0, $new, $event);
            return;
        }

        $from = $oldOrder ? OrderData::status($oldOrder) : (string) $index->status;
        if ($from !== $status && !$this->readyPair($from, $status)) {
            [$kind, $details] = $this->classify($new, $from, $status);
            $event($kind, ['from_status' => $from, 'to_status' => $status, 'details' => $details ? json_encode($details, JSON_UNESCAPED_UNICODE) : null]);
            if ($status === 'siap') $row['ready_at'] = $now;
        }
        if ($oldOrder) $this->itemEvents($oldOrder, $new, $event);

        // Kurir menimbang di lokasi → kasir memastikan timbangan saat memproses.
        if ($oldOrder && $mode === 'courier' && $from === 'jemput' && $this->quantities($oldOrder) !== $this->quantities($new)) {
            $row['weigh_status'] = 'pending'; $row['weigh_by'] = $user->id;
        }
        if ($index->weigh_status === 'pending' && $mode === 'full' && $status !== 'jemput') {
            $row['weigh_status'] = 'confirmed';
            $before = $oldOrder ? $this->quantities($oldOrder) : []; $after = $this->quantities($new);
            $event('timbang', ['details' => json_encode(['before' => $before, 'after' => $after, 'changed' => $before !== $after,
                'courier_id' => $index->weigh_by ?? $index->created_by], JSON_UNESCAPED_UNICODE)]);
        }
        DB::table('order_index')->where('id', $index->id)->update($row);
        $this->payment($user, $outletId, $key, $oldOrder ? OrderData::paid($oldOrder) : (int) $index->paid, $new, $event);
    }

    public function deleted(string $key): void {
        DB::table('order_index')->where('business_id', $this->business->id)->where('record_key', $key)->update(['deleted' => true, 'updated_at' => now()]);
    }

    /** Pembayaran bertambah: catat, dan bila tunai diterima kurir, masuk "dipegang kurir". */
    private function payment(User $user, int $outletId, string $key, int $before, array $new, \Closure $event): void {
        $amount = OrderData::paid($new) - $before;
        if ($amount <= 0) return;
        $payments = OrderData::payments($new);
        $last = $payments ? end($payments) : null;
        $method = (string) (($last['m'] ?? null) ?: ($new['card']['dataset']['method177'] ?? 'Tunai'));
        $event('bayar', ['details' => json_encode(['amount' => $amount, 'method' => $method], JSON_UNESCAPED_UNICODE)]);
        if ($user->orderMode() === 'courier' && mb_strtolower($method) === 'tunai') {
            DB::table('courier_ledger')->insert(['business_id' => $this->business->id, 'outlet_id' => $outletId, 'courier_id' => $user->id,
                'type' => 'collect', 'amount' => $amount, 'record_key' => $key, 'created_at' => now()]);
        }
    }

    /** @return array{0: string, 1: ?array} jenis peristiwa dan rinciannya */
    private function classify(array $order, string $from, string $to): array {
        if ($to === 'batal') return ['batal', null];
        $auto = OrderData::lastHistoryBy($order) === 'Otomatis';
        if ($from === 'batal') return ['mundur', ['reason' => $this->reason($order)]];
        $stages = $this->guard->stagesFor($order);
        $path = $this->guard->pathFor($order);
        $pos = fn (string $s) => array_search($s === 'telat' ? 'siap' : $s, $path, true);
        $a = $pos($from); $b = $pos($to);
        if ($a === false || $b === false) return ['maju', $auto ? ['auto' => true] : null]; // tahap di luar alur layanan ini
        if ($b < $a) return ['mundur', ['reason' => $this->reason($order)]];
        $skipped = array_values(array_intersect(array_slice($path, $a + 1, $b - $a - 1), $stages));
        if ($skipped) return ['lompat', ['skipped' => $skipped]];
        return ['maju', $auto ? ['auto' => true] : null];
    }

    /** Tahap per barang: catat setiap barang yang tahapnya berubah. */
    private function itemEvents(array $old, array $new, \Closure $event): void {
        $before = OrderData::items($old); $after = OrderData::items($new);
        foreach ($after as $i => $item) {
            $a = (string) ($before[$i]['st'] ?? ''); $b = (string) ($item['st'] ?? '');
            if ($b === '' || $a === $b) continue;
            $event('maju', ['item_index' => $i, 'from_status' => $a === '' ? null : $a, 'to_status' => $b,
                'details' => json_encode(['item' => (string) ($item['n'] ?? $item['name'] ?? '')], JSON_UNESCAPED_UNICODE)]);
        }
    }

    private function reason(array $order): ?string {
        $r = trim((string) ($order['detail']['backReason'] ?? ''));
        return $r === '' ? null : mb_substr($r, 0, 300);
    }

    private function quantities(array $order): array {
        return array_map(fn ($i) => ['n' => (string) ($i['n'] ?? $i['name'] ?? ''), 'qty' => (float) ($i['qty'] ?? 0)], OrderData::items($order));
    }

    private function readyPair(string $a, string $b): bool {
        return in_array($a, ['siap', 'telat'], true) && in_array($b, ['siap', 'telat'], true);
    }

    private function time(mixed $v): ?Carbon {
        if (!is_string($v) || $v === '') return null;
        try { return Carbon::parse($v)->utc(); } catch (\Throwable) { return null; }
    }
}
