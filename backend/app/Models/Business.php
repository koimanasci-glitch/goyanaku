<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Business extends Model {
    protected $fillable = ['name', 'trial_ends_at'];
    protected function casts(): array { return ['trial_ends_at' => 'immutable_datetime']; }
    public function outlets() { return $this->hasMany(Outlet::class); }
    public function grants() { return $this->hasMany(PackageGrant::class); }
    public function currentAccess(): array {
        $grant = $this->grants()->whereNull('revoked_at')->where('starts_at', '<=', now())->where('ends_at', '>', now())->latest('id')->first();
        if ($grant) return ['package' => $grant->package, 'source' => 'beta', 'ends_at' => $grant->ends_at, 'read_only' => false];
        if ($this->trial_ends_at->isFuture()) return ['package' => 'Basic', 'source' => 'trial', 'ends_at' => $this->trial_ends_at, 'read_only' => false];
        return ['package' => null, 'source' => 'expired', 'ends_at' => $this->trial_ends_at, 'read_only' => true];
    }
}
