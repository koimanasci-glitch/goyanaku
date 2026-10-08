<?php
namespace App\Support;

/**
 * Membaca isi pesanan yang disinkronkan aplikasi: {card: {dataset, fields, total, …}, detail: {…}}.
 * Bentuknya ditentukan aplikasi (goyana-sync-core.js, mobile/lib/core/models.dart); server hanya membaca.
 */
final class OrderData {
    public static function isOrder(mixed $d): bool { return is_array($d) && is_array($d['card']['dataset'] ?? null); }

    public static function status(array $d): string {
        $st = (string) ($d['card']['dataset']['st'] ?? '');
        return $st === '' ? 'antrian' : $st;
    }

    /** @return list<array<string, mixed>> */
    public static function items(array $d): array {
        $items = $d['detail']['items'] ?? null;
        if (!is_array($items) || !$items) {
            $raw = $d['card']['dataset']['items'] ?? null;
            $items = is_string($raw) ? json_decode($raw, true) : null;
        }
        return is_array($items) ? array_values(array_filter($items, 'is_array')) : [];
    }

    /** @return list<array<string, mixed>> */
    public static function payments(array $d): array {
        $raw = $d['card']['dataset']['payments178'] ?? null;
        $list = is_string($raw) ? json_decode($raw, true) : (is_array($raw) ? $raw : null);
        return is_array($list) ? array_values(array_filter($list, 'is_array')) : [];
    }

    public static function paid(array $d): int {
        if (isset($d['detail']['paid'])) return (int) round((float) $d['detail']['paid']);
        return (int) round((float) ($d['card']['dataset']['paid177'] ?? 0));
    }

    public static function subtotal(array $items): int {
        $sub = 0;
        foreach ($items as $it) $sub += (int) round((float) ($it['qty'] ?? 0) * (float) ($it['price'] ?? 0));
        return $sub;
    }

    /** Sama dengan calcTotals di aplikasi: "p10" = 10%, "n5000" = Rp5.000, tidak melebihi subtotal. */
    public static function discount(int $sub, string $discKey): int {
        if (!preg_match('/^([pn])(\d+)$/', $discKey, $m)) return 0;
        $disc = $m[1] === 'p' ? $sub * (int) $m[2] / 100 : (float) $m[2];
        return (int) max(0, min($sub, round($disc)));
    }

    public static function discKey(array $d): string {
        $k = (string) ($d['detail']['discKey'] ?? '');
        return $k === '' ? '0' : $k;
    }

    public static function ongkir(array $d): int { return (int) round((float) ($d['detail']['ongkir'] ?? 0)); }

    public static function computedTotal(array $d): int {
        $sub = self::subtotal(self::items($d));
        return $sub - self::discount($sub, self::discKey($d)) + self::ongkir($d);
    }

    public static function total(array $d): int {
        if (isset($d['card']['total']) && is_numeric($d['card']['total'])) return (int) round((float) $d['card']['total']);
        return self::computedTotal($d);
    }

    public static function courier(array $d): string { return trim((string) ($d['card']['dataset']['courier181'] ?? '')); }
    public static function delivery(array $d): bool { return (string) ($d['card']['dataset']['antar'] ?? '') === '1'; }
    public static function customer(array $d): string { return trim((string) ($d['detail']['name'] ?? ($d['card']['fields'][2][0] ?? ''))); }

    /** Sama dengan customerKey di goyana-sync-core.js. */
    public static function customerKey(array $d): ?string {
        $phone = preg_replace('/\D+/', '', (string) ($d['detail']['phone'] ?? ''));
        if (str_starts_with($phone, '0')) $phone = '62'.substr($phone, 1);
        if ($phone !== '') return 'phone:'.$phone;
        $name = mb_strtolower(self::customer($d));
        return $name === '' ? null : 'name:'.$name;
    }

    public static function lastHistoryBy(array $d): string {
        $hist = $d['detail']['hist'] ?? null;
        if (!is_array($hist) || !$hist) return '';
        $last = end($hist);
        return is_array($last) ? (string) ($last['by'] ?? '') : '';
    }
}
