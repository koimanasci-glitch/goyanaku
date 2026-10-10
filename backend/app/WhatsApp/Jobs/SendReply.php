<?php
namespace App\WhatsApp\Jobs;
use App\WhatsApp\{Chatbot, Devices, Media};
use App\WhatsApp\Contracts\{ChatkuExtras, ChatkuGateway};
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\{Crypt, DB};
final class SendReply implements ShouldQueue {
    use Queueable, WaQueue;
    public int $tries=5;
    public int $timeout=30;
    public function __construct(public int $outboxId) { $this->viaWaQueue(); }
    public function backoff(): array {return [15,60,180,600];}
    public function handle(Devices $devices,ChatkuGateway $gateway): void {
        if(!config('whatsapp.enabled')) return;
        // Claim a lease. Provider MUST deduplicate this stable send key even after worker crash.
        $o=DB::transaction(function()use($devices){
            $o=DB::table('wa_outbox')->where('id',$this->outboxId)->lockForUpdate()->first();
            if(!$o || in_array($o->state,['sent','cancelled','failed'],true))return null;
            if($o->attempts>=5 || \Carbon\Carbon::parse($o->created_at)->isBefore(now()->subMinutes(10))){
                DB::table('wa_outbox')->where('id',$o->id)->update(['state'=>'cancelled','body'=>'','recipient'=>'','lease_until'=>null]);return null;
            }
            if($o->lease_until && \Carbon\Carbon::parse($o->lease_until)->isFuture()){ $this->release(65);return null; }
            $d=DB::table('wa_devices')->where('id',$o->device_id)->first();
            if(!$d || $d->status!=='connected' || $d->version!==$o->device_version || !self::stillAllowed($devices,$d,$o->feature)){
                DB::table('wa_outbox')->where('id',$o->id)->update(['state'=>'cancelled','body'=>'','recipient'=>'']);return null;
            }
            DB::table('wa_outbox')->where('id',$o->id)->update(['state'=>'sending','lease_until'=>now()->addSeconds(60),'attempts'=>$o->attempts+1,'updated_at'=>now()]);
            $o->remote=$d->remote_id;$o->business_id=$d->business_id;return $o;
        });
        if(!$o)return;
        try {
            $to=Crypt::decryptString($o->recipient);$text=Crypt::decryptString($o->body);
            $m=$o->media_id?DB::table('wa_media')->where(['id'=>$o->media_id,'business_id'=>$o->business_id])->first():null;
            if($m && $gateway instanceof ChatkuExtras) $receipt=$gateway->sendMedia($o->remote,$to,$text!==''?$text:null,Media::forChatku($m),'goyana-reply:'.$o->id);
            elseif($text!=='') $receipt=$gateway->send($o->remote,$to,$text,'goyana-reply:'.$o->id);
            else { DB::table('wa_outbox')->where('id',$o->id)->update(['state'=>'cancelled','body'=>'','recipient'=>'','lease_until'=>null]);return; }
            if($receipt==='')throw new \RuntimeException('Chatku belum mengonfirmasi penerimaan.');
            DB::table('wa_outbox')->where('id',$o->id)->update(['state'=>'sent','provider_receipt'=>$receipt,'lease_until'=>null,'body'=>'','recipient'=>'','updated_at'=>now()]);
        } catch(\Throwable $e){
            DB::table('wa_outbox')->where('id',$o->id)->where('state','sending')->update(['state'=>'retry','lease_until'=>null,'updated_at'=>now()]);
            // Do not expose provider payloads/tokens in queue exceptions.
            throw new \RuntimeException('Pengiriman Chatku belum terkonfirmasi.');
        }
    }
    /** Paket/sakelar masih mengizinkan saat akan dikirim (pengaturan bisa berubah setelah antre). */
    public static function stillAllowed(Devices $devices, object $d, string $feature): bool {
        if(in_array($feature,['status','services'],true)) return (bool)$d->{'reply_'.$feature} && $devices->allowed($d,$feature);
        if(!$devices->allowed($d,'connection')) return false;
        $s=Chatbot::settings((int)$d->business_id,(int)$d->outlet_id);
        return match($feature){
            'quick'=>$s['quick_enabled'] && Chatbot::allows((int)$d->business_id,'quick'),
            'ai'=>$s['ai_enabled'] && Chatbot::allows((int)$d->business_id,'ai'),
            'auto'=>Chatbot::allows((int)$d->business_id,'messages'),
            'optout','handover'=>true,
            default=>false,
        };
    }
    public function failed(?\Throwable $exception): void {
        DB::table('wa_outbox')->where('id',$this->outboxId)->whereNotIn('state',['sent','cancelled'])->update(['state'=>'failed','lease_until'=>null,'body'=>'','recipient'=>'','updated_at'=>now()]);
    }
}
