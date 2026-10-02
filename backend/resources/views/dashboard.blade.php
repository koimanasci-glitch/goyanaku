@extends('layout')
@section('content')
<p class="row"><span></span><a class="button secondary" href="{{ route('support') }}">Bantuan / Tiket CS</a></p>
<h1>{{ $business->name }}</h1><p class="muted">Dashboard pemilik · Data usaha Anda</p>
<div class="grid"><section class="card"><h2>Paket</h2><strong>{{ $access['package'] ?? 'Berakhir' }}</strong> <span class="badge">{{ ['subscription' => 'Berlangganan', 'beta' => 'Beta', 'trial' => 'Trial', 'expired' => 'Berakhir'][$access['source']] ?? $access['source'] }}</span>
<p>{{ $access['read_only'] ? 'Mode baca saja — data tetap bisa dilihat, transaksi baru terkunci sampai paket aktif.' : 'Akses operasional aktif' }}</p>
@if($access['ends_at'])<small>{{ $access['read_only'] ? 'Berakhir sejak' : 'Aktif sampai' }}: {{ $access['ends_at']->timezone('Asia/Jakarta')->format('d M Y H:i') }} WIB</small>@endif</section>
<section class="card"><h2>Penjualan</h2>@php($s = $summary['total'])
@if($summary['synced'])<div class="grid"><div><small class="muted">Hari ini</small><br><strong>Rp{{ number_format($s['today_total'], 0, ',', '.') }}</strong><br><small>{{ $s['today_orders'] }} pesanan</small></div>
<div><small class="muted">Bulan ini</small><br><strong>Rp{{ number_format($s['month_total'], 0, ',', '.') }}</strong><br><small>{{ $s['month_orders'] }} pesanan · {{ $s['unpaid'] }} belum lunas</small></div></div>
@if(count($summary['per_outlet']) > 1)<ul>@foreach($summary['per_outlet'] as $name => $o)<li>{{ $name }}: Rp{{ number_format($o['today_total'], 0, ',', '.') }} hari ini · Rp{{ number_format($o['month_total'], 0, ',', '.') }} bulan ini</li>@endforeach</ul>@endif
<p><small class="muted">Dari data yang sudah tersinkron dari HP{{ $summary['last_sync'] ? ' · terakhir '.$summary['last_sync']->format('d M H:i').' WIB' : '' }}.</small></p>
@else<p class="muted">Belum ada data dari HP. Login di aplikasi Android dengan akun ini, data akan tersinkron otomatis.</p>@endif</section>
<section class="card"><h2>Outlet</h2><strong>{{ $outlets->count() }} / {{ $access['outlet_limit'] }}</strong><p class="muted">1 pusat + {{ $access['branches'] }} cabang sesuai paket. Maksimal {{ config('goyana.cashier_devices_per_outlet') }} perangkat kasir per outlet.</p>
@if(!$access['read_only'] && $outlets->count() < $access['outlet_limit'])<form method="post" action="{{ route('outlets.store') }}">@csrf<label for="outlet-name">Nama cabang baru</label><input id="outlet-name" name="name" required maxlength="120" placeholder="Contoh: Cabang Cikarang"><p><button>Tambah cabang</button></p></form>@endif</section></div>
@foreach($outlets as $outlet)<section class="card"><h2>{{ $outlet->name }}</h2>
<ul>@forelse($outlet->devices->whereNull('revoked_at') as $device)<li class="row"><span>{{ $device->label }} · Slot {{ $device->slot }}<br><small class="muted">{{ $device->device_uuid ? 'HP terpasang'.($device->last_seen_at ? ' · aktif '.\Carbon\CarbonImmutable::parse($device->last_seen_at)->timezone('Asia/Jakarta')->format('d M H:i') : '') : 'Menunggu HP' }}</small></span><form method="post" action="{{ route('devices.revoke', [$outlet, $device]) }}">@csrf<button class="secondary">Cabut akses</button></form></li>@empty<li>Belum ada perangkat kasir.</li>@endforelse</ul>
@if(!$access['read_only'])<form method="post" action="{{ route('devices.store', $outlet) }}">@csrf<label for="device-{{ $outlet->id }}">Nama perangkat</label><input id="device-{{ $outlet->id }}" name="label" required maxlength="120" placeholder="Contoh: Kasir meja depan"><p><button>Tambah slot perangkat</button></p></form>@endif
</section>@endforeach
<section class="card"><h2>Akun tim</h2><p class="muted">Kasir, produksi, kurir, dan admin outlet login dengan akun sendiri. Hak akses diperiksa di server.</p>
<div class="table team"><table><thead><tr><th>Nama</th><th>Peran & outlet</th><th>Status</th><th></th></tr></thead><tbody>
@forelse($team as $member)<tr><td>{{ $member->name }}<br><small class="muted">{{ $member->email }}</small></td>
<td><form method="post" action="{{ route('team.update', $member) }}">@csrf<select name="role" aria-label="Peran">@foreach($roles as $key => $role)<option value="{{ $key }}" @selected($member->role === $key)>{{ $role['label'] }}</option>@endforeach</select>
<select name="outlet_id" aria-label="Outlet">@foreach($outlets as $o)<option value="{{ $o->id }}" @selected($member->outlet_id === $o->id)>{{ $o->name }}</option>@endforeach</select><p><button class="secondary">Simpan</button></p></form></td>
<td>{{ $member->deactivated_at ? 'Nonaktif' : 'Aktif' }}</td>
<td>@if($member->deactivated_at)<form method="post" action="{{ route('team.activate', $member) }}">@csrf<button class="secondary">Aktifkan</button></form>@else<form method="post" action="{{ route('team.deactivate', $member) }}">@csrf<button class="secondary">Nonaktifkan</button></form>@endif
<form method="post" action="{{ route('team.password', $member) }}">@csrf<input name="password" type="password" placeholder="Password baru" aria-label="Password baru" autocomplete="new-password"><p><button class="secondary">Ganti password</button></p></form></td></tr>
@empty<tr><td colspan="4">Belum ada akun tim.</td></tr>@endforelse</tbody></table></div>
@if(!$access['read_only'])<h2>Tambah akun tim</h2><form method="post" action="{{ route('team.store') }}">@csrf<div class="grid">
<div><label for="t-name">Nama</label><input id="t-name" name="name" value="{{ old('name') }}" required maxlength="120"></div>
<div><label for="t-email">Email login</label><input id="t-email" name="email" type="email" value="{{ old('email') }}" required maxlength="254"></div>
<div><label for="t-role">Peran</label><select id="t-role" name="role">@foreach($roles as $key => $role)<option value="{{ $key }}" @selected(old('role') === $key)>{{ $role['label'] }}</option>@endforeach</select></div>
<div><label for="t-outlet">Outlet</label><select id="t-outlet" name="outlet_id">@foreach($outlets as $o)<option value="{{ $o->id }}">{{ $o->name }}</option>@endforeach</select></div>
<div><label for="t-pass">Password awal</label><input id="t-pass" name="password" type="password" required autocomplete="new-password"><small class="muted">Minimal 12 karakter, huruf dan angka.</small></div>
</div><p><button>Buat akun</button></p></form>@endif</section>
<p class="muted">HP kasir otomatis mengisi slot perangkat saat pertama kali menyimpan transaksi. Cabut slot untuk ganti HP.</p>
@endsection
