<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Ticket extends Model {
    public const CATEGORIES = ['aplikasi' => 'Aplikasi / error', 'sinkron' => 'Sinkron data', 'printer' => 'Printer', 'paket' => 'Paket & pembayaran', 'whatsapp' => 'WhatsApp', 'lainnya' => 'Lainnya'];
    public const STATUSES = ['open' => 'Menunggu CS', 'answered' => 'Dijawab', 'closed' => 'Selesai'];
    protected $fillable = ['subject', 'category', 'priority', 'source'];
    protected function casts(): array { return ['business_id' => 'integer', 'user_id' => 'integer', 'last_activity_at' => 'immutable_datetime', 'closed_at' => 'immutable_datetime']; }
    public function business() { return $this->belongsTo(Business::class); }
    public function user() { return $this->belongsTo(User::class); }
    public function messages() { return $this->hasMany(TicketMessage::class)->orderBy('id'); }
}
