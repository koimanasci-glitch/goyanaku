@extends('layout')
@section('content')
<p><a href="{{ route('admin.index') }}">← Daftar usaha</a></p><h1>{{ $business->name }}</h1><p class="muted">Usaha #{{ $business->id }} · {{ $access['package'] ?? 'Berakhir' }} · {{ $access['source'] }}</p>
<section class="card"><h2>Berikan paket sementara</h2><p class="muted">Untuk beta atau bantuan. Tidak membuat invoice, autodebit atau saldo AI.</p>
<form method="post" action="{{ route('admin.grant', $business) }}">@csrf
<label for="package">Paket</label><select id="package" name="package">@foreach(['Basic','Silver','Gold','Platinum'] as $package)<option @selected(old('package') === $package)>{{ $package }}</option>@endforeach</select>
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
