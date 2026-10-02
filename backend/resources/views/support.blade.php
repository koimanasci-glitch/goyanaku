@extends('layout')
@section('content')
<p><a href="{{ route('dashboard') }}">← Dashboard</a></p><h1>Bantuan</h1>
<p class="muted">Tulis kendala Anda. CS GOYANA membalas di halaman ini.@if($cs) Untuk yang mendesak, chat <a href="https://wa.me/{{ $cs }}" rel="noopener">WhatsApp CS</a>.@endif</p>
@if($owner)<section class="card"><h2>Mode Bantuan</h2>
@if($assist)<p><span class="pill good">Aktif</span> CS GOYANA boleh membantu mengatur harga layanan &amp; profil outlet sampai {{ \Carbon\Carbon::parse($assist->expires_at)->timezone('Asia/Jakarta')->format('H:i') }} WIB. Data pesanan, pelanggan &amp; uang tidak bisa diubah.</p>
<form method="post" action="{{ route('support.assist.stop') }}">@csrf<button class="secondary">Hentikan sekarang</button></form>
@else<p class="muted">Izinkan CS membantu mengatur harga layanan &amp; profil outlet dari pusat selama 30 menit. Perubahan masuk ke HP otomatis, tercatat, dan bisa dibatalkan.</p>
<form method="post" action="{{ route('support.assist') }}">@csrf<button>Izinkan Bantuan 30 menit</button></form>@endif</section>@endif
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
