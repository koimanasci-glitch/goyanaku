<?php
namespace App\WhatsApp;
final class Template {
    public const VARIABLES = ['nama_outlet', 'kode_pesanan', 'status', 'estimasi', 'daftar_pesanan', 'daftar_layanan', 'nama_pelanggan', 'tagihan', 'pengambilan', 'link_nota'];
    // Bahasa ramah "Kak" (keputusan Paduka 10 Okt 2026). {{nama_pelanggan}} berisi " Nama" atau kosong.
    public const DEFAULTS = [
        'status' => "Halo Kak{{nama_pelanggan}} 👋\nPesanan *{{kode_pesanan}}* di {{nama_outlet}}:\n*{{status}}*\nPerkiraan selesai: {{estimasi}}\n{{tagihan}}{{pengambilan}}",
        'choose' => "Halo Kak 👋 Ada beberapa pesanan di nomor ini:\n{{daftar_pesanan}}\nBalas dengan kode pesanan yang ingin dicek ya.",
        'bills' => "Halo Kak 👋 Tagihan pesanan Kakak di {{nama_outlet}}:\n{{daftar_pesanan}}",
        'not_found' => "Maaf Kak, pesanan untuk nomor ini belum ditemukan di {{nama_outlet}} 🙏\nBila pesanan memakai nomor lain, kirim kode nota + 4 angka terakhir nomor HP pemesan (contoh: BKS-261008-1-0133 7890).",
        'services' => "Layanan aktif di {{nama_outlet}}:\n{{daftar_layanan}}",
        'unknown_service' => 'Maaf Kak, info layanan itu belum ada di data kami. Admin laundry akan bantu konfirmasi ya 🙏',
        'receipt' => "Nota pesanan *{{kode_pesanan}}* di {{nama_outlet}}:\n{{link_nota}}",
        'nota' => "Halo Kak{{nama_pelanggan}} 👋\nTerima kasih sudah laundry di {{nama_outlet}}. Nota pesanan *{{kode_pesanan}}*:\n{{link_nota}}\nPerkiraan selesai: {{estimasi}}",
        'ready' => "Halo Kak{{nama_pelanggan}} 👋\nCucian *{{kode_pesanan}}* sudah *siap* di {{nama_outlet}} ✅\n{{pengambilan}}{{tagihan}}Terima kasih 🙏",
        'late' => "Halo Kak{{nama_pelanggan}} 👋\nCucian *{{kode_pesanan}}* sudah siap sejak {{estimasi}} dan belum diambil. Kami tunggu di {{nama_outlet}} ya 🙏\n{{tagihan}}",
        'handover' => 'Baik Kak, pertanyaannya kami teruskan ke admin ya 🙏 Mohon ditunggu sebentar.',
    ];
    public static function validate(string $body): void {
        if (trim($body) === '' || strlen($body) > 4000) throw new \InvalidArgumentException('Isi template wajib diisi, maksimal 4000 byte.');
        preg_match_all('/\{\{([a-z_]+)\}\}/', $body, $m);
        foreach ($m[1] as $v) if (!in_array($v, self::VARIABLES, true)) throw new \InvalidArgumentException('Variabel tidak dikenal: '.$v);
        if (preg_match('/[{}]/', preg_replace('/\{\{([a-z_]+)\}\}/', '', $body))) throw new \InvalidArgumentException('Format variabel tidak valid.');
    }
    public static function validateFor(string $purpose, string $body): void {
        self::validate($body);
        if (!isset(self::DEFAULTS[$purpose])) throw new \InvalidArgumentException('Kegunaan template tidak dikenal.');
        preg_match_all('/\{\{([a-z_]+)\}\}/', self::DEFAULTS[$purpose], $allowed);
        preg_match_all('/\{\{([a-z_]+)\}\}/', $body, $used);
        foreach ($used[1] as $v) if (!in_array($v, $allowed[1], true)) throw new \InvalidArgumentException('Variabel tidak tersedia untuk kegunaan ini: '.$v);
    }
    public static function render(string $body, array $values): string {
        self::validate($body);
        return preg_replace_callback('/\{\{([a-z_]+)\}\}/', function ($m) use ($values) {
            if (!array_key_exists($m[1], $values)) throw new \InvalidArgumentException('Nilai variabel belum tersedia.');
            // One-pass substitution; customer-supplied text is never interpreted as template code.
            return (string) $values[$m[1]];
        }, $body);
    }
}
