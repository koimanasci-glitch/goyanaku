@extends('layout')
@section('content')
@include('admin-nav')
<h1>Kesehatan sistem</h1><p class="muted">Pengecekan otomatis server. Kuning = perlu diatur sebelum produksi, merah = harus diperbaiki.</p>
<section class="card"><ul class="checks">
@foreach($checks as $c)<li class="{{ $c['state'] }}"><span class="dot" aria-hidden="true"></span><div><b>{{ $c['name'] }}</b><small>{{ $c['detail'] }}</small></div>
<span class="sr">{{ ['ok' => 'Baik', 'warn' => 'Perlu perhatian', 'fail' => 'Bermasalah'][$c['state']] }}</span></li>@endforeach
</ul></section>
<section class="card"><h2>Info</h2><div class="table"><table><tbody>
@foreach($info as $k => $v)<tr><th>{{ $k }}</th><td>{{ $v }}</td></tr>@endforeach</tbody></table></div></section>
<p class="muted">Pantauan antrean, backup, CHATKU dan AI ditambahkan saat layanan tersebut terhubung (§45).</p>
@endsection
