<?php
namespace App\WhatsApp\Jobs;

/** Semua job WhatsApp di antrean "wa" (koneksi dari whatsapp.queue_connection bila diisi). */
trait WaQueue {
    private function viaWaQueue(): void {
        if ($c = config('whatsapp.queue_connection')) $this->onConnection($c);
        $this->onQueue('wa');
    }
}
