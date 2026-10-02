<?php
namespace App\Models;
use Illuminate\Foundation\Auth\User as Authenticatable;
class User extends Authenticatable {
    use \Laravel\Sanctum\HasApiTokens;
    protected $fillable = ['name', 'email', 'password'];
    protected $hidden = ['password', 'remember_token'];
    protected function casts(): array { return ['business_id' => 'integer', 'password' => 'hashed', 'is_platform_admin' => 'boolean', 'email_verified_at' => 'datetime']; }
    public function business() { return $this->belongsTo(Business::class); }
}
