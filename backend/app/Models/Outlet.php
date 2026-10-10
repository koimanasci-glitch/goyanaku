<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Outlet extends Model {
    protected $fillable = ['name', 'code', 'address', 'phone'];
    protected function casts(): array { return ['business_id' => 'integer', 'process_outlet_id' => 'integer', 'deactivated_at' => 'immutable_datetime']; }
    public function isActive(): bool { return $this->deactivated_at === null; }
    public function syncKey(): string { return 'srv-'.$this->id; }

    /** Zona waktu cabang (10 Okt 2026): dipakai untuk "hari ini", jam perkiraan selesai di WA, dan laporan. */
    public const ZONES = ['Asia/Jakarta' => 'WIB', 'Asia/Makassar' => 'WITA', 'Asia/Jayapura' => 'WIT'];
    public function tz(): string { return isset(self::ZONES[$this->timezone ?? '']) ? $this->timezone : 'Asia/Jakarta'; }
    public function tzLabel(): string { return self::ZONES[$this->tz()]; }
    /** Zona waktu outlet [id]; tanpa outlet = zona outlet pusat usaha [businessId]. */
    public static function zoneOf(?int $id, ?int $businessId = null): string {
        $o = $id ? self::find($id) : ($businessId ? self::where('business_id', $businessId)->orderBy('id')->first() : null);
        return $o ? $o->tz() : 'Asia/Jakarta';
    }
    public static function labelOf(string $tz): string { return self::ZONES[$tz] ?? 'WIB'; }
    public function business() { return $this->belongsTo(Business::class); }
    public function devices() { return $this->hasMany(CashierDevice::class); }
}
