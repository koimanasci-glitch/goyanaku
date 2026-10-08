<?php
namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Team;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;

/** Owner mengelola akun tim dari dashboard web. Aturannya ada di App\Support\Team (dipakai juga oleh API aplikasi). */
class TeamController {
    public function store(Request $request) {
        $owner = $request->user();
        if ($request->filled('email')) $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate(Team::rules($owner));
        $user = Team::create($owner, $data);
        return back()->with('status', 'Akun '.$user->name.' dibuat. Berikan '.($user->pin ? 'nomor HP dan PIN' : 'email dan password').' ke pegawai secara langsung.');
    }

    public function update(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        $rules = Team::rules($owner, $member);
        $data = $request->validate(['role' => $rules['role'], 'outlet_id' => $rules['outlet_id'], 'phone' => $rules['phone'], 'courier_key' => $rules['courier_key']]);
        if (!$request->has('phone')) unset($data['phone']);
        Team::update($owner, $member, $data);
        return back()->with('status', 'Peran/outlet '.$member->name.' diperbarui.');
    }

    public function deactivate(Request $request, User $member) {
        Team::deactivate($request->user(), $member);
        return back()->with('status', $member->name.' dinonaktifkan. Riwayat transaksi tetap tersimpan.');
    }

    public function activate(Request $request, User $member) {
        Team::activate($request->user(), $member);
        return back()->with('status', $member->name.' diaktifkan kembali.');
    }

    public function resetPassword(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        $data = $request->validate(['password' => ['required', Password::min(12)->letters()->numbers()]]);
        Team::setPassword($owner, $member, $data['password']);
        return back()->with('status', 'Password '.$member->name.' diganti. Sesi lama di HP keluar otomatis.');
    }

    public function resetPin(Request $request, User $member) {
        $owner = $request->user(); Team::guard($owner, $member);
        $data = $request->validate(['pin' => ['required', 'string', 'regex:/^\d{'.(int) config('goyana.pin.length').'}$/']]);
        Team::setPin($owner, $member, $data['pin']);
        return back()->with('status', 'PIN '.$member->name.' diganti. Sesi lama di HP keluar otomatis.');
    }
}
