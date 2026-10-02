<?php
namespace App\Support;
use App\Models\Business;
use Illuminate\Support\Facades\DB;
/**
 * Balasan Cepat pintar untuk pelanggan laundry (GOYANA-SISTEM-PUSAT.md §47), tanpa AI.
 * Data dari sinkronisasi HP: pelanggan, pesanan, layanan, profil outlet. Hanya data milik nomor pengirim yang dibalas.
 * Mengembalikan null bila tidak ada maksud yang cocok (diteruskan ke kasir / Chatbot AI).
 */
class QuickReply {
    private const LABELS = ['jemput' => 'Menunggu dijemput', 'antrian' => 'Dalam antrean', 'proses' => 'Sedang diproses', 'telat' => 'Sedang diproses',
        'siap' => 'Siap diambil ✅', 'diantar' => 'Sedang diantar 🛵'];
    private const INTENTS = [
        'status' => ['sudah jadi', 'udah jadi', 'sdh jadi', 'jadi belum', 'selesai', 'beres', 'kapan', 'status', 'cucian', 'baju', 'laundry saya', 'pesanan', 'orderan', 'bisa diambil', 'sudah bisa'],
        'bill' => ['berapa', 'total', 'tagihan', 'bayar', 'sisa', 'harus bayar', 'biaya'],
        'receipt' => ['nota', 'struk', 'invoice', 'kwitansi'],
        'hours' => ['kapan buka', 'jam buka', 'buka jam', 'tutup jam', 'jam berapa', 'buka', 'tutup', 'alamat', 'lokasi', 'maps', 'dimana', 'di mana'],
        'price' => ['harga', 'price', 'tarif', 'per kilo', 'perkilo', 'kiloan', 'satuan', 'pricelist', 'daftar harga'],
        'pickup' => ['jemput', 'antar', 'pickup', 'delivery', 'kurir', 'ongkir'],
    ];

    public static function digits(string $phone): string {
        $d = preg_replace('/\D+/', '', $phone);
        return str_starts_with($d, '62') ? '0'.substr($d, 2) : $d;
    }

    private static function records(Business $b, string $collection) {
        return DB::table('sync_records')->where(['business_id' => $b->id, 'collection' => $collection, 'deleted' => false])->get()
            ->map(fn ($r) => json_decode((string) $r->data, true))->filter(fn ($d) => is_array($d))->values();
    }

    private static function rp(int|float $n): string { return 'Rp'.number_format((int) round($n), 0, ',', '.'); }

    public static function intent(string $text): ?string {
        $t = ' '.mb_strtolower(preg_replace('/\s+/u', ' ', $text)).' ';
        $best = null; $score = 0;
        foreach (self::INTENTS as $intent => $words) {
            $s = 0;
            foreach ($words as $w) if (str_contains($t, $w)) $s += substr_count($w, ' ') + 1;
            if ($s > $score) { $best = $intent; $score = $s; }
        }
        return $best;
    }

    /** @return array{intent:?string,reply:?string,customer:?string} */
    public static function answer(Business $b, string $from, string $text): array {
        $intent = self::intent($text);
        $phone = self::digits($from);
        $customer = strlen($phone) >= 8 ? self::records($b, 'customers')->first(fn ($c) => str_contains(self::digits((string) ($c['phone'] ?? '')), $phone)) : null;
        $name = $customer['name'] ?? null;
        $orders = $name ? self::records($b, 'orders')->filter(function ($o) use ($name) {
            $n = $o['detail']['name'] ?? ($o['card']['fields'][2][0] ?? '');
            $st = $o['card']['dataset']['st'] ?? '';
            return mb_strtolower(trim((string) $n)) === mb_strtolower(trim($name)) && isset(self::LABELS[$st]);
        })->sortByDesc(fn ($o) => $o['card']['dataset']['created177'] ?? '')->take(5)->values() : collect();
        $hello = $name ? "Halo, $name 👋\n" : "Halo 👋\n";
        $reply = match ($intent) {
            'status' => $name ? ($orders->isEmpty() ? $hello.'Saat ini tidak ada cucian aktif atas nama Anda.' : $hello.self::statusLines($orders)) : null,
            'bill' => $name ? ($orders->isEmpty() ? $hello.'Tidak ada tagihan berjalan.' : $hello.self::billLines($orders)) : null,
            'receipt' => $name && $orders->isNotEmpty() ? $hello.'Nota pesanan Anda: '.$orders->map(fn ($o) => self::orderId($o))->implode(', ').".\nNota digital dikirim kasir saat pesanan dibuat. Balas \"kirim nota\" bila ingin dikirim ulang." : null,
            'hours' => self::outletLines($b),
            'price' => self::priceLines($b),
            'pickup' => self::pickupLine($b),
            default => null,
        };
        // Unknown number asking about orders: no personal data, only a general hint.
        if ($reply === null && in_array($intent, ['status', 'bill', 'receipt'], true) && !$name) {
            $reply = "Halo 👋\nNomor ini belum terdaftar sebagai pelanggan kami. Sebutkan nama atau nomor nota, admin akan membantu.";
        }
        return ['intent' => $intent, 'reply' => $reply, 'customer' => $name];
    }

    private static function orderId(array $o): string { return (string) ($o['detail']['id'] ?? ($o['card']['fields'][1][0] ?? 'pesanan')); }

    private static function statusLines($orders): string {
        return $orders->map(function ($o) {
            $st = $o['card']['dataset']['st'];
            $items = collect($o['detail']['items'] ?? [])->map(fn ($i) => ($i['n'] ?? '').' '.rtrim(rtrim(number_format((float) ($i['qty'] ?? 0), 2, ',', ''), '0'), ',').' '.($i['unit'] ?? ''))->implode(', ');
            $due = isset($o['detail']['due']) ? \Carbon\Carbon::parse($o['detail']['due'])->timezone('Asia/Jakarta')->format('d/m H:i') : null;
            return '• '.self::orderId($o).($items ? " ($items)" : '').': *'.self::LABELS[$st].'*'.($due && !in_array($st, ['siap', 'diantar'], true) ? " · perkiraan selesai $due" : '');
        })->implode("\n");
    }

    private static function billLines($orders): string {
        $sum = 0;
        $lines = $orders->map(function ($o) use (&$sum) {
            $total = (int) ($o['card']['total'] ?? 0);
            $paid = (int) ($o['card']['dataset']['paid177'] ?? ($o['detail']['paid'] ?? 0));
            $left = max(0, $total - $paid); $sum += $left;
            return '• '.self::orderId($o).': total '.self::rp($total).($left > 0 ? ', sisa '.self::rp($left) : ', *lunas*');
        })->implode("\n");
        return $lines.($sum > 0 ? "\nTotal belum dibayar: *".self::rp($sum).'*' : '');
    }

    private static function outletLines(Business $b): ?string {
        $o = self::records($b, 'outlet_profiles')->first();
        if (!$o) return null;
        $parts = array_filter([
            '*'.($o['name'] ?? $b->name).'*',
            !empty($o['address']) ? '📍 '.$o['address'] : null,
            !empty($o['hours']) ? '🕘 '.(is_array($o['hours']) ? implode(', ', $o['hours']) : $o['hours']) : null,
            !empty($o['maps']) ? '🗺 '.$o['maps'] : null,
            !empty($o['phone']) ? '☎ '.$o['phone'] : null,
        ]);
        return count($parts) > 1 ? implode("\n", $parts) : null;
    }

    private static function priceLines(Business $b): ?string {
        $services = self::records($b, 'services')->filter(fn ($s) => !empty($s['prices']))->take(12);
        if ($services->isEmpty()) return null;
        return "Daftar harga *{$b->name}*:\n".$services->map(function ($s) {
            $p = collect($s['prices'])->filter(fn ($v, $k) => ($s['enabled'][$k] ?? true) && $v > 0);
            return '• '.$s['name'].': '.$p->map(fn ($v, $k) => "$k ".self::rp($v))->implode(' · ').' /'.($s['unit'] ?? '');
        })->implode("\n");
    }

    private static function pickupLine(Business $b): string {
        return "Kami melayani antar-jemput 🛵. Kirim alamat lengkap + share lokasi, admin akan konfirmasi ongkir dan jadwal.";
    }
}
