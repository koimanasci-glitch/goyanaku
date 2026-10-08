<?php
namespace App\Http\Controllers;

use App\Models\{Outlet, SharedDevice};
use App\Support\{Outlets, Team};
use Illuminate\Http\Request;

/** Owner mengelola cabang dari dashboard web. Aturannya ada di App\Support\Outlets (dipakai juga oleh API aplikasi). */
class OutletController {
    public function store(Request $request) {
        $owner = $request->user();
        Outlets::create($owner, $request->validate(Outlets::rules($owner)));
        return back()->with('status', 'Cabang ditambahkan.');
    }

    public function update(Request $request, Outlet $outlet) {
        $owner = $request->user(); abort_unless($outlet->business_id === $owner->business_id, 404);
        // Pilihan "dikerjakan di outlet ini" dikirim sebagai teks kosong.
        if ($request->input('process_outlet_id') === '') $request->merge(['process_outlet_id' => null]);
        Outlets::update($owner, $outlet, $request->validate(Outlets::rules($owner, $outlet)));
        return back()->with('status', 'Data '.$outlet->name.' diperbarui.');
    }

    public function deactivate(Request $request, Outlet $outlet) {
        Outlets::deactivate($request->user(), $outlet);
        return back()->with('status', $outlet->name.' dinonaktifkan. Riwayatnya tetap tersimpan.');
    }

    public function activate(Request $request, Outlet $outlet) {
        Outlets::activate($request->user(), $outlet);
        return back()->with('status', $outlet->name.' diaktifkan lagi.');
    }

    /** Cabut HP outlet yang dipakai bergantian: pegawai tidak bisa lagi masuk dengan memilih nama di HP itu. */
    public function revokeShared(Request $request, SharedDevice $device) {
        $owner = $request->user(); abort_unless($device->business_id === $owner->business_id, 404);
        if (!$device->revoked_at) {
            $device->revoked_at = now(); $device->save();
            Team::audit($owner, 'device.shared_revoked', ['shared_device_id' => $device->id]);
        }
        return back()->with('status', 'HP outlet '.$device->label.' dicabut.');
    }

    /** Setelan usaha: boleh hutang (cucian diserahkan sebelum lunas) atau tidak. */
    public function settings(Request $request) {
        $owner = $request->user(); $business = $owner->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $business->allow_debt = $request->boolean('allow_debt'); $business->save();
        Team::audit($owner, 'business.settings', ['allow_debt' => $business->allow_debt]);
        return back()->with('status', $business->allow_debt ? 'Cucian boleh diserahkan sebelum lunas (hutang).' : 'Cucian hanya diserahkan setelah lunas.');
    }
}
