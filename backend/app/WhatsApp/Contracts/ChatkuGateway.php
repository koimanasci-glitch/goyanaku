<?php
namespace App\WhatsApp\Contracts;

use Illuminate\Http\Request;

/** Internal Goyana contract, NOT a claim about the unpublished Chatku HTTP API. */
interface ChatkuGateway {
    /** Stable idempotency key must recover the same provider session after a timeout. */
    public function provision(string $key, string $phone, string $label): string;
    /** Return {kind: qr|code, value: string, expires_at: ISO8601}; never invent values. */
    public function pairing(string $remoteId, string $method): array;
    /** Must verify provider account, connected identity/phone, and status remotely. */
    public function status(string $remoteId): array;
    public function disconnect(string $remoteId): void;
    /** MUST be provider-idempotent, including retry after an ambiguous timeout. */
    public function send(string $remoteId, string $phone, string $text, string $key): string;
    /** Authenticate raw request with the ACTUAL provider contract before normalizing.
     * Return {id, device, from, text, occurred_at, from_me, group} for incoming text only.
     * Invalid signatures, other provider accounts, unsupported events MUST throw.
     */
    public function verifyInbound(Request $request): array;
}
