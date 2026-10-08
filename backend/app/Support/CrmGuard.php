<?php
namespace App\Support;

use App\Models\User;

/**
 * Hak tulis data CRM saat sinkronisasi. Owner dan admin outlet (izin prices.edit) bebas.
 * Kasir hanya: menandai voucher terpakai, menambah poin yang sudah ditukar pelanggan, dan mencatat pengingat terkirim.
 */
final class CrmGuard {
    /** @return ?string alasan penolakan, atau null bila boleh */
    public static function problem(User $user, string $key, mixed $old, mixed $new, bool $deleted): ?string {
        if ($user->role === 'owner' || $user->hasPermission('prices.edit')) return null;
        if (str_starts_with($key, 'reminded:')) return $deleted ? 'Catatan pengingat dihapus oleh owner.' : null;
        if ($deleted) return 'Data CRM hanya bisa dihapus owner.';
        if (str_starts_with($key, 'voucher:')) {
            if (!is_array($old)) return 'Voucher dibuat oleh owner.';
            if (!is_array($new)) return 'Data voucher tidak lengkap.';
            $a = $old; $b = $new; unset($a['used'], $b['used']);
            ksort($a); ksort($b);
            if ($a != $b) return 'Kasir hanya bisa menandai voucher terpakai.';
            return !empty($old['used']) && empty($new['used']) ? 'Voucher yang sudah terpakai tidak bisa dipakai lagi.' : null;
        }
        if (str_starts_with($key, 'redeemed:')) {
            $before = is_array($old) ? (int) ($old['v'] ?? 0) : 0;
            $after = is_array($new) ? (int) ($new['v'] ?? 0) : -1;
            return $after < $before ? 'Poin yang sudah ditukar tidak bisa dikurangi kasir.' : null;
        }
        return 'Aturan poin dan pengingat diatur owner.';
    }
}
