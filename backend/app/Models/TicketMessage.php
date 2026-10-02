<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class TicketMessage extends Model {
    public const UPDATED_AT = null;
    protected $fillable = ['body', 'author_type', 'internal'];
    protected function casts(): array { return ['internal' => 'boolean', 'created_at' => 'immutable_datetime']; }
    public function author() { return $this->belongsTo(User::class, 'author_id'); }
}
