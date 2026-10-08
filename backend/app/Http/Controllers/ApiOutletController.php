<?php
namespace App\Http\Controllers;

use App\Models\{CashierDevice, Outlet, SharedDevice};
use App\Support\{Outlets, Team};
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/** Kelola Cabang, HP outlet, dan setelan usaha dari aplikasi (hanya owner). */
class ApiOutletController {
    public function index(Request $request) {
        $business = $request->user()->business; $access = $business->currentAccess();
        return response()->json([
            'outlets' => $business->outlets()->orderBy('id')->get()->map(fn (Outlet $o) => Outlets::present($o) + [
                'staff' => $business->users()->where('outlet_id', $o->id)->whereNull('deactivated_at')->count(),
            ])->values(),
            'limit' => $access['outlet_limit'], 'branches' => $access['branches'], 'package' => $access['package'], 'read_only' => $access['read_only'],
        ]);
    }

    public function store(Request $request) {
        $owner = $request->user();
        return response()->json(['outlet' => Outlets::present(Outlets::create($owner, $request->validate(Outlets::rules($owner))))], 201);
    }

    public function update(Request $request, Outlet $outlet) {
        $owner = $request->user(); abort_unless($outlet->business_id === $owner->business_id, 404);
        return response()->json(['outlet' => Outlets::present(Outlets::update($owner, $outlet, $request->validate(Outlets::rules($owner, $outlet))))]);
    }

    public function deactivate(Request $request, Outlet $outlet) {
        Outlets::deactivate($request->user(), $outlet);
        return response()->json(['outlet' => Outlets::present($outlet->fresh())]);
    }

    public function activate(Request $request, Outlet $outlet) {
        Outlets::activate($request->user(), $outlet);
        return response()->json(['outlet' => Outlets::present($outlet->fresh())]);
    }

    // ---------- HP ----------

    public function devices(Request $request) {
        $business = $request->user()->business;
        $ids = $business->outlets()->pluck('id');
        return response()->json([
            'limit_per_outlet' => $business->currentAccess()['cashier_device_limit'],
            'cashier' => CashierDevice::whereIn('outlet_id', $ids)->whereNull('revoked_at')->orderBy('outlet_id')->orderBy('slot')->get()
                ->map(fn ($d) => ['id' => $d->id, 'outlet_id' => $d->outlet_id, 'label' => $d->label, 'slot' => $d->slot,
                    'paired' => $d->device_uuid !== null, 'user_id' => $d->user_id, 'last_seen_at' => $d->last_seen_at ? (string) $d->last_seen_at : null])->values(),
            'shared' => SharedDevice::where('business_id', $business->id)->whereNull('revoked_at')->orderBy('outlet_id')->get()
                ->map(fn ($d) => ['id' => $d->id, 'outlet_id' => $d->outlet_id, 'label' => $d->label, 'last_seen_at' => $d->last_seen_at?->toIso8601String()])->values(),
        ]);
    }

    /** Owner mengikat HP ini ke outlet untuk dipakai bergantian. Kunci rahasia hanya dikirim sekali, ke HP itu. */
    public function bindShared(Request $request) {
        $owner = $request->user(); $business = $owner->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $data = $request->validate(['device_id' => 'required|string|min:8|max:64', 'outlet_id' => 'required|integer', 'label' => 'required|string|max:120']);
        $outlet = $business->outlets()->whereNull('deactivated_at')->whereKey($data['outlet_id'])->firstOrFail();
        SharedDevice::where('device_uuid', $data['device_id'])->whereNull('revoked_at')->where('business_id', $business->id)->update(['revoked_at' => now()]);
        $secret = Str::random(48);
        $device = new SharedDevice(['device_uuid' => $data['device_id'], 'label' => $data['label']]);
        $device->business_id = $business->id; $device->outlet_id = $outlet->id; $device->secret = $secret; $device->bound_by = $owner->id;
        $device->save();
        Team::audit($owner, 'device.shared_bound', ['shared_device_id' => $device->id, 'outlet_id' => $outlet->id]);
        return response()->json(['id' => $device->id, 'device_secret' => $secret, 'outlet' => Outlets::present($outlet)], 201);
    }

    public function revokeShared(Request $request, SharedDevice $device) {
        $owner = $request->user(); abort_unless($device->business_id === $owner->business_id, 404);
        if (!$device->revoked_at) {
            $device->revoked_at = now(); $device->save();
            Team::audit($owner, 'device.shared_revoked', ['shared_device_id' => $device->id]);
        }
        return response()->noContent();
    }

    public function revokeCashier(Request $request, CashierDevice $device) {
        $owner = $request->user(); abort_unless($device->outlet->business_id === $owner->business_id, 404);
        if (!$device->revoked_at) {
            $device->revoked_at = now(); $device->slot = null; $device->save();
            Team::audit($owner, 'device.revoked', ['device_id' => $device->id]);
        }
        return response()->noContent();
    }

    // ---------- setelan usaha ----------

    public function business(Request $request) {
        $owner = $request->user(); $business = $owner->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $data = $request->validate(['allow_debt' => 'required|boolean']);
        $business->allow_debt = (bool) $data['allow_debt']; $business->save();
        Team::audit($owner, 'business.settings', ['allow_debt' => $business->allow_debt]);
        return response()->json(['business' => ['id' => $business->id, 'name' => $business->name, 'allow_debt' => $business->allow_debt]]);
    }
}
