<?php
namespace App\WhatsApp;

use App\Models\Business;
use App\WhatsApp\Chatku\{ChatkuException, Client};
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Adapter resmi GOYANA → API Mitra CHATKU (KONTRAK-API-MITRA.md §8). CHATKU hanya "mesin WhatsApp":
 * data pelanggan, pesanan, balasan cepat, knowledge, dan media tetap di GOYANA.
 * Sub-akun CHATKU = satu usaha laundry ("biz-<id>"); nama perangkat tertaut di HP pemilik = "GOYANA".
 */
final class ChatkuHttpGateway implements ChatkuGateway, ChatkuExtras {
    public const PAIRING = ['pending', 'qr', 'connecting'];

    public function __construct(private Client $client, private array $config) {}

    public static function tenantRef(int $businessId): string { return config('whatsapp.chatku.tenant_prefix', 'biz-').$businessId; }

    /** Sub-akun usaha dibuat/diperbarui dulu (aman diulang), lalu perangkat per kunci stabil. */
    public function provision(string $key, string $phone, string $label): string {
        if (preg_match('/^goyana-wa:([0-9a-f-]{36})$/i', $key, $m)) {
            $businessId = (int) DB::table('wa_devices')->where('id', $m[1])->value('business_id');
            if (!$businessId) throw new HttpException(404, 'Perangkat tidak ditemukan.');
            $ref = self::tenantRef($businessId);
            $name = (string) (Business::whereKey($businessId)->value('name') ?: 'Laundry');
        } else {
            $ref = (string) ($this->config['marketing_tenant'] ?? 'goyana-pusat'); $name = 'GOYANA Pusat';
        }
        $this->wrap(fn () => $this->client->call('PUT', '/tenants/'.rawurlencode($ref), ['name' => mb_substr($name, 0, 120)]));
        $d = $this->wrap(fn () => $this->client->call('POST', '/tenants/'.rawurlencode($ref).'/devices', ['key' => $key, 'phone' => $phone, 'label' => mb_substr($label, 0, 60)]));
        return (string) ($d['id'] ?? '');
    }

    public function pairing(string $remoteId, string $method): array {
        $p = $this->wrap(fn () => $this->client->call('POST', '/devices/'.$this->id($remoteId).'/pairing', ['method' => $method]));
        if (($p['status'] ?? '') === 'connected') throw new HttpException(409, 'WhatsApp sudah tersambung. Tekan Perbarui status.');
        return ['kind' => (string) ($p['kind'] ?? ''), 'value' => $p['value'] ?? null, 'expires_at' => (string) ($p['expires_at'] ?? '')];
    }

    public function status(string $remoteId): array {
        $d = $this->wrap(fn () => $this->client->call('GET', '/devices/'.$this->id($remoteId)));
        return ['status' => self::mapStatus((string) ($d['status'] ?? '')), 'phone' => (string) ($d['phone'] ?? ''), 'phone_match' => $d['phone_match'] ?? null];
    }

    public static function mapStatus(string $s): string {
        return $s === 'connected' ? 'connected' : (in_array($s, self::PAIRING, true) ? 'pairing' : 'disconnected');
    }

    public function disconnect(string $remoteId): void {
        $this->wrap(fn () => $this->client->call('POST', '/devices/'.$this->id($remoteId).'/disconnect'), notFoundOk: true);
    }

    public function remove(string $remoteId): void {
        $this->wrap(fn () => $this->client->call('DELETE', '/devices/'.$this->id($remoteId)), notFoundOk: true);
    }

    public function send(string $remoteId, string $phone, string $text, string $key): string {
        return $this->message($remoteId, ['to' => $phone, 'text' => $text], $key);
    }

    public function sendMedia(string $remoteId, string $phone, ?string $text, array $media, string $key): string {
        return $this->message($remoteId, array_filter(['to' => $phone, 'text' => $text ?: null, 'media' => array_filter($media)]), $key);
    }

    private function message(string $remoteId, array $body, string $key): string {
        $d = $this->client->call('POST', '/devices/'.$this->id($remoteId).'/messages', $body, ['Idempotency-Key' => mb_substr($key, 0, 120)]);
        return (string) ($d['message_id'] ?? '');
    }

    public function ai(int $businessId, array $payload): array {
        return $this->client->call('POST', '/tenants/'.rawurlencode(self::tenantRef($businessId)).'/ai', $payload, [], 60);
    }

    public function aiTopup(int $businessId, int $amount, string $reference): int {
        $ref = self::tenantRef($businessId);
        $this->client->call('PUT', '/tenants/'.rawurlencode($ref), ['name' => mb_substr((string) (Business::whereKey($businessId)->value('name') ?: 'Laundry'), 0, 120)]);
        return (int) ($this->client->call('POST', '/tenants/'.rawurlencode($ref).'/ai-topup', ['amount' => $amount, 'reference' => mb_substr($reference, 0, 120)])['ai_balance'] ?? 0);
    }

    public function blast(string $remoteId, array $payload): array { return $this->client->call('POST', '/devices/'.$this->id($remoteId).'/blasts', $payload); }
    public function blastStatus(string $ref, int $page = 1): array { return $this->client->call('GET', '/blasts/'.rawurlencode($ref), ['page' => $page]); }
    public function cancelBlast(string $ref): array { return $this->client->call('POST', '/blasts/'.rawurlencode($ref).'/cancel'); }

    /**
     * Verifikasi webhook §6: HMAC-SHA256(rahasia, timestamp + "." + body mentah), umur ≤ 5 menit.
     * Pesan (masuk / dari pemilik) dinormalkan ke bentuk Inbound; event lain dikembalikan dengan "type".
     */
    public function verifyInbound(Request $request): array {
        $secret = (string) ($this->config['webhook_secret'] ?? '');
        if ($secret === '') throw new HttpException(503, 'CHATKU_WEBHOOK_SECRET belum diisi.');
        $ts = (string) $request->header('X-Chatku-Timestamp', '');
        $sig = strtolower((string) $request->header('X-Chatku-Signature', ''));
        $raw = $request->getContent();
        if (!ctype_digit($ts) || abs(time() - (int) $ts) > (int) config('whatsapp.event_max_age_seconds', 300)) throw new HttpException(401, 'Tanda waktu webhook tidak sah.');
        if ($sig === '' || !hash_equals(hash_hmac('sha256', $ts.'.'.$raw, $secret), $sig)) throw new HttpException(401, 'Tanda tangan webhook tidak sah.');
        $p = json_decode($raw, true);
        if (!is_array($p) || !is_string($p['event'] ?? null)) throw new HttpException(422, 'Isi webhook tidak dikenal.');
        $data = is_array($p['data'] ?? null) ? $p['data'] : [];
        $device = isset($p['device']['id']) ? (string) $p['device']['id'] : null;
        $base = ['id' => (string) ($p['id'] ?? ''), 'device' => $device];
        return match ($p['event']) {
            'message.received' => ['type' => 'message', 'id' => (string) ($data['message_id'] ?? $p['id'] ?? ''),
                'from' => (string) ($data['from'] ?? ''), 'name' => mb_substr((string) ($data['name'] ?? ''), 0, 80), 'text' => (string) ($data['text'] ?? ''),
                'occurred_at' => (string) ($data['received_at'] ?? $p['created_at'] ?? now()->toIso8601String()), 'from_me' => false, 'group' => (bool) ($data['is_group'] ?? false),
                'msg_type' => (string) ($data['type'] ?? 'text')] + $base,
            'message.from_me' => ['type' => 'message', 'id' => (string) ($data['message_id'] ?? $p['id'] ?? ''),
                // Chat ke diri sendiri (perintah #stop/#bot): CHATKU mengirim "to" kosong → pakai nomor perangkat.
                'from' => (string) (($data['to'] ?? null) ?: ($p['device']['phone'] ?? '')), 'text' => (string) ($data['text'] ?? ''), 'self' => (bool) ($data['self'] ?? false),
                'occurred_at' => (string) ($data['sent_at'] ?? $p['created_at'] ?? now()->toIso8601String()), 'from_me' => true, 'group' => false] + $base,
            default => ['type' => $p['event'], 'tenant' => $p['tenant'] ?? null, 'data' => $data] + $base,
        };
    }

    private function id(string $remoteId): string {
        if (!ctype_digit($remoteId)) throw new HttpException(422, 'ID perangkat CHATKU tidak valid.');
        return $remoteId;
    }

    /** Galat CHATKU → jawaban HTTP GOYANA yang jelas (tanpa isi permintaan). */
    private function wrap(\Closure $fn, bool $notFoundOk = false): array {
        try {
            return $fn();
        } catch (ChatkuException $e) {
            if ($notFoundOk && $e->status === 404) return [];
            $status = match (true) { $e->status === 409 => 409, $e->status === 422 => 422, $e->status === 404 => 404, default => 503 };
            throw new HttpException($status, $e->getMessage(), null, $e->retryAfter ? ['Retry-After' => (string) $e->retryAfter] : []);
        }
    }
}
