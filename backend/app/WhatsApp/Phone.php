<?php
namespace App\WhatsApp;
final class Phone {
    public static function normalize(string $value): string {
        $value = trim($value);
        if (!preg_match('/^\+?[0-9 ()-]+$/D', $value)) throw new \InvalidArgumentException('Nomor WhatsApp tidak valid.');
        $n = preg_replace('/\D/', '', $value);
        if (str_starts_with($n, '0')) $n = '62'.substr($n, 1);
        elseif (str_starts_with($n, '8')) $n = '62'.$n;
        if (!preg_match('/^[1-9][0-9]{7,14}$/D', $n)) throw new \InvalidArgumentException('Nomor WhatsApp tidak valid.');
        return $n;
    }
}
