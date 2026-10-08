<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
/** HP milik outlet yang dipakai bergantian; pegawai memilih nama lalu mengetik PIN. */
class SharedDevice extends Model {
    protected $fillable = ['device_uuid', 'label'];
    protected $hidden = ['secret'];
    protected function casts(): array {
        return ['business_id' => 'integer', 'outlet_id' => 'integer', 'secret' => 'hashed',
            'last_seen_at' => 'immutable_datetime', 'revoked_at' => 'immutable_datetime'];
    }
    public function outlet() { return $this->belongsTo(Outlet::class); }
}
