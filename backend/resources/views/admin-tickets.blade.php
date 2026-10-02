@extends('layout')
@section('content')
@include('admin-nav')
<h1>Tiket CS</h1><p class="muted">Kendala dari klien laundry. Prioritas tinggi dan yang menunggu CS tampil paling atas.</p>
<div class="adminnav sub">@foreach(['active' => 'Belum selesai', 'open' => 'Menunggu CS', 'answered' => 'Dijawab', 'closed' => 'Selesai'] as $k => $v)
<a href="{{ route('admin.tickets', ['status' => $k]) }}" @class(['on' => $status === $k])>{{ $v }}@if($k !== 'active') ({{ $counts[$k] ?? 0 }})@endif</a>@endforeach</div>
<section class="card"><ul class="plain">
@forelse($tickets as $t)<li><a href="{{ route('admin.ticket', $t) }}"><b>{{ $t->subject }}</b></a>
@if($t->priority === 'high')<span class="pill bad">Prioritas</span>@endif <span @class(['pill', 'bad' => $t->status === 'open', 'good' => $t->status === 'answered'])>{{ \App\Models\Ticket::STATUSES[$t->status] }}</span><br>
<small class="muted">#{{ $t->id }} · {{ $t->business?->name ?? 'Tanpa usaha' }} · {{ $t->user?->name }} · {{ \App\Models\Ticket::CATEGORIES[$t->category] ?? $t->category }} · {{ $t->source }} · {{ $t->last_activity_at->timezone('Asia/Jakarta')->format('d M H:i') }}</small></li>
@empty<li class="muted">Tidak ada tiket.</li>@endforelse</ul>{{ $tickets->links() }}</section>
@endsection
