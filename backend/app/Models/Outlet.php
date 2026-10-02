<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Outlet extends Model {
    protected $fillable = ['name'];
    protected function casts(): array { return ['business_id' => 'integer']; }
    public function business() { return $this->belongsTo(Business::class); }
    public function devices() { return $this->hasMany(CashierDevice::class); }
}
