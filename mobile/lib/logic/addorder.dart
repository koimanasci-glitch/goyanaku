// Tambah Transaksi: aturan v116, tanpa mengubah widget atau penyimpanan pesanan.
import 'dart:convert';
import '../core/business.dart';
import '../core/money.dart';

List<Map<String, dynamic>> _rows(Object? v) => (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
num _num(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
int _round(num n) => (n + .5).floor(); // Math.round, termasuk aturan seri negatif JS.

String _quantityText(num value) {
  final cents = _round(value * 100);
  final fraction = (cents.abs() % 100).toString().padLeft(2, '0').replaceFirst(RegExp(r'0+$'), '');
  return '${thousands(cents ~/ 100)}${fraction.isEmpty ? '' : ',$fraction'}';
}

/// Sama dengan input + val() v116: filter karakter, ganti koma pertama,
/// parseFloat (awalan angka), lalu bulatkan dua desimal.
double transactionQuantity(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.,]'), '').replaceFirst(',', '.');
  final prefix = RegExp(r'^(?:\d+(?:\.\d*)?|\.\d+)').firstMatch(cleaned)?.group(0);
  final n = double.tryParse(prefix ?? '') ?? 0;
  return _round(n * 100) / 100;
}

String? transactionQuantityError(double quantity, String unit) {
  if (!(quantity > 0)) return 'Isi ${unit == 'kg' ? 'berat' : 'jumlah'} dulu, contoh ${unit == 'pcs' ? '2' : '1,3'}';
  if (unit == 'pcs' && quantity % 1 != 0) return 'Jumlah pcs harus bilangan bulat';
  if (quantity > 999) return 'Jumlah terlalu besar';
  return null;
}

String transactionSubtotal(String input, num price) => rpSpaced(_round(transactionQuantity(input) * price));

Map<String, dynamic> transactionCartTotals(List<Map<String, dynamic>> cart) {
  var total = 0;
  final units = <String, num>{'kg': 0, 'pcs': 0, 'm': 0};
  for (final item in cart) {
    final qty = _num(item['qty']);
    total += _round(qty * _num(item['price']));
    final unit = '${item['unit']}';
    units[unit] = (units[unit] ?? 0) + qty;
  }
  return {'sum': '${_quantityText(units['kg']!)} kg · ${_quantityText(units['pcs']!)} pcs · ${_quantityText(units['m']!)} m', 'total': rpSpaced(total)};
}

num transactionServicePrice(Map<String, dynamic> item, String duration) {
  final prices = item['prices158'];
  if (prices is Map) return _num(prices[duration]);
  final factor = duration == 'Express' ? 1.5 : duration == 'Kilat' ? 2 : 1;
  return _round(_num(item['p']) * factor / 500) * 500;
}

/// Meniru setDur116: properti `n` lama dipertahankan, hanya `name` berubah.
/// Tidak mengubah estimasi selesai (aturan tersebut berada di tahap penyimpanan).
List<Map<String, dynamic>> transactionChangeDuration(List<Map<String, dynamic>> cart, List<Map<String, dynamic>> catalog, String duration) {
  final result = <Map<String, dynamic>>[];
  final items = catalog.expand((c) => _rows(c['items']));
  for (final old in cart) {
    final item = items.firstWhere((i) => i['id'] == old['id']);
    if (duration == 'Kilat' && item['noKilat'] == 1) continue;
    result.add({...old, 'price': transactionServicePrice(item, duration), 'dur': duration, 'name': '${item['n']} ($duration)'});
  }
  return result;
}

num _storedServicePrice(Business business, Map<String, dynamic> item, String duration) {
  final key = '${item['key158'] ?? ''}';
  return business.services.firstWhere((s) => s.key == key).priceFor(duration);
}

/// Pertahankan seluruh teks/ikon/tata letak dari model presentasi. Hanya nilai
/// keranjang & harga dihitung ulang. Harga selalu dibaca dari database HP,
/// sedangkan draft hanya membawa pilihan item/jumlah yang belum tersimpan.
Map<String, dynamic> addorderModel(Business business, Map<String, dynamic> draft, Map<String, dynamic> presentation) {
  final model = jsonDecode(jsonEncode(presentation)) as Map<String, dynamic>;
  if (model['stage'] != 'services') return model;
  final cart = _rows(draft['cart']);
  final duration = '${draft['duration'] ?? 'Reguler'}';
  final catalog = _rows(draft['catalog']).expand((c) => _rows(c['items'])).toList();
  final catalogById = <String, Map<String, dynamic>>{for (final item in catalog) '${item['id']}': item};
  final pricedCart = <Map<String, dynamic>>[
    for (final old in cart)
      {...old, 'price': _storedServicePrice(business, catalogById['${old['id']}']!, duration)},
  ];
  final footer = model['footer'];
  if (footer is Map) footer.addAll(transactionCartTotals(pricedCart));
  final durationRows = _rows(model['durations']);
  final durationRow = durationRows.where((d) => '${d['t']}' == duration).firstOrNull;
  final durationLabel = '${durationRow?['s'] ?? ''}'.trim();
  for (final row in (model['items'] as List? ?? const []).whereType<Map>()) {
    if (row['h'] == 1) continue;
    final item = catalog.firstWhere((i) => i['n'] == row['t']);
    final price = _storedServicePrice(business, item, duration);
    final selected = pricedCart.where((c) => c['id'] == item['id']).firstOrNull;
    final oldText = '${row['s'] ?? ''}';
    final dot = oldText.indexOf('·');
    final suffix = durationLabel.isNotEmpty ? durationLabel : (dot < 0 ? '' : oldText.substring(dot + 1).trim());
    row['s'] = '${rpSpaced(price)} / ${item['unit']}${suffix.isEmpty ? '' : ' · $suffix'}';
    row['on'] = selected != null;
    row['btn'] = selected == null ? 'Pilih' : '${_quantityText(_num(selected['qty']))} ${item['unit']}';
  }
  return model;
}
