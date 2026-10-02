<?php
namespace App\Support;
use App\Models\Business;
use Illuminate\Support\Facades\DB;
/**
 * Mode Bantuan (GOYANA-SISTEM-PUSAT.md §46): perubahan pengaturan oleh admin ditulis sebagai data sinkron baru
 * (rev naik) sehingga HP owner menerimanya dalam hitungan detik. Setiap perubahan diaudit dan bisa dibatalkan.
 */
class Assist {
    public const MINUTES = 30;
    /** Collections an admin may change in assist mode (settings only; never orders, money or customers). */
    public const EDITABLE = ['services', 'outlet_profiles'];

    public static function active(Business $b): ?object {
        return DB::table('support_sessions')->where('business_id', $b->id)->whereNull('revoked_at')->where('expires_at', '>', now())->orderByDesc('id')->first();
    }

    public static function write(Business $b, int $adminId, string $collection, string $key, ?array $data, string $note): int {
        abort_unless(in_array($collection, self::EDITABLE, true), 422);
        return DB::transaction(function () use ($b, $adminId, $collection, $key, $data, $note) {
            Business::whereKey($b->id)->lockForUpdate()->firstOrFail();
            abort_unless(self::active($b), 403, 'Mode Bantuan tidak aktif. Minta owner menekan "Izinkan Bantuan".');
            $existing = DB::table('sync_records')->where(['business_id' => $b->id, 'collection' => $collection, 'record_key' => $key])->first();
            $rev = (int) DB::table('sync_records')->where('business_id', $b->id)->max('rev') + 1;
            $json = $data === null ? null : json_encode($data, JSON_UNESCAPED_UNICODE);
            $row = ['data' => $json, 'deleted' => $data === null, 'rev' => $rev, 'updated_by' => $adminId, 'device_uuid' => 'admin-assist', 'updated_at' => now()];
            if ($existing) DB::table('sync_records')->where('id', $existing->id)->update($row);
            else DB::table('sync_records')->insert($row + ['business_id' => $b->id, 'collection' => $collection, 'record_key' => $key, 'outlet_id' => null, 'created_at' => now()]);
            return DB::table('audit_events')->insertGetId(['actor_id' => $adminId, 'business_id' => $b->id, 'action' => 'assist.changed', 'created_at' => now(),
                'details' => json_encode(['collection' => $collection, 'key' => $key, 'note' => $note,
                    'before' => $existing && !$existing->deleted ? json_decode((string) $existing->data, true) : null, 'after' => $data], JSON_UNESCAPED_UNICODE)]);
        });
    }
}
