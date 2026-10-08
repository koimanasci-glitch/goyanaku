@extends('layout')
@section('content')
<p><a href="{{ route('admin.campaigns') }}">← Kampanye</a></p>
<h1>{{ $c->name }}</h1><p class="muted">{{ $c->audience === 'clients' ? 'Client' : 'Calon client' }} · {{ ['draft' => 'Draf', 'running' => 'Berjalan', 'paused' => 'Dijeda', 'done' => 'Selesai'][$c->status] ?? $c->status }}</p>
<div class="kpis">@foreach([['Antre', $tally['queued'] ?? 0], ['Terkirim', ($tally['sent'] ?? 0) + ($tally['manual'] ?? 0)], ['Dilewati', $tally['skipped'] ?? 0], ['Gagal', $tally['failed'] ?? 0]] as [$label, $n])<div class="kpi"><small>{{ $label }}</small><b>{{ $n }}</b></div>@endforeach</div>
@unless($connected)<div class="notice">Gateway WhatsApp belum tersambung: pengiriman otomatis belum berjalan. Pakai tombol "WhatsApp" pada tiap baris, lalu "Tandai terkirim".</div>@endunless
<section class="card"><div class="row"><h2>Kendali</h2><span>
@if($c->status === 'draft' || $c->status === 'paused')<form class="inline" method="post" action="{{ route('admin.campaign.status', $c->id) }}">@csrf<input type="hidden" name="status" value="running"><button>{{ $c->status === 'draft' ? 'Mulai kampanye' : 'Lanjutkan' }}</button></form>@endif
@if($c->status === 'running')<form class="inline" method="post" action="{{ route('admin.campaign.status', $c->id) }}">@csrf<input type="hidden" name="status" value="paused"><button class="secondary">Jeda</button></form>@endif
@if($c->status !== 'done')<form class="inline" method="post" action="{{ route('admin.campaign.status', $c->id) }}">@csrf<input type="hidden" name="status" value="done"><button class="secondary">Hentikan</button></form>@endif</span></div>
<h3>Kalimat pembuka</h3><ul>@foreach((array) json_decode($c->variants, true) as $v)<li>{{ $v }}</li>@endforeach</ul>
@if(array_filter((array) json_decode((string) $c->followups, true)))<h3>Tindak lanjut</h3><ul>@foreach((array) json_decode($c->followups, true) as $v)<li>{{ $v }}</li>@endforeach</ul>@endif</section>
<section class="card"><h2>Pesan</h2><div class="table list"><table><thead><tr><th>Kepada</th><th>Pesan</th><th>Status</th><th></th></tr></thead><tbody>
@forelse($messages as $m)<tr><td><b>{{ $m->name }}</b><br><small class="muted">+{{ $m->phone }} · {{ $m->kind === 'followup' ? 'tindak lanjut' : 'pembuka' }}</small></td>
<td data-label="Pesan"><small>{{ $m->body }}</small></td>
<td data-label="Status"><span @class(['pill', 'good' => in_array($m->status, ['sent', 'manual']), 'bad' => $m->status === 'failed'])>{{ ['queued' => 'Antre', 'sent' => 'Terkirim', 'manual' => 'Terkirim manual', 'failed' => 'Gagal', 'skipped' => 'Dilewati'][$m->status] ?? $m->status }}</span>
@if($m->error)<br><small class="muted">{{ $m->error }}</small>@elseif($m->sent_at)<br><small class="muted">{{ \Carbon\Carbon::parse($m->sent_at)->timezone('Asia/Jakarta')->format('d M H:i') }}</small>@elseif($m->not_before)<br><small class="muted">mulai {{ \Carbon\Carbon::parse($m->not_before)->timezone('Asia/Jakarta')->format('d M') }}</small>@endif</td>
<td>@if($m->status === 'queued')<a class="button small secondary" href="https://wa.me/{{ $m->phone }}?text={{ rawurlencode($m->body) }}" target="_blank" rel="noopener">WhatsApp</a>
<form method="post" action="{{ route('admin.message.sent', $m->id) }}">@csrf<button class="secondary">Tandai terkirim</button></form>@endif</td></tr>
@empty<tr><td colspan="4" class="muted">Tidak ada pesan. Sasaran kampanye ini kosong atau semuanya dilewati.</td></tr>@endforelse</tbody></table></div>{{ $messages->links() }}</section>
@endsection
