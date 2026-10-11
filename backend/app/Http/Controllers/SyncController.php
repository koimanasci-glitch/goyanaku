<?php
namespace App\Http\Controllers;

use App\Models\{Business, CashierDevice, Outlet, User};
use App\Support\{AuditTrail, BranchTask, CaseGuard, Devices, OrderData, OrderGuard, OrderLedger, StockGuard};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Offline-first sync for the Android app (GOYANA-SISTEM-PUSAT.md §38).
 *
 * The phone keeps working on local data. It pushes changed records with a unique op_id
 * (safe to retry) and the server revision it last saw (base_rev). If someone else changed
 * the record meanwhile, the server keeps its copy, stores the phone's copy in
 * sync_conflicts and returns the server copy, so nothing is silently lost.
 * Pull returns everything changed after the phone's cursor, filtered by role and outlet.
 */
class SyncController {
    /** @var array<int, OrderGuard> */
    private array $guards = [];

    private function rules(): array { return config('goyana.sync.collections'); }

    private function allowed(User $user, array $permissions): bool {
        if ($user->role === 'owner') return true;
        if (in_array('*', $permissions, true)) return true;
        foreach ($permissions as $p) if ($p !== 'owner' && $user->hasPermission($p)) return true;
        return false;
    }

    private function user(Request $request): User {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->isActive(), 403, 'Akun dinonaktifkan.');
        abort_unless($user->tokenCan('business:read'), 403);
        return $user;
    }

    private function outletKey(?int $id): ?string { return $id ? 'srv-'.$id : null; }

    private function present(object $r): array {
        return [
            'collection' => $r->collection, 'key' => $r->record_key, 'outlet' => $this->outletKey($r->outlet_id),
            'data' => $r->deleted ? null : json_decode($r->data, true), 'deleted' => (bool) $r->deleted,
            'rev' => (int) $r->rev, 'updated_at' => (string) $r->updated_at,
        ];
    }

    /** Versi server yang dikembalikan ke HP (bentrok atau kiriman tidak diterima) juga mengikuti peran, sama seperti saat tarik data. */
    private function presentFor(User $user, object $row): array {
        return $this->forRole($user, collect([$this->present($row)]))->first();
    }

    public function pull(Request $request) {
        $user = $this->user($request);
        \App\Support\StaffRights::forget();
        $data = $request->validate(['cursor' => 'nullable|integer|min:0', 'limit' => 'nullable|integer|min:1|max:1000']);
        $cursor = (int) ($data['cursor'] ?? 0); $limit = (int) ($data['limit'] ?? 500);
        $readable = collect($this->rules())->filter(fn ($r) => $this->allowed($user, $r['read']))->keys()->all();
        $rows = DB::table('sync_records')->where('business_id', $user->business_id)->where('rev', '>', $cursor)
            ->orderBy('rev')->limit($limit + 1)->get();
        $more = $rows->count() > $limit; $rows = $rows->take($limit);
        $next = $rows->isEmpty() ? $cursor : (int) $rows->last()->rev;
        $visible = $rows->filter(function ($r) use ($user, $readable) {
            if (!in_array($r->collection, $readable, true)) return false;
            // Kiriman bahan antar cabang: staf hanya melihat yang dari/ke cabangnya.
            if ($r->collection === 'branch_tasks' && !$r->deleted && !BranchTask::visible($user, json_decode((string) $r->data, true))) return false;
            if ($r->collection === 'stock_transfers' && !$r->deleted && !StockGuard::visibleTransfer($user, json_decode((string) $r->data, true))) return false;
            return $user->role === 'owner' || $r->outlet_id === null || (int) $r->outlet_id === $user->outlet_id;
        })->map(fn ($r) => $this->present($r))->values();
        $visible = $this->forRole($user, $visible);
        $access = $user->business->currentAccess();
        return response()->json(['records' => $visible, 'cursor' => $next, 'more' => $more,
            'read_only' => $access['read_only'], 'server_time' => now()->toIso8601String()]);
    }

    /**
     * Isi yang dikirim ke HP mengikuti peran (keputusan pengguna 8 Oktober 2026):
     * - Kurir hanya menerima pesanan dan penjemputan yang ditunjuk kepadanya, dilengkapi alamat pelanggan.
     *   Yang bukan tugasnya dikirim sebagai tanda hapus, supaya tugas yang dialihkan hilang dari HP-nya.
     * - Pegawai menerima pesanan tanpa harga, pembayaran, dan nomor HP pelanggan.
     */
    private function forRole(User $user, $records) {
        $mode = $user->orderMode();
        if ($mode === 'full') return $records;
        $gone = fn (array $r) => ['data' => null, 'deleted' => true] + $r;
        if ($mode === 'courier') {
            $key = (string) $user->courier_key;
            $records = $records->map(function (array $r) use ($key, $gone) {
                if ($r['deleted']) return $r;
                if ($r['collection'] === 'orders') return $key !== '' && OrderData::isOrder($r['data']) && OrderData::courier($r['data']) === $key ? $r : $gone($r);
                if ($r['collection'] === 'pickups') return $key !== '' && is_array($r['data']) && (string) ($r['data']['courierId'] ?? '') === $key ? $r : $gone($r);
                return $r;
            });
            $keys = $records->filter(fn ($r) => $r['collection'] === 'orders' && !$r['deleted'])->map(fn ($r) => OrderData::customerKey($r['data']))->filter()->unique()->values();
            if ($keys->isEmpty()) return $records->values();
            $customers = DB::table('sync_records')->where('business_id', $user->business_id)->where('collection', 'customers')
                ->where('deleted', false)->whereIn('record_key', $keys->all())->pluck('data', 'record_key')->map(fn ($d) => json_decode((string) $d, true));
            return $records->map(function (array $r) use ($customers) {
                if ($r['collection'] !== 'orders' || $r['deleted']) return $r;
                $c = $customers[OrderData::customerKey($r['data'])] ?? null;
                if (is_array($c)) { $r['data']['detail']['address'] = (string) ($c['address'] ?? ''); $r['data']['detail']['maps'] = (string) ($c['maps'] ?? ''); }
                return $r;
            })->values();
        }
        // Hak akses pegawai per cabang (StaffRights): nomor HP dan nilai pesanan hanya dikirim bila pemilik mengizinkan.
        $business = $user->business;
        return $records->map(function (array $r) use ($business) {
            if ($r['collection'] !== 'orders' || $r['deleted'] || !OrderData::isOrder($r['data'])) return $r;
            $rights = \App\Support\StaffRights::pegawai($business, preg_match('/^srv-(\d+)$/', (string) ($r['outlet'] ?? ''), $m) ? (int) $m[1] : null);
            $d = $r['data'];
            if (!$rights['phone']) unset($d['detail']['phone']);
            if (!$rights['price']) {
                unset($d['card']['total'], $d['card']['paid'], $d['card']['payment'], $d['detail']['paid'], $d['detail']['discKey'], $d['detail']['ongkir']);
                foreach (['paid177', 'payments178', 'method177', 'disc', 'transport183', 'items'] as $k) unset($d['card']['dataset'][$k]);
                if (is_array($d['detail']['items'] ?? null)) {
                    $d['detail']['items'] = array_map(function ($i) { if (is_array($i)) unset($i['price']); return $i; }, $d['detail']['items']);
                }
            }
            $r['data'] = $d;
            return $r;
        })->values();
    }

    public function push(Request $request) {
        $user = $this->user($request);
        $this->allows = [];
        $max = (int) config('goyana.sync.max_changes');
        $data = $request->validate([
            'device_id' => 'required|string|min:8|max:64',
            'changes' => "required|array|max:$max",
            'changes.*.op_id' => 'required|string|min:8|max:64',
            'changes.*.collection' => 'required|string|max:40',
            'changes.*.key' => 'required|string|max:160',
            'changes.*.outlet' => 'nullable|string|max:40',
            'changes.*.deleted' => 'boolean',
            'changes.*.data' => 'nullable',
            'changes.*.base_rev' => 'nullable|integer|min:0',
        ]);
        $device = $data['device_id'];
        $this->guards = []; // aturan dibaca ulang setiap permintaan
        \App\Support\StaffRights::forget();

        $results = DB::transaction(function () use ($user, $data, $device) {
            $business = Business::whereKey($user->business_id)->lockForUpdate()->firstOrFail();
            $access = $business->currentAccess();
            $rev = (int) DB::table('sync_records')->where('business_id', $business->id)->max('rev');
            $deviceOk = [];
            $out = [];
            foreach ($data['changes'] as $change) {
                $done = DB::table('sync_ops')->where('business_id', $business->id)->where('op_id', $change['op_id'])->value('result');
                if ($done) { $out[] = json_decode($done, true); continue; }
                $result = $this->apply($user, $business, $access, $change, $device, $rev, $deviceOk);
                $result['op_id'] = $change['op_id'];
                // Rejections are not recorded so the phone can retry after the cause is fixed.
                if ($result['status'] !== 'rejected') {
                    DB::table('sync_ops')->insert(['business_id' => $business->id, 'op_id' => $change['op_id'],
                        'result' => json_encode($result), 'created_at' => now()]);
                }
                $out[] = $result;
            }
            return $out;
        });
        return response()->json(['results' => $results]);
    }

    private function apply(User $user, Business $business, array $access, array $change, string $device, int &$rev, array &$deviceOk): array {
        $rule = $this->rules()[$change['collection']] ?? null;
        if (!$rule) return $this->reject('Jenis data tidak dikenal.');
        if ($access['read_only']) return $this->reject('Paket sudah berakhir. Data hanya bisa dilihat.');
        if (!$this->allowed($user, $rule['write'])) return $this->reject('Akun ini tidak punya izin mengubah data ini.');

        $outletId = null;
        if ($rule['scope'] === 'outlet') {
            $outletId = $this->resolveOutlet($user, $business, $change['outlet'] ?? null);
            if (!$outletId) return $this->reject('Outlet tidak valid untuk akun ini.');
            if (Outlet::whereKey($outletId)->whereNotNull('deactivated_at')->exists()) return $this->reject('Cabang ini sudah dinonaktifkan owner.');
        }
        $deleted = (bool) ($change['deleted'] ?? false);
        // Fitur per paket: data baru untuk fitur yang belum termasuk paket ditolak (menghapus tetap boleh).
        if (!$deleted && ($feature = self::planFeature($change['collection'], (string) $change['key'])) && !($this->allows[$business->id][$feature] ??= $business->allows($feature))) {
            return $this->reject(self::FEATURE_TEXT[$feature]);
        }
        $json = $deleted ? null : json_encode($change['data'] ?? null, JSON_UNESCAPED_UNICODE);
        if (!$deleted && ($json === false || $json === 'null')) return $this->reject('Data kosong.');
        if ($json !== null && strlen($json) > (int) config('goyana.sync.max_record_bytes')) return $this->reject('Data terlalu besar.');

        $existing = DB::table('sync_records')->where('business_id', $business->id)
            ->where('collection', $change['collection'])->where('record_key', $change['key'])->first();
        if ($existing && $existing->outlet_id && $user->role !== 'owner' && (int) $existing->outlet_id !== $user->outlet_id) {
            return $this->reject('Data milik outlet lain.');
        }

        $cashier = $user->hasPermission('orders.create') || $user->hasPermission('payments.receive') || $user->hasPermission('cash.manage');
        if (!empty($rule['transactional']) && $cashier) {
            $slotOutlet = $outletId ?? $user->outlet_id ?? $business->outlets()->orderBy('id')->value('id');
            if (!isset($deviceOk[$slotOutlet])) $deviceOk[$slotOutlet] = $this->claimDevice($user, $business, $slotOutlet, $device);
            if ($deviceOk[$slotOutlet] !== true) return $this->reject($deviceOk[$slotOutlet]);
        }

        $base = $change['base_rev'] ?? null;
        if ($existing && (int) $existing->rev !== (int) ($base ?? 0)) {
            if ($existing->data === $json && (bool) $existing->deleted === $deleted) {
                return ['status' => 'applied', 'rev' => (int) $existing->rev];
            }
            DB::table('sync_conflicts')->insert(['business_id' => $business->id, 'collection' => $change['collection'],
                'record_key' => $change['key'], 'losing_data' => $json, 'user_id' => $user->id, 'device_uuid' => $device, 'created_at' => now()]);
            return ['status' => 'conflict', 'record' => $this->presentFor($user, $existing)];
        }
        if (!$existing && $deleted) return ['status' => 'applied', 'rev' => 0];
        // QRIS: hanya pemilik yang baru konfirmasi password/kode (App\Support\QrisGuard). Isi yang sama tidak dianggap perubahan.
        if (!($existing && $existing->data === $json && (bool) $existing->deleted === $deleted)
            && ($problem = \App\Support\QrisGuard::problem($user, (string) $change['collection'], (string) $change['key']))) return $this->reject($problem);

        if ($change['collection'] === 'crm') {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            if ($problem = \App\Support\CrmGuard::problem($user, (string) $change['key'], $before, $change['data'] ?? null, $deleted)) return $this->reject($problem);
        }

        // Stok per cabang: catatan stok tidak bisa diubah staf; kiriman antar cabang diterima oleh cabang tujuan.
        if ($change['collection'] === 'stock_ledger' && $user->role === 'produksi' && !\App\Support\StaffRights::pegawai($business, $user->outlet_id ? (int) $user->outlet_id : null)['stock']) {
            return $this->reject('Pegawai di cabang ini tidak diizinkan mencatat stok.');
        }
        if ($change['collection'] === 'stock_ledger') {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            $checked = StockGuard::ledger($user, (int) $outletId, $before, $change['data'] ?? null, $deleted);
            if (is_string($checked)) return $this->reject($checked);
            if (!$deleted) $json = json_encode($checked, JSON_UNESCAPED_UNICODE);
        }
        if ($change['collection'] === 'audit') {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            $checked = AuditTrail::check($user, $before, $change['data'] ?? null, $deleted);
            if (is_string($checked)) return $this->reject($checked);
            if ($before !== null) return ['status' => 'applied', 'rev' => (int) $existing->rev];
            $json = json_encode($checked, JSON_UNESCAPED_UNICODE);
        }
        if (in_array($change['collection'], ['complaints', 'order_photos'], true)) {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            $checked = $change['collection'] === 'complaints'
                ? CaseGuard::complaint($user, $before, $change['data'] ?? null, $deleted)
                : CaseGuard::photo($user, $before, $change['data'] ?? null, $deleted);
            if (is_string($checked)) return $this->reject($checked);
            if (!$deleted) $json = json_encode($checked, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        }
        if ($change['collection'] === 'branch_tasks') {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            $checked = BranchTask::check($user, $device, (int) $outletId, $before, $change['data'] ?? null, $deleted);
            if (is_string($checked)) return $this->reject($checked);
            if (!$deleted) $json = json_encode($checked, JSON_UNESCAPED_UNICODE);
        }
        if ($change['collection'] === 'stock_transfers') {
            $before = $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
            if ($problem = StockGuard::transfer($user, $business, $before, $change['data'] ?? null, $deleted)) return $this->reject($problem);
        }

        // Pesanan dan penjemputan: server menegakkan hak tiap peran, bukan menerima kiriman HP apa adanya.
        $guarded = in_array($change['collection'], ['orders', 'pickups'], true);
        $old = $guarded && $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null;
        $verdict = null;
        if ($guarded && $deleted && $user->orderMode() !== 'full') return $this->reject('Hanya kasir atau owner yang bisa menghapus data ini.');
        if ($guarded && !$deleted) {
            $guard = $this->guards[$business->id] ??= new OrderGuard($business);
            $verdict = $change['collection'] === 'orders'
                ? $guard->check($user, (int) $outletId, $old, $change['data'] ?? null)
                : $guard->checkPickup($user, $old, $change['data'] ?? null);
            if (is_string($verdict)) return $this->reject($verdict);
            $json = json_encode($verdict['data'], JSON_UNESCAPED_UNICODE);
            if ($existing && !$existing->deleted && OrderGuard::canon($verdict['data']) === OrderGuard::canon($old)) {
                // Tidak ada yang berubah di server. HP yang kirimannya tidak diterima diminta mengambil versi server.
                if (!$verdict['altered'] || $verdict['quiet']) return ['status' => 'applied', 'rev' => (int) $existing->rev];
                return ['status' => 'conflict', 'record' => $this->presentFor($user, $existing), 'message' => $verdict['message']];
            }
        }

        $rev++;
        $row = ['outlet_id' => $outletId ?? ($existing->outlet_id ?? null), 'data' => $json, 'deleted' => $deleted, 'rev' => $rev,
            'updated_by' => $user->id, 'device_uuid' => $device, 'updated_at' => now()];
        if ($existing) {
            DB::table('sync_records')->where('id', $existing->id)->update($row);
        } else {
            DB::table('sync_records')->insert($row + ['business_id' => $business->id, 'collection' => $change['collection'],
                'record_key' => $change['key'], 'created_at' => now()]);
        }
        if (in_array($change['collection'], ['services', 'couriers', 'settings', 'crm'], true)) ($this->guards[$business->id] ?? null)?->forget();
        if ($change['collection'] === 'settings') \App\Support\StaffRights::forget();
        // Profil outlet yang diubah owner di aplikasi (nama, alamat, nomor) ikut memperbarui data cabang di server.
        if ($change['collection'] === 'outlet_profiles' && !$deleted) \App\Support\Outlets::fromProfile($business, (string) $change['key'], $change['data'] ?? null);
        if ($change['collection'] === 'orders') {
            $ledger = new OrderLedger($business, $this->guards[$business->id] ??= new OrderGuard($business));
            $deleted ? $ledger->deleted($change['key']) : $ledger->record($user, (int) $row['outlet_id'], $change['key'], $old, $verdict['data'], $device);
        }
        if ($verdict && $verdict['altered']) {
            $stored = DB::table('sync_records')->where('business_id', $business->id)->where('collection', $change['collection'])->where('record_key', $change['key'])->first();
            return ['status' => 'conflict', 'record' => $this->presentFor($user, $stored), 'message' => $verdict['message']];
        }
        return ['status' => 'applied', 'rev' => $rev];
    }

    private array $allows = [];
    private const FEATURE_TEXT = [
        'suppliers' => 'Supplier & belanja bahan membutuhkan paket Silver.',
        'loyalty' => 'Poin & voucher pelanggan membutuhkan paket Gold.',
    ];

    private static function planFeature(string $collection, string $key): ?string {
        if (in_array($collection, ['stock_suppliers', 'stock_purchases'], true)) return 'suppliers';
        if ($collection === 'crm' && (str_starts_with($key, 'voucher:') || str_starts_with($key, 'redeemed:'))) return 'loyalty';
        return null;
    }

    private function reject(string $message): array { return ['status' => 'rejected', 'message' => $message]; }

    private function resolveOutlet(User $user, Business $business, ?string $key): ?int {
        if ($user->role !== 'owner') return $user->outlet_id;
        if ($key && preg_match('/^srv-(\d+)$/', $key, $m)) {
            $id = (int) $m[1];
            return Outlet::whereKey($id)->where('business_id', $business->id)->exists() ? $id : null;
        }
        // Old local outlet ids from before the phone was connected go to the main outlet.
        return $business->outlets()->orderBy('id')->value('id');
    }

    /** Batas HP kasir per outlet mengikuti paket (App\Support\Devices). Mengembalikan true atau pesan penolakan. */
    private function claimDevice(User $user, Business $business, int $outletId, string $uuid): bool|string {
        $slot = Devices::claim($user, $business, $outletId, $uuid);
        return is_string($slot) ? $slot : true;
    }
}
