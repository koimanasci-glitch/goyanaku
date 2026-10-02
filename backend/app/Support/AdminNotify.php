<?php
namespace App\Support;
use App\Models\User;
use Illuminate\Support\Facades\Mail;
/** Email every active platform administrator. WhatsApp to the owner follows once CHATKU is connected (§41). */
class AdminNotify {
    public static function send(string $subject, string $body): int {
        $emails = User::where('is_platform_admin', true)->whereNull('deactivated_at')->pluck('email')->all();
        foreach ($emails as $email) Mail::raw($body, fn ($m) => $m->to($email)->subject('[GOYANA] '.$subject));
        return count($emails);
    }
}
