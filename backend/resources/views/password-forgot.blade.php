@extends('layout')
@section('content')
<section class="card auth"><h1>Lupa password</h1><p class="muted">Masukkan email akun GOYANA. Kami kirim link untuk membuat password baru.</p>
<form method="post" action="{{ route('password.email') }}">@csrf<label for="email">Email</label><input id="email" name="email" type="email" value="{{ old('email') }}" required maxlength="254" autocomplete="username">
<p><button>Kirim link reset</button></p></form><a href="{{ route('login') }}">Kembali ke halaman masuk</a>
<p class="muted"><small>Pegawai/kasir juga bisa minta owner mereset password dari dashboard web.</small></p></section>
@endsection
