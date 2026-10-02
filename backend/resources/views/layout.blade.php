<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Goyana · Sistem Pusat</title>
@if(auth()->check() && auth()->user()->is_platform_admin)
<link rel="manifest" href="/admin.webmanifest"><meta name="theme-color" content="#db544b">
<link rel="apple-touch-icon" href="/icons/admin-192.png">
@endif
<style>
:root{color-scheme:light;--coral:#db544b;--ink:#26313b;--line:#e2e6ea}
*{box-sizing:border-box}body{margin:0;background:#f5f6f8;color:var(--ink);font:15px/1.6 system-ui,-apple-system,sans-serif}
header{background:white;border-bottom:1px solid var(--line)}header .bar{max-width:1100px;margin:auto;padding:18px 24px;display:flex;align-items:center;justify-content:space-between;gap:16px}
.brand{font-size:23px;font-weight:750;color:var(--coral);text-decoration:none}main{max-width:1100px;margin:32px auto;padding:0 24px}
.card{padding:24px;background:white;border:1px solid var(--line);border-radius:16px;margin-bottom:20px}.auth{max-width:480px;margin:40px auto}
h1{font-size:26px;margin:0 0 6px}h2{font-size:19px;margin-top:0}.muted{color:#64717e}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}
label{display:block;font-weight:600;margin:14px 0 6px}input,select,textarea{font:inherit;width:100%;border:1px solid #cad1d8;border-radius:9px;padding:10px;background:white}button,.button{font:inherit;cursor:pointer;padding:10px 17px;border:0;border-radius:9px;background:var(--coral);color:white;text-decoration:none;display:inline-block}button.secondary{background:#edf0f3;color:var(--ink)}form.inline{display:inline}a{color:#b73e37}.notice{padding:14px 18px;background:#fff1e9;border:1px solid #f1d4bd;border-radius:10px;margin-bottom:20px}
table{border-collapse:collapse;width:100%;text-align:left}th,td{border-bottom:1px solid var(--line);padding:12px 8px;vertical-align:top}.table{overflow:auto}ul{padding-left:22px}.row{display:flex;align-items:center;gap:12px;justify-content:space-between}
small{font-size:13px}.badge{background:#f1f3f5;padding:4px 9px;border-radius:7px;display:inline-block}button:disabled{opacity:.5;cursor:default}
.adminnav{display:flex;gap:6px;overflow-x:auto;margin:0 0 22px;padding-bottom:2px}.adminnav a{white-space:nowrap;text-decoration:none;color:var(--ink);background:white;border:1px solid var(--line);border-radius:999px;padding:8px 15px;font-size:14px}.adminnav a.on{background:var(--coral);border-color:var(--coral);color:white}
.kpis{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px;margin:18px 0 20px}.kpi{display:block;background:white;border:1px solid var(--line);border-radius:14px;padding:14px 16px;text-decoration:none;color:var(--ink);min-width:0}.kpi small{display:block;color:#64717e;font-size:12px}.kpi b{display:block;font-size:21px;line-height:1.3;overflow-wrap:anywhere}a.kpi:hover,.kpi.on{border-color:var(--coral)}.kpi.on{box-shadow:inset 0 0 0 1px var(--coral)}
.pill{display:inline-block;padding:2px 9px;border-radius:999px;background:#edf0f3;font-size:12px;font-weight:600}.pill.good{background:#e6f4ea;color:#1d6b36}.pill.bad{background:#fde8e6;color:#a3302a}
.filters{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:16px}.filters input,.filters select{width:auto;flex:1 1 180px}.filters label.check{display:flex;gap:6px;align-items:center;margin:0;font-weight:400}.filters label.check input{width:auto;flex:none}
.button.small{padding:7px 13px;font-size:14px}.button.secondary{background:#edf0f3;color:var(--ink)}ul.plain{list-style:none;padding:0;margin:0}ul.plain li{padding:8px 0;border-bottom:1px solid var(--line)}ul.plain li:last-child{border:0}h3{font-size:16px;margin:18px 0 6px}
code.details{font-size:12px;color:#55606b;overflow-wrap:anywhere;white-space:normal}.row h2{margin:0}
.checks{list-style:none;padding:0;margin:0}.checks li{display:flex;gap:12px;align-items:flex-start;padding:12px 0;border-bottom:1px solid var(--line)}.checks li:last-child{border:0}.checks small{display:block;color:#64717e;overflow-wrap:anywhere}.checks .dot{flex:none;width:12px;height:12px;border-radius:50%;margin-top:7px;background:#2f9e55}.checks .warn .dot{background:#e0a100}.checks .fail .dot{background:#d0362c}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
.adminnav.sub a{font-size:13px;padding:6px 12px}label.check{display:flex;gap:8px;align-items:center;font-weight:400;margin:8px 0}label.check input{width:auto}
.thread{display:flex;flex-direction:column;gap:12px}.msg{max-width:85%;background:#f1f3f5;border-radius:14px;padding:10px 14px}.msg.mine{align-self:flex-end;background:#fdeceb}.msg.note{background:#fff7d6;border:1px dashed #e0b400}.msg small{color:#64717e;font-size:12px}.msg p{margin:4px 0 0;white-space:pre-wrap;overflow-wrap:anywhere}
@media(max-width:600px){.list table,.list tbody,.list tr,.list td{display:block;width:100%}.list thead{display:none}.list tr{border-bottom:1px solid var(--line);padding:10px 0}.list td{border:0;padding:3px 0}.list td[data-label]::before{content:attr(data-label);display:block;font-size:12px;color:#64717e}.kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.kpi b{font-size:18px}.filters input,.filters select,.filters button,.filters .button{flex:1 1 100%;text-align:center}.team table,.team tbody,.team tr,.team td{display:block;width:100%}.team thead{display:none}.team tr{border-bottom:1px solid var(--line);padding:12px 0}.team td{border:0;padding:4px 0}.team select{margin-bottom:6px}header .bar,main{padding-left:16px;padding-right:16px}.card{padding:18px}h1{font-size:23px}.row{align-items:flex-start;flex-wrap:wrap}}
</style></head><body>
<header><div class="bar"><a class="brand" href="{{ url('/') }}">Goyana</a>@auth<div><span>{{ auth()->user()->name }}</span> <form class="inline" method="post" action="{{ route('logout') }}">@csrf<button class="secondary">Keluar</button></form></div>@endauth</div></header>
<main>@if(session('status'))<div class="notice" role="status">{{ session('status') }}</div>@endif
@if($errors->any())<div class="notice" role="alert"><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
@yield('content')</main>
@if(auth()->check() && auth()->user()->is_platform_admin)
<script>
if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register('/admin-sw.js').catch(() => {});
}
</script>
@endif
</body></html>
