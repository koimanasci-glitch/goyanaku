@extends('layout')
@section('content')
@include('admin-nav')
<h1>Paket & Langganan</h1><p class="muted">Paket diatur per client di halaman Kelola Client → Kelola.</p>
<section class="card"><div class="table list"><table><thead><tr><th>Paket</th><th>Harga / bulan</th><th>Cabang</th><th>HP kasir / outlet</th><th>Client</th></tr></thead><tbody>
@foreach($packages as $name => $p)<tr><td><b>{{ $name }}</b></td><td data-label="Harga">Rp{{ number_format($p['price'], 0, ',', '.') }}</td><td data-label="Cabang">1 pusat + {{ $p['branches'] }}</td><td data-label="HP kasir">{{ $p['cashier_devices'] }}</td><td data-label="Client">{{ $counts[$name] ?? 0 }}</td></tr>@endforeach
<tr><td>Berakhir (baca saja)</td><td></td><td></td><td></td><td data-label="Client">{{ $counts['Berakhir'] ?? 0 }}</td></tr>
</tbody></table></div></section>
<section class="card"><h2>Berakhir dalam 7 hari</h2><ul class="plain">
@forelse($endingTrials as $b)<li><a href="{{ route('admin.business', $b) }}">{{ $b->name }}</a> <span class="pill">Trial</span> <small class="muted">{{ $b->trial_ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</small></li>@empty @endforelse
@foreach($endingPaid as $s)<li><a href="{{ route('admin.business', $s->business_id) }}">{{ $s->business?->name }}</a> <span class="pill">{{ $s->package }}</span> <small class="muted">{{ $s->ends_at->timezone('Asia/Jakarta')->format('d M Y') }}</small></li>@endforeach
@if($endingTrials->isEmpty() && $endingPaid->isEmpty())<li class="muted">Tidak ada yang berakhir minggu ini.</li>@endif
</ul></section>
@endsection
