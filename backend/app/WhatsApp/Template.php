<?php
namespace App\WhatsApp;
final class Template {
    public const VARIABLES = ['nama_outlet', 'kode_pesanan', 'status', 'estimasi', 'daftar_pesanan', 'daftar_layanan'];
    public const DEFAULTS = [
        'status' => 'Pesanan {{kode_pesanan}}: {{status}}. Estimasi selesai: {{estimasi}}. Data dari {{nama_outlet}}.',
        'choose' => "Ada beberapa pesanan pada nomor Anda:\n{{daftar_pesanan}}\nBalas dengan kode pesanan yang ingin diperiksa.",
        'not_found' => 'Pesanan untuk nomor ini belum ditemukan pada outlet ini. Silakan hubungi admin laundry untuk pemeriksaan.',
        'services' => "Layanan aktif di {{nama_outlet}}:\n{{daftar_layanan}}",
        'unknown_service' => 'Informasi layanan tersebut belum tersedia di data kami. Silakan konfirmasi ke admin laundry.',
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
