@extends('layout')
@section('content')
<p><a href="{{ route('support') }}">← Bantuan</a></p><h1>{{ $ticket->subject }}</h1>
<p class="muted">#{{ $ticket->id }} · {{ \App\Models\Ticket::CATEGORIES[$ticket->category] ?? $ticket->category }} · <span class="pill">{{ \App\Models\Ticket::STATUSES[$ticket->status] }}</span></p>
<section class="card thread">
@foreach($messages as $m)<div @class(['msg', 'mine' => $m->author_type === 'customer'])><small>{{ $m->author_type === 'customer' ? ($m->author?->name ?? 'Anda') : 'CS GOYANA' }} · {{ $m->created_at->timezone('Asia/Jakarta')->format('d M H:i') }}</small><p>{{ $m->body }}</p></div>@endforeach
</section>
<section class="card"><form method="post" action="{{ route('support.reply', $ticket) }}">@csrf<label for="r-body">Balas</label><textarea id="r-body" name="body" rows="4" required maxlength="5000"></textarea><p><button>Kirim</button></p></form></section>
@endsection
