<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
class VerifiedWhenRequired {
    /** Enforced once production email sending is configured (GOYANA_REQUIRE_EMAIL_VERIFICATION=true). */
    public function handle(Request $request, Closure $next) {
        $user = $request->user();
        if (config('goyana.require_email_verification') && $user && !$user->is_platform_admin && !$user->hasVerifiedEmail()) {
            return $request->expectsJson() ? abort(403, 'Verifikasi email terlebih dahulu.') : redirect()->route('verification.notice');
        }
        return $next($request);
    }
}
