@extends('layout')
@section('content')
@include('admin-nav')
<h1>Client</h1><p class="muted">Pemilik laundry yang sudah terdaftar, untuk penawaran upgrade dan pengingat. Hanya nama usaha, pemilik, nomor, dan paket yang tampil.</p>
@include('admin-marketing-nav')
<form class="filters" method="get" action="{{ route('admin.marketing.clients') }}"><select name="status" aria-label="Status paket"><option value="">Semua</option>
@foreach(['paid' => 'Berbayar', 'beta' => 'Beta', 'trial' => 'Trial', 'expired' => 'Berakhir'] as $k => $v)<option value="{{ $k }}" @selected($status === $k)>{{ $v }}</option>@endforeach</select><button>Saring</button></form>
<section class="card"><div class="table list"><table><thead><tr><th>Usaha</th><th>Pemilik</th><th>Nomor</th><th>Paket</th><th>Outlet</th></tr></thead><tbody>
@forelse($clients as $b)
@php($owner = $b->users->first())
@php($access = $b->currentAccess())
@php($phone = $owner?->phone ?: $b->outlets->first()?->phone)
<tr><td><b>{{ $b->name }}</b><br><small class="muted">daftar {{ $b->created_at?->timezone('Asia/Jakarta')->format('d M Y') }}</small></td><td data-label="Pemilik">{{ $owner?->name ?? '—' }}</td>
<td data-label="Nomor">{{ $phone ? '+'.$phone : 'Belum ada nomor' }}</td>
<td data-label="Paket">{{ $access['source'] === 'trial' ? 'Trial' : ($access['package'] ?? 'Berakhir') }}@if($access['ends_at'])<br><small class="muted">s/d {{ \Carbon\Carbon::parse($access['ends_at'])->timezone('Asia/Jakarta')->format('d M Y') }}</small>@endif</td>
<td data-label="Outlet">{{ $b->outlets->count() }}</td></tr>
@empty<tr><td colspan="5" class="muted">Tidak ada client yang cocok.</td></tr>@endforelse
</tbody></table></div>{{ $clients->links() }}</section>
<p class="muted">Untuk mengirim penawaran ke client, buat kampanye dengan sasaran "Client".</p>
@endsection
