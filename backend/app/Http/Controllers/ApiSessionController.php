<?php
namespace App\Http\Controllers;

use App\Models\{SharedDevice, User};
use App\Support\{Devices, Outlets, Team};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * Sesi aplikasi. Owner masuk dengan email + password; kasir, pegawai, dan kurir dengan nomor HP + PIN
 * (keputusan pengguna 8 Oktober 2026). Akun lama dengan email + password tetap bisa masuk.
 */
class ApiSessionController {
    public function login(Request $request) {
        $data = $request->validate(['email' => 'required|string|max:254', 'password' => 'required|string|max:1024', 'device_id' => 'nullable|string|min:8|max:64']);
        $user = User::where('email', mb_strtolower(trim($data['email'])))->first();
        if (!$user || !$user->password || !Hash::check($data['password'], $user->password) || $user->is_platform_admin || !$user->business_id) {
            throw ValidationException::withMessages(['email' => 'Email atau password tidak sesuai.']);
        }
        if (!$user->isActive()) {
            throw ValidationException::withMessages(['email' => 'Akun dinonaktifkan. Hubungi owner usaha.']);
        }
        return response()->json($this->issue($user, 'android-'.$user->role, now()->addDay(), $data['device_id'] ?? null));
    }

    /** Login pegawai: nomor HP + PIN di HP sendiri, atau pilih nama + PIN di HP outlet yang sudah diikat owner. */
    public function loginPin(Request $request) {
        $len = (int) config('goyana.pin.length');
        $data = $request->validate([
            'phone' => 'required_without:user_id|nullable|string|max:20',
            'user_id' => 'required_without:phone|nullable|integer',
            'pin' => ['required', 'string', 'regex:/^\d{'.$len.'}$/'],
            'device_id' => 'required|string|min:8|max:64',
            'device_secret' => 'required_with:user_id|nullable|string|max:128',
        ]);
        $wrong = fn () => throw ValidationException::withMessages(['pin' => 'Nomor HP atau PIN tidak sesuai.']);
        $shared = null;
        if (!empty($data['user_id'])) {
            $shared = $this->sharedDevice($data['device_id'], (string) $data['device_secret']);
            $user = User::whereKey($data['user_id'])->where('outlet_id', $shared->outlet_id)->first();
        } else {
            $user = User::where('phone', User::normalizePhone($data['phone']))->first();
        }
        if (!$user || !$user->pin || $user->is_platform_admin || !$user->business_id || $user->role === 'owner') $wrong();
        if ($user->pin_locked_until && $user->pin_locked_until->isFuture()) {
            $minutes = max(1, (int) ceil(now()->diffInSeconds($user->pin_locked_until) / 60));
            throw ValidationException::withMessages(['pin' => 'Terlalu banyak percobaan. Coba lagi dalam '.$minutes.' menit, atau minta owner mengganti PIN.']);
        }
        if (!Hash::check($data['pin'], $user->pin)) {
            $user->pin_failed = $user->pin_failed + 1;
            if ($user->pin_failed >= (int) config('goyana.pin.max_attempts')) {
                $user->pin_failed = 0; $user->pin_locked_until = now()->addMinutes((int) config('goyana.pin.lock_minutes'));
                Team::audit($user, 'pin.locked', ['user_id' => $user->id, 'device' => substr($data['device_id'], 0, 12)]);
            }
            $user->save();
            $wrong();
        }
        if (!$user->isActive()) throw ValidationException::withMessages(['pin' => 'Akun dinonaktifkan. Hubungi owner usaha.']);
        $user->pin_failed = 0; $user->pin_locked_until = null; $user->save();
        if ($shared) { $shared->last_seen_at = now(); $shared->save(); }
        $expires = now()->addDays((int) config('goyana.pin.session_days'));
        return response()->json($this->issue($user, ($shared ? 'bersama-' : 'pin-').$user->role, $expires, $data['device_id']));
    }

    /** Daftar nama pegawai outlet untuk HP bersama. Hanya untuk HP yang diikat owner; tidak memuat nomor HP atau PIN. */
    public function roster(Request $request) {
        $data = $request->validate(['device_id' => 'required|string|min:8|max:64', 'device_secret' => 'required|string|max:128']);
        $shared = $this->sharedDevice($data['device_id'], $data['device_secret']);
        $shared->last_seen_at = now(); $shared->save();
        $staff = User::where('business_id', $shared->business_id)->where('outlet_id', $shared->outlet_id)->where('role', '!=', 'owner')
            ->whereNull('deactivated_at')->whereNotNull('pin')->orderBy('name')->get();
        return response()->json([
            'outlet' => ['id' => $shared->outlet_id, 'name' => $shared->outlet->name],
            'staff' => $staff->map(fn (User $u) => ['id' => $u->id, 'name' => $u->name, 'role' => $u->role, 'role_label' => $u->roleLabel()])->values(),
        ]);
    }

    public function me(Request $request) {
        $user = $this->user($request);
        $business = $user->business;
        $access = $business->currentAccess();
        $outlets = $business->outlets()->orderBy('id')->get()->filter(fn ($o) => $user->canAccessOutlet($o))->values();
        // Awalan nomor nota: kode cabang + kode HP (slot HP kasir, atau K<id> untuk HP kurir).
        $home = $user->role === 'owner' ? null : $outlets->firstWhere('id', $user->outlet_id);
        $device = (string) $request->query('device_id', '');
        $deviceCode = $user->orderMode() === 'courier' ? 'K'.$user->id : ($home && $device !== '' ? Devices::slot($home->id, $device) : null);
        return response()->json([
            'user' => ['id' => $user->id, 'name' => $user->name, 'role' => $user->role, 'role_label' => $user->roleLabel(),
                'permissions' => $user->permissions(), 'outlet_id' => $user->outlet_id, 'phone' => $user->phone,
                'login' => $user->pin ? 'pin' : 'password', 'courier_key' => $user->courier_key],
            'business' => ['id' => $business->id, 'name' => $business->name, 'allow_debt' => (bool) $business->allow_debt],
            'access' => [
                'package' => $access['package'], 'source' => $access['source'], 'read_only' => $access['read_only'],
                'ends_at' => $access['ends_at']?->toIso8601String(), 'outlet_limit' => $access['outlet_limit'],
                'cashier_device_limit' => $access['cashier_device_limit'],
            ],
            'outlets' => $outlets->map(fn ($o) => Outlets::present($o))->values(),
            'note' => ['prefix' => $home ? Outlets::ensureCode($home) : null, 'device' => $deviceCode === null ? null : (string) $deviceCode],
            'rules' => ['stages' => config('goyana.orders.stages'), 'done_status' => config('goyana.orders.done_status'),
                'pin_length' => (int) config('goyana.pin.length')],
        ]);
    }

    /** HP kasir meminta slot sebelum transaksi pertama, supaya nomor nota sudah memuat kode HP. */
    public function claimDevice(Request $request) {
        $user = $this->user($request);
        $data = $request->validate(['device_id' => 'required|string|min:8|max:64', 'outlet_id' => 'nullable|integer']);
        abort_unless($user->hasPermission('orders.create'), 403, 'Akun ini tidak memakai slot HP kasir.');
        $business = $user->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $outlet = $business->outlets()->whereNull('deactivated_at')->whereKey($user->role === 'owner' ? ($data['outlet_id'] ?? 0) : $user->outlet_id)->first();
        if (!$outlet) throw ValidationException::withMessages(['outlet_id' => 'Pilih outlet.']);
        $slot = DB::transaction(fn () => Devices::claim($user, $business, $outlet->id, $data['device_id']));
        if (is_string($slot)) throw ValidationException::withMessages(['device_id' => $slot]);
        return response()->json(['slot' => $slot, 'note' => ['prefix' => Outlets::ensureCode($outlet), 'device' => (string) $slot]]);
    }

    public function changePin(Request $request) {
        $user = $this->user($request);
        $rule = ['required', 'string', 'regex:/^\d{'.(int) config('goyana.pin.length').'}$/'];
        $data = $request->validate(['current_pin' => $rule, 'pin' => $rule]);
        if (!$user->pin || !Hash::check($data['current_pin'], $user->pin)) throw ValidationException::withMessages(['current_pin' => 'PIN saat ini tidak sesuai.']);
        Team::assertPin($data['pin']);
        $user->pin = $data['pin']; $user->save();
        $this->keepOnlyCurrentToken($request, $user);
        return response()->noContent();
    }

    public function changePassword(Request $request) {
        $user = $this->user($request);
        $data = $request->validate(['current_password' => 'required|string|max:1024', 'password' => ['required', Password::min(12)->letters()->numbers()]]);
        if (!$user->password || !Hash::check($data['current_password'], $user->password)) throw ValidationException::withMessages(['current_password' => 'Password saat ini tidak sesuai.']);
        $user->password = $data['password']; $user->save();
        $this->keepOnlyCurrentToken($request, $user);
        return response()->noContent();
    }

    public function logout(Request $request) {
        $token = $request->user()->currentAccessToken();
        abort_unless($token instanceof \Laravel\Sanctum\PersonalAccessToken, 403);
        $token->delete();
        return response()->noContent();
    }

    private function user(Request $request): User {
        $user = $request->user();
        abort_if($user->is_platform_admin || !$user->business_id, 403);
        abort_unless($user->isActive(), 403, 'Akun dinonaktifkan.');
        abort_unless($user->tokenCan('business:read'), 403);
        return $user;
    }

    private function issue(User $user, string $name, $expires, ?string $device): array {
        $user->tokens()->where('expires_at', '<=', now())->delete();
        // Satu akun pegawai aktif di satu HP: login di HP baru mengeluarkan HP lama. Owner boleh di beberapa perangkat.
        if ($user->role !== 'owner') $user->tokens()->delete();
        // Hak di token mengikuti peran, sehingga server menolak tindakan di luar peran itu.
        $abilities = array_values(array_unique(array_merge(['business:read'], $user->permissions())));
        $label = $device ? $name.'|'.substr($device, 0, 64) : $name;
        return ['token' => $user->createToken($label, $abilities, $expires)->plainTextToken, 'expires_at' => $expires->toIso8601String()];
    }

    private function keepOnlyCurrentToken(Request $request, User $user): void {
        $current = $user->currentAccessToken();
        $user->tokens()->when($current instanceof \Laravel\Sanctum\PersonalAccessToken, fn ($q) => $q->where('id', '!=', $current->id))->delete();
    }

    private function sharedDevice(string $uuid, string $secret): SharedDevice {
        $device = SharedDevice::where('device_uuid', $uuid)->whereNull('revoked_at')->latest('id')->first();
        if (!$device || !Hash::check($secret, $device->secret) || !$device->outlet->isActive()) {
            throw ValidationException::withMessages(['device_id' => 'HP ini belum diikat ke outlet, atau ikatannya sudah dicabut owner.']);
        }
        return $device;
    }
}
