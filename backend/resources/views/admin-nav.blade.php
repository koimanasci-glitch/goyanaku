<nav class="adminnav" aria-label="Menu administrator">
@foreach(['admin.index' => 'Usaha', 'admin.audit' => 'Audit', 'admin.system' => 'Sistem'] as $r => $label)
<a href="{{ route($r) }}" @class(['on' => request()->routeIs($r) || ($r === 'admin.index' && request()->routeIs('admin.business'))]) @if(request()->routeIs($r)) aria-current="page" @endif>{{ $label }}</a>
@endforeach
</nav>
