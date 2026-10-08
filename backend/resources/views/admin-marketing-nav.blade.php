<nav class="adminnav" aria-label="Menu marketing">
@foreach(['admin.marketing' => 'Calon client', 'admin.marketing.clients' => 'Client', 'admin.campaigns' => 'Kampanye & blast'] as $r => $label)
<a href="{{ route($r) }}" @class(['on' => request()->routeIs($r) || ($r === 'admin.marketing' && request()->routeIs('admin.prospect')) || ($r === 'admin.campaigns' && request()->routeIs('admin.campaign'))])>{{ $label }}</a>
@endforeach
</nav>
