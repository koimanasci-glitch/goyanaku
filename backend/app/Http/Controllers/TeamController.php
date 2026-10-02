<?php
namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/** Owner creates staff accounts (kasir, produksi, kurir, admin outlet) — GOYANA-ROADMAP.md §37. */
class TeamController {
    private function roles(): array { return array_values(array_diff(array_keys(config('goyana.roles')), ['owner'])); }

    public function store(Request $request) {
        $owner = $request->user(); $business = $owner->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $request->merge(['email' => mb_strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'email' => 'required|email|max:254|unique:users,email',
            'role' => ['required', Rule::in($this->roles())],
            'outlet_id' => ['required', 'integer', Rule::exists('outlets', 'id')->where('business_id', $business->id)],
            'password' => ['required', Password::min(12)->letters()->numbers()],
        ]);
        DB::transaction(function () use ($owner, $business, $data) {
            $user = new User(['name' => $data['name'], 'email' => $data['email'], 'password' => $data['password']]);
            $user->business_id = $business->id; $user->role = $data['role']; $user->outlet_id = (int) $data['outlet_id'];
            $user->email_verified_at = now(); // created by a verified owner; password is set by owner
            $user->save();
            $this->audit($owner, 'team.created', ['user_id' => $user->id, 'role' => $user->role, 'outlet_id' => $user->outlet_id]);
        });
        return back()->with('status', 'Akun '.$data['name'].' dibuat. Berikan email dan password ke pegawai secara langsung.');
    }

    public function update(Request $request, User $member) {
        $owner = $request->user(); $this->guard($owner, $member);
        $data = $request->validate([
            'role' => ['required', Rule::in($this->roles())],
            'outlet_id' => ['required', 'integer', Rule::exists('outlets', 'id')->where('business_id', $owner->business_id)],
        ]);
        $before = ['role' => $member->role, 'outlet_id' => $member->outlet_id];
        $member->role = $data['role']; $member->outlet_id = (int) $data['outlet_id']; $member->save();
        $member->tokens()->delete(); // new permissions apply on next login
        $this->audit($owner, 'team.updated', ['user_id' => $member->id, 'before' => $before, 'after' => $data]);
        return back()->with('status', 'Peran/outlet '.$member->name.' diperbarui.');
    }

    public function deactivate(Request $request, User $member) {
        $owner = $request->user(); $this->guard($owner, $member);
        if (!$member->deactivated_at) {
            $member->deactivated_at = now(); $member->save();
            $member->tokens()->delete();
            $this->audit($owner, 'team.deactivated', ['user_id' => $member->id]);
        }
        return back()->with('status', $member->name.' dinonaktifkan. Riwayat transaksi tetap tersimpan.');
    }

    public function activate(Request $request, User $member) {
        $owner = $request->user(); $this->guard($owner, $member);
        abort_if($owner->business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $member->deactivated_at = null; $member->save();
        $this->audit($owner, 'team.activated', ['user_id' => $member->id]);
        return back()->with('status', $member->name.' diaktifkan kembali.');
    }

    public function resetPassword(Request $request, User $member) {
        $owner = $request->user(); $this->guard($owner, $member);
        $data = $request->validate(['password' => ['required', Password::min(12)->letters()->numbers()]]);
        $member->password = $data['password']; $member->save();
        $member->tokens()->delete();
        $this->audit($owner, 'team.password_reset', ['user_id' => $member->id]);
        return back()->with('status', 'Password '.$member->name.' diganti. Sesi lama di HP keluar otomatis.');
    }

    private function guard(User $owner, User $member): void {
        abort_unless($member->business_id === $owner->business_id && $member->role !== 'owner' && !$member->is_platform_admin, 404);
    }

    private function audit(User $actor, string $action, array $details): void {
        DB::table('audit_events')->insert(['actor_id' => $actor->id, 'business_id' => $actor->business_id,
            'action' => $action, 'details' => json_encode($details), 'created_at' => now()]);
    }
}
