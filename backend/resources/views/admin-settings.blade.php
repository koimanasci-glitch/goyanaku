@extends('layout')
@section('content')
@include('admin-nav')
<h1>Pengaturan platform</h1><p class="muted">Berlaku untuk seluruh klien tanpa perlu update aplikasi.</p>
<form method="post" action="{{ route('admin.settings.save') }}">@csrf
<section class="card"><h2>Saldo AI klien</h2><p class="muted">Potongan = biaya OpenRouter (USD) × kurs harian × (1 + cadangan kurs) × (1 + untung). Lihat §44.</p><div class="grid">
<div><label for="m">Untung (%)</label><input id="m" name="ai_margin_percent" type="number" min="0" max="300" value="{{ old('ai_margin_percent', $s['ai_margin_percent']) }}" required></div>
<div><label for="t">Minimal top-up (Rp)</label><input id="t" name="ai_min_topup" type="number" min="10000" step="1000" value="{{ old('ai_min_topup', $s['ai_min_topup']) }}" required></div>
<div><label for="fx">Cadangan kurs (%)</label><input id="fx" name="fx_cushion_percent" type="number" min="0" max="20" step="0.5" value="{{ old('fx_cushion_percent', $s['fx_cushion_percent']) }}" required></div>
<div><label for="b">Batas biaya AI CS pusat / hari (USD)</label><input id="b" name="ai_daily_budget_usd" type="number" min="0" max="1000" step="0.5" value="{{ old('ai_daily_budget_usd', $s['ai_daily_budget_usd']) }}" required></div>
<div><label for="mp">Model AI utama (OpenRouter)</label><input id="mp" name="ai_model_primary" list="ai-models" value="{{ old('ai_model_primary', $s['ai_model_primary']) }}" placeholder="pilih dari daftar"></div>
<div><label for="mf">Model AI cadangan</label><input id="mf" name="ai_model_fallback" list="ai-models" value="{{ old('ai_model_fallback', $s['ai_model_fallback']) }}" placeholder="dipakai bila utama tidak tersedia"></div>
</div>
<datalist id="ai-models">@foreach($models as $m)<option value="{{ $m->id }}">{{ $m->name }} · ${{ (float) $m->prompt_usd_per_mtok }}/${{ (float) $m->completion_usd_per_mtok }} per 1 juta token</option>@endforeach</datalist>
<p class="muted">Kurs terakhir: @if($fx)<b>Rp{{ number_format($fx->rate, 2, ',', '.') }}</b> ({{ \Carbon\Carbon::parse($fx->day)->format('d M Y') }}, {{ $fx->source }})@else belum ada — server mengambil otomatis tiap hari @endif · {{ $models->count() }} model tersedia.
@if($fx) Contoh: biaya $0,01 dipotong <b>Rp{{ number_format(\App\Support\AiBilling::toRupiah(0.01), 0, ',', '.') }}</b> dari saldo klien.@endif</p>
</section>
<section class="card"><h2>WhatsApp</h2><div class="grid">
<div><label for="cs">Nomor WA CS pusat</label><input id="cs" name="cs_whatsapp" inputmode="numeric" value="{{ old('cs_whatsapp', $s['cs_whatsapp']) }}" placeholder="6281234567890"></div>
<div><label for="p">Bot diam setelah kasir membalas (menit)</label><input id="p" name="bot_pause_minutes" type="number" min="1" max="1440" value="{{ old('bot_pause_minutes', $s['bot_pause_minutes']) }}" required></div>
</div>
<h3>Pesan otomatis ke klien (hemat, masing-masing 1x)</h3>
@foreach(['msg_welcome' => 'Selamat datang + panduan saat daftar', 'msg_expiry_reminder' => 'Pengingat 3 hari sebelum paket habis', 'msg_expired' => 'Info saat paket habis (baca saja)', 'msg_payment' => 'Terima kasih setelah bayar'] as $k => $v)
<label class="check"><input type="checkbox" name="{{ $k }}" value="1" @checked(old($k, $s[$k]))> {{ $v }}</label>@endforeach
<p class="muted">Pengiriman aktif setelah CHATKU tersambung (§41).</p></section>
<p><button>Simpan pengaturan</button></p></form>
@if($history->isNotEmpty())<section class="card"><h2>Riwayat perubahan</h2><ul class="plain">
@foreach($history as $h)<li>{{ $h->actor_name }} <small class="muted">· {{ \Carbon\Carbon::parse($h->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}</small><br><code class="details">{{ $h->details }}</code></li>@endforeach</ul></section>@endif
@endsection
