<?php
namespace Tests\Support;

use App\WhatsApp\Contracts\ChatkuGateway;
use Illuminate\Http\Request;

/** Gateway tiruan khusus tes: mencatat kiriman, bisa dibuat gagal, dan menerima webhook bertanda rahasia tes. */
final class FakeGateway implements ChatkuGateway {
    /** @var list<array{remote:string,to:string,text:string,key:string}> */
    public array $sent = [];
    public function __construct(public bool $fail = false) {}
    public function provision(string $key, string $phone, string $label): string { return 'fake-'.$key; }
    public function pairing(string $remoteId, string $method): array { return ['kind' => $method, 'value' => 'TEST ONLY', 'expires_at' => now()->addMinute()->toIso8601String()]; }
    public function status(string $remoteId): array { return ['status' => 'connected', 'phone' => '6281234567890']; }
    public function disconnect(string $remoteId): void {}
    public function send(string $remoteId, string $phone, string $text, string $key): string {
        if ($this->fail) throw new \RuntimeException('ditolak');
        $this->sent[] = ['remote' => $remoteId, 'to' => $phone, 'text' => $text, 'key' => $key];
        return 'receipt-'.$key;
    }
    public function verifyInbound(Request $request): array {
        abort_unless($request->header('X-Test-Signature') === 'sah', 401);
        return $request->json()->all();
    }
}
