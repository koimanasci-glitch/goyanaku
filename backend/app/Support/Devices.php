<?php
namespace App\Support;

use App\Models\{Business, CashierDevice, Outlet, User};
use Illuminate\Support\Facades\DB;

/** HP kasir per outlet: jumlahnya mengikuti paket (Trial/Basic 2, Silver 3, Gold 4, Platinum 5). */
final class Devices {
    /** Mengisi slot HP kasir untuk outlet ini. Mengembalikan nomor slot, atau pesan penolakan. Panggil di dalam transaksi. */
    public static function claim(User $user, Business $business, int $outletId, string $uuid): int|string {
        $outlet = Outlet::whereKey($outletId)->lockForUpdate()->firstOrFail();
        $mine = CashierDevice::where('outlet_id', $outletId)->where('device_uuid', $uuid)->first();
        if ($mine) {
            if ($mine->revoked_at) return 'Perangkat ini sudah dicabut owner. Minta owner menambah slot baru.';
            $mine->last_seen_at = now(); $mine->user_id = $user->id; $mine->save();
            return (int) $mine->slot;
        }
        $limit = (int) $business->currentAccess()['cashier_device_limit'];
        // Slot yang dibuat owner di dashboard (belum ada HP) diambil HP pertama.
        $free = CashierDevice::where('outlet_id', $outletId)->whereNull('revoked_at')->whereNull('device_uuid')->orderBy('slot')->first();
        if (!$free) {
            $used = CashierDevice::where('outlet_id', $outletId)->whereNull('revoked_at')->pluck('slot')->all();
            $slot = collect(range(1, $limit))->first(fn ($s) => !in_array($s, $used, true));
            if (!$slot) {
                DB::table('audit_events')->insert(['actor_id' => $user->id, 'business_id' => $business->id, 'action' => 'device.rejected',
                    'details' => json_encode(['outlet_id' => $outletId, 'device' => substr($uuid, 0, 12)]), 'created_at' => now()]);
                return 'Maksimal '.$limit.' perangkat kasir per outlet.';
            }
            $free = $outlet->devices()->create(['label' => $user->name.' · Android', 'slot' => $slot]);
        }
        $free->device_uuid = $uuid; $free->user_id = $user->id; $free->last_seen_at = now(); $free->save();
        DB::table('audit_events')->insert(['actor_id' => $user->id, 'business_id' => $business->id, 'action' => 'device.paired',
            'details' => json_encode(['device_id' => $free->id, 'outlet_id' => $outletId]), 'created_at' => now()]);
        return (int) $free->slot;
    }

    /** Slot HP ini bila sudah terpasang sebagai HP kasir di outlet tersebut. */
    public static function slot(int $outletId, string $uuid): ?int {
        $slot = CashierDevice::where('outlet_id', $outletId)->where('device_uuid', $uuid)->whereNull('revoked_at')->value('slot');
        return $slot === null ? null : (int) $slot;
    }
}
