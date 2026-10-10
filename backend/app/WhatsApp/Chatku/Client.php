<?php
namespace App\WhatsApp\Chatku;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

/**
 * Klien HTTP API Mitra CHATKU (KONTRAK-API-MITRA.md). Kunci API hanya dibaca dari config (.env server).
 * Pesan galat tidak pernah memuat kunci, nomor, atau isi pesan.
 */
final class Client {
    public function __construct(private array $config) {}

    public function configured(): bool { return ($this->config['api_key'] ?? '') !== ''; }

    /** @return array isi "data" */
    public function call(string $method, string $path, array $body = [], array $headers = [], ?int $timeout = null): array {
        if (!$this->configured()) throw new ChatkuException('not_configured', 'CHATKU_API_KEY belum diisi.', 503);
        $req = Http::baseUrl($this->config['base_url'])->withToken((string) $this->config['api_key'])
            ->acceptJson()->asJson()->timeout($timeout ?? max(5, (int) ($this->config['timeout'] ?? 20)))->withHeaders($headers + ['User-Agent' => 'GOYANA/1']);
        try {
            $res = match (strtoupper($method)) {
                'GET' => $req->get($path, $body ?: null),
                'POST' => $req->post($path, $body ?: (object) []),
                'PUT' => $req->put($path, $body ?: (object) []),
                'DELETE' => $req->delete($path),
            };
        } catch (ConnectionException) {
            throw new ChatkuException('unreachable', 'CHATKU tidak dapat dihubungi.', 0, 30);
        }
        if ($res->status() === 204) return [];
        if ($res->successful()) {
            $data = $res->json('data');
            if (!is_array($data)) throw new ChatkuException('bad_response', 'Jawaban CHATKU tidak dikenal.', 502);
            return $data;
        }
        $code = (string) ($res->json('error.code') ?? 'http_'.$res->status());
        $msg = mb_substr((string) ($res->json('error.message') ?? 'CHATKU menolak permintaan.'), 0, 200);
        $retry = $res->json('error.retry_after') ?? ($res->header('Retry-After') ?: null);
        throw new ChatkuException($code, $msg, $res->status(), $retry !== null ? (int) $retry : null);
    }
}
