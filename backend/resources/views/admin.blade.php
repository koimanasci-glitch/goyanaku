@extends('layout')
@section('content')
@include('admin-nav')
<h1>Administrator pusat</h1><p class="muted">Ringkasan seluruh usaha laundry GOYANA</p>
<div class="kpis">
@foreach([['Total usaha', $stats['total'], null], ['Berbayar', $stats['paid'], 'paid'], ['Beta', $stats['beta'], 'beta'], ['Trial', $stats['trial'], 'trial'], ['Baca saja', $stats['expired'], 'expired']] as [$label, $n, $key])
<a class="kpi @if($status === $key && $key) on @endif" href="{{ route('admin.index', $key ? ['status' => $key] : []) }}"><small>{{ $label }}</small><b>{{ number_format($n, 0, ',', '.') }}</b></a>
@endforeach
<div class="kpi"><small>Daftar 7 hari</small><b>{{ $stats['new7'] }}</b></div>
<div class="kpi"><small>Pemasukan bulan ini</small><b>Rp{{ number_format($stats['revenue'], 0, ',', '.') }}</b></div>
<div class="kpi"><small>HP kasir tersambung</small><b>{{ $stats['devices'] }}</b></div>
<div class="kpi"><small>Konflik sinkron 7 hari</small><b>{{ $stats['conflicts7'] }}</b></div>
</div>
@if(!$status && $term === '' && ($endingTrials->isNotEmpty() || $endingPaid->isNotEmpty()))
<section class="card"><h2>Berakhir dalam 7 hari</h2><ul class="plain">
@foreach($endingTrials as $b)<li><a href="{{ route('admin.business', $b) }}">{{ $b->name }}</a> <span class="badge">Trial</span> <small class="muted">{{ $b->trial_ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</small></li>@endforeach
@foreach($endingPaid as $s)<li><a href="{{ route('admin.business', $s->business_id) }}">{{ $s->business?->name }}</a> <span class="badge">{{ $s->package }}</span> <small class="muted">{{ $s->ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</small></li>@endforeach
</ul></section>
@endif
<section class="card">
<form class="filters" method="get" action="{{ route('admin.index') }}" role="search">
<input name="q" value="{{ $term }}" placeholder="Cari nama usaha, email, atau ID" aria-label="Cari usaha">
<select name="status" aria-label="Status"><option value="">Semua status</option>
@foreach(['paid' => 'Berbayar', 'beta' => 'Beta', 'trial' => 'Trial', 'expired' => 'Baca saja'] as $k => $v)<option value="{{ $k }}" @selected($status === $k)>{{ $v }}</option>@endforeach
</select><button>Cari</button>@if($term !== '' || $status)<a class="button secondary" href="{{ route('admin.index') }}">Reset</a>@endif
</form>
<div class="table list"><table><thead><tr><th>Usaha</th><th>Paket</th><th>Status</th><th>Sinkron terakhir</th><th></th></tr></thead><tbody>
@forelse($businesses as $business)
@php($access = $business->currentAccess())
@php($owner = $business->users->firstWhere('role', 'owner'))
@php($last = $lastSync[$business->id] ?? null)
<tr><td data-label="Usaha"><b>{{ $business->name }}</b><br><small class="muted">#{{ $business->id }}@if($owner) · {{ $owner->email }}@endif · daftar {{ $business->created_at?->timezone('Asia/Jakarta')->format('d M Y') }}</small></td>
<td data-label="Paket">{{ $access['package'] ?? '—' }}<br><small class="muted">{{ ['subscription' => 'berbayar', 'beta' => 'beta', 'trial' => 'trial', 'expired' => 'berakhir'][$access['source']] ?? $access['source'] }}@if($access['ends_at']) · s/d {{ \Carbon\Carbon::parse($access['ends_at'])->timezone('Asia/Jakarta')->format('d M Y') }}@endif</small></td>
<td data-label="Status"><span @class(['pill', 'bad' => $access['read_only'], 'good' => !$access['read_only']])>{{ $access['read_only'] ? 'Baca saja' : 'Aktif' }}</span></td>
<td data-label="Sinkron">{{ $last ? \Carbon\Carbon::parse($last)->timezone('Asia/Jakarta')->format('d M H:i') : 'Belum' }}</td>
<td><a class="button small" href="{{ route('admin.business', $business) }}">Kelola</a></td></tr>
@empty<tr><td colspan="5">Tidak ada usaha yang cocok.</td></tr>@endforelse
</tbody></table></div>{{ $businesses->links() }}</section>
<p class="muted">Pembayaran otomatis, WhatsApp/CHATKU, AI CS dan tiket belum terhubung (lihat GOYANA-SISTEM-PUSAT.md §41–§47).</p>
@endsection
