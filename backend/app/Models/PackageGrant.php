<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class PackageGrant extends Model {
    protected $fillable = ['package', 'reason', 'starts_at', 'ends_at', 'granted_by'];
    protected function casts(): array { return ['business_id' => 'integer', 'starts_at' => 'immutable_datetime', 'ends_at' => 'immutable_datetime', 'revoked_at' => 'immutable_datetime']; }
    public function business() { return $this->belongsTo(Business::class); }
}
