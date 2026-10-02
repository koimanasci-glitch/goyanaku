<?php
namespace App\Support;
use Illuminate\Support\Facades\DB;
/** Server checks shared by /admin/system and the scheduled `goyana:health` monitor (GOYANA-SISTEM-PUSAT.md §45 level 1). */
class Health {
    /** @return list<array{name:string,state:string,detail:string}> */
    public static function checks(): array {
        $checks = [];
        $add = function (string $name, bool $ok, string $detail, bool $warnOnly = false) use (&$checks) {
            $checks[] = ['name' => $name, 'state' => $ok ? 'ok' : ($warnOnly ? 'warn' : 'fail'), 'detail' => $detail];
        };
        try { DB::select('select 1'); $add('Database', true, DB::connection()->getDriverName().' terhubung'); }
        catch (\Throwable $e) { $add('Database', false, 'Tidak terhubung: '.class_basename($e)); }
        try {
            $migrator = app('migrator');
            $files = array_keys($migrator->getMigrationFiles(database_path('migrations')));
            $pending = array_diff($files, $migrator->getRepository()->getRan());
            $add('Migrasi database', !$pending, $pending ? count($pending).' migrasi belum dijalankan (php artisan migrate --force)' : 'Semua migrasi sudah dijalankan');
        } catch (\Throwable $e) { $add('Migrasi database', false, 'Tidak dapat dibaca'); }
        $prod = app()->environment('production');
        $add('Mode debug', !config('app.debug'), config('app.debug') ? 'APP_DEBUG=true — matikan di server produksi' : 'Mati', !$prod);
        $https = str_starts_with((string) config('app.url'), 'https://');
        $add('Alamat HTTPS', $https, $https ? config('app.url') : 'APP_URL belum https', !$prod);
        $mailer = (string) config('mail.default');
        $add('Email (verifikasi & reset)', !in_array($mailer, ['log', 'array'], true), 'Mailer: '.$mailer, !$prod);
        $add('OTP administrator', (bool) config('goyana.admin_mfa'), config('goyana.admin_mfa') ? 'Wajib' : 'Tidak wajib — nyalakan di produksi', !$prod);
        $free = @disk_free_space(base_path()); $total = @disk_total_space(base_path());
        if ($free && $total) {
            $pct = (int) round($free / $total * 100);
            $add('Ruang disk', $pct >= 15, number_format($free / 1073741824, 1, ',', '.').' GB kosong dari '.number_format($total / 1073741824, 1, ',', '.').' GB ('.$pct.'%)', $pct >= 5);
        }
        $writable = is_writable(storage_path('logs')) && is_writable(storage_path('framework'));
        $add('Folder storage', $writable, $writable ? 'Dapat ditulis' : 'storage/ tidak dapat ditulis');
        $last = DB::table('sync_records')->max('updated_at');
        $add('Sinkronisasi HP', true, $last ? 'Terakhir: '.\Carbon\Carbon::parse($last)->timezone('Asia/Jakarta')->format('d M Y H:i').' WIB' : 'Belum ada data sinkron');
        // Scheduler heartbeat: written by goyana:health every 5 minutes.
        $beat = cache('goyana.health.beat');
        $add('Penjadwal (cron)', $beat && now()->diffInMinutes(\Carbon\Carbon::parse($beat)) <= 15,
            $beat ? 'Terakhir jalan '.\Carbon\Carbon::parse($beat)->timezone('Asia/Jakarta')->format('d M H:i').' WIB' : 'Belum pernah jalan — pasang cron "php artisan schedule:run" tiap menit', !app()->environment('production'));
        return $checks;
    }
    public static function info(): array {
        return [
            'PHP' => PHP_VERSION, 'Laravel' => app()->version(), 'Lingkungan' => app()->environment(),
            'Waktu server' => now('Asia/Jakarta')->format('d M Y H:i:s').' WIB',
            'Operasi sinkron 24 jam' => DB::table('sync_ops')->where('created_at', '>=', now()->subDay())->count(),
            'Konflik sinkron 24 jam' => DB::table('sync_conflicts')->where('created_at', '>=', now()->subDay())->count(),
            'HP aktif 24 jam' => \App\Models\CashierDevice::whereNull('revoked_at')->where('last_seen_at', '>=', now()->subDay())->count(),
        ];
    }
}
