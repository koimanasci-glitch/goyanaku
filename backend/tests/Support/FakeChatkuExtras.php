<?php
namespace Tests\Support;

use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Http\Request;

/** Gateway tiruan lengkap (dengan kemampuan API Mitra): mencatat semua panggilan; jawaban AI/blast bisa diatur tes. */
final class FakeChatkuExtras implements ChatkuGateway, ChatkuExtras {
    public array $calls = [];
    public array $aiAnswer = ['answer' => 'Halo Kak, bisa.', 'media_id' => null, 'handover' => false, 'cost' => 120, 'balance' => 5000, 'model' => 'test', 'unverified_prices' => []];
    public ?\Throwable $aiError = null;
    private function log(string $m, array $a): string { $this->calls[] = [$m, $a]; return (string) count($this->calls); }
    public function provision(string $key, string $phone, string $label): string { $this->log('provision', func_get_args()); return '77'; }
    public function pairing(string $remoteId, string $method): array { return ['kind' => $method, 'value' => 'TEST ONLY', 'expires_at' => now()->addMinute()->toIso8601String()]; }
    public function status(string $remoteId): array { return ['status' => 'connected', 'phone' => '6281234567890']; }
    public function disconnect(string $remoteId): void { $this->log('disconnect', func_get_args()); }
    public function remove(string $remoteId): void { $this->log('remove', func_get_args()); }
    public function send(string $remoteId, string $phone, string $text, string $key): string { return 'msg-'.$this->log('send', func_get_args()); }
    public function sendMedia(string $remoteId, string $phone, ?string $text, array $media, string $key): string { return 'msg-'.$this->log('sendMedia', func_get_args()); }
    public function ai(int $businessId, array $payload): array { $this->log('ai', func_get_args()); if ($this->aiError) throw $this->aiError; return $this->aiAnswer; }
    public function aiTopup(int $businessId, int $amount, string $reference): int { $this->log('aiTopup', func_get_args()); return $amount; }
    public function blast(string $remoteId, array $payload): array { $this->log('blast', func_get_args()); return ['ref' => $payload['ref'], 'status' => 'running', 'skipped' => 0]; }
    public function blastStatus(string $ref, int $page = 1): array { return ['ref' => $ref]; }
    public function cancelBlast(string $ref): array { $this->log('cancelBlast', func_get_args()); return ['ref' => $ref, 'status' => 'cancelled']; }
    public function verifyInbound(Request $request): array { abort_unless($request->header('X-Test-Signature') === 'sah', 401); return $request->json()->all(); }
    public function called(string $m): array { return array_values(array_map(fn ($c) => $c[1], array_filter($this->calls, fn ($c) => $c[0] === $m))); }
}
