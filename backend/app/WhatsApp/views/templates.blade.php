@extends('layout')
@section('content')
@include('admin-nav')
<h1>Template WhatsApp</h1>
<p class="muted">Pola balasan otomatis untuk semua laundry. Isi pesanan, layanan dan harga selalu diambil dari data laundry masing-masing, tidak ditulis di sini.</p>
<section class="card"><h2>Variabel yang boleh dipakai</h2><p>@foreach($variables as $v)<span class="pill">{{ '{'.'{'.$v.'}'.'}' }}</span> @endforeach</p>
<p class="muted">Tiap kegunaan hanya menerima variabel yang datanya tersedia. Template yang memakai variabel lain ditolak saat disimpan.</p></section>
@foreach($templates as $template)
<section class="card"><details @if($errors->any() && old('purpose') === $template->purpose) open @endif><summary><b>{{ $template->name }}</b>
@if($template->ai_draft)<span class="pill">Usulan AI</span>@elseif($template->active)<span class="pill good">Aktif</span>@else<span class="pill bad">Nonaktif</span>@endif
<small class="muted">· {{ $template->purpose }} · revisi {{ $template->version }}</small></summary>
@if($template->ai_draft)
<p class="muted">Usulan tidak pernah langsung aktif. Tinjau teksnya, lalu salin ke template dengan kegunaan yang sesuai.</p>
<pre>{{ $template->body }}</pre>
@else
<form method="post" action="{{ route('admin.wa.templates.save') }}">@csrf
<input type="hidden" name="purpose" value="{{ $template->purpose }}"><input type="hidden" name="version" value="{{ $template->version }}">
<label for="n{{ $template->id }}">Nama</label><input id="n{{ $template->id }}" name="name" value="{{ $template->name }}" maxlength="100" required>
<label for="b{{ $template->id }}">Isi pesan</label><textarea id="b{{ $template->id }}" name="body" rows="6" maxlength="4000" required>{{ $template->body }}</textarea>
<label for="a{{ $template->id }}">Status</label><select id="a{{ $template->id }}" name="active"><option value="0" @selected(!$template->active)>Nonaktif</option><option value="1" @selected($template->active)>Aktif</option></select>
<p class="row"><button>Simpan</button><button class="secondary" formaction="{{ route('admin.wa.templates.preview') }}" formtarget="_blank">Pratinjau</button>
<a href="{{ route('admin.wa.templates.revisions', $template->id) }}" target="_blank" rel="noopener">Riwayat revisi</a></p></form>
@endif
</details></section>
@endforeach
@if($templates->isEmpty())<p class="muted">Belum ada template tersimpan. Selama belum ada, balasan memakai teks bawaan sistem.</p>@endif
{{ $templates->links() }}
<section class="card"><h2>Tambah template</h2><p class="muted">Satu kegunaan hanya punya satu template. Menyimpan kegunaan yang sudah ada berarti mengubah template itu.</p>
<form method="post" action="{{ route('admin.wa.templates.save') }}">@csrf
<input type="hidden" name="version" value="0">
<label for="np">Kegunaan</label><select id="np" name="purpose">@foreach($purposes as $purpose)<option @selected(old('purpose') === $purpose)>{{ $purpose }}</option>@endforeach</select>
<label for="nn">Nama</label><input id="nn" name="name" maxlength="100" required value="{{ old('name') }}">
<label for="nb">Isi pesan</label><textarea id="nb" name="body" rows="6" maxlength="4000" required>{{ old('body') }}</textarea>
<label for="na">Status</label><select id="na" name="active"><option value="0">Nonaktif (draf)</option><option value="1">Aktif</option></select>
<p class="row"><button>Simpan</button><button class="secondary" formaction="{{ route('admin.wa.templates.preview') }}" formtarget="_blank">Pratinjau</button></p></form></section>
<section class="card"><h2>Usulan AI pusat</h2><p class="muted">AI pusat hanya membaca jumlah topik pertanyaan yang belum terjawab, bukan isi percakapan atau data laundry. Usulannya tersimpan sebagai draf dan baru dipakai setelah ditinjau. Penyedia AI belum dipasang, jadi tombol ini belum menghasilkan usulan.</p>
<form method="post" action="{{ route('admin.wa.templates.propose') }}">@csrf<button class="secondary">Minta usulan AI</button></form></section>
@endsection
