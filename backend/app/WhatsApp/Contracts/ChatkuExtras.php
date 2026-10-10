<?php
namespace App\WhatsApp\Contracts;

/**
 * Kemampuan tambahan API Mitra CHATKU di luar ChatkuGateway (KONTRAK-API-MITRA.md §2–§5).
 * Hanya adapter resmi (ChatkuHttpGateway) dan gateway tiruan tes yang mengimplementasikannya;
 * fitur yang membutuhkannya diam (tidak mengarang hasil) bila gateway aktif tidak mendukung.
 */
interface ChatkuExtras {
    /** Kirim teks + berkas (link sementara milik GOYANA). $media = {url, key, filename?}. Idempotent per $key. */
    public function sendMedia(string $remoteId, string $phone, ?string $text, array $media, string $key): string;
    /** Hapus perangkat di CHATKU (bukan hanya putus). */
    public function remove(string $remoteId): void;
    /** AI tanpa simpan data. Mengembalikan {answer, media_id, handover, cost, balance, unverified_prices, …}. */
    public function ai(int $businessId, array $payload): array;
    /** Teruskan isi saldo AI usaha ke CHATKU (idempotent per $reference). Mengembalikan saldo AI di CHATKU. */
    public function aiTopup(int $businessId, int $amount, string $reference): int;
    /** Buat blast (idempotent per ref). */
    public function blast(string $remoteId, array $payload): array;
    public function blastStatus(string $ref, int $page = 1): array;
    public function cancelBlast(string $ref): array;
}
