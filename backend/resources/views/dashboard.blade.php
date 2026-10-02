@extends('layout')
@section('content')
<h1>{{ $business->name }}</h1><p class="muted">Dashboard pemilik · Data usaha Anda</p>
<div class="grid"><section class="card"><h2>Paket</h2><strong>{{ $access['package'] ?? 'Berakhir' }}</strong> <span class="badge">{{ $access['source'] }}</span><p>{{ $access['read_only'] ? 'Mode baca saja' : 'Hak dasar aktif' }}</p><small>Batas waktu: {{ $access['ends_at']->timezone('Asia/Jakarta')->format('d M Y H:i') }} WIB</small></section>
<section class="card"><h2>Outlet</h2><strong>{{ $outlets->count() }}</strong><p class="muted">Maksimal dua slot perangkat kasir per outlet.</p></section></div>
@foreach($outlets as $outlet)<section class="card"><h2>{{ $outlet->name }}</h2>
<ul>@forelse($outlet->devices->whereNull('revoked_at') as $device)<li class="row"><span>{{ $device->label }} · Slot {{ $device->slot }}</span><form method="post" action="{{ route('devices.revoke', [$outlet, $device]) }}">@csrf<button class="secondary">Cabut akses</button></form></li>@empty<li>Belum ada perangkat kasir.</li>@endforelse</ul>
@if(!$access['read_only'])<form method="post" action="{{ route('devices.store', $outlet) }}">@csrf<label for="device-{{ $outlet->id }}">Nama perangkat</label><input id="device-{{ $outlet->id }}" name="label" required maxlength="120" placeholder="Contoh: Kasir meja depan"><p><button>Tambah slot perangkat</button></p></form>@endif
</section>@endforeach
<p class="muted">Pendaftaran slot belum memasangkan HP Android. Transaksi, sinkronisasi dan verifikasi perangkat Android akan ditambahkan pada tahap berikutnya.</p>
@endsection
