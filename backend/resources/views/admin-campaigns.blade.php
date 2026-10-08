@extends('layout')
@section('content')
@include('admin-nav')
<h1>Promosi & Notifikasi</h1><p class="muted">Pesan WhatsApp ke pemilik laundry, dikirim bergiliran dan sedikit demi sedikit supaya nomor pengirim aman.</p>
@include('admin-marketing-nav')
@unless($connected)<div class="notice">Gateway WhatsApp belum tersambung, jadi pengiriman otomatis belum berjalan. Kampanye tetap bisa disusun, dan tiap pesan bisa dikirim manual lewat WhatsApp dari halaman kampanyenya.</div>@endunless
<section class="card"><div class="row"><h2>Nomor pengirim</h2><span @class(['pill', 'good' => $open && $connected])>{{ !$connected ? 'Gateway belum tersambung' : ($open ? 'Jam kirim' : 'Di luar jam kirim') }}</span></div>
<ul class="plain">@forelse($senders as $s)<li class="row"><span><b>{{ $s['label'] }}</b> · +{{ $s['phone'] }}<br>
<small class="muted">@if($s['paused_at'])Dihentikan otomatis: {{ $s['pause_reason'] }}@elseif(!$s['active'])Dimatikan@else Hari ini {{ $s['today'] }} dari jatah {{ $s['quota'] }} pesan · mulai {{ \Carbon\Carbon::parse($s['started_at'])->timezone('Asia/Jakarta')->format('d M Y') }}@endif</small>
<span class="meter {{ $s['paused_at'] ? 'fail' : '' }}" style="display:block;max-width:260px"><i style="width:{{ $s['quota'] ? min(100, round($s['today'] / $s['quota'] * 100)) : 0 }}%"></i></span></span>
<form method="post" action="{{ route('admin.senders.toggle', $s['id']) }}">@csrf<button class="secondary">{{ $s['paused_at'] ? 'Jalankan lagi' : ($s['active'] ? 'Matikan' : 'Nyalakan') }}</button></form></li>
@empty<li class="muted">Belum ada nomor pengirim. Tambahkan nomor khusus marketing; jangan memakai nomor CS pusat.</li>@endforelse</ul>
<details><summary>Tambah nomor pengirim</summary><form method="post" action="{{ route('admin.senders.store') }}">@csrf<div class="grid">
<div><label for="s-l">Nama</label><input id="s-l" name="label" required maxlength="80" placeholder="Contoh: Marketing 1"></div>
<div><label for="s-p">Nomor WhatsApp</label><input id="s-p" name="phone" required inputmode="tel" maxlength="30" placeholder="0812…"></div></div><p><button>Tambah</button></p></form></details></section>
<section class="card"><h2>Kampanye</h2><div class="table list"><table><thead><tr><th>Nama</th><th>Sasaran</th><th>Status</th><th>Antre · terkirim · dilewati · gagal</th><th></th></tr></thead><tbody>
@forelse($campaigns as $c)
@php($t = $tally[$c->id] ?? [])
<tr><td><b>{{ $c->name }}</b><br><small class="muted">{{ \Carbon\Carbon::parse($c->created_at)->timezone('Asia/Jakarta')->format('d M Y') }}</small></td>
<td data-label="Sasaran">{{ $c->audience === 'clients' ? 'Client' : 'Calon client' }}</td>
<td data-label="Status"><span @class(['pill', 'good' => $c->status === 'running'])>{{ ['draft' => 'Draf', 'running' => 'Berjalan', 'paused' => 'Dijeda', 'done' => 'Selesai'][$c->status] ?? $c->status }}</span></td>
<td data-label="Antre · terkirim · dilewati · gagal">{{ $t['queued'] ?? 0 }} · {{ ($t['sent'] ?? 0) + ($t['manual'] ?? 0) }} · {{ $t['skipped'] ?? 0 }} · {{ $t['failed'] ?? 0 }}</td>
<td><a class="button small" href="{{ route('admin.campaign', $c->id) }}">Buka</a></td></tr>
@empty<tr><td colspan="5" class="muted">Belum ada kampanye.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Kampanye baru</h2><form method="post" action="{{ route('admin.campaigns.store') }}">@csrf<div class="grid">
<div><label for="k-n">Nama kampanye</label><input id="k-n" name="name" value="{{ old('name') }}" required maxlength="120" placeholder="Contoh: Perkenalan Bekasi Oktober"></div>
<div><label for="k-a">Sasaran</label><select id="k-a" name="audience"><option value="prospects" @selected(old('audience') !== 'clients')>Calon client</option><option value="clients" @selected(old('audience') === 'clients')>Client (sudah terdaftar)</option></select></div>
<div><label for="k-c">Kota (calon client)</label><select id="k-c" name="city"><option value="">Semua kota</option>@foreach($cities as $c)<option value="{{ $c }}">{{ $c }}</option>@endforeach</select></div>
<div><label for="k-x">Status paket (client)</label><select id="k-x" name="access"><option value="">Semua</option>@foreach(['trial' => 'Trial', 'expired' => 'Berakhir', 'paid' => 'Berbayar', 'beta' => 'Beta'] as $k => $v)<option value="{{ $k }}">{{ $v }}</option>@endforeach</select></div></div>
<label>Status calon client yang dituju</label><div>@foreach(['baru', 'dihubungi', 'membalas', 'tertarik'] as $key)<label class="check"><input type="checkbox" name="statuses[]" value="{{ $key }}" @checked($key === 'baru')> {{ $statuses[$key] }}</label>@endforeach</div>
<label>Kalimat pesan pembuka</label><p class="muted">Isi beberapa variasi; sistem memakainya bergiliran supaya pesan tidak seragam. Bisa memakai {nama}, {usaha}, {kota}.</p>
@foreach([0, 1, 2] as $i)<textarea name="variants[]" rows="3" maxlength="1000" aria-label="Variasi pesan {{ $i + 1 }}" placeholder="{{ $i === 0 ? 'Halo {nama}, saya dari GOYANA, aplikasi kasir laundry. Boleh saya kirim info singkatnya untuk {usaha}?' : 'Variasi '.($i + 1).' (boleh kosong)' }}" @if($i === 0) required @endif>{{ old('variants.'.$i) }}</textarea>@endforeach
<label>Pesan tindak lanjut (boleh kosong)</label><p class="muted">Dikirim sekali, {{ $rules['blast_followup_days'] }} hari setelah pembuka, hanya ke yang belum membalas.</p>
<textarea name="followups[]" rows="2" maxlength="1000" aria-label="Tindak lanjut">{{ old('followups.0') }}</textarea>
<p class="muted">Tambahkan kalimat seperti "Balas STOP bila tidak ingin dihubungi lagi": balasan itu otomatis menghentikan semua kiriman ke nomor tersebut.</p>
<p><button>Susun antrean</button></p></form></section>
<section class="card"><h2>Aturan pengiriman</h2><p class="muted">Titik awal yang hati-hati. WhatsApp tidak mengumumkan batasnya, jadi angka ini menurunkan risiko blokir, tidak menghilangkannya.</p>
<form method="post" action="{{ route('admin.blast.rules') }}">@csrf<div class="grid">
@foreach([['blast_start_per_day', 'Jatah per nomor, minggu pertama (pesan/hari)'], ['blast_step_per_week', 'Kenaikan jatah tiap minggu'], ['blast_max_per_day', 'Batas atas per nomor (pesan/hari)'],
    ['blast_gap_min', 'Jeda antar pesan, paling cepat (menit)'], ['blast_gap_max', 'Jeda antar pesan, paling lama (menit)'], ['blast_hour_start', 'Mulai kirim (jam WIB)'], ['blast_hour_end', 'Berhenti kirim (jam WIB)'],
    ['blast_followup_days', 'Jarak tindak lanjut (hari)'], ['blast_recontact_days', 'Jarak sebelum dikirimi kampanye lain (hari)'], ['blast_fail_stop', 'Gagal berturut-turut sebelum nomor dihentikan']] as [$key, $label])
<div><label for="r-{{ $key }}">{{ $label }}</label><input id="r-{{ $key }}" name="{{ $key }}" type="number" min="0" value="{{ old($key, $rules[$key]) }}" required></div>
@endforeach</div>
<label class="check"><input type="checkbox" name="blast_sunday" value="1" @checked($rules['blast_sunday'])> Kirim juga pada hari Minggu</label><p><button class="secondary">Simpan aturan</button></p></form></section>
@endsection
