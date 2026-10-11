<?php
namespace App\Support;

use App\Models\User;
use Illuminate\Support\Facades\Cache;

/**
 * Pengaman QRIS (keputusan Paduka 10 Okt 2026): QRIS usaha (teks, gambar, opsi) hanya boleh diganti atau dihapus
 * oleh pemilik yang baru saja mengonfirmasi password / kode email (berlaku 10 menit). Kiriman sama persis tetap diterima.
 * Perubahan yang tetap terjadi juga dipantau App\WhatsApp\QrisWatch (email ke pemilik).
 */
final class QrisGuard {
    public const KEYS = ['goyana-qris-text', 'goyana-qris-image', 'goyana-qris-options185'];
    public const MINUTES = 10;

    public static function unlockKey(int $userId): string { return 'qris-unlock:'.$userId; }

    public static function unlock(User $user): string {
        $until = now()->addMinutes(self::MINUTES);
        Cache::put(self::unlockKey($user->id), $until->getTimestamp(), $until);
        return $until->toIso8601String();
    }

    public static function unlocked(User $user): bool { return Cache::has(self::unlockKey($user->id)); }

    /** Null = boleh; teks = alasan ditolak. */
    public static function problem(User $user, string $collection, string $key): ?string {
        if ($collection !== 'settings' || !in_array($key, self::KEYS, true)) return null;
        if (!$user->isOwner()) return 'QRIS hanya bisa diganti pemilik usaha.';
        if (!self::unlocked($user)) return 'Konfirmasi password pemilik dulu untuk mengganti QRIS.';
        return null;
    }
}
