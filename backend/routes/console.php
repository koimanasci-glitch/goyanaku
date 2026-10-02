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
