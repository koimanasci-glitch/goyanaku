@extends('layout')
@section('content')
@include('admin-nav')
<h1>FAQ jawaban otomatis</h1><p class="muted">Tiket baru dicocokkan dengan kata kunci di sini dulu (gratis, tanpa AI). Pertanyaan yang sering muncul sebaiknya dijadikan FAQ.</p>
<section class="card"><h2>Coba pertanyaan</h2><form class="filters" method="get" action="{{ route('admin.faqs') }}"><input name="test" value="{{ $test }}" placeholder="Contoh: struk tidak keluar dari printer" aria-label="Pertanyaan uji"><button class="secondary">Cek</button></form>
@if($test !== '')<p>{!! $match ? 'Cocok dengan: <b>'.e($match->question).'</b>' : 'Tidak ada yang cocok — akan diteruskan ke CS.' !!}</p>@endif</section>
<section class="card"><h2>Tambah FAQ</h2><form method="post" action="{{ route('admin.faqs.store') }}">@csrf
<label for="q">Pertanyaan</label><input id="q" name="question" required maxlength="200" value="{{ old('question') }}">
<label for="k">Kata kunci (pisahkan dengan koma)</label><input id="k" name="keywords" required maxlength="500" value="{{ old('keywords') }}" placeholder="printer, struk tidak keluar">
<label for="a">Jawaban</label><textarea id="a" name="answer" rows="4" required maxlength="3000">{{ old('answer') }}</textarea><p><button>Tambah</button></p></form></section>
@foreach($faqs as $f)<section class="card"><details><summary><b>{{ $f->question }}</b> @if(!$f->active)<span class="pill bad">Nonaktif</span>@endif <small class="muted">· dipakai {{ $f->hits }}x</small></summary>
<form method="post" action="{{ route('admin.faqs.update', $f->id) }}">@csrf
<label for="q{{ $f->id }}">Pertanyaan</label><input id="q{{ $f->id }}" name="question" required maxlength="200" value="{{ $f->question }}">
<label for="k{{ $f->id }}">Kata kunci</label><input id="k{{ $f->id }}" name="keywords" required maxlength="500" value="{{ $f->keywords }}">
<label for="a{{ $f->id }}">Jawaban</label><textarea id="a{{ $f->id }}" name="answer" rows="5" required maxlength="3000">{{ $f->answer }}</textarea>
<label class="check"><input type="checkbox" name="active" value="1" @checked($f->active)> Aktif</label>
<p class="row"><button>Simpan</button></p></form>
<form method="post" action="{{ route('admin.faqs.delete', $f->id) }}">@csrf<button class="secondary">Hapus FAQ</button></form></details></section>@endforeach
@endsection
