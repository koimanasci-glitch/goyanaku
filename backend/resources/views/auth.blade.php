@extends('layout')
@section('content')
<section class="card auth"><h1>{{ $register ? 'Daftar usaha' : 'Masuk' }}</h1><p class="muted">{{ $register ? 'Buat akun pemilik dan outlet pusat. Trial Basic dua bulan.' : 'Gunakan akun Goyana Anda.' }}</p>
<form method="post" action="{{ $register ? route('register') : route('login') }}">@csrf
@if($register)<label for="name">Nama pemilik</label><input id="name" name="name" value="{{ old('name') }}" required maxlength="120" autocomplete="name">
<label for="business_name">Nama usaha / outlet pusat</label><input id="business_name" name="business_name" value="{{ old('business_name') }}" required maxlength="120">@endif
<label for="email">Email</label><input id="email" name="email" type="email" value="{{ old('email') }}" required maxlength="254" autocomplete="username">
<label for="password">Password</label><input id="password" name="password" type="password" required autocomplete="{{ $register ? 'new-password' : 'current-password' }}">
@if($register)<small class="muted">Minimal 12 karakter, mengandung huruf dan angka.</small><label for="password_confirmation">Ulangi password</label><input id="password_confirmation" name="password_confirmation" type="password" required autocomplete="new-password">@endif
<p><button>{{ $register ? 'Daftar' : 'Masuk' }}</button></p></form>
@unless($register)<p><a href="{{ route('password.request') }}">Lupa password?</a></p>@endunless
<a href="{{ $register ? route('login') : route('register') }}">{{ $register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar' }}</a>
<p class="muted"><small>Versi fondasi untuk pengujian. Login Google belum tersedia.</small></p></section>
@endsection
