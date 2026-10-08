<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Outlet extends Model {
    protected $fillable = ['name', 'code', 'address', 'phone'];
    protected function casts(): array { return ['business_id' => 'integer', 'process_outlet_id' => 'integer', 'deactivated_at' => 'immutable_datetime']; }
    public function isActive(): bool { return $this->deactivated_at === null; }
    public function syncKey(): string { return 'srv-'.$this->id; }
    public function business() { return $this->belongsTo(Business::class); }
    public function devices() { return $this->hasMany(CashierDevice::class); }
}
