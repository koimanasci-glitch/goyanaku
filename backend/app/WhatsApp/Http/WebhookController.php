<?php
namespace App\WhatsApp\Http;
use App\WhatsApp\{Inbound};
use App\WhatsApp\Contracts\ChatkuGateway;
use Illuminate\Http\Request;
final class WebhookController {
    public function __invoke(Request $r,ChatkuGateway $gateway,Inbound $inbound){
        abort_if(strlen($r->getContent())>16384,413);
        $event=$gateway->verifyInbound($r); // Raw signature/account verification belongs to documented Chatku adapter.
        $inbound->receive($event);return response()->json(['accepted'=>true]);
    }
}
