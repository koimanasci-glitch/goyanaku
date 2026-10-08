<?php
namespace App\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * Akun tim usaha (kasir, pegawai, kurir, admin outlet). Dipakai dashboard web dan API aplikasi,
 * supaya aturannya satu (keputusan pengguna 8 Oktober 2026):
 * - Hanya owner yang membuat, menempatkan, memindahkan, dan menonaktifkan.
 * - Setiap orang terikat tepat satu outlet.
 * - Pegawai login nomor HP + PIN; email + password tetap diterima untuk akun lama.
 * - Akun kurir selalu punya data kurir dengan tepat satu outlet.
 */
final class Team {
    /** @return list<string> */
    public static function roles(): array { return array_values(array_diff(array_keys(config('goyana.roles')), ['owner'])); }

    public static function rules(User $owner, ?User $member = null): array {
        $len = (int) config('goyana.pin.length');
        return [
            'name' => [$member ? 'sometimes' : 'required', 'string', 'max:120'],
            'role' => [$member ? 'sometimes' : 'required', Rule::in(self::roles())],
            'outlet_id' => [$member ? 'sometimes' : 'required', 'integer', Rule::exists('outlets', 'id')->where('business_id', $owner->business_id)->whereNull('deactivated_at')],
            'phone' => ['nullable', 'string', 'max:20'],
            'pin' => ['nullable', 'string', 'regex:/^\d{'.$len.'}$/'],
            'email' => ['nullable', 'email', 'max:254', Rule::unique('users', 'email')->ignore($member?->id)],
            'password' => ['nullable', Password::min(12)->letters()->numbers()],
            'courier_key' => ['nullable', 'string', 'max:160'],
        ];
    }

    public static function create(User $owner, array $data): User {
        $business = $owner->business;
        abort_if($business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        $phone = self::phone($data['phone'] ?? null, null);
        $hasPin = $phone !== null && !empty($data['pin']);
        $hasPassword = !empty($data['email']) && !empty($data['password']);
        if (!$hasPin && !$hasPassword) {
            throw ValidationException::withMessages(['phone' => 'Isi nomor HP dan PIN '.config('goyana.pin.length').' angka untuk login pegawai.']);
        }
        if (!empty($data['pin'])) self::assertPin($data['pin']);
        return DB::transaction(function () use ($owner, $business, $data, $phone) {
            $user = new User(['name' => $data['name'], 'email' => $data['email'] ?? null, 'phone' => $phone]);
            $user->business_id = $business->id; $user->role = $data['role']; $user->outlet_id = (int) $data['outlet_id'];
            if (!empty($data['password'])) $user->password = $data['password'];
            if (!empty($data['pin'])) $user->pin = $data['pin'];
            $user->email_verified_at = now(); // dibuat oleh owner yang sudah terverifikasi
            $user->save();
            self::syncCourier($owner, $user, $data['courier_key'] ?? null);
            self::audit($owner, 'team.created', ['user_id' => $user->id, 'role' => $user->role, 'outlet_id' => $user->outlet_id]);
            return $user;
        });
    }

    public static function update(User $owner, User $member, array $data): User {
        self::guard($owner, $member);
        $before = ['role' => $member->role, 'outlet_id' => $member->outlet_id];
        return DB::transaction(function () use ($owner, $member, $data, $before) {
            if (array_key_exists('name', $data)) $member->name = $data['name'];
            if (array_key_exists('email', $data)) $member->email = $data['email'] ?: null;
            if (array_key_exists('phone', $data)) $member->phone = self::phone($data['phone'], $member);
            if (array_key_exists('role', $data)) $member->role = $data['role'];
            if (array_key_exists('outlet_id', $data)) $member->outlet_id = (int) $data['outlet_id'];
            $member->save();
            // Hak di token mengikuti peran, jadi ganti peran mengeluarkan sesi lama. Pindah outlet saja tidak:
            // outlet dibaca dari akun pada setiap permintaan, sehingga langsung berlaku tanpa login ulang.
            if ($member->role !== $before['role']) $member->tokens()->delete();
            self::syncCourier($owner, $member, $data['courier_key'] ?? null);
            self::audit($owner, 'team.updated', ['user_id' => $member->id, 'before' => $before, 'after' => ['role' => $member->role, 'outlet_id' => $member->outlet_id]]);
            return $member;
        });
    }

    public static function setPin(User $owner, User $member, string $pin): void {
        self::guard($owner, $member);
        if (!$member->phone) throw ValidationException::withMessages(['pin' => 'Isi nomor HP pegawai ini terlebih dahulu.']);
        self::assertPin($pin);
        $member->pin = $pin; $member->pin_failed = 0; $member->pin_locked_until = null; $member->save();
        $member->tokens()->delete();
        self::audit($owner, 'team.pin_reset', ['user_id' => $member->id]);
    }

    public static function setPassword(User $owner, User $member, string $password): void {
        self::guard($owner, $member);
        if (!$member->email) throw ValidationException::withMessages(['password' => 'Akun ini login dengan nomor HP dan PIN.']);
        $member->password = $password; $member->save();
        $member->tokens()->delete();
        self::audit($owner, 'team.password_reset', ['user_id' => $member->id]);
    }

    public static function deactivate(User $owner, User $member): void {
        self::guard($owner, $member);
        if ($member->deactivated_at) return;
        DB::transaction(function () use ($owner, $member) {
            $member->deactivated_at = now(); $member->save();
            $member->tokens()->delete();
            self::syncCourier($owner, $member, null);
            self::audit($owner, 'team.deactivated', ['user_id' => $member->id]);
        });
    }

    public static function activate(User $owner, User $member): void {
        self::guard($owner, $member);
        abort_if($owner->business->currentAccess()['read_only'], 403, 'Paket sudah berakhir.');
        DB::transaction(function () use ($owner, $member) {
            $member->deactivated_at = null; $member->save();
            self::syncCourier($owner, $member, null);
            self::audit($owner, 'team.activated', ['user_id' => $member->id]);
        });
    }

    public static function guard(User $owner, User $member): void {
        abort_unless($member->business_id === $owner->business_id && $member->role !== 'owner' && !$member->is_platform_admin, 404);
    }

    /** PIN yang mudah ditebak ditolak. */
    public static function assertPin(string $pin): void {
        $weak = preg_match('/^(\d)\1+$/', $pin) || str_contains('0123456789012345', $pin) || str_contains('9876543210987654', $pin);
        if ($weak) throw ValidationException::withMessages(['pin' => 'PIN terlalu mudah ditebak. Hindari angka berurutan atau kembar.']);
    }

    private static function phone(?string $raw, ?User $member): ?string {
        if ($raw === null || trim($raw) === '') return null;
        $phone = User::normalizePhone($raw);
        if (!preg_match('/^62\d{8,13}$/', $phone)) throw ValidationException::withMessages(['phone' => 'Periksa nomor HP.']);
        if (User::where('phone', $phone)->when($member, fn ($q) => $q->where('id', '!=', $member->id))->exists()) {
            throw ValidationException::withMessages(['phone' => 'Nomor HP ini sudah dipakai akun lain.']);
        }
        return $phone;
    }

    /**
     * Data kurir (yang dipakai aplikasi untuk menunjuk kurir) selalu mengikuti akunnya: satu outlet, aktif bila akunnya aktif.
     * $link: kunci data kurir lama yang dipilih owner untuk disambungkan ke akun ini.
     */
    private static function syncCourier(User $owner, User $member, ?string $link): void {
        $business = $owner->business;
        if ($member->role !== 'kurir') {
            // Bukan kurir lagi: data kurirnya dinonaktifkan supaya tidak bisa ditunjuk.
            if ($member->courier_key && ($old = SyncStore::get($business->id, 'couriers', $member->courier_key))) {
                SyncStore::put($business, 'couriers', $member->courier_key, ['active' => false] + $old, $owner);
            }
            return;
        }
        if ($link !== null && $link !== '' && $link !== $member->courier_key) {
            if (!SyncStore::get($business->id, 'couriers', $link)) throw ValidationException::withMessages(['courier_key' => 'Data kurir tidak ditemukan.']);
            if (User::where('business_id', $business->id)->where('courier_key', $link)->where('id', '!=', $member->id)->exists()) {
                throw ValidationException::withMessages(['courier_key' => 'Data kurir ini sudah tersambung ke akun lain.']);
            }
            $member->courier_key = $link;
        }
        if (!$member->courier_key) $member->courier_key = 'akun-'.$member->id;
        $member->save();
        $old = SyncStore::get($business->id, 'couriers', $member->courier_key) ?? [];
        $data = ['id' => $member->courier_key, 'name' => $member->name, 'phone' => $member->phone ?: (string) ($old['phone'] ?? ''),
            'email' => $member->email ?: (string) ($old['email'] ?? ''), 'outlets' => ['srv-'.$member->outlet_id],
            'active' => $member->deactivated_at === null, 'userId' => $member->id] + $old;
        unset($data['deleted']);
        SyncStore::put($business, 'couriers', $member->courier_key, $data, $owner);
    }

    public static function present(User $member): array {
        return ['id' => $member->id, 'name' => $member->name, 'role' => $member->role, 'role_label' => $member->roleLabel(),
            'outlet_id' => $member->outlet_id, 'phone' => $member->phone, 'email' => $member->email, 'has_pin' => $member->pin !== null,
            'active' => $member->isActive(), 'courier_key' => $member->courier_key,
            'pin_locked' => $member->pin_locked_until !== null && $member->pin_locked_until->isFuture()];
    }

    public static function audit(User $actor, string $action, array $details): void {
        DB::table('audit_events')->insert(['actor_id' => $actor->id, 'business_id' => $actor->business_id,
            'action' => $action, 'details' => json_encode($details), 'created_at' => now()]);
    }
}
