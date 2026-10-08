<?php
namespace App\WhatsApp\Http;
use App\WhatsApp\{Inbound};
use App\WhatsApp\Contracts\ChatkuGateway;
use App\Support\Blast;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class WebhookController {
    public function __invoke(Request $r,ChatkuGateway $gateway,Inbound $inbound){
        abort_if(strlen($r->getContent())>16384,413);
        $event=$gateway->verifyInbound($r); // Raw signature/account verification belongs to documented Chatku adapter.
        // Satu webhook untuk dua pemakai: nomor pengirim marketing pusat (berhenti/balasan prospek) dan perangkat WA client.
        if(is_string($event['device']??null) && DB::table('marketing_senders')->where('remote_id',$event['device'])->exists()){
            if(!($event['from_me']??false) && !($event['group']??false)) Blast::inbound((string)($event['from']??''),(string)($event['text']??''));
            return response()->json(['accepted'=>true]);
        }
        $inbound->receive($event);return response()->json(['accepted'=>true]);
    }
}
