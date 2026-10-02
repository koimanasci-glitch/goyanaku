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
@media(max-width:600px){.team table,.team tbody,.team tr,.team td{display:block;width:100%}.team thead{display:none}.team tr{border-bottom:1px solid var(--line);padding:12px 0}.team td{border:0;padding:4px 0}.team select{margin-bottom:6px}header .bar,main{padding-left:16px;padding-right:16px}.card{padding:18px}h1{font-size:23px}.row{align-items:flex-start;flex-wrap:wrap}}
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
