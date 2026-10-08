@extends('layout')
@section('content')
@include('admin-nav')
<h1>Pengguna</h1><p class="muted">Akun administrator pusat per divisi. Tiap orang memakai akun dan OTP sendiri; semua tindakannya tercatat atas namanya.</p>
<section class="card"><div class="table list"><table><thead><tr><th>Nama</th><th>Divisi</th><th>Status</th><th></th></tr></thead><tbody>
@foreach($admins as $a)<tr><td>{{ $a->name }}<br><small class="muted">{{ $a->email }}{{ $a->mfa_confirmed_at ? ' · OTP aktif' : ' · OTP belum dipasang' }}</small></td>
<td data-label="Divisi"><form method="post" action="{{ route('admin.admins.update', $a) }}">@csrf<select name="division" aria-label="Divisi">@foreach($divisions as $key => $d)<option value="{{ $key }}" @selected($a->adminDivision() === $key)>{{ $d['label'] }}</option>@endforeach</select><p><button class="secondary">Simpan</button></p></form></td>
<td data-label="Status"><span @class(['pill', 'good' => !$a->deactivated_at, 'bad' => (bool) $a->deactivated_at])>{{ $a->deactivated_at ? 'Nonaktif' : 'Aktif' }}</span></td>
<td>@if($a->id !== auth()->id())<form method="post" action="{{ route('admin.admins.toggle', $a) }}">@csrf<button class="secondary">{{ $a->deactivated_at ? 'Aktifkan' : 'Nonaktifkan' }}</button></form>@else<small class="muted">Akun Anda</small>@endif</td></tr>@endforeach
</tbody></table></div></section>
<section class="card"><h2>Yang bisa dibuka tiap divisi</h2><ul class="plain">
<li><b>Pemilik</b> — semuanya, termasuk akun divisi lain, langganan, dan saldo AI.</li>
<li><b>Marketing</b> — CRM client dan calon client, WA blast, promosi, laporan. Tanpa data transaksi atau pelanggan milik laundry.</li>
<li><b>CS / Bantuan</b> — data client, tiket, FAQ, Mode Bantuan, paket sementara.</li>
<li><b>Teknis</b> — Monitor VPS, pengaturan sistem, audit, data client untuk memeriksa sinkronisasi.</li></ul></section>
<section class="card"><h2>Tambah akun</h2><form method="post" action="{{ route('admin.admins.store') }}">@csrf<div class="grid">
<div><label for="a-n">Nama</label><input id="a-n" name="name" value="{{ old('name') }}" required maxlength="120"></div>
<div><label for="a-e">Email</label><input id="a-e" name="email" type="email" value="{{ old('email') }}" required maxlength="254"></div>
<div><label for="a-p">Password awal</label><input id="a-p" name="password" type="password" required autocomplete="new-password"><small class="muted">Minimal 12 karakter, huruf dan angka.</small></div>
<div><label for="a-d">Divisi</label><select id="a-d" name="division">@foreach($divisions as $key => $d)<option value="{{ $key }}" @selected(old('division', 'marketing') === $key)>{{ $d['label'] }}</option>@endforeach</select></div>
</div><p><button>Buat akun</button></p></form></section>
@endsection
