<?php
namespace App\Support;

use App\Models\User;

/**
 * Riwayat aktivitas (Audit Aktivitas) yang dikirim HP (keputusan Paduka 10 Oktober 2026): tersimpan di server per cabang,
 * supaya pemilik melihat kejadian di semua cabang. Sekali tersimpan tidak bisa diubah atau dihapus siapa pun.
 * Nama pengirim dicap server dari akun yang masuk, bukan dari isi HP.
 */
final class AuditTrail {
    private const STAMP = ['by', 'uid', 'role'];

    /** @return string|array alasan penolakan, atau data yang disimpan */
    public static function check(User $user, mixed $old, mixed $new, bool $deleted): string|array {
        if ($deleted) return 'Riwayat aktivitas tidak bisa dihapus.';
        if (!is_array($new) || trim((string) ($new['t'] ?? '')) === '') return 'Riwayat aktivitas tidak lengkap.';
        if (is_array($old)) {
            $a = $old; $b = $new;
            foreach (self::STAMP as $k) unset($a[$k], $b[$k]);
            ksort($a); ksort($b);
            return $a == $b ? $old : 'Riwayat aktivitas tidak bisa diubah.';
        }
        foreach (['t', 's', 'ic'] as $k) if (isset($new[$k])) $new[$k] = mb_substr((string) $new[$k], 0, 300);
        $new['by'] = $user->name;
        $new['uid'] = $user->id;
        $new['role'] = $user->role;
        return $new;
    }
}
