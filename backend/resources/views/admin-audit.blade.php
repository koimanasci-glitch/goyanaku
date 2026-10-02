@extends('layout')
@section('content')
@include('admin-nav')
<h1>Audit</h1><p class="muted">Semua tindakan penting: paket, pembayaran, perangkat, tim, dan tindakan administrator.</p>
<section class="card"><form class="filters" method="get" action="{{ route('admin.audit') }}">
<select name="action" aria-label="Jenis aktivitas"><option value="">Semua aktivitas</option>@foreach($actions as $a)<option @selected($action === $a)>{{ $a }}</option>@endforeach</select>
<input name="business" inputmode="numeric" value="{{ request('business') }}" placeholder="ID usaha" aria-label="ID usaha">
<label class="check"><input type="checkbox" name="admin" value="1" @checked(request()->boolean('admin'))> Hanya administrator</label>
<button>Saring</button>@if(request()->query())<a class="button secondary" href="{{ route('admin.audit') }}">Reset</a>@endif</form>
<div class="table list"><table><thead><tr><th>Waktu (WIB)</th><th>Aktivitas</th><th>Pelaku</th><th>Usaha</th><th>Rincian</th></tr></thead><tbody>
@forelse($events as $e)<tr><td data-label="Waktu">{{ \Carbon\Carbon::parse($e->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}</td>
<td data-label="Aktivitas"><span class="badge">{{ $e->action }}</span></td>
<td data-label="Pelaku">{{ $e->actor_name ?? '—' }}@if($e->actor_admin) <small class="pill">admin</small>@endif</td>
<td data-label="Usaha">@if($e->business_id)<a href="{{ route('admin.business', $e->business_id) }}">{{ $e->business_name ?? '#'.$e->business_id }}</a>@endif</td>
<td data-label="Rincian"><code class="details">{{ \Illuminate\Support\Str::limit($e->details, 160) }}</code></td></tr>
@empty<tr><td colspan="5">Belum ada aktivitas.</td></tr>@endforelse</tbody></table></div>{{ $events->links() }}</section>
@endsection
