@extends('layout')
@section('content')
@include('admin-nav')
@php($S = \App\Support\ServerStats::class)
<h1>Monitor VPS</h1><p class="muted">Dibaca langsung dari server saat halaman dibuka. Kuning mulai 80%, merah mulai 92%.</p>
<div class="grid">
@foreach([['RAM', $server['ram_percent'], $S::bytes($server['ram_used']).' terpakai dari '.$S::bytes($server['ram_total']), $server['swap_total'] ? 'Swap '.$S::bytes($server['swap_used']).' dari '.$S::bytes($server['swap_total']) : 'Tanpa swap'],
    ['CPU', $server['cpu_percent'], $server['load1'] === null ? 'Beban tidak terbaca di sistem ini' : 'Beban 1/5/15 menit: '.number_format($server['load1'], 2, ',', '.').' · '.number_format($server['load5'], 2, ',', '.').' · '.number_format($server['load15'], 2, ',', '.'), ($server['cpu_cores'] ?? '?').' inti'],
    ['Disk', $server['disk_percent'], $S::bytes($server['disk_used']).' terpakai dari '.$S::bytes($server['disk_total']), 'Database '.$S::bytes($server['database_bytes'])]] as [$name, $percent, $line, $extra])
<section class="card"><div class="row"><h2>{{ $name }}</h2><b>{{ $percent === null ? '—' : $percent.'%' }}</b></div>
<div class="meter {{ $S::state($percent) }}"><i style="width:{{ min(100, (int) $percent) }}%"></i></div><small class="muted">{{ $line }}<br>{{ $extra }}</small></section>
@endforeach
</div>
<section class="card"><div class="row"><h2>24 jam terakhir</h2><span class="legend"><span><i style="background:#2f6fe0"></i>RAM</span><span><i style="background:#f0472f"></i>CPU</span></span></div>
@if(count($history) > 1)
@php($n = count($history) - 1)
@php($line = fn ($key) => collect($history)->map(fn ($h, $i) => round($i / $n * 600, 1).','.round(88 - min(100, $h[$key]) * 0.86, 1))->implode(' '))
<svg class="spark" viewBox="0 0 600 90" preserveAspectRatio="none" role="img" aria-label="Grafik RAM dan CPU 24 jam terakhir dalam persen">
<line x1="0" y1="88" x2="600" y2="88" stroke="#e2e6ea"/><line x1="0" y1="45" x2="600" y2="45" stroke="#eef1f4"/><line x1="0" y1="2" x2="600" y2="2" stroke="#eef1f4"/>
<polyline fill="none" stroke="#2f6fe0" stroke-width="2" vector-effect="non-scaling-stroke" points="{{ $line('ram') }}"/>
<polyline fill="none" stroke="#f0472f" stroke-width="2" vector-effect="non-scaling-stroke" points="{{ $line('cpu') }}"/></svg>
<small class="muted">Garis atas 100%, tengah 50%. Tertinggi: RAM {{ collect($history)->max('ram') }}%, CPU {{ collect($history)->max('cpu') }}%. Dicatat tiap 5 menit.</small>
@else<p class="muted">Belum ada riwayat. Grafik terisi setelah penjadwal (cron) berjalan beberapa kali.</p>@endif
</section>
<section class="card"><h2>Server menyala</h2><p><b>{{ $S::duration($server['uptime_seconds']) }}</b></p></section>
<section class="card"><h2>Pemeriksaan</h2><ul class="checks">
@foreach($checks as $c)<li class="{{ $c['state'] }}"><span class="dot" aria-hidden="true"></span><div><b>{{ $c['name'] }}</b><small>{{ $c['detail'] }}</small></div>
<span class="sr">{{ ['ok' => 'Baik', 'warn' => 'Perlu perhatian', 'fail' => 'Bermasalah'][$c['state']] }}</span></li>@endforeach
</ul></section>
<section class="card"><h2>Info</h2><div class="table"><table><tbody>
@foreach($info as $k => $v)<tr><th>{{ $k }}</th><td>{{ $v }}</td></tr>@endforeach</tbody></table></div></section>
@endsection
