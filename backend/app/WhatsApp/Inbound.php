<?php
namespace App\WhatsApp;
use App\WhatsApp\Jobs\SendReply;
use Illuminate\Support\Facades\{Crypt, DB, RateLimiter};

final class Inbound {
    public function __construct(private Devices $devices, private Replies $replies) {}
    /** Receives ONLY an authenticated, provider-normalized event from ChatkuGateway. */
    public function receive(array $e): void {
        validator($e, ['id'=>'required|string|max:160','device'=>'required|string|max:255','from'=>'required|string|max:40','text'=>'required|string|max:2000','occurred_at'=>'required|date','from_me'=>'required|boolean','group'=>'required|boolean'])->validate();
        if ($e['from_me'] || $e['group']) return;
        $time=\Carbon\CarbonImmutable::parse($e['occurred_at']);
        abort_if($time->isAfter(now()->addSeconds(30)) || $time->isBefore(now()->subSeconds(config('whatsapp.event_max_age_seconds',300))),422,'Pesan kedaluwarsa.');
        try { $from=Phone::normalize($e['from']); } catch(\InvalidArgumentException) { abort(422,'Nomor pengirim tidak valid.'); }
        $device=DB::table('wa_devices')->where('remote_id',$e['device'])->first();
        if (!$device) return;
        $throttle='wa-in:'.hash('sha256',$device->id.':'.$from);
        if (RateLimiter::tooManyAttempts($throttle,10)) return;
        RateLimiter::hit($throttle,60);
        DB::transaction(function()use($e,$device,$from){
            // Serialize settings/removal, duplicate webhooks, and admission per business.
            \App\Models\Business::whereKey($device->business_id)->lockForUpdate()->firstOrFail();
            $d=DB::table('wa_devices')->where('id',$device->id)->first();
            if(!$d || $d->status!=='connected') return;
            if(DB::table('wa_events')->where(['device_id'=>$d->id,'provider_id'=>$e['id']])->exists()) return;
            $event=DB::table('wa_events')->insertGetId(['device_id'=>$d->id,'provider_id'=>$e['id'],'state'=>'ignored','created_at'=>now(),'updated_at'=>now()]);
            $feature=(preg_match('/\b(status|cucian|pesanan|selesai)\b/i',$e['text'])||preg_match(Replies::ORDER_CODE,$e['text']))?'status':(preg_match('/harga|tarif|layanan|melayani|pricelist/i',$e['text'])?'services':null);
            if(!$feature){
                TopicStats::record($e['text']); return;
            }
            if(!$d->{'reply_'.$feature} || !$this->devices->allowed($d,$feature)) return;
            $reply=$feature==='status'?$this->replies->status($d,$from,$e['text']):$this->replies->services($d,$e['text']);
            if($feature==='services' && $reply===$this->replies->render('unknown_service')) TopicStats::record($e['text']);
            if($reply==='') return;
            $outbox=DB::table('wa_outbox')->insertGetId(['event_id'=>$event,'device_id'=>$d->id,'device_version'=>$d->version,'feature'=>$feature,'recipient'=>Crypt::encryptString($from),'body'=>Crypt::encryptString($reply),'state'=>'pending','created_at'=>now(),'updated_at'=>now()]);
            DB::table('wa_events')->where('id',$event)->update(['state'=>'queued']);
            SendReply::dispatch($outbox)->afterCommit();
        });
    }
}
