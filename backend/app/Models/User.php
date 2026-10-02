<?php
namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable implements MustVerifyEmail {
    use \Laravel\Sanctum\HasApiTokens, Notifiable, \Illuminate\Auth\MustVerifyEmail;

    protected $fillable = ['name', 'email', 'password'];
    protected $attributes = ['role' => 'owner'];
    protected $hidden = ['password', 'remember_token', 'mfa_secret'];

    protected function casts(): array {
        return [
            'business_id' => 'integer', 'outlet_id' => 'integer', 'password' => 'hashed',
            'is_platform_admin' => 'boolean', 'email_verified_at' => 'datetime',
            'deactivated_at' => 'immutable_datetime', 'mfa_secret' => 'encrypted',
            'mfa_confirmed_at' => 'immutable_datetime', 'mfa_last_step' => 'integer',
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

    public function roleLabel(): string { return config("goyana.roles.{$this->role}.label", $this->role); }
}
