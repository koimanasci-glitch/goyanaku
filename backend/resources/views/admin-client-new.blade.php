@extends('layout')
@section('content')
@include('admin-nav')
<h1>Tambah Client</h1><p class="muted">Membuat usaha baru dengan akun pemiliknya. Client mulai dengan trial; paketnya diatur sesudah dibuat.</p>
<section class="card"><form method="post" action="{{ route('admin.client.store') }}">@csrf<div class="grid">
<div><label for="c-b">Nama usaha</label><input id="c-b" name="business_name" value="{{ old('business_name') }}" required maxlength="120" placeholder="Contoh: Laundry Bersih Jaya"></div>
<div><label for="c-n">Nama pemilik</label><input id="c-n" name="name" value="{{ old('name') }}" required maxlength="120"></div>
<div><label for="c-e">Email pemilik (untuk masuk)</label><input id="c-e" name="email" type="email" value="{{ old('email') }}" required maxlength="254"></div>
<div><label for="c-p">Nomor HP pemilik</label><input id="c-p" name="phone" inputmode="tel" value="{{ old('phone') }}" maxlength="20" placeholder="0812…"></div>
<div><label for="c-w">Password awal</label><input id="c-w" name="password" type="password" required autocomplete="new-password"><small class="muted">Minimal 12 karakter, huruf dan angka. Pemilik juga bisa masuk dengan Google bila emailnya sama.</small></div>
</div><p><button>Buat client</button></p></form></section>
@endsection
