<?php
namespace App\Support;

use App\Models\{Business, User};

/**
 * Stok per cabang (keputusan Paduka 10 Oktober 2026): saldo bahan dihitung dari catatan stok (stock_ledger) per outlet,
 * dan kiriman bahan antar cabang (stock_transfers) tercatat dua sisi: cabang asal mengirim, cabang tujuan menerima.
 *
 * - Catatan stok tidak bisa diubah atau dihapus staf setelah tersimpan (anti-curang); koreksi lewat Cek Stok (opname).
 * - Pegawai dan kasir (izin stock.use) hanya mencatat pemakaian dan penerimaan kiriman; kepala cabang dan owner
 *   (stock.manage) boleh semua jenis catatan.
 * - Kiriman dibuat cabang asal; hanya cabang tujuan (atau owner) yang bisa menerimanya, sekali, tidak lebih dari yang dikirim.
 */
final class StockGuard {
    /** Jenis catatan yang boleh ditulis akun dengan izin stock.use saja. */
    private const USE_TYPES = ['Pemakaian', 'Pemakaian Otomatis', 'Transfer Masuk'];

    public static function outletKey(int $id): string { return 'srv-'.$id; }

    /**
     * Catatan stok. Mengembalikan alasan penolakan, atau array data yang disimpan (outletId mengikuti outlet server).
     * @return string|array
     */
    public static function ledger(User $user, int $outletId, mixed $old, mixed $new, bool $deleted): string|array {
        $owner = $user->role === 'owner';
        if ($deleted) return $owner ? [] : 'Catatan stok hanya bisa dihapus owner.';
        if (!is_array($new) || trim((string) ($new['itemId'] ?? '')) === '' || !is_numeric($new['qty'] ?? null)) return 'Catatan stok tidak lengkap.';
        if (is_array($old) && !$owner) {
            $a = $old; $b = $new; unset($a['outletId'], $b['outletId']);
            ksort($a); ksort($b);
            if ($a != $b) return 'Catatan stok yang sudah tersimpan tidak bisa diubah. Pakai Cek Stok untuk menyesuaikan.';
        }
        $type = (string) ($new['type'] ?? '');
        if (!$owner && !$user->hasPermission('stock.manage') && !in_array($type, self::USE_TYPES, true)) {
            return 'Akun ini hanya bisa mencatat pemakaian bahan dan menerima kiriman.';
        }
        $new['outletId'] = self::outletKey($outletId);
        return $new;
    }

    /**
     * Kiriman bahan antar cabang. Mengembalikan alasan penolakan atau null bila boleh.
     */
    public static function transfer(User $user, Business $business, mixed $old, mixed $new, bool $deleted): ?string {
        $owner = $user->role === 'owner';
        if ($deleted) return $owner ? null : 'Kiriman bahan hanya bisa dihapus owner.';
        if (!is_array($new)) return 'Data kiriman tidak lengkap.';
        $outlets = $business->outlets()->pluck('id')->map(fn ($id) => self::outletKey((int) $id))->all();
        $from = (string) ($new['from'] ?? ''); $to = (string) ($new['to'] ?? '');
        $qty = $new['qty'] ?? null;
        if (!in_array($from, $outlets, true) || !in_array($to, $outlets, true) || $from === $to) return 'Cabang asal atau tujuan kiriman tidak valid.';
        if (!is_numeric($qty) || (float) $qty <= 0 || trim((string) ($new['itemId'] ?? '')) === '') return 'Jumlah kiriman tidak valid.';
        $mine = $user->outlet_id ? self::outletKey((int) $user->outlet_id) : '';

        if (!is_array($old)) {
            if (($new['status'] ?? '') !== 'sent') return 'Kiriman baru harus berstatus dalam perjalanan.';
            if ($owner) return null;
            if (!$user->hasPermission('stock.manage')) return 'Hanya kepala cabang atau owner yang bisa mengirim bahan.';
            return $from === $mine ? null : 'Kiriman hanya bisa dibuat dari cabang Anda sendiri.';
        }

        // Perubahan: hanya penerimaan (dalam perjalanan → diterima), oleh cabang tujuan atau owner.
        $fixed = ['id', 'itemId', 'from', 'to', 'qty', 'sentAt'];
        foreach ($fixed as $k) if (($old[$k] ?? null) != ($new[$k] ?? null)) return 'Isi kiriman yang sudah dikirim tidak bisa diubah.';
        if (($old['status'] ?? '') === 'received') {
            return $old == $new ? null : 'Kiriman ini sudah diterima.';
        }
        if (($new['status'] ?? '') !== 'received') return $owner ? null : 'Status kiriman tidak valid.';
        if (!$owner && $to !== $mine) return 'Hanya cabang tujuan yang bisa menerima kiriman ini.';
        $got = $new['receivedQty'] ?? $qty;
        if (!is_numeric($got) || (float) $got < 0 || (float) $got > (float) $qty) return 'Jumlah diterima tidak boleh melebihi jumlah dikirim.';
        return null;
    }

    /** Kiriman yang boleh dilihat akun ini: owner semua; staf hanya yang dari/ke cabangnya. */
    public static function visibleTransfer(User $user, mixed $data): bool {
        if ($user->role === 'owner') return true;
        if (!is_array($data) || !$user->outlet_id) return false;
        $mine = self::outletKey((int) $user->outlet_id);
        return ($data['from'] ?? null) === $mine || ($data['to'] ?? null) === $mine;
    }
}
