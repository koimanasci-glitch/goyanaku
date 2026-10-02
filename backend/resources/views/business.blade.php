@extends('layout')
@section('content')
<p><a href="{{ route('admin.index') }}">← Daftar usaha</a></p><h1>{{ $business->name }}</h1><p class="muted">Usaha #{{ $business->id }} · {{ $access['package'] ?? 'Berakhir' }} · {{ $access['source'] }}</p>
<section class="card"><h2>Catat pembayaran paket</h2><p class="muted">Untuk transfer/QRIS yang sudah dicek manual, sampai gateway pembayaran & Google Play Billing aktif. Perpanjangan dimulai dari akhir langganan yang masih berjalan.</p>
<form method="post" action="{{ route('admin.subscribe', $business) }}">@csrf<div class="grid">
<div><label for="s-package">Paket</label><select id="s-package" name="package">@foreach($packages as $name => $p)<option value="{{ $name }}" @selected(old('package') === $name)>{{ $name }} · Rp{{ number_format($p['price'], 0, ',', '.') }}/bln · {{ $p['branches'] }} cabang</option>@endforeach</select></div>
<div><label for="s-months">Lama (bulan)</label><input id="s-months" name="months" type="number" min="1" max="12" value="{{ old('months', 1) }}" required></div>
<div><label for="s-amount">Nominal diterima (Rp)</label><input id="s-amount" name="amount" type="number" min="0" value="{{ old('amount') }}" required></div>
<div><label for="s-ref">Referensi pembayaran</label><input id="s-ref" name="reference" value="{{ old('reference') }}" required maxlength="120" placeholder="No. transfer / ID QRIS"></div>
</div><p><button>Catat pembayaran</button></p></form>
<div class="table"><table><thead><tr><th>Paket</th><th>Periode (WIB)</th><th>Nominal</th><th>Referensi</th><th>Status</th></tr></thead><tbody>
@forelse($subscriptions as $s)<tr><td>{{ $s->package }}</td><td>{{ $s->starts_at->timezone('Asia/Jakarta')->format('d M Y') }} – {{ $s->ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</td><td>Rp{{ number_format((int) $s->amount, 0, ',', '.') }}</td><td>{{ $s->reference }}</td><td>
@if($s->cancelled_at)Dibatalkan
@elseif($s->ends_at->isPast())Berakhir
@else<form method="post" action="{{ route('admin.subscription.cancel', [$business, $s]) }}">@csrf<input name="reason" required maxlength="500" placeholder="Alasan pembatalan" aria-label="Alasan pembatalan"><p><button class="secondary">Batalkan catatan</button></p></form>@endif
</td></tr>@empty<tr><td colspan="5">Belum ada pembayaran tercatat.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Berikan paket sementara</h2><p class="muted">Untuk beta atau bantuan. Tidak membuat invoice, autodebit atau saldo AI.</p>
<form method="post" action="{{ route('admin.grant', $business) }}">@csrf
<label for="package">Paket</label><select id="package" name="package">@foreach(array_keys($packages) as $package)<option @selected(old('package') === $package)>{{ $package }}</option>@endforeach</select>
<label for="ends_at">Berakhir pada (WIB)</label><input id="ends_at" name="ends_at" type="datetime-local" value="{{ old('ends_at') }}" required>
<label for="reason">Alasan</label><textarea id="reason" name="reason" maxlength="500" required>{{ old('reason') }}</textarea><p><button>Berikan paket</button></p>
</form></section>
<section class="card table"><h2>Riwayat paket sementara</h2><table><thead><tr><th>Paket</th><th>Berakhir (WIB)</th><th>Alasan</th><th>Status</th></tr></thead><tbody>
@forelse($grants as $grant)<tr><td>{{ $grant->package }}</td><td>{{ $grant->ends_at->timezone('Asia/Jakarta')->format('d M Y H:i') }}</td><td>{{ $grant->reason }}</td><td>
@if($grant->revoked_at)Dicabut
@elseif($grant->ends_at->isPast())Berakhir
@else<form method="post" action="{{ route('admin.revoke', [$business, $grant]) }}">@csrf<button class="secondary">Cabut</button></form>@endif
</td></tr>@empty<tr><td colspan="4">Belum ada paket sementara.</td></tr>@endforelse</tbody></table></section>
@endsection
