<?php
namespace App\Http\Controllers;
use App\Models\CashierDevice;
use App\Models\Outlet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
class DeviceController {
    private function authorize(Request $request, Outlet $outlet): void {
        abort_unless(!$request->user()->is_platform_admin && $request->user()->business_id === $outlet->business_id, 403);
        abort_if($outlet->business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
    }
    public function store(Request $request, Outlet $outlet) {
        $this->authorize($request, $outlet);
        $data = $request->validate(['label' => 'required|string|max:120']);
        DB::transaction(function () use ($request, $outlet, $data) {
            $locked = Outlet::whereKey($outlet->id)->lockForUpdate()->firstOrFail();
            abort_if($locked->business->currentAccess()['read_only'], 403);
            $used = $locked->devices()->whereNull('revoked_at')->pluck('slot')->all();
            $slot = collect([1, 2])->first(fn ($slot) => !in_array($slot, $used, true));
            if (!$slot) throw ValidationException::withMessages(['label' => 'Maksimal dua perangkat kasir per outlet. Cabut perangkat lama terlebih dahulu.']);
            $device = $locked->devices()->create(['label' => $data['label'], 'slot' => $slot]);
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $outlet->business_id, 'action' => 'device.registered',
                'details' => json_encode(['device_id' => $device->id, 'outlet_id' => $outlet->id]), 'created_at' => now()]);
        });
        return back()->with('status', 'Slot perangkat kasir ditambahkan.');
    }
    public function revoke(Request $request, Outlet $outlet, CashierDevice $device) {
        // Revoke remains available when expired to let owners secure their account.
        abort_unless(!$request->user()->is_platform_admin && $request->user()->business_id === $outlet->business_id, 403);
        abort_unless($device->outlet_id === $outlet->id, 404);
        DB::transaction(function () use ($request, $outlet, $device) {
            Outlet::whereKey($outlet->id)->lockForUpdate()->firstOrFail();
            $locked = CashierDevice::whereKey($device->id)->lockForUpdate()->firstOrFail();
            if ($locked->revoked_at) return;
            $locked->revoked_at = now(); $locked->slot = null; $locked->save();
            DB::table('audit_events')->insert(['actor_id' => $request->user()->id, 'business_id' => $outlet->business_id, 'action' => 'device.revoked',
                'details' => json_encode(['device_id' => $device->id]), 'created_at' => now()]);
        });
        return back()->with('status', 'Akses perangkat dicabut.');
    }
}
