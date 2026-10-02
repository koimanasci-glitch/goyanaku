<?php
namespace App\Support;
use Illuminate\Support\Facades\DB;
/** Platform settings the administrator can change without deploying (defaults in config/goyana.php `settings`). */
class Settings {
    public static function all(): array {
        $stored = DB::table('platform_settings')->pluck('value', 'key')->map(fn ($v) => json_decode($v, true))->all();
        return array_replace(config('goyana.settings'), array_intersect_key($stored, config('goyana.settings')));
    }
    public static function get(string $key): mixed { return self::all()[$key] ?? null; }
    public static function put(array $values, ?int $by): void {
        foreach ($values as $key => $value) {
            if (!array_key_exists($key, config('goyana.settings'))) continue;
            DB::table('platform_settings')->updateOrInsert(['key' => $key], ['value' => json_encode($value), 'updated_by' => $by, 'updated_at' => now()]);
        }
    }
}
