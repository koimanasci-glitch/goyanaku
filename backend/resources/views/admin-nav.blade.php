<nav class="adminnav" aria-label="Menu administrator">
@foreach(['admin.index' => 'Usaha', 'admin.tickets' => 'Tiket CS', 'admin.settings' => 'Pengaturan', 'admin.audit' => 'Audit', 'admin.system' => 'Sistem'] as $r => $label)
<a href="{{ route($r) }}" @class(['on' => request()->routeIs($r) || ($r === 'admin.index' && request()->routeIs('admin.business')) || ($r === 'admin.tickets' && request()->routeIs('admin.ticket'))]) @if(request()->routeIs($r)) aria-current="page" @endif>{{ $label }}</a>
@endforeach
</nav>
