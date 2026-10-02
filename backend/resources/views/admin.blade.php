@extends('layout')
@section('content')
<h1>Administrator pusat</h1><p class="muted">Akun usaha, trial dan paket beta sementara</p>
<section class="card table"><table><thead><tr><th>Usaha</th><th>Paket saat ini</th><th>Status</th><th></th></tr></thead><tbody>
@forelse($businesses as $business)
@php($access = $business->currentAccess())
<tr><td>{{ $business->name }}<br><small class="muted">ID {{ $business->id }}</small></td><td>{{ $access['package'] ?? '—' }} · {{ $access['source'] }}</td><td>{{ $access['read_only'] ? 'Baca saja' : 'Aktif' }}</td><td><a href="{{ route('admin.business', $business) }}">Kelola</a></td></tr>
@empty<tr><td colspan="4">Belum ada usaha terdaftar.</td></tr>@endforelse
</tbody></table>{{ $businesses->links() }}</section>
<p class="muted">Monitoring VPS, AI, pembayaran dan WhatsApp belum terhubung pada versi fondasi ini.</p>
@endsection
