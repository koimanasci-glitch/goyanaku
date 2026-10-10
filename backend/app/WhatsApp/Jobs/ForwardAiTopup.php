<?php
namespace App\WhatsApp\Jobs;

use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\DB;

/** Isi saldo AI di GOYANA → isi saldo AI sub-akun di CHATKU (idempotent per referensi; masuk tagihan mitra CHATKU). */
final class ForwardAiTopup implements ShouldQueue {
    use Queueable, WaQueue;
    public int $tries = 8;
    public function __construct(public int $businessId, public int $amount, public string $reference) { $this->viaWaQueue(); }
    public function backoff(): array { return [30, 120, 600, 1800, 3600]; }

    public static function dispatchIfConnected(int $businessId, int $amount, string $reference): void {
        if (!config('whatsapp.enabled') || !(app(ChatkuGateway::class) instanceof ChatkuExtras)) return;
        self::dispatch($businessId, $amount, $reference)->afterCommit();
    }

    /** Referensi tetap (≤120 karakter) supaya pengulangan tidak mengisi dua kali di CHATKU. */
    public static function reference(string $ref): string { return 'goyana-topup:'.hash('sha256', $ref); }

    public function failed(?\Throwable $e): void {
        \App\Support\AdminNotify::send('Isi saldo AI belum masuk ke CHATKU',
            "Isi saldo AI usaha #{$this->businessId} sebesar Rp".number_format($this->amount, 0, ',', '.')." (ref {$this->reference}) gagal diteruskan ke CHATKU setelah beberapa kali.\n"
            ."Saldo di GOYANA sudah bertambah. Periksa kunci API & minimal isi saldo mitra di admin CHATKU, lalu jalankan: php artisan queue:retry all");
    }

    public function handle(ChatkuGateway $gateway): void {
        if (!$gateway instanceof ChatkuExtras) return;
        $balance = $gateway->aiTopup($this->businessId, $this->amount, self::reference($this->reference));
        $actor = DB::table('users')->where('business_id', $this->businessId)->orderBy('id')->value('id');
        if ($actor) DB::table('audit_events')->insert(['actor_id' => $actor,
            'business_id' => $this->businessId, 'action' => 'ai.topup_chatku',
            'details' => json_encode(['amount' => $this->amount, 'reference' => $this->reference, 'chatku_balance' => $balance]), 'created_at' => now()]);
    }
}
