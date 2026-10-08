<?php
namespace App\Support;

use App\Models\{Business, User};
use Illuminate\Support\Facades\DB;

/**
 * Menulis data sinkron dari sisi server (bukan dari HP), misalnya data kurir saat owner membuat akun kurir.
 * Nomor revisi mengikuti urutan usaha yang sama dengan SyncController, jadi HP menerimanya saat tarik data.
 */
final class SyncStore {
    public static function get(int $businessId, string $collection, string $key): ?array {
        $row = DB::table('sync_records')->where('business_id', $businessId)->where('collection', $collection)->where('record_key', $key)->where('deleted', false)->first();
        $data = $row ? json_decode((string) $row->data, true) : null;
        return is_array($data) ? $data : null;
    }

    /** Panggil di dalam DB::transaction. */
    public static function put(Business $business, string $collection, string $key, array $data, User $by, ?int $outletId = null): int {
        Business::whereKey($business->id)->lockForUpdate()->firstOrFail();
        $rev = (int) DB::table('sync_records')->where('business_id', $business->id)->max('rev') + 1;
        $row = ['outlet_id' => $outletId, 'data' => json_encode($data, JSON_UNESCAPED_UNICODE), 'deleted' => false, 'rev' => $rev,
            'updated_by' => $by->id, 'device_uuid' => null, 'updated_at' => now()];
        $existing = DB::table('sync_records')->where('business_id', $business->id)->where('collection', $collection)->where('record_key', $key)->first();
        if ($existing) DB::table('sync_records')->where('id', $existing->id)->update($row);
        else DB::table('sync_records')->insert($row + ['business_id' => $business->id, 'collection' => $collection, 'record_key' => $key, 'created_at' => now()]);
        return $rev;
    }
}
