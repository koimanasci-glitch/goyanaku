<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
class EnsureActive {
    /** Deactivated staff lose access immediately on their next request; history is kept. */
    public function handle(Request $request, Closure $next) {
        $user = $request->user();
        if ($user && !$user->isActive()) {
            if ($request->expectsJson() || $request->is('api/*')) abort(403, 'Akun dinonaktifkan.');
            Auth::guard('web')->logout();
            $request->session()->invalidate();
            return redirect()->route('login')->withErrors(['email' => 'Akun dinonaktifkan. Hubungi owner usaha.']);
        }
        return $next($request);
    }
}
