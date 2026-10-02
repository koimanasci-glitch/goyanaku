@extends('layout')
@section('content')
<section class="card auth">
@if($setup)
<h1>Aktifkan OTP admin</h1>
<p class="muted">Akun administrator pusat wajib memakai kode OTP dari aplikasi authenticator (Google Authenticator, Microsoft Authenticator, Authy).</p>
<ol><li>Buka aplikasi authenticator → tambah akun → <b>masukkan kunci manual</b>.</li>
<li>Nama akun: <b>GOYANA Pusat</b>, kunci:</li></ol>
<p><code style="font-size:18px;letter-spacing:2px;word-break:break-all">{{ trim(chunk_split($secret, 4, ' ')) }}</code></p>
<p><small class="muted">Atau buka tautan ini di HP yang sama: <a href="{{ $uri }}">tambahkan ke authenticator</a></small></p>
<form method="post" action="{{ route('admin.mfa.setup') }}">@csrf
<label for="code">Kode 6 digit dari aplikasi</label><input id="code" name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="10" required autofocus>
<p><button>Aktifkan</button></p></form>
@else
<h1>Kode OTP</h1><p class="muted">Masukkan kode 6 digit dari aplikasi authenticator Anda.</p>
<form method="post" action="{{ route('admin.mfa') }}">@csrf
<label for="code">Kode OTP</label><input id="code" name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="10" required autofocus>
<p><button>Masuk</button></p></form>
<p><small class="muted">HP hilang? Jalankan <code>php artisan goyana:admin-reset-mfa email</code> di terminal server.</small></p>
@endif
</section>
@endsection
