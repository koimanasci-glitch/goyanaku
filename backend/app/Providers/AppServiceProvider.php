<?php
namespace App\Providers;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
class AppServiceProvider extends ServiceProvider {
    public function register(): void {}
    public function boot(): void {
        RateLimiter::for('login', fn (Request $r) => [
            Limit::perMinute(20)->by('login-ip:'.$r->ip()),
            Limit::perMinute(5)->by('login-account:'.hash('sha256', mb_strtolower(trim((string) $r->input('email'))).'|'.$r->ip())),
        ]);
        // PIN hanya 6 angka: batasi per nomor/akun dan per alamat, di samping kunci akun setelah salah berkali-kali.
        RateLimiter::for('pin', fn (Request $r) => [
            Limit::perMinute(30)->by('pin-ip:'.$r->ip()),
            Limit::perMinute(8)->by('pin-account:'.hash('sha256', preg_replace('/\D+/', '', (string) $r->input('phone')).'|'.$r->input('user_id').'|'.$r->input('device_id'))),
        ]);
        RateLimiter::for('api', fn (Request $r) => Limit::perMinute(60)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('sync', fn (Request $r) => Limit::perMinute(120)->by('sync:'.($r->user()?->id ?: $r->ip())));
        RateLimiter::for('registration', fn (Request $r) => Limit::perHour(10)->by('register:'.$r->ip()));
    }
}
