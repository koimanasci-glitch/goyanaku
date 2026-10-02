<?php
namespace App\Http\Controllers;

use App\Models\{Business, CashierDevice, Outlet, User};
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

    public function pull(Request $request) {
        $user = $this->user($request);
        $data = $request->validate(['cursor' => 'nullable|integer|min:0', 'limit' => 'nullable|integer|min:1|max:1000']);
        $cursor = (int) ($data['cursor'] ?? 0); $limit = (int) ($data['limit'] ?? 500);
        $readable = collect($this->rules())->filter(fn ($r) => $this->allowed($user, $r['read']))->keys()->all();
        $rows = DB::table('sync_records')->where('business_id', $user->business_id)->where('rev', '>', $cursor)
            ->orderBy('rev')->limit($limit + 1)->get();
        $more = $rows->count() > $limit; $rows = $rows->take($limit);
        $next = $rows->isEmpty() ? $cursor : (int) $rows->last()->rev;
        $visible = $rows->filter(function ($r) use ($user, $readable) {
            if (!in_array($r->collection, $readable, true)) return false;
            return $user->role === 'owner' || $r->outlet_id === null || (int) $r->outlet_id === $user->outlet_id;
        })->map(fn ($r) => $this->present($r))->values();
        $access = $user->business->currentAccess();
        return response()->json(['records' => $visible, 'cursor' => $next, 'more' => $more,
            'read_only' => $access['read_only'], 'server_time' => now()->toIso8601String()]);
    }

    public function push(Request $request) {
        $user = $this->user($request);
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
        }
        $deleted = (bool) ($change['deleted'] ?? false);
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
            return ['status' => 'conflict', 'record' => $this->present($existing)];
        }
        if (!$existing && $deleted) return ['status' => 'applied', 'rev' => 0];

        $rev++;
        $row = ['outlet_id' => $outletId ?? ($existing->outlet_id ?? null), 'data' => $json, 'deleted' => $deleted, 'rev' => $rev,
            'updated_by' => $user->id, 'device_uuid' => $device, 'updated_at' => now()];
        if ($existing) {
            DB::table('sync_records')->where('id', $existing->id)->update($row);
        } else {
            DB::table('sync_records')->insert($row + ['business_id' => $business->id, 'collection' => $change['collection'],
                'record_key' => $change['key'], 'created_at' => now()]);
        }
        return ['status' => 'applied', 'rev' => $rev];
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

    /** Max 2 cashier devices per outlet (GOYANA-ROADMAP.md §37). Returns true or a message. */
    private function claimDevice(User $user, Business $business, int $outletId, string $uuid): bool|string {
        $outlet = Outlet::whereKey($outletId)->lockForUpdate()->firstOrFail();
        $mine = CashierDevice::where('outlet_id', $outletId)->where('device_uuid', $uuid)->first();
        if ($mine) {
            if ($mine->revoked_at) return 'Perangkat ini sudah dicabut owner. Minta owner menambah slot baru.';
            $mine->last_seen_at = now(); $mine->user_id = $user->id; $mine->save();
            return true;
        }
        $limit = (int) config('goyana.cashier_devices_per_outlet');
        // A slot the owner created on the dashboard (no phone yet) is taken by the first phone.
        $free = CashierDevice::where('outlet_id', $outletId)->whereNull('revoked_at')->whereNull('device_uuid')->orderBy('slot')->first();
        if (!$free) {
            $used = CashierDevice::where('outlet_id', $outletId)->whereNull('revoked_at')->pluck('slot')->all();
            $slot = collect(range(1, $limit))->first(fn ($s) => !in_array($s, $used, true));
            if (!$slot) {
                DB::table('audit_events')->insert(['actor_id' => $user->id, 'business_id' => $business->id, 'action' => 'device.rejected',
                    'details' => json_encode(['outlet_id' => $outletId, 'device' => substr($uuid, 0, 12)]), 'created_at' => now()]);
                return 'Maksimal 2 perangkat kasir per outlet.';
            }
            $free = $outlet->devices()->create(['label' => $user->name.' · Android', 'slot' => $slot]);
        }
        $free->device_uuid = $uuid; $free->user_id = $user->id; $free->last_seen_at = now(); $free->save();
        DB::table('audit_events')->insert(['actor_id' => $user->id, 'business_id' => $business->id, 'action' => 'device.paired',
            'details' => json_encode(['device_id' => $free->id, 'outlet_id' => $outletId]), 'created_at' => now()]);
        return true;
    }
}
