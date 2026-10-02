@extends('layout')
@section('content')
<p><a href="{{ route('dashboard') }}">← Dashboard</a></p><h1>Bantuan</h1>
<p class="muted">Tulis kendala Anda. CS GOYANA membalas di halaman ini.@if($cs) Untuk yang mendesak, chat <a href="https://wa.me/{{ $cs }}" rel="noopener">WhatsApp CS</a>.@endif</p>
<section class="card"><h2>Tiket baru</h2><form method="post" action="{{ route('support.store') }}">@csrf
<label for="t-subject">Judul</label><input id="t-subject" name="subject" value="{{ old('subject') }}" required maxlength="160" placeholder="Contoh: Printer tidak mau mencetak">
<label for="t-cat">Kategori</label><select id="t-cat" name="category">@foreach($categories as $k => $v)<option value="{{ $k }}" @selected(old('category') === $k)>{{ $v }}</option>@endforeach</select>
<label for="t-body">Ceritakan kendalanya</label><textarea id="t-body" name="body" rows="5" required maxlength="5000" placeholder="Apa yang terjadi, di HP/outlet mana, sejak kapan">{{ old('body') }}</textarea>
<p><button>Kirim tiket</button></p></form></section>
<section class="card"><h2>Tiket saya</h2><ul class="plain">
@forelse($tickets as $t)<li><a href="{{ route('support.show', $t) }}"><b>{{ $t->subject }}</b></a> <span @class(['pill', 'good' => $t->status === 'answered', 'bad' => $t->status === 'open'])>{{ \App\Models\Ticket::STATUSES[$t->status] }}</span><br>
<small class="muted">#{{ $t->id }} · {{ \App\Models\Ticket::CATEGORIES[$t->category] ?? $t->category }} · {{ $t->last_activity_at->timezone('Asia/Jakarta')->format('d M Y H:i') }}</small></li>
@empty<li class="muted">Belum ada tiket.</li>@endforelse</ul>{{ $tickets->links() }}</section>
@endsection
