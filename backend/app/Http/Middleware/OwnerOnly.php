<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Http\Request;
class OwnerOnly {
    public function handle(Request $request, Closure $next) {
        abort_unless($request->user()?->isOwner(), 403, 'Hanya owner usaha.');
        return $next($request);
    }
}
