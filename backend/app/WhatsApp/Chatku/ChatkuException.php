<?php
namespace App\WhatsApp\Chatku;

/** Jawaban gagal dari API Mitra CHATKU: kode resmi (§ tabel kode) tanpa membawa kunci/isi permintaan. */
final class ChatkuException extends \RuntimeException {
    public function __construct(public readonly string $codeName, string $message, public readonly int $status = 0, public readonly ?int $retryAfter = null) {
        parent::__construct($message, $status);
    }
    /** Sementara (boleh diulang nanti), bukan kesalahan data. */
    public function temporary(): bool {
        return $this->status === 0 || $this->status === 429 || $this->status >= 500 || $this->codeName === 'device_offline';
    }
}
