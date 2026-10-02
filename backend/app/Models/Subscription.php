<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Subscription extends Model {
    protected $fillable = ['package', 'starts_at', 'ends_at', 'source', 'reference', 'amount', 'recorded_by'];

    protected function casts(): array {
        return [
            'business_id' => 'integer', 'amount' => 'integer',
            'starts_at' => 'immutable_datetime', 'ends_at' => 'immutable_datetime', 'cancelled_at' => 'immutable_datetime',
        ];
    }

    public function business() { return $this->belongsTo(Business::class); }
}
