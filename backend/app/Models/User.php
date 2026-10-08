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
        ];
    }

    public function business() { return $this->belongsTo(Business::class); }
    public function outlet() { return $this->belongsTo(Outlet::class); }

    public function isOwner(): bool { return !$this->is_platform_admin && $this->business_id && $this->role === 'owner'; }
    public function isActive(): bool { return $this->deactivated_at === null; }

    /** @return list<string> */
    public function permissions(): array {
        if ($this->is_platform_admin || !$this->business_id) return [];
        return config("goyana.roles.{$this->role}.permissions", []);
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
