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
