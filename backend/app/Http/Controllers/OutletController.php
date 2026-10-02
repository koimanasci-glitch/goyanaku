<?php
namespace App\Http\Controllers;

use App\Models\Outlet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Owner adds branches within the package limit (1 pusat + cabang paket). */
class OutletController {
    public function store(Request $request) {
        $owner = $request->user();
        $data = $request->validate(['name' => 'required|string|max:120']);
        DB::transaction(function () use ($owner, $data) {
            $business = \App\Models\Business::whereKey($owner->business_id)->lockForUpdate()->firstOrFail();
            $access = $business->currentAccess();
            abort_if($access['read_only'], 403, 'Paket sudah berakhir.');
            if ($business->outlets()->count() >= $access['outlet_limit']) {
                throw ValidationException::withMessages(['name' => 'Paket '.$access['package'].' maksimal 1 pusat + '.$access['branches'].' cabang. Upgrade paket untuk menambah cabang.']);
            }
            $outlet = $business->outlets()->create(['name' => $data['name']]);
            DB::table('audit_events')->insert(['actor_id' => $owner->id, 'business_id' => $business->id, 'action' => 'outlet.created',
                'details' => json_encode(['outlet_id' => $outlet->id]), 'created_at' => now()]);
        });
        return back()->with('status', 'Cabang ditambahkan.');
    }
}
