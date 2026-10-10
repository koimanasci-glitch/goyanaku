<?php
namespace App\Support;

use App\Models\User;

/**
 * Kelola Cabang Ini (Tahap 2, 10 Oktober 2026): pemilik mencatat kas masuk, tarik uang, pengeluaran, atau minta cek stok
 * untuk cabang lain dari HP-nya. Catatan kas dikirim ke laci kas cabang itu: satu HP kasir cabang mengambilnya (sekali saja,
 * dicap dengan id HP), lalu masuk ke kas masuk/pengeluaran lacinya sehingga tutup omset cabang tetap cocok.
 * Hanya pemilik (atau kepala cabang untuk cabangnya) yang membuat dan membatalkan; staf hanya mengambil.
 */
final class BranchTask {
    public const CASH = ['kas_in', 'kas_out', 'expense'];
    public const KINDS = ['kas_in', 'kas_out', 'expense', 'opname'];
    private const CLAIM = ['claimedBy', 'claimedAt'];

    private static function boss(User $user): bool { return in_array($user->role, ['owner', 'manager'], true); }

    /** @return string|array alasan penolakan, atau data yang disimpan */
    public static function check(User $user, string $device, int $outletId, mixed $old, mixed $new, bool $deleted): string|array {
        if ($deleted) {
            if (!self::boss($user)) return 'Hanya pemilik atau kepala cabang yang bisa membatalkan catatan ini.';
            if (is_array($old) && !empty($old['claimedBy'])) return 'Sudah masuk ke laci kas cabang. Catat kebalikannya bila perlu dibatalkan.';
            return [];
        }
        if (!is_array($new)) return 'Catatan cabang tidak lengkap.';
        if (!is_array($old)) {
            if (!self::boss($user)) return 'Hanya pemilik atau kepala cabang yang bisa mencatat untuk cabang ini.';
            $kind = (string) ($new['kind'] ?? '');
            if (!in_array($kind, self::KINDS, true)) return 'Jenis catatan cabang tidak dikenal.';
            $amount = $new['amount'] ?? 0;
            if (in_array($kind, self::CASH, true) && (!is_numeric($amount) || (int) $amount <= 0 || (int) $amount > 1000000000)) return 'Isi jumlah uang yang benar.';
            foreach (self::CLAIM as $k) unset($new[$k]);
            $new['note'] = mb_substr((string) ($new['note'] ?? ''), 0, 200);
            $new['by'] = $user->name;
            $new['o'] = 'srv-'.$outletId;
            return $new;
        }
        // Perubahan hanya untuk mengambil catatan kas ke laci kas cabang: isi lain tidak boleh berubah.
        $a = $old; $b = $new;
        foreach (self::CLAIM as $k) unset($a[$k], $b[$k]);
        ksort($a); ksort($b);
        if ($a != $b) return 'Catatan cabang tidak bisa diubah. Batalkan lalu catat ulang.';
        if (!in_array((string) ($old['kind'] ?? ''), self::CASH, true)) return 'Catatan ini tidak perlu diambil.';
        if (!empty($old['claimedBy'])) return 'Catatan ini sudah masuk ke laci kas HP lain.';
        if ((string) ($new['claimedBy'] ?? '') !== $device) return 'Catatan hanya bisa diambil oleh HP ini sendiri.';
        if ($user->role === 'owner' || !$user->hasPermission('cash.manage')) return 'Hanya HP kasir cabang yang mengambil catatan kas ini.';
        return $new;
    }

    /** Catatan kas hanya untuk pemegang laci; permintaan cek stok untuk yang mengurus stok. */
    public static function visible(User $user, mixed $data): bool {
        if ($user->role === 'owner' || !is_array($data)) return true;
        return in_array((string) ($data['kind'] ?? ''), self::CASH, true)
            ? $user->hasPermission('cash.manage')
            : $user->hasPermission('stock.manage') || $user->hasPermission('stock.use');
    }
}
