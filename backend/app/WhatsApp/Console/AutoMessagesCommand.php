<?php
namespace App\WhatsApp\Console;
use App\WhatsApp\AutoMessages;
use Illuminate\Console\Command;
final class AutoMessagesCommand extends Command {
    protected $signature = 'goyana:wa-auto';
    protected $description = 'Kirim pesan otomatis WhatsApp (link nota, siap diambil, belum diambil) sesuai pengaturan tiap cabang';
    public function handle(AutoMessages $auto): int { $this->info($auto->run().' pesan otomatis diantrekan.'); return 0; }
}
