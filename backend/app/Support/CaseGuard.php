<?php
namespace App\Support;

use App\Models\User;

/**
 * Komplain & klaim + foto cucian (Tahap 2 fitur 9, 10 Oktober 2026).
 * - Foto cucian (order_photos): bukti kondisi saat masuk/diambil. Sekali tersimpan tidak bisa diubah; hanya pemilik yang menghapus.
 * - Komplain (complaints): kasir mencatat dan memproses; ganti rugi uang diputuskan pemilik atau kepala cabang;
 *   komplain yang sudah selesai tidak bisa diubah kasir. Nama pencatat dicap server.
 */
final class CaseGuard {
    public const TYPES = ['kurang', 'rusak', 'luntur', 'kotor', 'telat', 'lain'];
    public const DONE = ['ulang', 'ganti', 'tolak', 'damai'];

    private static function boss(User $u): bool { return in_array($u->role, ['owner', 'manager'], true); }

    /** @return string|array */
    public static function photo(User $user, mixed $old, mixed $new, bool $deleted): string|array {
        if ($deleted) return $user->role === 'owner' ? [] : 'Foto cucian hanya bisa dihapus pemilik.';
        if (!is_array($new) || !preg_match('#^data:image/(jpeg|png|webp);base64,#', (string) ($new['img'] ?? '')) || trim((string) ($new['order'] ?? '')) === '') {
            return 'Foto cucian tidak lengkap.';
        }
        if (!in_array($new['slot'] ?? '', ['in', 'out'], true)) return 'Foto cucian tidak lengkap.';
        if (is_array($old)) return ($old['img'] ?? null) === $new['img'] ? $old : 'Foto cucian tidak bisa diubah.';
        $new['by'] = $user->name;
        return $new;
    }

    /** @return string|array */
    public static function complaint(User $user, mixed $old, mixed $new, bool $deleted): string|array {
        if ($deleted) return $user->role === 'owner' ? [] : 'Komplain hanya bisa dihapus pemilik.';
        if (!is_array($new) || trim((string) ($new['order'] ?? '')) === '' || !in_array($new['type'] ?? '', self::TYPES, true)) return 'Komplain tidak lengkap.';
        $status = (string) ($new['status'] ?? 'baru');
        if (!in_array($status, ['baru', 'proses', 'selesai'], true)) return 'Status komplain tidak dikenal.';
        if ($status === 'selesai' && !in_array($new['result'] ?? '', self::DONE, true)) return 'Pilih hasil penyelesaian komplain.';
        $amount = (int) ($new['amount'] ?? 0);
        if ($amount < 0) return 'Jumlah ganti rugi tidak valid.';
        $paid = ($new['result'] ?? '') === 'ganti' && $amount > 0;
        $oldPaid = is_array($old) && ($old['result'] ?? '') === 'ganti' && (int) ($old['amount'] ?? 0) > 0;
        if (!self::boss($user)) {
            if ($paid && (!$oldPaid || (int) $old['amount'] !== $amount)) return 'Ganti rugi uang diputuskan pemilik atau kepala cabang.';
            if (is_array($old) && ($old['status'] ?? '') === 'selesai' && $old != $new) return 'Komplain yang sudah selesai hanya bisa diubah pemilik atau kepala cabang.';
        }
        if (!is_array($old)) $new['by'] = $user->name;
        else $new['by'] = $old['by'] ?? $user->name;
        if ($status === 'selesai' && (!is_array($old) || ($old['status'] ?? '') !== 'selesai')) $new['closedBy'] = $user->name;
        foreach (['note', 'resNote'] as $k) if (isset($new[$k])) $new[$k] = mb_substr((string) $new[$k], 0, 500);
        return $new;
    }
}
