<?php
namespace App\WhatsApp;
use App\WhatsApp\Jobs\SendReply;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
final class RetryOutbox extends Command {
    protected $signature='goyana:wa-retry';
    protected $description='Recover unscheduled/stalled WhatsApp replies (module must be enabled).';
    public function handle(): int {
        if(!config('whatsapp.enabled')){$this->warn('Modul WhatsApp belum diaktifkan.');return self::FAILURE;}
        // Drop old unsent content instead of sending stale order status hours later.
        DB::table('wa_outbox')->whereNotIn('state',['sent','cancelled','failed'])->where('created_at','<',now()->subMinutes(10))
            ->update(['state'=>'cancelled','body'=>'','recipient'=>'','lease_until'=>null,'updated_at'=>now()]);
        $ids=DB::table('wa_outbox')->whereIn('state',['pending','retry','sending'])->where('attempts','<',5)
            ->where(function($q){$q->whereNull('lease_until')->orWhere('lease_until','<',now());})->orderBy('id')->limit(100)->pluck('id');
        foreach($ids as$id)SendReply::dispatch($id);
        $this->info('Antrean pemulihan: '.$ids->count());return self::SUCCESS;
    }
}
