// Tambah Transaksi: aturan v116/v127/v183, tanpa mengubah widget atau penyimpanan pesanan.
import 'dart:convert';
import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';

List<Map<String, dynamic>> _rows(Object? v) => (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
num _num(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
int _round(num n) => (n + .5).floor(); // Math.round, termasuk aturan seri negatif JS.
num _plainNum(num n) => n == n.roundToDouble() ? n.round() : n;

String _quantityText(num value) {
  final cents = _round(value * 100);
  final fraction = (cents.abs() % 100).toString().padLeft(2, '0').replaceFirst(RegExp(r'0+$'), '');
  return '${thousands(cents ~/ 100)}${fraction.isEmpty ? '' : ',$fraction'}';
}

/// Sama dengan input + raw()/bad()/val() HTML (v116 + v199): filter karakter (minus dibiarkan
/// supaya bisa ditolak), lalu hanya angka dengan satu koma/titik yang sah. Selain itu = 0.
String _quantityRaw(String input) => input.replaceAll(RegExp(r'[^0-9.,\-]'), '').replaceAll(RegExp(r'\s'), '');
bool _quantityBad(String raw) => raw.isNotEmpty && !RegExp(r'^(\d+([.,]\d*)?|[.,]\d+)$').hasMatch(raw);

double transactionQuantity(String input) {
  final raw = _quantityRaw(input);
  if (_quantityBad(raw)) return 0;
  final n = double.tryParse(raw.replaceFirst(',', '.')) ?? 0;
  return _round(n * 100) / 100;
}

/// Keputusan Koko 4 Okt: minus dan dua pemisah (contoh -2,5 / 1,2,3) ditolak dengan peringatan.
String? transactionQuantityError(double quantity, String unit, {String? input}) {
  if (input != null) {
    final raw = _quantityRaw(input);
    if (raw.contains('-')) return '${unit == 'kg' ? 'Berat' : 'Jumlah'} tidak boleh minus. Periksa lagi angkanya';
    if (_quantityBad(raw)) return 'Angka tidak sah: "$raw". Pakai satu koma saja, contoh ${unit == 'pcs' ? '2' : '1,3'}';
  }
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

Service _storedCartService(Business business, Map<String, dynamic> item, Map<String, dynamic> draft) {
  final id = '${item['id'] ?? ''}';
  final catalog = _rows(draft['catalog']).expand((c) => _rows(c['items']));
  final source = catalog.where((c) => '${c['id'] ?? ''}' == id).firstOrNull;
  final key = '${source?['key158'] ?? ''}';
  if (key.isNotEmpty) {
    final byKey = business.services.where((s) => s.key == key).firstOrNull;
    if (byKey != null) return byKey;
  }
  final rawName = '${item['name'] ?? item['n'] ?? ''}'.trim();
  final name = rawName.replaceFirst(RegExp(r'\s*\((?:Reguler|Express|Ekspres|Kilat)\)\s*$'), '').trim();
  final unit = '${item['unit'] ?? ''}';
  return business.services.firstWhere((s) => s.name == name && (unit.isEmpty || s.unit == unit));
}

List<Map<String, dynamic>> _pricedCart(Business business, Map<String, dynamic> draft) {
  final duration = '${draft['duration'] ?? 'Reguler'}';
  return [
    for (final old in _rows(draft['cart']))
      {...old, 'price': _storedCartService(business, old, draft).priceFor(duration)},
  ];
}

Map<String, dynamic> _transportDefaults() => <String, dynamic>{
      'mode': 'free', 'fixed': 0, 'pickup': 0, 'delivery': 0,
      'roundtrip': 0, 'perKm': 0, 'freeRadius': 0, 'manual': false,
    };

String _transportType(String handover) {
  final pick = RegExp('jemput', caseSensitive: false).hasMatch(handover);
  final delivery = RegExp('antar|diantar', caseSensitive: false).hasMatch(handover);
  if (pick && delivery) return 'roundtrip';
  if (pick) return 'pickup';
  if (delivery) return 'delivery';
  return 'none';
}

Future<Map<String, dynamic>> _transportConfig(Business business) async {
  final defaults = _transportDefaults();
  try {
    final decoded = jsonDecode(await business.store.get('goyana-transport183') ?? '{}');
    if (decoded is! Map) return defaults;
    var id = business.activeOutlet;
    if (id.isEmpty && business.outlets.isNotEmpty) id = business.outlets.first.id;
    if (id.isEmpty) id = 'default';
    final value = decoded[id];
    if (value is Map) defaults.addAll(Map<String, dynamic>.from(value));
  } catch (_) {}
  return defaults;
}

num _transportFee(String type, Map<String, dynamic> cfg) {
  final mode = '${cfg['mode'] ?? 'free'}';
  if (type == 'none' || mode == 'free') return 0;
  if (mode == 'fixed') return _plainNum(_num(cfg['fixed']).clamp(0, double.infinity));
  if (mode == 'split') {
    if (type == 'pickup') return _plainNum(_num(cfg['pickup']).clamp(0, double.infinity));
    if (type == 'delivery') return _plainNum(_num(cfg['delivery']).clamp(0, double.infinity));
    return _plainNum((_num(cfg['pickup']) + _num(cfg['delivery'])).clamp(0, double.infinity));
  }
  if (mode == 'roundtrip') {
    if (type == 'roundtrip') return _plainNum(_num(cfg['roundtrip']).clamp(0, double.infinity));
    if (type == 'pickup') return _plainNum(_num(cfg['pickup']).clamp(0, double.infinity));
    return _plainNum(_num(cfg['delivery']).clamp(0, double.infinity));
  }
  // v183: mode jarak belum dihitung otomatis pada prototype offline.
  return 0;
}

/// Diskon v127 + ongkir v183. Keputusan Koko 4 Okt: diskon/voucher hanya
/// memotong harga layanan. Ongkir ditambahkan ke total, tetapi tidak pernah
/// masuk ke dasar diskon. Diskon kategori tetap memakai subtotal unitnya.
Future<Map<String, dynamic>> transactionPricingModel(Business business, Map<String, dynamic> draft) async {
  final cart = _pricedCart(business, draft);
  final serviceSubtotal = cart.fold<int>(0, (sum, item) => sum + _round(_num(item['qty']) * _num(item['price'])));
  final handover = '${draft['handover'] ?? ''}';
  final transportType = _transportType(handover);
  final cfg = await _transportConfig(business);
  final fee = _transportFee(transportType, cfg);
  final gross = serviceSubtotal + fee;

  final discountDraft = draft['discount'] is Map ? Map<String, dynamic>.from(draft['discount'] as Map) : <String, dynamic>{};
  final selected = '${discountDraft['value'] ?? ''}';
  Map<String, dynamic>? discount;
  if (selected.isNotEmpty) {
    Map<String, dynamic>? definition;
    if (selected == 'manual') {
      definition = <String, dynamic>{
        'name': 'Manual', 'type': 'n', 'val': _num(discountDraft['manual']), 'scope': 'Semua layanan',
      };
    } else if (selected.startsWith('d')) {
      final id = selected.substring(1);
      definition = _rows(discountDraft['definitions']).where((d) => '${d['id']}' == id).firstOrNull;
    }
    if (definition != null) {
      final scope = '${definition['scope'] ?? 'Semua layanan'}';
      final unit = const {'Kiloan': 'kg', 'Satuan': 'pcs', 'Meteran': 'm'}[scope];
      final base = scope == 'Semua layanan' || cart.isEmpty
          ? serviceSubtotal
          : cart.where((item) => item['unit'] == unit).fold<num>(0, (sum, item) => sum + _round(_num(item['qty']) * _num(item['price'])));
      final value = _num(definition['val']);
      final amount = definition['type'] == 'p' ? _round(base * value / 100) : (value < base ? value : base);
      final cleanAmount = _plainNum(amount.clamp(0, double.infinity));
      if (cleanAmount > 0) {
        discount = <String, dynamic>{
          'amt': cleanAmount,
          'pct': definition['type'] == 'p' && scope == 'Semua layanan' ? _plainNum(value) : 0,
          'name': '${definition['name'] ?? ''}',
        };
      }
    }
  }

  final amount = _num(discount?['amt']);
  final total = (gross - amount).clamp(0, double.infinity);
  return <String, dynamic>{
    'total': rpSpaced(total),
    'discount': discount,
    'transport': <String, dynamic>{'fee': _plainNum(fee), 'type': transportType},
  };
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
