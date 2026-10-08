@extends('layout')
@section('content')
@include('admin-nav')
<h1>WhatsApp & CRM</h1><p class="muted">Pemilik laundry yang belum memakai GOYANA. Pelanggan milik laundry client tidak pernah masuk ke daftar ini.</p>
@include('admin-marketing-nav')
<div class="kpis">
<a class="kpi @if(!$status) on @endif" href="{{ route('admin.marketing') }}"><small>Semua</small><b>{{ number_format(array_sum($counts), 0, ',', '.') }}</b></a>
@foreach($statuses as $key => $label)<a class="kpi @if($status === $key) on @endif" href="{{ route('admin.marketing', ['status' => $key]) }}"><small>{{ $label }}</small><b>{{ number_format($counts[$key] ?? 0, 0, ',', '.') }}</b></a>@endforeach
</div>
<section class="card"><form class="filters" method="get" action="{{ route('admin.marketing') }}" role="search">
<input name="q" value="{{ $term }}" placeholder="Cari nama usaha, pemilik, atau nomor" aria-label="Cari calon client">
<select name="city" aria-label="Kota"><option value="">Semua kota</option>@foreach($cities as $c)<option value="{{ $c }}" @selected($city === $c)>{{ $c }}</option>@endforeach</select>
@if($status)<input type="hidden" name="status" value="{{ $status }}">@endif<button>Cari</button></form>
<div class="table list"><table><thead><tr><th>Usaha</th><th>Nomor</th><th>Kota</th><th>Status</th><th></th></tr></thead><tbody>
@forelse($prospects as $p)<tr><td><b>{{ $p->name }}</b>@if($p->owner_name)<br><small class="muted">{{ $p->owner_name }}</small>@endif</td>
<td data-label="Nomor">+{{ $p->phone }}</td><td data-label="Kota">{{ $p->city ?: '—' }}</td>
<td data-label="Status"><span @class(['pill', 'good' => in_array($p->status, ['tertarik', 'daftar', 'membalas']), 'bad' => $p->status === 'menolak'])>{{ $statuses[$p->status] ?? $p->status }}</span>@if($p->last_contacted_at)<br><small class="muted">dihubungi {{ \Carbon\Carbon::parse($p->last_contacted_at)->timezone('Asia/Jakarta')->format('d M') }}</small>@endif</td>
<td><a class="button small" href="{{ route('admin.prospect', $p->id) }}">Buka</a></td></tr>
@empty<tr><td colspan="5" class="muted">Belum ada calon client. Tambahkan satu per satu atau impor dari file di bawah.</td></tr>@endforelse
</tbody></table></div>{{ $prospects->links() }}</section>
<div class="grid"><section class="card"><h2>Tambah calon client</h2><form method="post" action="{{ route('admin.prospects.store') }}">@csrf
<label for="p-n">Nama usaha</label><input id="p-n" name="name" required maxlength="160" placeholder="Contoh: Laundry Kencana">
<label for="p-p">Nomor WhatsApp pemilik</label><input id="p-p" name="phone" required inputmode="tel" maxlength="30" placeholder="0812…">
<label for="p-o">Nama pemilik</label><input id="p-o" name="owner_name" maxlength="120">
<label for="p-c">Kota</label><input id="p-c" name="city" maxlength="80" list="cities"><datalist id="cities">@foreach($cities as $c)<option value="{{ $c }}">@endforeach</datalist>
<p><button>Tambah</button></p></form></section>
<section class="card"><h2>Impor dari file</h2><p class="muted">File CSV dengan kolom berurutan: nama usaha, nomor HP, nama pemilik (boleh kosong), kota (boleh kosong). Nomor kembar, nomor yang sudah jadi client, dan yang pernah minta tidak dihubungi dilewati otomatis.</p>
<form method="post" action="{{ route('admin.prospects.import') }}" enctype="multipart/form-data">@csrf
<label for="i-f">File CSV (maks. 2 MB, 5.000 baris)</label><input id="i-f" name="file" type="file" accept=".csv,text/csv,text/plain" required>
<label for="i-s">Sumber data</label><input id="i-s" name="source" maxlength="40" placeholder="Contoh: pameran Bekasi, daftar komunitas">
<p><button>Impor</button></p></form></section></div>
@endsection
