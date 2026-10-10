<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Stok per cabang (10 Oktober 2026): catatan stok lama tersimpan tanpa outlet (stok satu usaha).
 * Outletnya diambil dari isi catatan (outletId "srv-<id>"); catatan tanpa outlet yang dikenali masuk ke outlet pertama usaha itu.
 */
return new class extends Migration {
    public function up(): void {
        $first = [];
        DB::table('sync_records')->where('collection', 'stock_ledger')->whereNull('outlet_id')->orderBy('id')
            ->chunkById(500, function ($rows) use (&$first) {
                foreach ($rows as $r) {
                    $data = json_decode((string) $r->data, true);
                    $id = null;
                    if (is_array($data) && preg_match('/^srv-(\d+)$/', (string) ($data['outletId'] ?? ''), $m)
                        && DB::table('outlets')->where('id', (int) $m[1])->where('business_id', $r->business_id)->exists()) {
                        $id = (int) $m[1];
                    }
                    $id ??= $first[$r->business_id] ??= DB::table('outlets')->where('business_id', $r->business_id)->orderBy('id')->value('id');
                    if ($id) DB::table('sync_records')->where('id', $r->id)->update(['outlet_id' => $id]);
                }
            });
    }

    public function down(): void {
        DB::table('sync_records')->where('collection', 'stock_ledger')->update(['outlet_id' => null]);
    }
};
