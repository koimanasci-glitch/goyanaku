@extends('layout')
@section('content')
@include('admin-nav')
<h1>Slot WhatsApp Tambahan</h1>
<p class="muted">Rp{{ number_format($price, 0, ',', '.') }} per nomor per bulan (di luar 1 nomor bawaan paket Silver ke atas). Selama pembayaran Google Play belum tersambung, catat pembayaran transfer/QRIS di sini. Semua tercatat di Audit.</p>
@if(session('status'))<p class="pill good">{{ session('status') }}</p>@endif
<section class="card"><h2>Tambah / perpanjang slot</h2>
<form method="post" action="{{ route('admin.wa.slots.store') }}">@csrf
<label for="c">Client (ID usaha atau email pemilik)</label><input id="c" name="client" value="{{ old('client') }}" required>
@error('client')<p class="bad">{{ $message }}</p>@enderror
<div class="row">
<div><label for="s">Jumlah nomor</label><input id="s" name="slots" type="number" min="1" max="10" value="{{ old('slots', 1) }}" required></div>
<div><label for="m">Bulan</label><input id="m" name="months" type="number" min="1" max="12" value="{{ old('months', 1) }}" required></div>
<div><label for="p">Dibayar (Rp)</label><input id="p" name="paid" type="number" min="0" value="{{ old('paid', $price) }}" required></div>
</div>
<label for="r">Referensi pembayaran (no. transfer / bukti)</label><input id="r" name="reference" value="{{ old('reference') }}" maxlength="120" required>
@error('reference')<p class="bad">{{ $message }}</p>@enderror
<p class="row"><button>Simpan</button></p></form></section>
<section class="card"><h2>Riwayat</h2>
<table><thead><tr><th>Client</th><th>Nomor</th><th>Berlaku</th><th>Referensi</th><th></th></tr></thead><tbody>
@forelse($grants as $g)
<tr><td>{{ $g->business }}</td><td>{{ $g->slots }}</td>
<td>{{ \Carbon\Carbon::parse($g->starts_at)->timezone('Asia/Jakarta')->format('d/m/Y') }} – {{ \Carbon\Carbon::parse($g->ends_at)->timezone('Asia/Jakarta')->format('d/m/Y') }}
@if($g->revoked_at)<span class="pill bad">Dicabut</span>@elseif(\Carbon\Carbon::parse($g->ends_at)->isPast())<span class="pill">Berakhir</span>@else<span class="pill good">Aktif</span>@endif</td>
<td>{{ $g->payment_reference }}</td>
<td>@if(!$g->revoked_at && \Carbon\Carbon::parse($g->ends_at)->isFuture())<form method="post" action="{{ route('admin.wa.slots.revoke', $g->id) }}" onsubmit="return confirm('Cabut slot ini?')">@csrf<button class="secondary">Cabut</button></form>@endif</td></tr>
@empty<tr><td colspan="5" class="muted">Belum ada slot tambahan.</td></tr>@endforelse
</tbody></table>
{{ $grants->links() }}</section>
@endsection
