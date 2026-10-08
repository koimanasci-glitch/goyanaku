<?php
namespace App\Support;

use App\Models\{Business, User};
use Illuminate\Support\Facades\DB;

/**
 * Aturan pesanan yang ditegakkan server saat sinkronisasi (keputusan pengguna 8 Oktober 2026).
 *
 * Sebelumnya server menerima isi pesanan utuh dari siapa pun yang boleh mengubah status, sehingga
 * akun kurir atau pegawai bisa mengubah harga dan pembayaran lewat permintaan langsung. Sekarang:
 * - full (kasir, admin outlet, owner): boleh mengubah pesanan, melompati tahap, menandai Siap Ambil.
 * - production (pegawai): hanya memajukan satu tahap sampai Selesai Proses; kolom lain diabaikan.
 * - courier (kurir): hanya tugas yang ditunjuk kepadanya; jemput, antar, terima pembayaran,
 *   dan menimbang saat jemput dengan harga dari daftar harga.
 *
 * Hasil check(): string = ditolak; array {data, altered, message, quiet}:
 * data = isi yang disimpan, altered = berbeda dari kiriman HP (HP perlu mengambil versi server).
 */
final class OrderGuard {
    /** @var array<string, array<string, mixed>>|null nama layanan => data layanan */
    private ?array $services = null;
    /** @var array<string, array<string, mixed>>|null kunci kurir => data kurir */
    private ?array $couriers = null;

    public function __construct(private Business $business) {}

    /** @return array{data: mixed, altered: bool, message: ?string, quiet: bool}|string */
    public function check(User $user, int $outletId, mixed $old, mixed $new): array|string {
        $mode = $user->orderMode();
        if ($mode === 'none') return 'Akun ini tidak punya izin mengubah pesanan.';
        $oldOrder = OrderData::isOrder($old) ? $old : null;
        if (!OrderData::isOrder($new)) {
            // Kiriman tanpa bentuk pesanan hanya diterima dari akun yang boleh mengubah pesanan sepenuhnya.
            return $mode === 'full' ? $this->ok($new, $new) : 'Data pesanan tidak lengkap.';
        }
        return match ($mode) {
            'full' => $this->full($outletId, $oldOrder, $new),
            'production' => $this->production($oldOrder, $new),
            default => $this->courier($user, $oldOrder, $new),
        };
    }

    /** Tugas penjemputan: kurir hanya memperbarui status tugas yang ditunjuk kepadanya. */
    public function checkPickup(User $user, mixed $old, mixed $new): array|string {
        if ($user->orderMode() !== 'courier') return $this->ok($new, $new);
        if (!is_array($old)) return 'Tugas penjemputan dibuat oleh kasir atau owner.';
        if (!$user->courier_key || (string) ($old['courierId'] ?? '') !== $user->courier_key) return 'Tugas ini bukan milik Anda.';
        if (!is_array($new)) return 'Data penjemputan tidak lengkap.';
        $merged = $old;
        foreach (['status', 'orderId', 'arrivedAt', 'doneAt'] as $k) if (array_key_exists($k, $new)) $merged[$k] = $new[$k];
        return $this->ok($merged, $new);
    }

    // ---------- kasir / admin outlet / owner ----------

    private function full(int $outletId, ?array $old, array $new): array|string {
        $data = $new; $message = null;
        // Menunjuk kurir: kurir harus aktif dan terikat tepat pada outlet pesanan ini.
        $courier = OrderData::courier($new);
        if ($courier !== '' && $courier !== ($old ? OrderData::courier($old) : '')) {
            $problem = $this->courierProblem($courier, $outletId);
            if ($problem) {
                // Penunjukan saja yang tidak diterima; perubahan lain pada pesanan tetap tersimpan.
                if ($old && array_key_exists('courier181', $old['card']['dataset'])) $data['card']['dataset']['courier181'] = $old['card']['dataset']['courier181'];
                else unset($data['card']['dataset']['courier181']);
                $message = $problem;
            }
        }
        if ($debt = $this->debtProblem($old, $data)) return $old ? $this->revert($old, $new, $debt) : $debt;
        if ($old && config('goyana.orders.require_reason_for_backward') && $this->isBackward($data, OrderData::status($old), OrderData::status($data))
            && trim((string) ($data['detail']['backReason'] ?? '')) === '') {
            return $this->revert($old, $new, 'Isi alasan sebelum memundurkan tahap.');
        }
        return $this->ok($data, $new, $message);
    }

    // ---------- pegawai ----------

    private function production(?array $old, array $new): array|string {
        if (!$old) return 'Akun pegawai tidak bisa membuat pesanan.';
        $from = OrderData::status($old); $to = OrderData::status($new);
        $merged = $old;
        if ($this->sameReadyState($from, $to)) $merged = $this->acceptReadyState($merged, $new);
        if ($to !== $from && !$this->sameReadyState($from, $to)) {
            // Urutan umum semua tahap; tahap berikut = tahap pertama dalam alur layanan pesanan ini sesudah tahap sekarang.
            // Jadi pesanan yang sedang di tahap di luar alur layanannya (mis. "cuci" untuk layanan setrika saja) tetap bisa dimajukan.
            $done = config('goyana.orders.done_status');
            $order = array_merge(['antrian'], config('goyana.orders.stages'), [$done]);
            $at = array_search($from, $order, true);
            if ($at === false) return $this->revert($old, $new, 'Pesanan ini tidak sedang diproses.');
            if (!in_array($to, $order, true)) {
                return $this->revert($old, $new, in_array($to, ['siap', 'telat', 'diantar', 'diambil'], true)
                    ? 'Hanya kasir atau owner yang menandai Siap Ambil.' : 'Pegawai hanya bisa memajukan tahap proses.');
            }
            $next = null;
            foreach (array_merge($this->stagesFor($old), [$done]) as $stage) {
                if (array_search($stage, $order, true) > $at) { $next = $stage; break; }
            }
            if ($to !== $next) return $this->revert($old, $new, 'Pegawai hanya bisa memajukan satu tahap.');
            $merged['card']['dataset']['st'] = $to;
            $this->copy($merged, $new, ['card.dataset.ts133', 'detail.hist']);
        }
        $merged = $this->copyItemStages($merged, $new);
        return $this->ok($merged, $new);
    }

    // ---------- kurir ----------

    private function courier(User $user, ?array $old, array $new): array|string {
        $key = (string) $user->courier_key;
        if ($key === '') return 'Akun kurir belum terhubung ke data kurir. Hubungi owner.';
        if (!$old) return $this->courierCreates($key, $new);
        if (OrderData::courier($old) !== $key) return 'Tugas ini bukan milik Anda.';

        $from = OrderData::status($old); $to = OrderData::status($new);
        $merged = $old;
        if ($this->sameReadyState($from, $to)) $merged = $this->acceptReadyState($merged, $new);
        if ($to !== $from && !$this->sameReadyState($from, $to)) {
            $allowed = ($from === 'jemput' && $to === 'antrian')
                || (in_array($from, ['siap', 'telat'], true) && $to === 'diantar' && OrderData::delivery($old))
                || ($from === 'diantar' && $to === 'diambil');
            if (!$allowed) return $this->revert($old, $new, 'Kurir hanya bisa menjemput, mengantar, dan menyerahkan tugasnya.');
            $merged['card']['dataset']['st'] = $to;
            $this->copy($merged, $new, ['card.dataset.ts133', 'card.dataset.picked', 'detail.hist']);
        }

        // Menimbang di lokasi: selama masih Penjemputan, kurir boleh mengisi berat/jumlah dengan harga dari daftar harga.
        if ($from === 'jemput' && $this->itemsChanged($old, $new)) {
            $items = OrderData::items($new);
            if ($problem = $this->priceProblem($items, (string) ($old['detail']['dur'] ?? ''))) return $this->revert($old, $new, $problem);
            $merged['detail']['items'] = $items;
            $merged['card']['dataset']['items'] = json_encode($items, JSON_UNESCAPED_UNICODE);
            $merged['card']['total'] = OrderData::computedTotal($merged);
        }

        // Pembayaran di lokasi: hanya boleh bertambah, tidak melebihi total, riwayat lama tidak diubah.
        $paidOld = OrderData::paid($old); $paidNew = OrderData::paid($new);
        if ($paidNew !== $paidOld) {
            $total = OrderData::total($merged);
            $before = OrderData::payments($old); $after = OrderData::payments($new);
            if ($paidNew < $paidOld || $paidNew > $total || array_slice($after, 0, count($before)) !== $before) {
                return $this->revert($old, $new, 'Pembayaran tidak sesuai tagihan pesanan.');
            }
            $this->copy($merged, $new, ['card.dataset.paid177', 'card.dataset.payments178', 'card.dataset.method177', 'card.paid', 'card.payment', 'detail.paid']);
        }
        if ($debt = $this->debtProblem($old, $merged)) return $this->revert($old, $new, $debt);
        return $this->ok($merged, $new);
    }

    /** Transaksi baru yang dibuat kurir saat menjemput. */
    private function courierCreates(string $key, array $new): array|string {
        if (!in_array(OrderData::status($new), ['jemput', 'antrian'], true)) return 'Transaksi kurir harus dimulai dari penjemputan.';
        if (OrderData::discKey($new) !== '0') return 'Kurir tidak bisa memberi diskon.';
        $items = OrderData::items($new);
        if (!$items) return 'Isi layanan dan berat atau jumlahnya.';
        if ($problem = $this->priceProblem($items, (string) ($new['detail']['dur'] ?? ''))) return $problem;
        if (OrderData::ongkir($new) < 0) return 'Ongkos kirim tidak valid.';
        if (isset($new['card']['total']) && OrderData::total($new) !== OrderData::computedTotal($new)) return 'Total tidak sesuai daftar harga.';
        if (OrderData::paid($new) < 0 || OrderData::paid($new) > OrderData::computedTotal($new)) return 'Pembayaran tidak sesuai tagihan pesanan.';
        $data = $new;
        $data['card']['dataset']['courier181'] = $key; // transaksi jemput selalu tercatat atas nama kurir pembuatnya
        return $this->ok($data, $new);
    }

    // ---------- pemeriksaan bersama ----------

    /** Usaha yang tidak mengizinkan hutang: pesanan belum lunas tidak boleh diserahkan. */
    private function debtProblem(?array $old, array $new): ?string {
        if ($this->business->allow_debt) return null;
        if (OrderData::status($new) !== 'diambil' || ($old && OrderData::status($old) === 'diambil')) return null;
        $total = OrderData::total($new);
        return $total > 0 && OrderData::paid($new) < $total ? 'Pesanan belum lunas. Usaha ini tidak mengizinkan hutang.' : null;
    }

    /** Siap Ambil dan Telat Ambil dihitung otomatis dari waktu di setiap HP; perpindahan di antaranya bukan perubahan tahap. */
    private function sameReadyState(string $a, string $b): bool {
        return $a !== $b && in_array($a, ['siap', 'telat'], true) && in_array($b, ['siap', 'telat'], true);
    }

    private function acceptReadyState(array $merged, array $new): array {
        $merged['card']['dataset']['st'] = OrderData::status($new);
        $this->copy($merged, $new, ['detail.hist']);
        return $merged;
    }

    /** Tahap proses yang berlaku untuk pesanan ini, gabungan alur semua layanannya. */
    public function stagesFor(array $order): array {
        $all = config('goyana.orders.stages'); $names = config('goyana.orders.stage_names');
        $found = [];
        foreach (OrderData::items($order) as $item) {
            $service = $this->services()[mb_strtolower(trim((string) ($item['n'] ?? $item['name'] ?? '')))] ?? null;
            foreach ((array) ($service['proc'] ?? []) as $name) if (isset($names[$name])) $found[$names[$name]] = true;
        }
        return $found ? array_values(array_filter($all, fn ($s) => isset($found[$s]))) : $all;
    }

    /** Urutan lengkap pesanan ini, dari penjemputan sampai diambil. */
    public function pathFor(array $order): array {
        return array_merge(['jemput', 'antrian'], $this->stagesFor($order), [config('goyana.orders.done_status'), 'siap', 'diantar', 'diambil']);
    }

    public function isBackward(array $order, string $from, string $to): bool {
        if ($from === 'batal') return true;
        $path = $this->pathFor($order);
        $a = array_search($from === 'telat' ? 'siap' : $from, $path, true); $b = array_search($to === 'telat' ? 'siap' : $to, $path, true);
        return $a !== false && $b !== false && $b < $a;
    }

    /** Tahap untuk satu barang. */
    public function stagesForItem(array $item): array {
        $all = config('goyana.orders.stages'); $names = config('goyana.orders.stage_names');
        $service = $this->services()[mb_strtolower(trim((string) ($item['n'] ?? $item['name'] ?? '')))] ?? null;
        $found = [];
        foreach ((array) ($service['proc'] ?? []) as $name) if (isset($names[$name])) $found[$names[$name]] = true;
        return $found ? array_values(array_filter($all, fn ($s) => isset($found[$s]))) : $all;
    }

    /** Harga setiap barang harus sama dengan daftar harga usaha untuk durasi pesanan. */
    private function priceProblem(array $items, string $dur): ?string {
        foreach ($items as $item) {
            $name = trim((string) ($item['n'] ?? $item['name'] ?? ''));
            $service = $this->services()[mb_strtolower($name)] ?? null;
            if (!$service) return 'Layanan "'.$name.'" tidak ada di daftar harga.';
            $qty = (float) ($item['qty'] ?? 0); $price = (int) round((float) ($item['price'] ?? 0));
            if ($qty <= 0) return 'Berat atau jumlah "'.$name.'" belum diisi.';
            $prices = array_map(fn ($p) => (int) round((float) $p), (array) ($service['prices'] ?? []));
            $expected = $prices[$dur] ?? null;
            if ($expected !== null ? $price !== $expected : !in_array($price, $prices, true)) return 'Harga "'.$name.'" tidak sesuai daftar harga.';
        }
        return null;
    }

    private function itemsChanged(array $old, array $new): bool {
        $strip = fn (array $items) => array_map(fn ($i) => [(string) ($i['n'] ?? $i['name'] ?? ''), (float) ($i['qty'] ?? 0), (float) ($i['price'] ?? 0)], $items);
        return $strip(OrderData::items($old)) !== $strip(OrderData::items($new));
    }

    /** Tahap per barang (disimpan server; tampilan aplikasi menyusul). Barang lain dan harganya tidak ikut berubah. */
    private function copyItemStages(array $merged, array $new): array {
        $statuses = config('goyana.orders.statuses');
        $items = $merged['detail']['items'] ?? null; $incoming = $new['detail']['items'] ?? null;
        if (!is_array($items) || !is_array($incoming)) return $merged;
        foreach ($items as $i => $item) {
            $st = is_array($incoming[$i] ?? null) ? ($incoming[$i]['st'] ?? null) : null;
            if (!is_string($st) || !in_array($st, $statuses, true) || !is_array($item)) continue;
            $stages = array_merge(['antrian'], $this->stagesForItem($item), [config('goyana.orders.done_status')]);
            $a = array_search((string) ($item['st'] ?? 'antrian'), $stages, true); $b = array_search($st, $stages, true);
            if ($a !== false && $b === $a + 1) $merged['detail']['items'][$i]['st'] = $st;
        }
        return $merged;
    }

    /** Kurir lama yang tercentang banyak outlet atau "Semua Outlet" belum bisa menerima tugas sampai owner memilihkan satu. */
    public function courierProblem(string $key, int $outletId): ?string {
        $courier = $this->couriers()[$key] ?? null;
        // Data kurir bisa tiba setelah pesanannya (urutan kirim HP); yang belum dikenal server tidak dihalangi.
        if (!$courier) return null;
        if (!empty($courier['deleted'])) return 'Kurir sudah dihapus.';
        $name = (string) ($courier['name'] ?? 'Kurir');
        if (($courier['active'] ?? true) === false) return $name.' sedang nonaktif.';
        $outlets = array_values(array_map('strval', (array) ($courier['outlets'] ?? [])));
        if (count($outlets) !== 1) return $name.' belum punya outlet. Owner perlu memilih satu outlet di Management Kurir.';
        if ($outlets[0] !== 'srv-'.$outletId) return $name.' terikat ke outlet lain.';
        return null;
    }

    // ---------- alat ----------

    private function ok(mixed $data, mixed $sent, ?string $message = null): array {
        return ['data' => $data, 'altered' => self::canon($data) !== self::canon($sent), 'message' => $message, 'quiet' => false];
    }

    /**
     * Kiriman tidak diterima; HP diminta kembali ke versi server.
     * quiet: perubahan berasal dari status otomatis aplikasi (riwayat terakhir "Otomatis"), yang akan
     * diulang HP itu terus-menerus bila dikembalikan. Perubahan seperti itu cukup diabaikan server.
     */
    private function revert(array $old, mixed $sent, string $message): array {
        $auto = is_array($sent) && OrderData::lastHistoryBy($sent) === 'Otomatis';
        return ['data' => $old, 'altered' => true, 'message' => $message, 'quiet' => $auto];
    }

    private function copy(array &$target, array $source, array $paths): void {
        foreach ($paths as $path) {
            $keys = explode('.', $path); $from = $source; $found = true;
            foreach ($keys as $k) {
                if (!is_array($from) || !array_key_exists($k, $from)) { $found = false; break; }
                $from = $from[$k];
            }
            if (!$found) continue;
            $ref = &$target;
            foreach ($keys as $k) {
                if (!is_array($ref)) $ref = [];
                if (!array_key_exists($k, $ref)) $ref[$k] = null;
                $ref = &$ref[$k];
            }
            $ref = $from; unset($ref);
        }
    }

    /** JSON dengan kunci terurut, untuk membandingkan isi tanpa terpengaruh urutan kunci. */
    public static function canon(mixed $v): string { return (string) json_encode(self::sorted($v), JSON_UNESCAPED_UNICODE); }

    private static function sorted(mixed $v): mixed {
        if (!is_array($v)) return $v;
        if (!array_is_list($v)) ksort($v);
        return array_map([self::class, 'sorted'], $v);
    }

    private function collection(string $name): array {
        $out = [];
        $rows = DB::table('sync_records')->where('business_id', $this->business->id)->where('collection', $name)->where('deleted', false)->get(['record_key', 'data']);
        foreach ($rows as $row) { $d = json_decode((string) $row->data, true); if (is_array($d)) $out[$row->record_key] = $d; }
        return $out;
    }

    private function services(): array {
        if ($this->services === null) {
            $this->services = [];
            foreach ($this->collection('services') as $service) {
                $name = mb_strtolower(trim((string) ($service['name'] ?? '')));
                if ($name !== '') $this->services[$name] = $service;
            }
        }
        return $this->services;
    }

    private function couriers(): array { return $this->couriers ??= $this->collection('couriers'); }

    /** Dipanggil setelah data kurir atau layanan berubah dalam permintaan yang sama. */
    public function forget(): void { $this->services = null; $this->couriers = null; }
}
