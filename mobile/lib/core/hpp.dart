// HPP bahan (HTML v182): resep per layanan, pemakaian otomatis saat pesanan mulai diproduksi,
// pengembalian bila pesanan kembali ke Antrian/Penjemputan sebelum pernah diproduksi,
// dan pembelian lunas yang ikut tercatat sebagai pengeluaran kas.

import 'business.dart';
import 'models.dart';
import 'stock.dart';

const _prod = {'cuci', 'kering', 'setrika', 'packing', 'selesaiproses', 'siap', 'telat', 'diantar', 'diambil'};
const _prodHist = {'cuci', 'kering', 'setrika', 'packing', 'selesaiproses', 'siap', 'diantar', 'diambil'};

List<Map> _ledger(StockBook s) => (s.raw['ledger'] as List).whereType<Map>().toList();
List<Map> hppRecipes(StockBook s) => ((s.raw['recipes'] ??= <dynamic>[]) as List).whereType<Map>().toList();

double _n(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;

List<Map> _activeUses(StockBook s, String id) {
  final l = _ledger(s);
  final reversed = {for (final x in l) if (x['orderId'] == id && x['type'] == 'Pembatalan HPP' && x['reversalOf'] != null) x['reversalOf']};
  return [for (final x in l) if (x['orderId'] == id && x['type'] == 'Pemakaian Otomatis' && !reversed.contains(x['id'])) x];
}

/// Simpan / perbarui resep. Mengembalikan pesan salah atau null.
String? saveRecipe(StockBook s, {required String service, required String itemId, required double qty, required DateTime now}) {
  final sv = service.trim();
  if (sv.isEmpty || !s.items.any((i) => i['id'] == itemId) || !qty.isFinite || qty <= 0) return 'Isi layanan, bahan, dan takaran';
  final list = (s.raw['recipes'] ??= <dynamic>[]) as List;
  final r = list.whereType<Map>().where((x) => '${x['service']}'.toLowerCase() == sv.toLowerCase() && x['itemId'] == itemId).firstOrNull;
  final q = qty == qty.roundToDouble() ? qty.round() : qty;
  if (r != null) {
    r['qty'] = q;
  } else {
    list.add({'id': 'resep-${now.microsecondsSinceEpoch}', 'service': sv, 'itemId': itemId, 'qty': q});
  }
  return null;
}

class HppResult {
  const HppResult({this.stock = false, this.orders = false, this.consumed = 0, this.reversed = false});
  final bool stock, orders, reversed;
  final int consumed;
}

/// Cocokkan pemakaian bahan dengan status tiap pesanan (HTML reconcileHpp).
HppResult reconcileHpp(Business b, StockBook s, DateTime now) {
  var stock = false, orders = false, consumed = 0, reversedAny = false;
  final recipes = hppRecipes(s);
  final ledger = s.raw['ledger'] as List;
  var seq = 0;
  String uid() => 'mut-${now.microsecondsSinceEpoch}-${ledger.length}-${seq++}';
  final at = now.toUtc().toIso8601String();
  for (final o in b.orders) {
    final st = o.status, flag = '${o.dataset['hpp182'] ?? ''}';
    final outlet = o.outlet.isNotEmpty ? o.outlet : (b.activeOutlet.isNotEmpty ? b.activeOutlet : (b.outlets.firstOrNull?.id ?? 'default'));
    if (st == 'batal') continue; // bahan yang sudah terpakai tetap terpakai
    if ((st == 'jemput' || st == 'antrian') && flag == '1' && !o.history.any((h) => _prodHist.contains('${h['st']}'))) {
      final uses = _activeUses(s, o.id);
      for (final x in uses) {
        ledger.add({
          'id': uid(), 'itemId': x['itemId'], 'outletId': x['outletId'] ?? outlet, 'type': 'Pembatalan HPP', 'qty': _n(x['qty']).abs(), 'cost': _n(x['cost']),
          'note': 'Pembatalan order ${o.id}', 'orderId': o.id, 'reversalOf': x['id'], 'at': at,
        });
        stock = true;
        reversedAny = true;
      }
      o.dataset['hpp182'] = 'reversed';
      orders = true;
    } else if (_prod.contains(st) && flag != '1') {
      if (_activeUses(s, o.id).isNotEmpty) {
        o.dataset['hpp182'] = '1';
        orders = true;
        continue;
      }
      var n = 0;
      for (final OrderItem it in o.items) {
        final service = it.name.replaceFirst(RegExp(r'\s*\(.*?\)\s*$'), '').trim().toLowerCase();
        for (final r in recipes) {
          if ('${r['service']}'.trim().toLowerCase() != service) continue;
          final q = _n(r['qty']) * it.qty;
          if (q <= 0) continue;
          final mat = s.items.where((i) => i['id'] == r['itemId']).firstOrNull;
          ledger.add({
            'id': uid(), 'itemId': r['itemId'], 'outletId': outlet, 'type': 'Pemakaian Otomatis', 'qty': -q, 'cost': _n(mat?['cost']),
            'note': 'Order ${o.id}', 'orderId': o.id, 'at': at,
          });
          n++;
        }
      }
      if (n > 0) {
        o.dataset['hpp182'] = '1';
        stock = true;
        orders = true;
        consumed += n;
      }
    }
  }
  return HppResult(stock: stock, orders: orders, consumed: consumed, reversed: reversedAny);
}

/// Pembelian bahan yang sudah lunas dicatat sekali sebagai pengeluaran kas "Bahan Baku · nama".
bool syncPurchaseCash(Business b, StockBook s, DateTime now) {
  var changed = false;
  final outs = b.kas.putIfAbsent('outs', () => <dynamic>[]) as List;
  for (final p in (s.raw['purchases'] as List).whereType<Map>()) {
    if (_n(p['paid']) < _n(p['total']) || p['cashRecorded182'] == true) continue;
    final item = s.items.where((i) => i['id'] == p['itemId']).firstOrNull;
    if (!outs.whereType<Map>().any((x) => x['purchase182'] == p['id'])) {
      final m = '${p['payMethod'] ?? 'Tunai'}';
      outs.add({
        'm': m == 'Tunai' ? 'Tunai' : 'Non-Tunai', 'actualMethod178': m, 't': 'Bahan Baku · ${item?['name'] ?? 'Pembelian'}', 'a': _n(p['total']).round(), 'n': '',
        'at': '${p['paidAt'] ?? p['at'] ?? now.toUtc().toIso8601String()}', 'purchase182': p['id'],
      });
    }
    p['cashRecorded182'] = true;
    changed = true;
  }
  return changed;
}

double _cost(Map x) => -_n(x['qty']) * _n(x['cost']);

Iterable<Map> _hppEntries(StockBook s, DateTime from, DateTime to) => _ledger(s).where((x) {
      final d = DateTime.tryParse('${x['at']}');
      return d != null && !d.isBefore(from) && d.isBefore(to) && (x['type'] == 'Pemakaian Otomatis' || x['type'] == 'Pembatalan HPP');
    });

/// Total HPP bahan pada rentang waktu.
double hppTotal(StockBook s, DateTime from, DateTime to) => _hppEntries(s, from, to).fold<double>(0, (a, x) => a + _cost(x));

/// Baris laporan "HPP Bahan Terpakai": [nama, satuan, jumlah bersih, biaya].
List<List<Object>> hppRows(StockBook s, DateTime from, DateTime to) {
  final rows = <String, List<Object>>{};
  for (final x in _hppEntries(s, from, to)) {
    final item = s.items.where((i) => i['id'] == x['itemId']).firstOrNull;
    final z = rows.putIfAbsent('${x['itemId']}', () => ['${item?['name'] ?? 'Bahan'}', '${item?['unit'] ?? ''}', 0.0, 0.0]);
    z[2] = (z[2] as double) - _n(x['qty']);
    z[3] = (z[3] as double) + _cost(x);
  }
  return [for (final z in rows.values) if ((z[2] as double).abs() > 1e-9 || (z[3] as double).abs() > 1e-9) z];
}
