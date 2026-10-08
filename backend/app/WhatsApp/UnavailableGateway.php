<?php
namespace App\WhatsApp;
use App\WhatsApp\Contracts\ChatkuGateway;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpException;
final class UnavailableGateway implements ChatkuGateway {
    private function unavailable(): never { throw new HttpException(503, 'Kontrak API Chatku belum dikonfigurasi.'); }
    public function provision(string $key, string $phone, string $label): string { $this->unavailable(); }
    public function pairing(string $remoteId, string $method): array { $this->unavailable(); }
    public function status(string $remoteId): array { $this->unavailable(); }
    public function disconnect(string $remoteId): void { $this->unavailable(); }
    public function send(string $remoteId, string $phone, string $text, string $key): string { $this->unavailable(); }
    public function verifyInbound(Request $request): array { $this->unavailable(); }
}
