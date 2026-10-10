<?php
namespace App\WhatsApp\Console;
use App\WhatsApp\QrisWatch;
use Illuminate\Console\Command;
final class QrisWatchCommand extends Command {
    protected $signature = 'goyana:qris-watch';
    protected $description = 'Pantau perubahan QRIS tiap usaha dan beri tahu pemilik bila berubah';
    public function handle(QrisWatch $watch): int { $this->info($watch->run().' QRIS berubah.'); return 0; }
}
