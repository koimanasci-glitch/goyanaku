<?php
namespace App\WhatsApp;

/**
 * Maksud pesan pelanggan untuk balasan tanpa AI. Urutan: kode nota → tagihan → status → harga → jam/alamat → antar-jemput → nota.
 * Perbaikan 10 Okt 2026: "harga cucian berapa" tidak lagi dianggap tanya status; "berapa" saja tidak dianggap apa pun (diteruskan ke AI/admin).
 */
final class Intent {
    private const BILL = '/\b(tagihan|sisa (bayar|tagihan|pembayaran|nya)|total (bayar|tagihan|saya|nya)|harus (saya )?bayar|berapa (yang )?(harus )?(di)?bayar|belum (lunas|dibayar|bayar)|(udah|sudah|sdh) lunas|lunas (belum|blm)|kurang bayar)\b/u';
    private const STATUS = '/\b(status|(sudah|udah|sdh|dah|blm|belum) (jadi|selesai|beres|siap|bisa diambil)|jadi (belum|blm)|selesai(kah)?|beres|sampai mana|sampe mana|kapan (jadi|selesai|beres|bisa (di)?ambil|diantar|siap)|bisa diambil|siap diambil|(cucian|laundry|laundryan|pesanan|orderan|order|baju|pakaian) (saya|aku|ku|sy)|cek (cucian|pesanan|laundry|status|orderan))\b/u';
    private const PRICE = '/\b(harga|tarif|price ?list|daftar harga|per ?kilo|perkilo|per ?kg|sekilo|biaya cuci|ongkos cuci|berapa(an)? (per|1 ?kg|satu kilo|sekilo))\b/u';
    private const HOURS = '/\b(jam (buka|tutup|operasional|berapa)|buka (jam|gak|nggak|ngga|tidak|ga|hari)|tutup jam|alamat(nya)?|lokasi(nya)?|di ?mana (alamat|lokasi|tempat)|share ?loc|maps)\b/u';
    private const PICKUP = '/\b(jemput|antar ?jemput|pick ?up|delivery|kurir|ongkir)\b/u';
    private const RECEIPT = '/\b(nota|struk|kwitansi|invoice)\b/u';

    public static function of(string $text): ?string {
        $t = mb_strtolower(preg_replace('/\s+/u', ' ', trim($text)));
        if ($t === '') return null;
        if (preg_match(Replies::ORDER_CODE, $text)) return preg_match(self::BILL, $t) ? 'bill' : 'status';
        foreach (['bill' => self::BILL, 'status' => self::STATUS, 'price' => self::PRICE, 'hours' => self::HOURS, 'pickup' => self::PICKUP, 'receipt' => self::RECEIPT] as $intent => $re) {
            if (preg_match($re, $t)) return $intent;
        }
        return null;
    }

    /** Fitur paket/sakelar yang dipakai tiap maksud. */
    public static function feature(string $intent): string {
        return match ($intent) { 'status', 'bill', 'receipt' => 'status', 'price' => 'services', default => 'quick' };
    }
}
