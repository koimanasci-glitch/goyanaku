@extends('layout')
@section('content')
<section class="card auth"><h1>Verifikasi email</h1>
<p class="muted">Kami mengirim link verifikasi ke <b>{{ auth()->user()->email }}</b>. Buka email tersebut lalu klik link-nya.</p>
<form method="post" action="{{ route('verification.send') }}">@csrf<button>Kirim ulang link</button></form></section>
@endsection
