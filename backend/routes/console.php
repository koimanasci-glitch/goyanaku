<?php
use App\Models\User;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;
Artisan::command('goyana:admin', function () {
    $name = $this->ask('Nama administrator');
    $email = mb_strtolower(trim((string) $this->ask('Email administrator')));
    $password = $this->secret('Password baru (minimal 12 karakter, huruf dan angka)');
    $validation = Validator::make(compact('name', 'email', 'password'), [
        'name' => 'required|string|max:120', 'email' => 'required|email|max:254|unique:users,email',
        'password' => ['required', Password::min(12)->letters()->numbers()],
    ]);
    if ($validation->fails()) { foreach ($validation->errors()->all() as $message) $this->error($message); return 1; }
    $user = new User(compact('name', 'email', 'password'));
    $user->is_platform_admin = true; $user->save();
    $this->info('Administrator dibuat. Password tidak dicetak atau disimpan di dokumen.');
    return 0;
})->purpose('Buat administrator pusat melalui terminal tepercaya, tanpa password bawaan');

Artisan::command('goyana:admin-reset-mfa {email}', function (string $email) {
    $user = User::where('email', mb_strtolower(trim($email)))->where('is_platform_admin', true)->first();
    if (!$user) { $this->error('Administrator tidak ditemukan.'); return 1; }
    $user->mfa_secret = null; $user->mfa_confirmed_at = null; $user->mfa_last_step = null; $user->save();
    $this->info('OTP direset. Administrator harus memasang ulang authenticator saat login berikutnya.');
    return 0;
})->purpose('Reset OTP administrator pusat yang kehilangan HP (jalankan dari terminal server tepercaya)');

// ---------- Otomatis (GOYANA-SISTEM-PUSAT.md §43, §45). Server: cron "* * * * * php artisan schedule:run" ----------

Artisan::command('goyana:health', function () {
    cache()->forever('goyana.health.beat', now()->toIso8601String());
    $checks = \App\Support\Health::checks();
    $failing = collect($checks)->where('state', 'fail')->pluck('detail', 'name')->all();
    $before = cache('goyana.health.failing', []);
    // Alert only on change, so a lasting problem does not flood the inbox.
    $new = array_diff_key($failing, $before); $fixed = array_diff_key($before, $failing);
    if ($new) \App\Support\AdminNotify::send('Gangguan sistem', "Pemeriksaan otomatis menemukan masalah:\n\n".collect($new)->map(fn ($d, $n) => "- $n: $d")->implode("\n")."\n\nBuka /admin/system untuk detail.");
    if ($fixed) \App\Support\AdminNotify::send('Sistem pulih', "Sudah normal kembali:\n\n".collect($fixed)->keys()->map(fn ($n) => "- $n")->implode("\n"));
    cache()->forever('goyana.health.failing', $failing);
    $this->info($failing ? count($failing).' masalah: '.implode(', ', array_keys($failing)) : 'Semua pemeriksaan baik.');
    return $failing ? 1 : 0;
})->purpose('Pemeriksaan kesehatan server; email administrator saat ada gangguan baru atau sudah pulih');

Artisan::command('goyana:prune', function () {
    // sync_ops only guard against duplicate pushes from phones that retry; 30 days is far beyond any retry window.
    $ops = \Illuminate\Support\Facades\DB::table('sync_ops')->where('created_at', '<', now()->subDays(30))->delete();
    $conflicts = \Illuminate\Support\Facades\DB::table('sync_conflicts')->where('created_at', '<', now()->subDays(180))->delete();
    $this->info("Dibersihkan: $ops sync_ops, $conflicts konflik lama.");
})->purpose('Bersihkan data teknis lama (idempotensi sinkron, konflik > 180 hari)');

Artisan::command('goyana:weekly-report {--print : Tampilkan saja, tanpa email}', function () {
    $since = now()->subDays(7);
    $count = fn ($status) => \App\Models\Business::withAccessStatus($status)->count();
    $db = \Illuminate\Support\Facades\DB::class;
    $lines = [
        'Laporan mingguan GOYANA · '.$since->timezone('Asia/Jakarta')->format('d M').' – '.now('Asia/Jakarta')->format('d M Y'),
        '',
        'KLIEN',
        '- Usaha baru: '.\App\Models\Business::where('created_at', '>=', $since)->count(),
        '- Total: '.\App\Models\Business::count().' (berbayar '.$count('paid').', beta '.$count('beta').', trial '.$count('trial').', baca saja '.$count('expired').')',
        '- Trial berakhir 7 hari ke depan: '.\App\Models\Business::where('trial_ends_at', '>', now())->where('trial_ends_at', '<=', now()->addDays(7))->count(),
        '',
        'PEMASUKAN',
        '- Pembayaran paket 7 hari: Rp'.number_format((int) \App\Models\Subscription::whereNull('cancelled_at')->where('created_at', '>=', $since)->sum('amount'), 0, ',', '.'),
        '',
        'PEMAKAIAN',
        '- HP kasir aktif 7 hari: '.\App\Models\CashierDevice::whereNull('revoked_at')->where('last_seen_at', '>=', $since)->count(),
        '- Operasi sinkron 7 hari: '.$db::table('sync_ops')->where('created_at', '>=', $since)->count(),
        '- Konflik sinkron 7 hari: '.$db::table('sync_conflicts')->where('created_at', '>=', $since)->count(),
        '',
        'CS',
        '- Tiket baru: '.\App\Models\Ticket::where('created_at', '>=', $since)->count().', selesai: '.\App\Models\Ticket::where('closed_at', '>=', $since)->count().', masih menunggu CS: '.\App\Models\Ticket::where('status', 'open')->count(),
        '',
        'SISTEM',
        ...collect(\App\Support\Health::checks())->where('state', '!=', 'ok')->map(fn ($c) => '- '.$c['name'].': '.$c['detail'])->values()->all() ?: ['- Semua pemeriksaan baik'],
    ];
    $text = implode("\n", $lines);
    if ($this->option('print')) { foreach ($lines as $l) $this->line($l); return 0; }
    $n = \App\Support\AdminNotify::send('Laporan mingguan', $text);
    $this->info("Laporan dikirim ke $n administrator.");
    return 0;
})->purpose('Ringkasan mingguan untuk pemilik platform (klien, pemasukan, pemakaian, CS, sistem)');

\Illuminate\Support\Facades\Schedule::command('goyana:health')->everyFiveMinutes()->withoutOverlapping();
\Illuminate\Support\Facades\Schedule::command('goyana:prune')->dailyAt('02:30')->timezone('Asia/Jakarta');
\Illuminate\Support\Facades\Schedule::command('goyana:weekly-report')->weeklyOn(1, '07:00')->timezone('Asia/Jakarta');
