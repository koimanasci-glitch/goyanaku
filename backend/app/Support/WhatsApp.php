<?php
namespace App\Support;

use App\WhatsApp\Contracts\ChatkuGateway;
use App\WhatsApp\UnavailableGateway;

/**
 * Pintu kirim WA blast marketing. Sejak 8 Oktober 2026 hanya ada satu jalur ke Chatku: kontrak ChatkuGateway milik
 * modul App\WhatsApp, yang juga dipakai balasan status client. Mesin antrean (App\Support\Blast) mengatur giliran dan batas.
 * Selama adapter Chatku resmi belum dipasang, gateway bawaan menolak semua kiriman dan blast tetap diam.
 */
final class WhatsApp {
    public static function connected(): bool {
        return !(app(ChatkuGateway::class) instanceof UnavailableGateway);
    }

    /**
     * Kirim dari nomor pengirim marketing yang sudah dipasangkan di Chatku ($sender->remote_id).
     * $key tetap per pesan supaya pengulangan setelah timeout tidak mengirim ganda. Melempar \RuntimeException bila gagal.
     */
    public static function send(object $sender, string $to, string $text, string $key): void {
        if (!self::connected()) throw new \RuntimeException('Gateway WhatsApp belum tersambung.');
        if (($sender->remote_id ?? '') === '') throw new \RuntimeException('Nomor pengirim belum dipasangkan di Chatku.');
        try {
            app(ChatkuGateway::class)->send($sender->remote_id, $to, $text, $key);
        } catch (\Throwable $e) {
            throw new \RuntimeException('Gateway menolak: '.class_basename($e));
        }
    }
}
