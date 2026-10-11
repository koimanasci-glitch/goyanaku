<?php
namespace App\WhatsApp\Http;
use App\WhatsApp\{Blasts, ChatkuHttpGateway, Inbound};
use App\WhatsApp\Contracts\ChatkuGateway;
use App\Support\Blast;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Satu alamat webhook CHATKU (KONTRAK-API-MITRA.md §6). Selalu menjawab 2xx untuk event sah yang tidak perlu tindakan
 * (lama, kosong, tidak dikenal) supaya CHATKU tidak mengulang; hanya tanda tangan salah yang ditolak.
 */
final class WebhookController {
    public function __invoke(Request $r,ChatkuGateway $gateway,Inbound $inbound){
        abort_if(strlen($r->getContent())>65536,413);
        $event=$gateway->verifyInbound($r);
        $type=$event['type']??'message';
        if($type==='message'){
            // Satu webhook untuk dua pemakai: nomor pengirim marketing pusat (berhenti/balasan prospek) dan perangkat WA client.
            if(is_string($event['device']??null) && DB::table('marketing_senders')->where('remote_id',$event['device'])->exists()){
                if(!($event['from_me']??false) && !($event['group']??false)) Blast::inbound((string)($event['from']??''),(string)($event['text']??''));
                return response()->json(['accepted'=>true]);
            }
            $inbound->receive($event);return response()->json(['accepted'=>true]);
        }
        $data=(array)($event['data']??[]);$device=$event['device']??null;
        match($type){
            'device.status'=>$this->deviceStatus((string)$device,$data,$gateway),
            'message.status'=>$this->messageStatus($data),
            'blast.message','blast.status'=>app(Blasts::class)->event($type,$data),
            default=>null, // tenant.ai_low, test: cukup diterima
        };
        return response()->json(['accepted'=>true]);
    }

    /** Status nyata dari CHATKU. Nomor yang di-scan beda dengan nomor terdaftar → langsung diputus (keamanan). */
    private function deviceStatus(string $remote,array $data,ChatkuGateway $gateway): void {
        $d=DB::table('wa_devices')->where('remote_id',$remote)->first();
        if(!$d)return;
        $status=ChatkuHttpGateway::mapStatus((string)($data['status']??''));$note=null;
        if($status==='connected' && ($data['phone_match']??null)===false){
            try{$gateway->disconnect($remote);}catch(\Throwable){}
            $status='disconnected';$note='Nomor yang di-scan berbeda dengan nomor terdaftar. Sambungkan ulang dengan nomor yang benar.';
        }
        DB::table('wa_devices')->where('id',$d->id)->update(['status'=>$status,'status_note'=>$note,'status_checked_at'=>now(),'updated_at'=>now()]);
    }

    private function messageStatus(array $data): void {
        $id=(string)($data['message_id']??'');$st=(string)($data['status']??'');
        if($id==='' || !in_array($st,['sent','delivered','read','failed'],true))return;
        DB::table('wa_outbox')->where('provider_receipt',$id)->update(['delivery'=>$st,'updated_at'=>now()]);
    }
}
