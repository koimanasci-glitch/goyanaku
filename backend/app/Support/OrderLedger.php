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
            // Batal setelah ada pembayaran: dicatat nominalnya supaya muncul di laporan Koreksi Transaksi.
            if ($kind === 'batal' && $oldOrder && OrderData::paid($oldOrder) > 0) $details = ['paid' => OrderData::paid($oldOrder)];
            $event($kind, ['from_status' => $from, 'to_status' => $status, 'details' => $details ? json_encode($details, JSON_UNESCAPED_UNICODE) : null]);
            if ($status === 'siap') $row['ready_at'] = $now;
        }
        if ($oldOrder) $this->itemEvents($oldOrder, $new, $event);
        if ($oldOrder) $this->changeEvents($oldOrder, $new, $from, $event);

        // Kurir menimbang di lokasi → kasir memastikan timbangan saat memproses.
        if ($oldOrder && $mode === 'courier' && $from === 'jemput' && $this->quantities($oldOrder) !== $this->quantities($new)) {
            $row['weigh_status'] = 'pending'; $row['weigh_by'] = $user->id;
        }
        // Aplikasi baru menandai 'timbang' = 'cek' sampai kasir menekan "Timbangan Sesuai"; aplikasi lama tidak mengirim tanda itu.
        if ($index->weigh_status === 'pending' && $mode === 'full' && $status !== 'jemput' && ($new['card']['dataset']['timbang'] ?? 'ok') !== 'cek') {
            $row['weigh_status'] = 'confirmed';
            // Angka pembanding: timbangan kurir yang dicatat server; tanpa catatan itu (aplikasi lama) dipakai isi sebelum kiriman ini.
            $noted = json_decode((string) ($new['card']['dataset']['timbangAwal'] ?? ''), true);
            $before = is_array($noted) ? array_map(fn ($i) => ['n' => (string) ($i['n'] ?? ''), 'qty' => (float) ($i['qty'] ?? 0)], $noted)
                : ($oldOrder ? $this->quantities($oldOrder) : []);
            $after = $this->quantities($new);
            $event('timbang', ['details' => json_encode(['before' => $before, 'after' => $after, 'changed' => $before !== $after,
                'courier_id' => $index->weigh_by ?? $index->created_by], JSON_UNESCAPED_UNICODE)]);
        }
        DB::table('order_index')->where('id', $index->id)->update($row);
        $this->payment($user, $outletId, $key, $oldOrder ? OrderData::paid($oldOrder) : (int) $index->paid, $new, $event);
    }

    /**
     * Mengisi order_index untuk pesanan yang sudah ada di server sebelum catatan ini dibuat
     * (php artisan goyana:reindex-orders). Riwayat peristiwa lama tidak bisa direka ulang, jadi tidak dibuat.
     */
    public static function reindex(Business $business): int {
        $n = 0;
        $known = DB::table('order_index')->where('business_id', $business->id)->pluck('record_key')->flip();
        DB::table('sync_records')->where('business_id', $business->id)->where('collection', 'orders')->where('deleted', false)->whereNotNull('outlet_id')
            ->orderBy('id')->chunk(200, function ($rows) use ($business, $known, &$n) {
                foreach ($rows as $row) {
                    $d = json_decode((string) $row->data, true);
                    if (isset($known[$row->record_key]) || !OrderData::isOrder($d)) continue;
                    $status = OrderData::status($d); $time = fn ($v) => is_string($v) && $v !== '' ? rescue(fn () => \Illuminate\Support\Carbon::parse($v)->utc(), null, false) : null;
                    DB::table('order_index')->insert(['business_id' => $business->id, 'outlet_id' => $row->outlet_id, 'record_key' => $row->record_key, 'status' => $status,
                        'total' => max(0, OrderData::total($d)), 'paid' => max(0, OrderData::paid($d)), 'discount' => max(0, (int) ($d['card']['dataset']['disc'] ?? 0)),
                        'delivery' => OrderData::delivery($d), 'customer' => mb_substr(OrderData::customer($d), 0, 160) ?: null, 'customer_key' => OrderData::customerKey($d),
                        'courier_key' => OrderData::courier($d) ?: null, 'created_by' => $row->updated_by,
                        'ordered_at' => $time($d['card']['dataset']['created177'] ?? ($d['detail']['masuk'] ?? null)) ?? $row->created_at, 'due_at' => $time($d['detail']['due'] ?? null),
                        'ready_at' => in_array($status, ['siap', 'telat'], true) ? $row->updated_at : null, 'created_at' => now(), 'updated_at' => now()]);
                    $n++;
                }
            });
        return $n;
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

    /**
     * Riwayat Transaksi (keputusan Paduka 10 Oktober 2026, pengganti jatah koreksi): setiap perubahan isi atau nilai pesanan
     * yang sudah tersimpan dicatat sebelum → sesudah. "flag" = diubah setelah diproses atau setelah ada pembayaran.
     * Timbangan pertama penjemputan yang masih kosong bukan perubahan (dicatat sebagai pengisian).
     */
    private function changeEvents(array $old, array $new, string $from, \Closure $event): void {
        $a = $this->lines($old); $b = $this->lines($new);
        $ta = OrderData::total($old); $tb = OrderData::total($new);
        if ($a !== $b || $ta !== $tb) {
            $paidBefore = OrderData::paid($old);
            $first = $a === [] && $from === 'jemput';
            $event($first ? 'isi' : 'ubah', ['details' => json_encode([
                'before' => ['items' => $a, 'total' => $ta], 'after' => ['items' => $b, 'total' => $tb],
                'paid_before' => $paidBefore, 'stage' => $from,
                'flag' => !$first && ($paidBefore > 0 || !in_array($from, ['antrian', 'jemput'], true)),
            ], JSON_UNESCAPED_UNICODE)]);
        }
        $refund = OrderData::paid($old) - OrderData::paid($new);
        if ($refund > 0) $event('kembali', ['details' => json_encode(['amount' => $refund], JSON_UNESCAPED_UNICODE)]);
    }

    /** Isi pesanan untuk dibandingkan: nama, jumlah, harga satuan. */
    private function lines(array $order): array {
        return array_map(fn ($i) => ['n' => (string) ($i['n'] ?? $i['name'] ?? ''), 'q' => (float) ($i['qty'] ?? 0), 'p' => (int) round((float) ($i['price'] ?? $i['p'] ?? 0))],
            OrderData::items($order));
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
