<?php
namespace App\Support;

/** RFC 6238 time-based one-time passwords (Google Authenticator, Authy, etc). */
final class Totp {
    private const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

    public static function secret(): string {
        $bytes = random_bytes(20);
        $bits = '';
        foreach (str_split($bytes) as $c) $bits .= str_pad(decbin(ord($c)), 8, '0', STR_PAD_LEFT);
        $out = '';
        foreach (str_split($bits, 5) as $chunk) $out .= self::ALPHABET[bindec(str_pad($chunk, 5, '0'))];
        return $out;
    }

    public static function code(string $secret, int $step): string {
        $key = self::decode($secret);
        $hash = hash_hmac('sha1', pack('N2', 0, $step), $key, true);
        $offset = ord($hash[19]) & 0x0f;
        $value = ((ord($hash[$offset]) & 0x7f) << 24) | (ord($hash[$offset + 1]) << 16) | (ord($hash[$offset + 2]) << 8) | ord($hash[$offset + 3]);
        return str_pad((string) ($value % 1000000), 6, '0', STR_PAD_LEFT);
    }

    /** Returns the matching time step (±30 s window) or null. */
    public static function verify(string $secret, string $code, ?int $now = null): ?int {
        $code = preg_replace('/\D/', '', $code);
        if (strlen($code) !== 6) return null;
        $step = intdiv($now ?? time(), 30);
        foreach ([0, -1, 1] as $drift) {
            if (hash_equals(self::code($secret, $step + $drift), $code)) return $step + $drift;
        }
        return null;
    }

    public static function uri(string $secret, string $email): string {
        return 'otpauth://totp/'.rawurlencode('GOYANA Pusat:'.$email).'?secret='.$secret.'&issuer='.rawurlencode('GOYANA Pusat').'&digits=6&period=30';
    }

    private static function decode(string $secret): string {
        $bits = '';
        foreach (str_split(strtoupper($secret)) as $c) {
            $i = strpos(self::ALPHABET, $c);
            if ($i !== false) $bits .= str_pad(decbin($i), 5, '0', STR_PAD_LEFT);
        }
        $out = '';
        foreach (str_split($bits, 8) as $byte) if (strlen($byte) === 8) $out .= chr(bindec($byte));
        return $out;
    }
}
