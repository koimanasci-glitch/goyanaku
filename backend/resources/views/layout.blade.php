<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Goyana · Sistem Pusat</title>
@if(auth()->check() && auth()->user()->is_platform_admin)
<link rel="manifest" href="/admin.webmanifest"><meta name="theme-color" content="#f0472f">
<link rel="apple-touch-icon" href="/icons/admin-192.png">
@endif
<style>
@font-face{font-family:Poppins;font-weight:400;font-display:swap;src:url(/fonts/Poppins-Regular.ttf) format('truetype')}
@font-face{font-family:Poppins;font-weight:500;font-display:swap;src:url(/fonts/Poppins-Medium.ttf) format('truetype')}
@font-face{font-family:Poppins;font-weight:600 800;font-display:swap;src:url(/fonts/Poppins-SemiBold.ttf) format('truetype')}
:root{color-scheme:light;--coral:#f0472f;--coral2:#ff6b48;--ink:#26313b;--line:#e2e6ea}
*{box-sizing:border-box}body{margin:0;background:#f5f6f8;color:var(--ink);font:15px/1.6 Poppins,system-ui,-apple-system,sans-serif}
header{background:white;border-bottom:1px solid var(--line)}header .bar{max-width:1100px;margin:auto;padding:18px 24px;display:flex;align-items:center;justify-content:space-between;gap:16px}
.brand{font-size:23px;font-weight:750;color:var(--coral);text-decoration:none}main{max-width:1100px;margin:32px auto;padding:0 24px}
.card{padding:24px;background:white;border:1px solid var(--line);border-radius:16px;margin-bottom:20px}.auth{max-width:480px;margin:40px auto}
h1{font-size:26px;margin:0 0 6px}h2{font-size:19px;margin-top:0}.muted{color:#64717e}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}
label{display:block;font-weight:600;margin:14px 0 6px}input,select,textarea{font:inherit;width:100%;border:1px solid #cad1d8;border-radius:9px;padding:10px;background:white}button,.button{font:inherit;cursor:pointer;padding:10px 17px;border:0;border-radius:9px;background:var(--coral);color:white;text-decoration:none;display:inline-block}button.secondary{background:#edf0f3;color:var(--ink)}form.inline{display:inline}a{color:#c93a22}.notice{padding:14px 18px;background:#fff1e9;border:1px solid #f1d4bd;border-radius:10px;margin-bottom:20px}
table{border-collapse:collapse;width:100%;text-align:left}th,td{border-bottom:1px solid var(--line);padding:12px 8px;vertical-align:top}.table{overflow:auto}ul{padding-left:22px}.row{display:flex;align-items:center;gap:12px;justify-content:space-between}
small{font-size:13px}.badge{background:#f1f3f5;padding:4px 9px;border-radius:7px;display:inline-block}button:disabled{opacity:.5;cursor:default}
.adminnav{display:flex;gap:6px;overflow-x:auto;margin:0 0 22px;padding-bottom:2px}.adminnav a{white-space:nowrap;text-decoration:none;color:var(--ink);background:white;border:1px solid var(--line);border-radius:999px;padding:8px 15px;font-size:14px}.adminnav a.on{background:var(--coral);border-color:var(--coral);color:white}
.app .appbar{background:linear-gradient(100deg,var(--coral2),var(--coral));color:white;padding:18px 20px 34px}.app .appbar .in{max-width:1100px;margin:auto;display:flex;align-items:center;gap:14px}
.app .appbar img{width:46px;height:46px;flex:none}.app .appbar .name{font-size:24px;font-weight:600;line-height:1.1;letter-spacing:.5px}.app .appbar .name small{display:block;font-size:10px;font-weight:400;letter-spacing:2.5px;opacity:.9;white-space:nowrap}
.app .appbar .role{border-left:1px solid rgba(255,255,255,.6);padding-left:14px;font-weight:500;font-size:17px;line-height:1.25;min-width:0}.app .appbar .role small{display:block;font-weight:400;font-size:12.5px;opacity:.95}
.app .appbar .end{margin-left:auto;display:flex;align-items:center;gap:10px}.app .appbar .end a{color:white;display:flex;position:relative}.app .appbar .end .dot{position:absolute;top:0;right:0;width:9px;height:9px;border-radius:50%;background:#ffe14d}
.app .appbar button{background:rgba(255,255,255,.2);color:white;padding:6px 10px;font-size:12px}.app .appbar .role small{white-space:nowrap}
.app main{margin:-18px auto 0;padding:0 16px 96px;position:relative}.app main>.sheet{background:#f5f6f8;border-radius:22px 22px 0 0;padding:18px 0 0}
.tabbar{position:fixed;left:0;right:0;bottom:0;background:white;border-top:1px solid var(--line);z-index:5}.tabbar .in{max-width:640px;margin:auto;display:flex}
.tabbar a{flex:1;display:flex;flex-direction:column;align-items:center;gap:2px;padding:9px 2px 10px;font-size:11.5px;color:#6b7686;text-decoration:none;min-width:0}.tabbar a.on{color:var(--coral);font-weight:500}.tabbar a.on span{border-bottom:2px solid var(--coral)}
.stats{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-bottom:16px}.stat{background:#3b3d42;color:white;border-radius:16px;padding:14px;display:flex;gap:12px;align-items:center;text-decoration:none;min-width:0}
.stat .ic{flex:none;width:46px;height:46px;border-radius:12px;background:rgba(255,255,255,.12);display:flex;align-items:center;justify-content:center}.stat small{display:block;font-size:12.5px;opacity:.9}.stat b{display:block;font-size:26px;line-height:1.15}.stat em{font-style:normal;font-size:12px;color:#67d58b}.stat em i{font-style:normal;color:#d5d8dd}
.tiles{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:16px}.tile{background:white;border:1px solid var(--line);border-radius:14px;padding:14px 6px;text-align:center;text-decoration:none;color:var(--ink);font-size:12.5px;line-height:1.3;min-width:0}
.tile .ic{width:46px;height:46px;border-radius:12px;margin:0 auto 8px;display:flex;align-items:center;justify-content:center}.tile.off{opacity:.45}
.t-orange{background:#fff0e6;color:#f07a1f}.t-red{background:#ffe9e7;color:#e8493f}.t-amber{background:#fff4dc;color:#f29d0b}.t-blue{background:#e6f0ff;color:#2f6fe0}.t-green{background:#e3f7ea;color:#19a35a}.t-violet{background:#efe7ff;color:#7a4be0}.t-gray{background:#eceff3;color:#5c6676}
.rows{list-style:none;margin:0;padding:0}.rows li{display:flex;gap:12px;align-items:center;padding:12px 0;border-top:1px solid var(--line)}.rows li:first-child{border-top:0}.rows .ic{flex:none;width:42px;height:42px;border-radius:11px;display:flex;align-items:center;justify-content:center}
.rows .grow{flex:1;min-width:0}.rows .grow b{font-weight:500;display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.rows .end{text-align:right;font-size:13px;flex:none}.state{display:inline-flex;align-items:center;gap:6px;font-weight:500}.state::before{content:'';width:9px;height:9px;border-radius:50%;background:currentColor}.state.good{color:#19a35a}.state.warn{color:#e08a00}.state.bad{color:#c63a31}
.meter{height:10px;border-radius:99px;background:#e9edf1;overflow:hidden;margin:8px 0 4px}.meter i{display:block;height:100%;border-radius:99px;background:#19a35a}.meter.warn i{background:#e0a100}.meter.fail i{background:#d0362c}
.spark{width:100%;height:90px;display:block}.legend{display:flex;gap:14px;font-size:12px;color:#64717e}.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:5px}
@media(max-width:420px){.tiles{gap:8px}.tile{font-size:11.5px;padding:12px 3px}.stat{padding:12px;gap:10px}.stat .ic{width:40px;height:40px}.stat b{font-size:22px}.app .appbar{padding-left:14px;padding-right:14px}.app .appbar .in{gap:10px}.app .appbar img{width:40px;height:40px}.app .appbar .name{font-size:19px}.app .appbar .name small{font-size:8.5px;letter-spacing:2px}.app .appbar .role{font-size:15px;padding-left:10px}.app .appbar .role small{font-size:11.5px}}
.kpis{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px;margin:18px 0 20px}.kpi{display:block;background:white;border:1px solid var(--line);border-radius:14px;padding:14px 16px;text-decoration:none;color:var(--ink);min-width:0}.kpi small{display:block;color:#64717e;font-size:12px}.kpi b{display:block;font-size:21px;line-height:1.3;overflow-wrap:anywhere}a.kpi:hover,.kpi.on{border-color:var(--coral)}.kpi.on{box-shadow:inset 0 0 0 1px var(--coral)}
.pill{display:inline-block;padding:2px 9px;border-radius:999px;background:#edf0f3;font-size:12px;font-weight:600}.pill.good{background:#e6f4ea;color:#1d6b36}.pill.bad{background:#fde8e6;color:#a3302a}
.filters{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:16px}.filters input,.filters select{width:auto;flex:1 1 180px}.filters label.check{display:flex;gap:6px;align-items:center;margin:0;font-weight:400}.filters label.check input{width:auto;flex:none}
.button.small{padding:7px 13px;font-size:14px}.button.secondary{background:#edf0f3;color:var(--ink)}ul.plain{list-style:none;padding:0;margin:0}ul.plain li{padding:8px 0;border-bottom:1px solid var(--line)}ul.plain li:last-child{border:0}h3{font-size:16px;margin:18px 0 6px}
code.details{font-size:12px;color:#55606b;overflow-wrap:anywhere;white-space:normal}.row h2{margin:0}
.checks{list-style:none;padding:0;margin:0}.checks li{display:flex;gap:12px;align-items:flex-start;padding:12px 0;border-bottom:1px solid var(--line)}.checks li:last-child{border:0}.checks small{display:block;color:#64717e;overflow-wrap:anywhere}.checks .dot{flex:none;width:12px;height:12px;border-radius:50%;margin-top:7px;background:#2f9e55}.checks .warn .dot{background:#e0a100}.checks .fail .dot{background:#d0362c}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
.adminnav.sub a{font-size:13px;padding:6px 12px}label.check{display:flex;gap:8px;align-items:center;font-weight:400;margin:8px 0}label.check input{width:auto}
.thread{display:flex;flex-direction:column;gap:12px}.msg{max-width:85%;background:#f1f3f5;border-radius:14px;padding:10px 14px}.msg.mine{align-self:flex-end;background:#fdeceb}.msg.note{background:#fff7d6;border:1px dashed #e0b400}.msg small{color:#64717e;font-size:12px}.msg p{margin:4px 0 0;white-space:pre-wrap;overflow-wrap:anywhere}
@media(max-width:600px){.list table,.list tbody,.list tr,.list td{display:block;width:100%}.list thead{display:none}.list tr{border-bottom:1px solid var(--line);padding:10px 0}.list td{border:0;padding:3px 0}.list td[data-label]::before{content:attr(data-label);display:block;font-size:12px;color:#64717e}.kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.kpi b{font-size:18px}.filters input,.filters select,.filters button,.filters .button{flex:1 1 100%;text-align:center}.team table,.team tbody,.team tr,.team td{display:block;width:100%}.team thead{display:none}.team tr{border-bottom:1px solid var(--line);padding:12px 0}.team td{border:0;padding:4px 0}.team select{margin-bottom:6px}header .bar,main{padding-left:16px;padding-right:16px}.card{padding:18px}h1{font-size:23px}.row{align-items:flex-start;flex-wrap:wrap}}
</style></head>
@php($adminApp = auth()->check() && auth()->user()->is_platform_admin && request()->routeIs('admin.*') && !request()->routeIs('admin.mfa*'))
<body @class(['app' => $adminApp])>
@if($adminApp)
@php($me = auth()->user())
<header class="appbar"><div class="in"><img src="/icons/mark.svg" alt=""><div class="name">GOYANA<small>KASIR LAUNDRY</small></div>
<div class="role">Administrator<small>Management Client</small></div>
<div class="end">@if($me->adminCan('support'))<a href="{{ route('admin.tickets') }}" aria-label="Tiket bantuan">@include('admin-icon', ['icon' => 'bell', 'size' => 26])</a>@endif
<form class="inline" method="post" action="{{ route('logout') }}">@csrf<button>Keluar</button></form></div></div></header>
<main><div class="sheet">
@else
<header><div class="bar"><a class="brand" href="{{ url('/') }}">Goyana</a>@auth<div><span>{{ auth()->user()->name }}</span> <form class="inline" method="post" action="{{ route('logout') }}">@csrf<button class="secondary">Keluar</button></form></div>@endauth</div></header>
<main>
@endif
@if(session('status'))<div class="notice" role="status">{{ session('status') }}</div>@endif
@if($errors->any())<div class="notice" role="alert"><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
@yield('content')@if($adminApp)</div>@endif</main>
@if($adminApp)
<nav class="tabbar" aria-label="Menu utama"><div class="in">
@foreach([['admin.index', 'Beranda', 'home', null, ['admin.index']], ['admin.features', 'Fitur', 'grid', null, ['admin.features']], ['admin.reports', 'Laporan', 'chart', 'reports', ['admin.reports']],
    ['admin.clients', 'Administrator', 'people', 'clients', ['admin.clients', 'admin.business', 'admin.assist', 'admin.client.new']], ['admin.settings', 'Seting', 'gear', 'settings', ['admin.settings']]] as [$r, $label, $icon, $area, $match])
@if(!$area || $me->adminCan($area))<a href="{{ route($r) }}" @class(['on' => request()->routeIs(...$match)]) @if(request()->routeIs(...$match)) aria-current="page" @endif>@include('admin-icon', ['icon' => $icon])<span>{{ $label }}</span></a>@endif
@endforeach
</div></nav>
@endif
@if(auth()->check() && auth()->user()->is_platform_admin)
<script>
if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register('/admin-sw.js').catch(() => {});
}
</script>
@endif
</body></html>
