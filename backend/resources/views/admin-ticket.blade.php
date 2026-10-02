@extends('layout')
@section('content')
@include('admin-nav')
<p><a href="{{ route('admin.tickets') }}">← Tiket CS</a></p><h1>{{ $ticket->subject }}</h1>
<p class="muted">#{{ $ticket->id }} · @if($ticket->business)<a href="{{ route('admin.business', $ticket->business) }}">{{ $ticket->business->name }}</a>@else Tanpa usaha @endif · {{ $ticket->user?->name }} ({{ $ticket->user?->email }}) · {{ \App\Models\Ticket::CATEGORIES[$ticket->category] ?? $ticket->category }} · sumber {{ $ticket->source }}</p>
<section class="card thread">
@foreach($messages as $m)<div @class(['msg', 'mine' => $m->author_type !== 'customer', 'note' => $m->internal])><small>{{ $m->internal ? 'Catatan internal · ' : '' }}{{ $m->author?->name ?? strtoupper($m->author_type) }} · {{ $m->created_at->timezone('Asia/Jakarta')->format('d M H:i') }}</small><p>{{ $m->body }}</p></div>@endforeach
</section>
<section class="card"><form method="post" action="{{ route('admin.ticket.reply', $ticket) }}">@csrf<label for="a-body">Balasan</label><textarea id="a-body" name="body" rows="4" required maxlength="5000"></textarea>
<div class="filters"><label class="check"><input type="checkbox" name="internal" value="1"> Catatan internal (tidak terlihat klien)</label><label class="check"><input type="checkbox" name="close" value="1"> Tandai selesai</label></div>
<p><button>Kirim</button></p></form></section>
<section class="card"><h2>Status</h2><form class="filters" method="post" action="{{ route('admin.ticket.update', $ticket) }}">@csrf
<select name="status" aria-label="Status">@foreach(\App\Models\Ticket::STATUSES as $k => $v)<option value="{{ $k }}" @selected($ticket->status === $k)>{{ $v }}</option>@endforeach</select>
<select name="priority" aria-label="Prioritas"><option value="normal" @selected($ticket->priority === 'normal')>Normal</option><option value="high" @selected($ticket->priority === 'high')>Prioritas tinggi</option></select>
<button class="secondary">Simpan</button></form></section>
@endsection
