<?php
namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable implements MustVerifyEmail {
    use \Laravel\Sanctum\HasApiTokens, Notifiable, \Illuminate\Auth\MustVerifyEmail;

    protected $fillable = ['name', 'email', 'password', 'phone'];
    protected $attributes = ['role' => 'owner'];
    protected $hidden = ['password', 'remember_token', 'mfa_secret', 'pin'];

    protected function casts(): array {
        return [
            'business_id' => 'integer', 'outlet_id' => 'integer', 'password' => 'hashed',
            'is_platform_admin' => 'boolean', 'email_verified_at' => 'datetime',
            'deactivated_at' => 'immutable_datetime', 'mfa_secret' => 'encrypted',
            'mfa_confirmed_at' => 'immutable_datetime', 'mfa_last_step' => 'integer',
            'pin' => 'hashed', 'pin_failed' => 'integer', 'pin_locked_until' => 'immutable_datetime',
            'courier_limits' => 'array',
        ];
    }

    public function business() { return $this->belongsTo(Business::class); }
    public function outlet() { return $this->belongsTo(Outlet::class); }

    /** Divisi administrator pusat; administrator lama tanpa divisi adalah pemilik platform. */
    public function adminDivision(): ?string {
        if (!$this->is_platform_admin) return null;
        return array_key_exists((string) $this->admin_division, config('goyana.admin_divisions')) ? $this->admin_division : 'owner';
    }

    /** Boleh membuka area aplikasi administrator ini? (config goyana.admin_divisions) */
    public function adminCan(string $area): bool {
        $division = $this->adminDivision();
        if ($division === null) return false;
        $areas = (array) config("goyana.admin_divisions.$division.areas");
        return in_array('*', $areas, true) || in_array($area, $areas, true);
    }

    public function isOwner(): bool { return !$this->is_platform_admin && $this->business_id && $this->role === 'owner'; }
    public function isActive(): bool { return $this->deactivated_at === null; }

    /** @return list<string> */
    public function permissions(): array {
        if ($this->is_platform_admin || !$this->business_id) return [];
        return config("goyana.roles.{$this->role}.permissions", []);
    }

    /** Hak akses per kurir: weigh (timbang saat jemput), create (transaksi di lokasi), pay (terima pembayaran). Bawaan: boleh. */
    public const COURIER_LIMITS = ['weigh', 'create', 'pay'];
    public function courierCan(string $what): bool {
        return ((array) ($this->courier_limits ?? []))[$what] ?? true;
    }

    /** @return array<string, bool> */
    public function courierLimits(): array {
        return array_combine(self::COURIER_LIMITS, array_map(fn ($k) => (bool) $this->courierCan($k), self::COURIER_LIMITS));
    }

    public function hasPermission(string $permission): bool {
        $list = $this->permissions();
        return in_array('*', $list, true) || in_array($permission, $list, true);
    }

    /** Owner sees every outlet; staff only the outlet they are assigned to. */
    public function canAccessOutlet(Outlet $outlet): bool {
        if ($outlet->business_id !== $this->business_id) return false;
        return $this->role === 'owner' || $this->outlet_id === $outlet->id;
    }

    /**
     * Cara akun ini boleh mengubah pesanan saat sinkronisasi (App\Support\OrderGuard):
     * full = kasir/admin outlet/owner, courier = kurir, production = pegawai, none = tidak boleh.
     */
    public function orderMode(): string {
        if ($this->hasPermission('orders.update')) return 'full';
        if ($this->hasPermission('courier.tasks')) return 'courier';
        if ($this->hasPermission('orders.status')) return 'production';
        return 'none';
    }

    /** Nomor HP disimpan sebagai angka saja dengan awalan 62. */
    public static function normalizePhone(?string $phone): string {
        $n = preg_replace('/\D+/', '', (string) $phone);
        if (str_starts_with($n, '0')) $n = '62'.substr($n, 1);
        elseif (str_starts_with($n, '8')) $n = '62'.$n;
        return $n;
    }

    public function roleLabel(): string { return config("goyana.roles.{$this->role}.label", $this->role); }
}
