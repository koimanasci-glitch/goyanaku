@extends('layout')
@section('content')
<h1>Template WhatsApp</h1>
<p>Pola balasan berlaku universal. Data pesanan dan layanan tetap berasal dari laundry terkait.</p>
<p>Variabel: {{ implode(', ', $variables) }}.</p>
@if(session('status'))<p role="status">{{ session('status') }}</p>@endif
@if($errors->any())<p role="alert">{{ $errors->first() }}</p>@endif
@foreach($templates as $template)
<section class="card">
<h2>{{ $template->name }} @if($template->ai_draft) — Usulan AI, belum aktif @endif</h2>
<p>Kegunaan: {{ $template->purpose }} · Revisi {{ $template->version }}</p>
@if($template->ai_draft)
<p>Tinjau teks ini lalu salin ke template kegunaan yang sesuai untuk menerbitkannya. Usulan tidak pernah langsung aktif.</p>
<pre>{{ $template->body }}</pre>
@else
<form method="post" action="{{ url('/admin/whatsapp/templates') }}">
@csrf
<input type="hidden" name="purpose" value="{{ $template->purpose }}">
<input type="hidden" name="version" value="{{ $template->version }}">
<label>Nama <input name="name" value="{{ $template->name }}" maxlength="100" required></label>
<label>Isi <textarea name="body" rows="5" required>{{ $template->body }}</textarea></label>
<label>Status <select name="active"><option value="0" @selected(!$template->active)>Nonaktif</option><option value="1" @selected($template->active)>Aktif</option></select></label>
<button type="submit">Simpan</button>
<button formaction="{{ url('/admin/whatsapp/templates/preview') }}" formtarget="_blank">Pratinjau</button>
<a href="{{ url('/admin/whatsapp/templates/'.$template->id.'/revisions') }}">Riwayat revisi</a>
</form>
@endif
</section>
@endforeach
{{ $templates->links() }}
<section class="card"><h2>Tambah Template</h2>
<form method="post" action="{{ url('/admin/whatsapp/templates') }}">
@csrf
<input type="hidden" name="version" value="0">
<label>Kegunaan <select name="purpose">@foreach($purposes as $purpose)<option>{{ $purpose }}</option>@endforeach</select></label>
<label>Nama <input name="name" maxlength="100" required></label>
<label>Isi <textarea name="body" rows="5" required></textarea></label>
<label>Status <select name="active"><option value="0">Draf / Nonaktif</option><option value="1">Aktif</option></select></label>
<button>Simpan</button><button formaction="{{ url('/admin/whatsapp/templates/preview') }}" formtarget="_blank">Pratinjau</button>
</form></section>
<form method="post" action="{{ url('/admin/whatsapp/templates/propose') }}">@csrf<button>Minta Usulan AI</button></form>
<p>Usulan AI membutuhkan penyedia dan anggaran yang sudah dikonfigurasi. Periksa keakuratan dan hindari identitas, harga, atau janji khusus laundry pada template universal.</p>
@endsection
