<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
class PlatformAdmin {
    /** `platform.admin` = admin + OTP passed this session. `platform.admin:password` = before OTP (setup/challenge pages). */
    public function handle(Request $request, Closure $next, string $stage = 'full') {
        $user = $request->user();
        abort_unless($user?->is_platform_admin, 403);
        if ($stage === 'full' && config('goyana.admin_mfa')) {
            if (!$user->mfa_confirmed_at) return redirect()->route('admin.mfa.setup');
            if (!$request->session()->get('mfa_passed_for') || $request->session()->get('mfa_passed_for') !== $user->id) {
                return redirect()->route('admin.mfa');
            }
        }
        return $next($request);
    }
}
