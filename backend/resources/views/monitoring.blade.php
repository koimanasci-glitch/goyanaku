@extends('layout')
@section('content')
@php($rp = fn ($n) => 'Rp'.number_format((int) $n, 0, ',', '.'))
@php($when = fn ($iso) => $iso ? \Carbon\CarbonImmutable::parse($iso)->timezone('Asia/Jakarta')->format('d M H:i') : '-')
@php($stages = fn ($list) => collect($stageNames)->filter(fn ($label, $key) => !empty($list[$key]))->map(fn ($label, $key) => $label.' '.$list[$key])->implode(' · '))
@php($outletName = fn ($id) => optional($outlets->firstWhere('id', $id))->name ?? '-')
<p><a href="{{ route('dashboard') }}">← Dashboard</a></p>
<h1>Monitoring</h1><p class="muted">{{ $business->name }} · {{ $from->format('d M Y') }}{{ $from->isSameDay($to) ? '' : ' – '.$to->format('d M Y') }} · dari data yang tersinkron dari semua HP</p>
<form class="filters" method="get" action="{{ route('monitoring') }}">
@if($owner)<select name="outlet_id" aria-label="Cabang"><option value="">Semua cabang</option>@foreach($outlets as $o)<option value="{{ $o->id }}" @selected($outletId === $o->id)>{{ $o->name }}</option>@endforeach</select>@endif
<input type="date" name="from" value="{{ $from->toDateString() }}" aria-label="Dari tanggal"><input type="date" name="to" value="{{ $to->toDateString() }}" aria-label="Sampai tanggal"><button>Tampilkan</button></form>
@php($t = $report['totals'])
<div class="kpis"><div class="kpi"><small>Omzet</small><b>{{ $rp($t['revenue']) }}</b><small>{{ $t['orders'] }} nota</small></div>
<div class="kpi"><small>Uang diterima</small><b>{{ $rp($t['cash_in']) }}</b></div>
<div class="kpi"><small>Belum lunas</small><b>{{ $rp($t['debt']) }}</b><small>{{ $t['unpaid'] }} nota</small></div>
<div class="kpi"><small>Sedang dikerjakan</small><b>{{ $t['in_process'] }}</b><small>{{ $t['late'] }} lewat waktu</small></div>
<div class="kpi"><small>Siap, belum diambil</small><b>{{ $t['ready_uncollected'] }}</b></div>
<div class="kpi"><small>Tunai di kurir</small><b>{{ $rp($report['money']['courier_cash_total']) }}</b><small>{{ $t['pending_weigh'] }} menunggu cek timbangan</small></div></div>
@if($report['alerts'])<section class="card"><h2>Perlu diperhatikan</h2><ul>@foreach($report['alerts'] as $alert)<li>{{ $alert['outlet'] ? $alert['outlet'].': ' : '' }}{{ $alert['text'] }}</li>@endforeach</ul></section>@endif
<section class="card"><h2>Penjemputan berjalan</h2><ul class="plain">@forelse($report['pickups'] ?? [] as $p)<li class="row"><span>{{ $p['customer'] }}<br><small class="muted">{{ $p['when'] ?? 'Jadwal belum diatur' }}@if($p['address']) · {{ $p['address'] }}@endif · {{ $outletName($p['outlet_id']) }}</small></span><span>@if($p['courier']){{ $p['self'] ? 'Dijemput sendiri: ' : '' }}{{ $p['courier'] }}@else<span class="pill bad">Belum ada kurir</span>@endif<br><small class="muted">dibuat {{ $when($p['since']) }}</small></span></li>@empty<li class="muted">Tidak ada penjemputan yang sedang berjalan.</li>@endforelse</ul></section>
<section class="card"><h2>Per cabang</h2><div class="table list"><table><thead><tr><th>Cabang</th><th>Omzet</th><th>Diterima</th><th>Belum lunas</th><th>Tahap cucian</th></tr></thead><tbody>
@foreach($report['outlets'] as $o)<tr><td>{{ $o['name'] }} <span class="pill">{{ $o['code'] }}</span>@unless($o['active']) <span class="pill bad">Nonaktif</span>@endunless</td>
<td data-label="Omzet">{{ $rp($o['revenue']) }}<br><small class="muted">{{ $o['orders'] }} nota</small></td><td data-label="Diterima">{{ $rp($o['cash_in']) }}</td>
<td data-label="Belum lunas">{{ $rp($o['debt']) }}<br><small class="muted">{{ $o['unpaid'] }} nota</small></td>
<td data-label="Tahap cucian">{{ $stages($o['stages']) ?: 'Tidak ada cucian berjalan' }}@if($o['late'])<br><small class="muted">{{ $o['late'] }} lewat waktu</small>@endif</td></tr>@endforeach
</tbody></table></div></section>
<div class="grid"><section class="card"><h2>Uang masuk per cara bayar</h2><ul class="plain">@forelse($report['money']['cash_in_by_method'] as $method => $amount)<li class="row"><span>{{ $method }}</span><b>{{ $rp($amount) }}</b></li>@empty<li class="muted">Belum ada pembayaran pada rentang ini.</li>@endforelse</ul></section>
<section class="card"><h2>Tunai dipegang kurir</h2><ul class="plain">@forelse($report['money']['courier_cash'] as $c)<li class="row"><span>{{ $c['courier'] }}<br><small class="muted">{{ $c['notes'] }} nota · sejak {{ $when($c['since']) }}</small></span><b>{{ $rp($c['held']) }}</b></li>@empty<li class="muted">Tidak ada tunai yang belum disetor.</li>@endforelse</ul></section></div>
<section class="card"><h2>Setoran kurir</h2><div class="table list"><table><thead><tr><th>Waktu</th><th>Kurir</th><th>Catatan server</th><th>Diterima</th><th>Selisih</th><th>Penerima</th></tr></thead><tbody>
@forelse($report['money']['deposits'] as $d)<tr><td data-label="Waktu">{{ $when($d['at']) }}</td><td data-label="Kurir">{{ $d['courier'] }}</td><td data-label="Catatan server">{{ $rp($d['expected']) }}</td><td data-label="Diterima">{{ $rp($d['received']) }}</td>
<td data-label="Selisih">@if($d['difference'])<span class="pill bad">{{ $d['difference'] < 0 ? '-' : '+' }}{{ $rp(abs($d['difference'])) }}</span> {{ $d['note'] }}@else<span class="pill good">Pas</span>@endif</td><td data-label="Penerima">{{ $d['confirmed_by'] }}</td></tr>
@empty<tr><td colspan="6" class="muted">Belum ada setoran pada rentang ini.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Tutup kas</h2><div class="table list"><table><thead><tr><th>Waktu</th><th>Cabang</th><th>Kasir</th><th>Disetor</th><th>Selisih</th></tr></thead><tbody>
@forelse($report['money']['cash_closes'] as $c)<tr><td data-label="Waktu">{{ $when($c['at']) }}</td><td data-label="Cabang">{{ $outletName($c['outlet_id']) }}</td><td data-label="Kasir">{{ $c['cashier'] ?: '-' }}</td><td data-label="Disetor">{{ $c['deposited'] === null ? '-' : $rp($c['deposited']) }}</td>
<td data-label="Selisih">@if($c['difference'])<span class="pill bad">{{ $c['difference'] < 0 ? '-' : '+' }}{{ $rp(abs($c['difference'])) }}</span> {{ $c['note'] }}@else<span class="pill good">Pas</span>@endif</td></tr>
@empty<tr><td colspan="5" class="muted">Belum ada tutup kas pada rentang ini.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Kasir</h2><div class="table list"><table><thead><tr><th>Nama</th><th>Nota dibuat</th><th>Uang diterima</th><th>Siap ambil</th><th>Batal · Lompat · Mundur</th></tr></thead><tbody>
@forelse($report['cashiers'] as $c)<tr><td>{{ $c['name'] }}<br><small class="muted">{{ $outletName($c['outlet_id']) }}</small></td><td data-label="Nota dibuat">{{ $c['created'] }}</td><td data-label="Uang diterima">{{ $rp($c['received']) }}</td><td data-label="Siap ambil">{{ $c['marked_ready'] }}</td><td data-label="Batal · Lompat · Mundur">{{ $c['cancelled'] }} · {{ $c['skipped'] }} · {{ $c['moved_back'] }}</td></tr>
@empty<tr><td colspan="5" class="muted">Belum ada catatan kerja kasir pada rentang ini.</td></tr>@endforelse</tbody></table></div></section>
<div class="grid"><section class="card"><h2>Pegawai</h2><ul class="plain">@forelse($report['production'] as $p)<li class="row"><span>{{ $p['name'] }}<br><small class="muted">{{ $stages($p['stages']) ?: 'Belum ada tahap' }}</small></span><b>{{ $p['total'] }} tahap</b></li>@empty<li class="muted">Belum ada tahap yang dikerjakan pegawai.</li>@endforelse</ul></section>
<section class="card"><h2>Kurir</h2><ul class="plain">@forelse($report['couriers'] as $c)<li class="row"><span>{{ $c['name'] }}<br><small class="muted">Jemput {{ $c['pickups'] }} · Antar {{ $c['deliveries'] }} · Nota dibuat {{ $c['created'] }}@if($c['weigh_corrected']) · timbangan dikoreksi {{ $c['weigh_corrected'] }}×@endif</small></span><b>{{ $rp($c['cash_collected']) }}</b></li>@empty<li class="muted">Belum ada tugas kurir pada rentang ini.</li>@endforelse</ul></section></div>
<section class="card"><h2>HP kasir</h2><ul class="plain">@forelse($report['devices'] as $d)<li class="row"><span>{{ $d['label'] }} · HP {{ $d['slot'] }}<br><small class="muted">{{ $outletName($d['outlet_id']) }}</small></span><span>{{ $d['last_sync_at'] ? 'Sinkron '.$when($d['last_sync_at']) : 'Belum pernah sinkron' }}</span></li>@empty<li class="muted">Belum ada HP kasir yang terpasang.</li>@endforelse</ul></section>
@endsection
