<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>Nota {{ $n['code'] }}</title>
<style>
body{margin:0;background:#f4f1f8;font:14px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#222}
.w{max-width:420px;margin:0 auto;padding:16px}.c{background:#fff;border-radius:14px;padding:18px;box-shadow:0 2px 10px #0000000d}
h1{font-size:17px;margin:0}small,.m{color:#777}.r{display:flex;justify-content:space-between;gap:10px;padding:5px 0}
hr{border:0;border-top:1px dashed #ddd;margin:10px 0}.b{font-weight:700}.chip{display:inline-block;background:#efe6fa;color:#6b2fb3;border-radius:20px;padding:3px 10px;font-size:12px;font-weight:600}
.ok{background:#e3f5ec;color:#21794f}.due{color:#b3412f}
</style></head><body><div class="w"><div class="c">
<h1>{{ $n['business'] }}</h1>
<small>{{ $n['outlet'] }}@if($n['address']) · {{ $n['address'] }}@endif @if($n['phone']) · {{ $n['phone'] }}@endif</small>
<hr>
<div class="r"><span>Nota</span><b>{{ $n['code'] }}</b></div>
@if($n['customer'])<div class="r"><span>Pelanggan</span><span>{{ $n['customer'] }}</span></div>@endif
<div class="r"><span>Masuk</span><span>{{ $n['ordered'] }}</span></div>
<div class="r"><span>Perkiraan selesai</span><span>{{ $n['due'] }}</span></div>
<div class="r"><span>Status</span><span class="chip">{{ $n['status'] }}</span></div>
<hr>
@foreach($n['items'] as $i)
<div class="r"><span>{{ $i['name'] }} <span class="m">· {{ rtrim(rtrim(number_format($i['qty'], 2, ',', '.'), '0'), ',') }} {{ $i['unit'] }}</span></span><span>Rp{{ number_format($i['total'], 0, ',', '.') }}</span></div>
@endforeach
@if($n['discount'])<div class="r"><span>Diskon</span><span>−Rp{{ number_format($n['discount'], 0, ',', '.') }}</span></div>@endif
@if($n['ongkir'])<div class="r"><span>Ongkir</span><span>Rp{{ number_format($n['ongkir'], 0, ',', '.') }}</span></div>@endif
<hr>
<div class="r b"><span>Total</span><span>Rp{{ number_format($n['total'], 0, ',', '.') }}</span></div>
<div class="r"><span>Dibayar</span><span>Rp{{ number_format($n['paid'], 0, ',', '.') }}</span></div>
<div class="r b"><span>Sisa</span>@if($n['left'] > 0)<span class="due">Rp{{ number_format($n['left'], 0, ',', '.') }}</span>@else<span class="chip ok">Lunas</span>@endif</div>
@if($n['delivery'])<p class="m" style="margin:10px 0 0">Pesanan diantar kurir.</p>@endif
</div><p class="m" style="text-align:center;font-size:11px">Nota digital · {{ $n['business'] }}</p></div></body></html>
