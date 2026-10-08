@extends('layout')
@section('content')
<p><a href="{{ route('admin.marketing') }}">← Calon client</a></p>
<h1>{{ $p->name }}</h1><p class="muted">+{{ $p->phone }}{{ $p->city ? ' · '.$p->city : '' }} · sumber: {{ $p->source }}{{ $p->replies ? ' · '.$p->replies.' balasan' : '' }}</p>
@if($p->do_not_contact)<div class="notice">Kontak ini meminta tidak dihubungi. Sistem tidak akan mengiriminya pesan lagi.</div>@endif
@if($p->business_id)<div class="notice">Sudah mendaftar sebagai client.</div>@endif
<section class="card"><form method="post" action="{{ route('admin.prospect.update', $p->id) }}">@csrf<div class="grid">
<div><label for="s">Status</label><select id="s" name="status">@foreach($statuses as $key => $label)<option value="{{ $key }}" @selected($p->status === $key)>{{ $label }}</option>@endforeach</select><small class="muted">"Menolak" berarti tidak dihubungi lagi, selamanya.</small></div>
<div><label for="o">Nama pemilik</label><input id="o" name="owner_name" value="{{ $p->owner_name }}" maxlength="120"></div>
<div><label for="c">Kota</label><input id="c" name="city" value="{{ $p->city }}" maxlength="80"></div></div>
<label for="n">Catatan</label><textarea id="n" name="note" rows="3" maxlength="1000">{{ $p->note }}</textarea><p><button>Simpan</button>
@unless($p->do_not_contact) <a class="button secondary" href="https://wa.me/{{ $p->phone }}" target="_blank" rel="noopener">Buka WhatsApp</a>@endunless</p></form></section>
@if($pending->isNotEmpty())<section class="card"><h2>Menunggu dikirim</h2><ul class="plain">@foreach($pending as $m)<li><b>{{ $m->campaign }}</b> · {{ $m->kind === 'followup' ? 'tindak lanjut' : 'pembuka' }}<br><small class="muted">{{ $m->body }}</small></li>@endforeach</ul></section>@endif
<section class="card"><h2>Riwayat</h2><ul class="plain">@forelse($events as $e)<li>{{ ['dibuat' => 'Ditambahkan', 'status' => 'Status', 'kirim' => 'Dikirimi', 'balas' => 'Membalas', 'stop' => 'Minta berhenti', 'catatan' => 'Catatan'][$e->kind] ?? $e->kind }}@if($e->detail): {{ $e->detail }}@endif
<br><small class="muted">{{ \Carbon\Carbon::parse($e->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}{{ $e->actor ? ' · '.$e->actor : '' }}</small></li>@empty<li class="muted">Belum ada riwayat.</li>@endforelse</ul></section>
@endsection
