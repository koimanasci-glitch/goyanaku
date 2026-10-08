<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/** Area aplikasi administrator per divisi (pemilik, marketing, CS, teknis). Dipasang sesudah `platform.admin`. */
class AdminArea {
    public function handle(Request $request, Closure $next, string ...$areas) {
        $user = $request->user();
        abort_unless($user && collect($areas)->contains(fn ($a) => $user->adminCan($a)), 403, 'Menu ini bukan untuk divisi Anda.');
        return $next($request);
    }
}
