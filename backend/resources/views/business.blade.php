@extends('layout')
@section('content')
@include('admin-nav')
<p><a href="{{ route('admin.index') }}">← Daftar usaha</a></p><h1>{{ $business->name }}</h1>
<p class="muted">Usaha #{{ $business->id }} · daftar {{ $business->created_at?->timezone('Asia/Jakarta')->format('d M Y') }}</p>
<div class="kpis">
<div class="kpi"><small>Paket</small><b>{{ $access['package'] ?? '—' }}</b></div>
<div class="kpi"><small>Status</small><b>{{ $access['read_only'] ? 'Baca saja' : 'Aktif' }}</b></div>
<div class="kpi"><small>Sumber</small><b>{{ ['subscription' => 'Berbayar', 'beta' => 'Beta', 'trial' => 'Trial', 'expired' => 'Berakhir'][$access['source']] ?? $access['source'] }}</b></div>
<div class="kpi"><small>Berakhir (WIB)</small><b>{{ $access['ends_at'] ? \Carbon\Carbon::parse($access['ends_at'])->timezone('Asia/Jakarta')->format('d M Y') : '—' }}</b></div>
<div class="kpi"><small>Outlet / batas</small><b>{{ $outlets->count() }} / {{ $access['outlet_limit'] }}</b></div>
<div class="kpi"><small>Sinkron terakhir</small><b>{{ $sync['last'] ? \Carbon\Carbon::parse($sync['last'])->timezone('Asia/Jakarta')->format('d M H:i') : 'Belum' }}</b></div>
</div>
<section class="card"><h2>Tim</h2><div class="table list"><table><thead><tr><th>Nama</th><th>Peran</th><th>Outlet</th><th>Status</th></tr></thead><tbody>
@forelse($users as $u)<tr><td data-label="Nama"><b>{{ $u->name }}</b><br><small class="muted">{{ $u->email }}</small></td><td data-label="Peran">{{ ucfirst($u->role) }}</td>
<td data-label="Outlet">{{ $u->outlet?->name ?? 'Semua' }}</td><td data-label="Status">
<span @class(['pill', 'good' => $u->isActive() && $u->email_verified_at, 'bad' => !$u->isActive()])>{{ !$u->isActive() ? 'Nonaktif' : ($u->email_verified_at ? 'Aktif' : 'Email belum verifikasi') }}</span></td></tr>
@empty<tr><td colspan="4">Belum ada pengguna.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Outlet & HP kasir</h2>
@foreach($outlets as $o)<h3>{{ $o->name }} @if($loop->first)<span class="badge">Pusat</span>@endif</h3>
<div class="table list"><table><thead><tr><th>Perangkat</th><th>Slot</th><th>Terakhir aktif</th><th></th></tr></thead><tbody>
@forelse($o->devices as $d)<tr><td data-label="Perangkat">{{ $d->label }}<br><small class="muted">{{ $d->device_uuid ? 'ID '.substr($d->device_uuid, 0, 8) : 'Belum dipasang di HP' }}</small></td>
<td data-label="Slot">{{ $d->revoked_at ? '—' : $d->slot }}</td>
<td data-label="Terakhir aktif">{{ $d->last_seen_at ? \Carbon\Carbon::parse($d->last_seen_at)->timezone('Asia/Jakarta')->format('d M Y H:i') : '—' }}</td>
<td>@if($d->revoked_at)<span class="pill bad">Dicabut</span>@else
<form method="post" action="{{ route('admin.device.revoke', [$business, $d]) }}">@csrf<input name="reason" required maxlength="300" placeholder="Alasan (mis. HP hilang)" aria-label="Alasan cabut perangkat"><p><button class="secondary">Cabut akses HP</button></p></form>@endif</td></tr>
@empty<tr><td colspan="4">Belum ada HP kasir.</td></tr>@endforelse</tbody></table></div>@endforeach
</section>
<section class="card"><h2>Sinkronisasi</h2><p class="muted">{{ $sync['ops24'] }} operasi dalam 24 jam terakhir.</p>
<div class="table"><table><thead><tr><th>Data</th><th>Jumlah</th><th>Terakhir berubah</th></tr></thead><tbody>
@forelse($sync['records'] as $r)<tr><td>{{ $r->collection }}</td><td>{{ number_format($r->n, 0, ',', '.') }}</td><td>{{ \Carbon\Carbon::parse($r->last)->timezone('Asia/Jakarta')->format('d M Y H:i') }}</td></tr>
@empty<tr><td colspan="3">Belum ada data dari HP.</td></tr>@endforelse</tbody></table></div>
@if($sync['conflicts']->isNotEmpty())<h3>Konflik terbaru</h3><p class="muted">Data server dipakai; versi HP yang kalah disimpan untuk diperiksa.</p><ul class="plain">
@foreach($sync['conflicts'] as $c)<li>{{ $c->collection }} · {{ \Illuminate\Support\Str::limit($c->record_key, 40) }} <small class="muted">{{ \Carbon\Carbon::parse($c->created_at)->timezone('Asia/Jakarta')->format('d M H:i') }}</small></li>@endforeach</ul>@endif
</section>
<section class="card"><h2>Saldo AI · Rp{{ number_format($business->ai_balance, 0, ',', '.') }}</h2>
<p class="muted">Catat top-up yang sudah dicek manual (transfer/QRIS) sampai pembayaran otomatis aktif. Minimal Rp{{ number_format(\App\Support\Settings::get('ai_min_topup'), 0, ',', '.') }}.</p>
<form method="post" action="{{ route('admin.ai.topup', $business) }}">@csrf<div class="grid">
<div><label for="ai-amount">Nominal (Rp)</label><input id="ai-amount" name="amount" type="number" min="1" step="1000" required value="{{ old('amount') }}"></div>
<div><label for="ai-ref">Referensi pembayaran</label><input id="ai-ref" name="reference" required maxlength="120" value="{{ old('reference') }}" placeholder="No. transfer / ID QRIS"></div>
</div><p><button>Catat top-up</button></p></form>
@if($aiLedger->isNotEmpty())<div class="table"><table><thead><tr><th>Waktu (WIB)</th><th>Jenis</th><th>Jumlah</th><th>Saldo</th><th>Rincian</th></tr></thead><tbody>
@foreach($aiLedger as $l)<tr><td>{{ \Carbon\Carbon::parse($l->created_at)->timezone('Asia/Jakarta')->format('d M H:i') }}</td><td>{{ ['topup' => 'Top-up', 'usage' => 'Pemakaian', 'adjust' => 'Koreksi'][$l->type] ?? $l->type }}</td>
<td>{{ $l->amount > 0 ? '+' : '−' }}Rp{{ number_format(abs($l->amount), 0, ',', '.') }}</td><td>Rp{{ number_format($l->balance_after, 0, ',', '.') }}</td><td><small class="muted">{{ $l->model ?? $l->reference }}@if($l->cost_usd) · ${{ rtrim(rtrim(number_format($l->cost_usd, 6, '.', ''), '0'), '.') }} × {{ number_format($l->fx_rate, 0, ',', '.') }}@endif</small></td></tr>@endforeach
</tbody></table></div>@endif</section>
<section class="card"><h2>Catat pembayaran paket</h2><p class="muted">Untuk transfer/QRIS yang sudah dicek manual, sampai gateway pembayaran & Google Play Billing aktif. Perpanjangan dimulai dari akhir langganan yang masih berjalan.</p>
<form method="post" action="{{ route('admin.subscribe', $business) }}">@csrf<div class="grid">
<div><label for="s-package">Paket</label><select id="s-package" name="package">@foreach($packages as $name => $p)<option value="{{ $name }}" @selected(old('package') === $name)>{{ $name }} · Rp{{ number_format($p['price'], 0, ',', '.') }}/bln · {{ $p['branches'] }} cabang</option>@endforeach</select></div>
<div><label for="s-months">Lama (bulan)</label><input id="s-months" name="months" type="number" min="1" max="12" value="{{ old('months', 1) }}" required></div>
<div><label for="s-amount">Nominal diterima (Rp)</label><input id="s-amount" name="amount" type="number" min="0" value="{{ old('amount') }}" required></div>
<div><label for="s-ref">Referensi pembayaran</label><input id="s-ref" name="reference" value="{{ old('reference') }}" required maxlength="120" placeholder="No. transfer / ID QRIS"></div>
</div><p><button>Catat pembayaran</button></p></form>
<div class="table"><table><thead><tr><th>Paket</th><th>Periode (WIB)</th><th>Nominal</th><th>Referensi</th><th>Status</th></tr></thead><tbody>
@forelse($subscriptions as $s)<tr><td>{{ $s->package }}</td><td>{{ $s->starts_at->timezone('Asia/Jakarta')->format('d M Y') }} – {{ $s->ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</td><td>Rp{{ number_format((int) $s->amount, 0, ',', '.') }}</td><td>{{ $s->reference }}</td><td>
@if($s->cancelled_at)Dibatalkan
@elseif($s->ends_at->isPast())Berakhir
@else<form method="post" action="{{ route('admin.subscription.cancel', [$business, $s]) }}">@csrf<input name="reason" required maxlength="500" placeholder="Alasan pembatalan" aria-label="Alasan pembatalan"><p><button class="secondary">Batalkan catatan</button></p></form>@endif
</td></tr>@empty<tr><td colspan="5">Belum ada pembayaran tercatat.</td></tr>@endforelse</tbody></table></div></section>
<section class="card"><h2>Berikan paket sementara</h2><p class="muted">Untuk beta atau bantuan. Tidak membuat invoice, autodebit atau saldo AI.</p>
<form method="post" action="{{ route('admin.grant', $business) }}">@csrf
<label for="package">Paket</label><select id="package" name="package">@foreach(array_keys($packages) as $package)<option @selected(old('package') === $package)>{{ $package }}</option>@endforeach</select>
<label for="ends_at">Berakhir pada (WIB)</label><input id="ends_at" name="ends_at" type="datetime-local" value="{{ old('ends_at') }}" required>
<label for="reason">Alasan</label><textarea id="reason" name="reason" maxlength="500" required>{{ old('reason') }}</textarea><p><button>Berikan paket</button></p>
</form></section>
<section class="card table"><h2>Riwayat paket sementara</h2><table><thead><tr><th>Paket</th><th>Berakhir (WIB)</th><th>Alasan</th><th>Status</th></tr></thead><tbody>
@forelse($grants as $grant)<tr><td>{{ $grant->package }}</td><td>{{ $grant->ends_at->timezone('Asia/Jakarta')->format('d M Y H:i') }}</td><td>{{ $grant->reason }}</td><td>
@if($grant->revoked_at)Dicabut
@elseif($grant->ends_at->isPast())Berakhir
@else<form method="post" action="{{ route('admin.revoke', [$business, $grant]) }}">@csrf<button class="secondary">Cabut</button></form>@endif
</td></tr>@empty<tr><td colspan="4">Belum ada paket sementara.</td></tr>@endforelse</tbody></table></section>
@php($assist = \App\Support\Assist::active($business))
<section class="card"><div class="row"><h2>Mode Bantuan</h2><a class="button small {{ $assist ? '' : 'secondary' }}" href="{{ route('admin.assist', $business) }}">{{ $assist ? 'Buka Mode Bantuan' : 'Lihat' }}</a></div>
<p class="muted">{{ $assist ? 'Aktif sampai '.\Carbon\Carbon::parse($assist->expires_at)->timezone('Asia/Jakarta')->format('H:i').' WIB (diizinkan owner).' : 'Tidak aktif. Owner menekan "Izinkan Bantuan" di halaman Bantuan untuk memberi akses 30 menit.' }}</p></section>
<section class="card"><h2>Uji Balasan Cepat WhatsApp</h2><p class="muted">Jawaban otomatis tanpa AI untuk pelanggan laundry ini (cek status, tagihan, nota, harga, jam buka). Aktif di WhatsApp setelah CHATKU tersambung.</p>
<form method="post" action="{{ route('admin.qr.test', $business) }}">@csrf<div class="grid">
<div><label for="qr-from">Nomor pengirim</label><input id="qr-from" name="from" value="{{ old('from') }}" required maxlength="30" placeholder="6281234567890"></div>
<div><label for="qr-text">Pesan</label><input id="qr-text" name="text" value="{{ old('text') }}" required maxlength="500" placeholder="Mas baju saya sudah jadi belum?"></div>
</div><p><button class="secondary">Coba</button></p></form>
@if(session('qr'))@php($qr = session('qr'))<div class="msg mine" style="max-width:100%"><small>Maksud: {{ $qr['intent'] ?? 'tidak dikenali' }}{{ $qr['customer'] ? ' · pelanggan: '.$qr['customer'] : ' · nomor tidak dikenal' }}</small><p>{{ $qr['reply'] ?? '(Tidak ada jawaban otomatis — diteruskan ke kasir / Chatbot AI)' }}</p></div>@endif
</section>
<section class="card"><h2>Pesan otomatis ke owner</h2><ul class="plain">
@forelse($messages as $m)<li>{{ $m->subject }} <span @class(['pill', 'good' => $m->status === 'sent', 'bad' => $m->status !== 'sent'])>{{ $m->status === 'sent' ? 'Terkirim' : 'Gagal' }}</span><br><small class="muted">{{ $m->channel }} · {{ $m->recipient }} · {{ \Carbon\Carbon::parse($m->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}@if($m->error) · {{ $m->error }}@endif</small></li>
@empty<li class="muted">Belum ada.</li>@endforelse</ul></section>
<section class="card"><div class="row"><h2>Aktivitas terakhir</h2><a href="{{ route('admin.audit', ['business' => $business->id]) }}">Lihat semua →</a></div><ul class="plain audit">
@forelse($audit as $e)<li><span class="badge">{{ $e->action }}</span> {{ $e->actor_name ?? '—' }}@if($e->actor_admin) <small class="pill">admin</small>@endif
<small class="muted">· {{ \Carbon\Carbon::parse($e->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}</small></li>
@empty<li>Belum ada aktivitas.</li>@endforelse</ul></section>
@endsection
