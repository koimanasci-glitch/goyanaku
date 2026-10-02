@extends('layout')
@section('content')
<section class="card auth"><h1>{{ $business->name }}</h1>
<p>Anda masuk sebagai <b>{{ $user->roleLabel() }}</b>@if($outlet) di <b>{{ $outlet->name }}</b>@endif.</p>
<p class="muted">Pekerjaan harian dilakukan di aplikasi Android GOYANA dengan akun ini. Laporan usaha, paket, dan pengelolaan tim hanya untuk owner.</p></section>
@endsection
