<?php
namespace App\Support;

use App\Models\Business;
use Illuminate\Support\Facades\DB;

/**
 * Hak akses pegawai per cabang (keputusan Paduka 10 Oktober 2026), diatur pemilik di aplikasi
 * (Pengaturan › Hak Akses Pegawai) dan tersimpan di setelan usaha bersama ("goyana-pure-shared" → tpl.pegawai).
 * - phone: pegawai melihat nomor HP pelanggan (bawaan: tidak)
 * - price: pegawai melihat nilai pesanan dan harga (bawaan: tidak)
 * - stock: pegawai mencatat bahan dipakai (bawaan: ya)
 * Setelan cabang (tgOutlet["srv-<id>"]) didahulukan, lalu setelan umum (tg), lalu bawaan.
 */
final class StaffRights {
    public const KEYS = ['phone' => 0, 'price' => 1, 'stock' => 2];
    private const DEFAULTS = ['phone' => false, 'price' => false, 'stock' => true];

    /** @var array<int, array> */
    private static array $cache = [];

    public static function forget(): void { self::$cache = []; }

    private static function config(Business $business): array {
        if (isset(self::$cache[$business->id])) return self::$cache[$business->id];
        $raw = DB::table('sync_records')->where('business_id', $business->id)->where('collection', 'settings')
            ->where('record_key', 'goyana-pure-shared')->where('deleted', false)->value('data');
        $data = json_decode((string) $raw, true);
        if (is_string($data)) $data = json_decode($data, true); // disimpan sebagai teks JSON
        $tpl = is_array($data) ? (array) (($data['tpl'] ?? [])['pegawai'] ?? []) : [];
        return self::$cache[$business->id] = $tpl;
    }

    /** @return array{phone: bool, price: bool, stock: bool} */
    public static function pegawai(Business $business, ?int $outletId): array {
        $tpl = self::config($business);
        $own = $outletId ? (array) (($tpl['tgOutlet'] ?? [])['srv-'.$outletId] ?? []) : [];
        $all = (array) ($tpl['tg'] ?? []);
        $out = [];
        foreach (self::KEYS as $key => $i) {
            $v = $own[(string) $i] ?? $all[(string) $i] ?? null;
            $out[$key] = is_bool($v) ? $v : self::DEFAULTS[$key];
        }
        return $out;
    }
}
