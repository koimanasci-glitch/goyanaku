@extends('layout')
@section('content')
@include('admin-nav')
<h1>Laporan SaaS</h1><p class="muted">Pertumbuhan client dan pemasukan langganan, enam bulan terakhir.</p>
<div class="kpis"><div class="kpi"><small>Total client</small><b>{{ number_format($total, 0, ',', '.') }}</b></div>
<div class="kpi"><small>Pernah berlangganan</small><b>{{ $converted }}</b><small>{{ round($converted / $total * 100) }}% dari semua client</small></div>
<div class="kpi"><small>Aktif memakai (30 hari)</small><b>{{ $active30 }}</b><small>client dengan data tersinkron</small></div></div>
@php($maxSignups = max(1, collect($months)->max('signups')))
@php($maxRevenue = max(1, collect($months)->max('revenue')))
<section class="card"><h2>Per bulan</h2><div class="table list"><table><thead><tr><th>Bulan</th><th>Client baru</th><th>Berlangganan</th><th>Pemasukan</th></tr></thead><tbody>
@foreach($months as $m)<tr><td>{{ $m['label'] }}</td>
<td data-label="Client baru">{{ $m['signups'] }}<div class="meter"><i style="width:{{ round($m['signups'] / $maxSignups * 100) }}%;background:#2f6fe0"></i></div></td>
<td data-label="Berlangganan">{{ $m['paid'] }}</td>
<td data-label="Pemasukan">Rp{{ number_format($m['revenue'], 0, ',', '.') }}<div class="meter"><i style="width:{{ round($m['revenue'] / $maxRevenue * 100) }}%"></i></div></td></tr>@endforeach
</tbody></table></div></section>
<div class="grid"><section class="card"><h2>Client per paket</h2><ul class="plain">@forelse($packages as $name => $n)<li class="row"><span>{{ $name }}</span><b>{{ $n }}</b></li>@empty<li class="muted">Belum ada client.</li>@endforelse</ul></section>
<section class="card"><h2>Calon client</h2><ul class="plain">@forelse(\App\Support\Blast::STATUSES as $key => $label)<li class="row"><span>{{ $label }}</span><b>{{ $prospects[$key] ?? 0 }}</b></li>@empty @endforelse</ul></section></div>
@endsection
