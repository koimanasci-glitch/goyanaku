<?php
namespace App\Support;

use Illuminate\Support\Facades\Http;

/**
 * Gateway WhatsApp untuk blast marketing. Sengaja tipis: mesin antrean (App\Support\Blast) yang mengatur giliran dan batas.
 * Driver "none" = belum tersambung. Driver "http" mengirim JSON {from, to, text}; bentuk ini disesuaikan saat CHATKU tersambung.
 */
final class WhatsApp {
    public static function connected(): bool {
        return config('goyana.whatsapp.driver') === 'http' && config('goyana.whatsapp.url') !== '';
    }

    /** Melempar \RuntimeException bila pesan tidak terkirim. */
    public static function send(string $from, string $to, string $text): void {
        if (!self::connected()) throw new \RuntimeException('Gateway WhatsApp belum tersambung.');
        try {
            $reply = Http::timeout(20)->withToken((string) config('goyana.whatsapp.token'))->acceptJson()
                ->post((string) config('goyana.whatsapp.url'), ['from' => $from, 'to' => $to, 'text' => $text]);
        } catch (\Throwable $e) {
            throw new \RuntimeException('Gateway tidak terjangkau: '.class_basename($e));
        }
        if (!$reply->successful()) throw new \RuntimeException('Gateway menolak ('.$reply->status().')');
    }
}
