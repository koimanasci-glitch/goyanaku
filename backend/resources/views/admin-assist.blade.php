@extends('layout')
@section('content')
@include('admin-nav')
<p><a href="{{ route('admin.business', $business) }}">← {{ $business->name }}</a></p><h1>Mode Bantuan</h1>
@if($session)<div class="notice">Aktif sampai <b>{{ \Carbon\Carbon::parse($session->expires_at)->timezone('Asia/Jakarta')->format('H:i') }} WIB</b>. Perubahan masuk ke HP owner dalam ±20 detik. Hanya pengaturan; pesanan, pelanggan &amp; uang tidak bisa diubah.</div>
@else<div class="notice">Tidak aktif — hanya bisa melihat. Minta owner menekan <b>Izinkan Bantuan</b> di halaman Bantuan.</div>@endif
<section class="card"><h2>Harga layanan</h2>
@forelse($services as $s)<form method="post" action="{{ route('admin.assist.service', $business) }}" class="assist-row">@csrf<input type="hidden" name="key" value="{{ $s->key }}">
<b>{{ $s->data['name'] ?? $s->key }}</b> <small class="muted">/{{ $s->data['unit'] ?? '' }}</small><div class="grid">
@foreach($s->data['prices'] as $dur => $price)<div><label for="p-{{ $loop->parent->index }}-{{ $loop->index }}">{{ $dur }}</label>
<input id="p-{{ $loop->parent->index }}-{{ $loop->index }}" name="prices[{{ $dur }}]" type="number" min="0" step="500" value="{{ $price }}" @disabled(!$session)>
@if(isset($s->data['enabled']))<label class="check"><input type="checkbox" name="enabled[{{ $dur }}]" value="1" @checked($s->data['enabled'][$dur] ?? true) @disabled(!$session)> Aktif</label>@endif</div>@endforeach
</div>@if($session)<p><button class="secondary">Simpan {{ $s->data['name'] ?? '' }}</button></p>@endif</form>
@empty<p class="muted">Belum ada data layanan dari HP (sinkron belum berjalan).</p>@endforelse</section>
<section class="card"><h2>Profil outlet</h2>
@forelse($outlets as $o)<form method="post" action="{{ route('admin.assist.outlet', $business) }}">@csrf<input type="hidden" name="key" value="{{ $o->key }}"><div class="grid">
<div><label>Nama</label><input name="name" value="{{ $o->data['name'] ?? '' }}" required maxlength="120" @disabled(!$session)></div>
<div><label>Alamat</label><input name="address" value="{{ $o->data['address'] ?? '' }}" maxlength="300" @disabled(!$session)></div>
<div><label>Telepon</label><input name="phone" value="{{ $o->data['phone'] ?? '' }}" maxlength="30" @disabled(!$session)></div>
</div>@if($session)<p><button class="secondary">Simpan outlet</button></p>@endif</form>
@empty<p class="muted">Belum ada profil outlet tersinkron.</p>@endforelse</section>
<section class="card"><h2>Riwayat perubahan</h2><ul class="plain">
@forelse($changes as $c)@php($d = json_decode($c->details, true))<li>{{ $d['note'] ?? $d['collection'] }} <small class="muted">· {{ \Carbon\Carbon::parse($c->created_at)->timezone('Asia/Jakarta')->format('d M H:i') }}</small>
@if($session)<form class="inline" method="post" action="{{ route('admin.assist.revert', [$business, $c->id]) }}">@csrf<button class="secondary small">Batalkan</button></form>@endif</li>
@empty<li class="muted">Belum ada perubahan.</li>@endforelse</ul></section>
@endsection
