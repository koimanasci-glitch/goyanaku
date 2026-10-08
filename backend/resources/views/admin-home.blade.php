@extends('layout')
@section('content')
@php($me = auth()->user())
<div class="stats">
@foreach($stats as [$label, $value, $delta, $icon, $route, $query])
@if($me->adminCan('clients'))<a class="stat" href="{{ route($route, $query) }}">@else<div class="stat">@endif
<span class="ic">@include('admin-icon', ['icon' => $icon, 'size' => 26])</span>
<span><small>{{ $label }}</small><b>{{ number_format($value, 0, ',', '.') }}</b><em>↑ +{{ number_format($delta, 0, ',', '.') }} <i>bulan ini</i></em></span>
@if($me->adminCan('clients'))</a>@else</div>@endif
@endforeach
</div>
<div class="tiles">
@foreach($menu as [$route, $label, $icon, $color, $area])
@if($me->adminCan($area))<a class="tile" href="{{ route($route) }}"><span class="ic t-{{ $color }}">@include('admin-icon', ['icon' => $icon, 'size' => 26])</span>{{ $label }}</a>
@else<span class="tile off" title="Bukan untuk divisi Anda"><span class="ic t-gray">@include('admin-icon', ['icon' => $icon, 'size' => 26])</span>{{ $label }}</span>@endif
@endforeach
</div>
@if($recent->isNotEmpty())
<section class="card"><div class="row"><h2>Client Terbaru</h2>@if($me->adminCan('clients'))<a href="{{ route('admin.clients') }}">Lihat Semua ›</a>@endif</div>
<ul class="rows">
@foreach($recent as $i => $b)
@php($access = $b->currentAccess())
@php($ending = !$access['read_only'] && $access['ends_at'] && \Carbon\Carbon::parse($access['ends_at'])->lte(now()->addDays(7)))
<li><span class="ic t-{{ ['red', 'blue', 'green', 'orange', 'violet'][$i % 5] }}">@include('admin-icon', ['icon' => 'store'])</span>
<span class="grow">@if($me->adminCan('clients'))<a href="{{ route('admin.business', $b) }}" style="text-decoration:none;color:inherit"><b>{{ $b->name }}</b></a>@else<b>{{ $b->name }}</b>@endif
<small class="muted">{{ $b->outlets_count }} Outlet</small> <span class="pill">{{ $access['source'] === 'trial' ? 'Trial' : ($access['package'] ?? 'Berakhir') }}</span></span>
<span class="end"><span class="state {{ $access['read_only'] ? 'bad' : ($ending ? 'warn' : 'good') }}">{{ $access['read_only'] ? 'Baca saja' : ($ending ? 'Hampir Berakhir' : 'Aktif') }}</span><br><span class="muted">{{ $b->created_at?->timezone('Asia/Jakarta')->locale('id')->translatedFormat('j M Y') }}</span></span></li>
@endforeach
</ul></section>
@endif
@if($server)
<section class="card"><div class="row"><h2>Server</h2><a href="{{ route('admin.system') }}">Monitor VPS ›</a></div>
<div class="grid">@foreach([['RAM', $server['ram_percent'], \App\Support\ServerStats::bytes($server['ram_used']).' dari '.\App\Support\ServerStats::bytes($server['ram_total'])],
    ['CPU', $server['cpu_percent'], $server['load1'] === null ? 'Tidak terbaca' : 'Beban '.number_format($server['load1'], 2, ',', '.').' · '.$server['cpu_cores'].' inti'],
    ['Disk', $server['disk_percent'], \App\Support\ServerStats::bytes($server['disk_used']).' dari '.\App\Support\ServerStats::bytes($server['disk_total'])]] as [$name, $percent, $detail])
<div><b>{{ $name }}</b> <span class="muted">{{ $percent === null ? '—' : $percent.'%' }}</span><div class="meter {{ \App\Support\ServerStats::state($percent) }}"><i style="width:{{ min(100, (int) $percent) }}%"></i></div><small class="muted">{{ $detail }}</small></div>
@endforeach</div></section>
@endif
@endsection
