@extends('layout')
@section('content')
<section class="card auth"><h1>Buat password baru</h1>
<form method="post" action="{{ route('password.update') }}">@csrf<input type="hidden" name="token" value="{{ $token }}">
<label for="email">Email</label><input id="email" name="email" type="email" value="{{ old('email', $email) }}" required maxlength="254" autocomplete="username">
<label for="password">Password baru</label><input id="password" name="password" type="password" required autocomplete="new-password"><small class="muted">Minimal 12 karakter, mengandung huruf dan angka.</small>
<label for="password_confirmation">Ulangi password</label><input id="password_confirmation" name="password_confirmation" type="password" required autocomplete="new-password">
<p><button>Simpan password</button></p></form></section>
@endsection
