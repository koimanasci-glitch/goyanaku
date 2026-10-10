<?php
namespace App\WhatsApp\Console;
use App\WhatsApp\{Chatbot, Media};
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
final class PruneCommand extends Command {
    protected $signature = 'goyana:wa-prune';
    protected $description = 'Hapus riwayat chat singkat (>24 jam), jeda bot yang habis, berkas media yatim, dan catatan pesan otomatis lama';
    public function handle(): int {
        $chat = Chatbot::prune(); $files = Media::prune(); app(\App\WhatsApp\Blasts::class)->settle();
        DB::table('wa_auto_sent')->where('created_at', '<', now()->subDays(90))->delete();
        $this->info("$chat riwayat chat, $files berkas yatim dibersihkan.");
        return 0;
    }
}
