<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class CashierDevice extends Model {
    protected $fillable = ['label', 'slot'];
    protected function casts(): array { return ['slot' => 'integer', 'outlet_id' => 'integer', 'revoked_at' => 'immutable_datetime']; }
    public function outlet() { return $this->belongsTo(Outlet::class); }
}
