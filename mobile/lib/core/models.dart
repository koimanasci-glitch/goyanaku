// Model data GOYANA di Dart. Data disimpan dengan format yang sama seperti aplikasi HTML
// ("goyana-business177", "goyana-services158", ...), jadi data lama di HP langsung terbaca dan
// kunci yang belum dikenal Dart tetap dipertahankan saat disimpan ulang.

import 'dart:convert';

import 'money.dart';

String _s(Object? v) => v == null ? '' : '$v';
num _n(Object? v) => v is num ? v : (num.tryParse(_s(v)) ?? 0);
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(Object? v) => v is List ? List<dynamic>.from(v) : <dynamic>[];
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(_s(v))?.toLocal();
String _iso(DateTime d) => d.toUtc().toIso8601String().replaceFirstMapped(RegExp(r'\.(\d{3})\d*Z$'), (m) => '.${m.group(1)}Z');

/// Urutan status pesanan (sama dengan FLOW di HTML).
const orderFlow = ['jemput', 'antrian', 'cuci', 'kering', 'setrika', 'packing', 'siap', 'diantar', 'diambil'];
const procStages = ['cuci', 'kering', 'setrika', 'packing'];
const statusLabel = {
  'jemput': 'Penjemputan', 'antrian': 'Antrian', 'cuci': 'Proses · Cuci', 'kering': 'Proses · Kering', 'setrika': 'Proses · Setrika',
  'packing': 'Proses · Packing', 'siap': 'Siap Ambil', 'telat': 'Terlambat', 'diantar': 'Diantar', 'diambil': 'Diambil', 'batal': 'Batal',
};
const nextLabel = {
  'jemput': 'Sudah Dijemput ›', 'antrian': 'Mulai Cuci ›', 'cuci': 'Lanjut Kering ›', 'kering': 'Lanjut Setrika ›', 'setrika': 'Packing ›',
  'packing': 'Tandai Siap ›', 'siap': 'Serahkan ›', 'diantar': 'Diterima ›', 'diambil': 'Selesai ✓', 'batal': 'Dibatalkan',
};

/// Durasi bawaan & lamanya (jam), sama dengan HTML: Kilat 6, Express 24, lainnya 72.
int durationHours(String dur) {
  if (RegExp('Kilat').hasMatch(dur)) return 6;
  if (RegExp('Express|Ekspres').hasMatch(dur)) return 24;
  return 72;
}

class Service {
  Service(this.raw);
  final Map<String, dynamic> raw;
  String get key => _s(raw['key']);
  String get name => _s(raw['name']);
  String get unit => _s(raw['unit']);
  Map<String, int> get prices => _map(raw['prices']).map((k, v) => MapEntry(k, _n(v).round()));
  Map<String, bool> get enabled => _map(raw['enabled']).map((k, v) => MapEntry(k, v == true));
  List<String> get proc => _list(raw['proc']).map(_s).toList();
  int priceFor(String dur) => prices[dur] ?? 0;
  bool enabledFor(String dur) => enabled[dur] ?? prices.containsKey(dur);
  Map<String, dynamic> toJson() => raw;
}

class Customer {
  Customer({required this.name, this.phone = '', this.address = '', this.gender = 'male', this.maps = ''});
  factory Customer.fromJson(Map<String, dynamic> j) =>
      Customer(name: _s(j['name']), phone: _s(j['phone']), address: _s(j['address']), gender: _s(j['gender']).isEmpty ? 'male' : _s(j['gender']), maps: _s(j['maps']));
  String name, phone, address, gender, maps;
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'address': address, 'gender': gender, 'maps': maps};
}

class OrderItem {
  OrderItem({required this.name, this.icon = '', required this.unit, required this.price, required this.qty});
  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(name: _s(j['n'] ?? j['name']), icon: _s(j['ic']), unit: _s(j['unit']), price: _n(j['price']).round(), qty: _n(j['qty']).toDouble());
  String name, icon, unit;
  int price;
  double qty;
  int get subtotal => (qty * price).round();
  Map<String, dynamic> toJson() => {'n': name, 'ic': icon, 'unit': unit, 'price': price, 'qty': qty == qty.roundToDouble() ? qty.round() : qty};
}

class Totals {
  const Totals(this.sub, this.disc, this.total);
  final int sub, disc, total;
}

/// Satu pesanan = kartu daftar (snapshot HTML) + rincian (orderData177).
class Order {
  Order(this.card, this.detail);
  final Map<String, dynamic> card; // {dataset, fields, total, payment, paid, chips}
  final Map<String, dynamic> detail; // {id, name, phone, dur, items, discKey, ongkir, paid, ...}

  Map<String, dynamic> get dataset => card.putIfAbsent('dataset', () => <String, dynamic>{}) as Map<String, dynamic>;
  List<dynamic> get fields => card.putIfAbsent('fields', () => [<dynamic>[], <dynamic>[], <dynamic>[], <dynamic>[], <dynamic>[], <dynamic>[]]) as List<dynamic>;

  String _field(int i, [int j = 0]) {
    final f = fields.length > i ? _list(fields[i]) : const [];
    return f.length > j ? _s(f[j]) : '';
  }

  String get id => _s(detail['id']).isNotEmpty ? _s(detail['id']) : _field(1);
  String get name => _s(detail['name']).isNotEmpty ? _s(detail['name']) : _field(2);
  String get phone => _s(detail['phone']);
  String get dur => _s(detail['dur']).isNotEmpty ? _s(detail['dur']) : _field(0);
  String get status => _s(dataset['st']).isEmpty ? 'antrian' : _s(dataset['st']);
  set status(String v) => dataset['st'] = v;
  bool get antar => _s(dataset['antar']) == '1';
  String get method => _s(dataset['method177']).isEmpty ? 'Tunai' : _s(dataset['method177']);
  String get outlet => _s(dataset['outlet180']);
  DateTime? get created => _date(dataset['created177']) ?? masuk;
  DateTime? get masuk => _date(detail['masuk']);
  DateTime? get due => _date(detail['due']);
  String get perfume => _s(detail['perfume']);
  String get note => _s(detail['note']);
  String get handover => _s(detail['handover']).isEmpty ? 'Datang Langsung' : _s(detail['handover']);
  int get ongkir => _n(detail['ongkir']).round();
  String get discKey => _s(detail['discKey']).isEmpty ? '0' : _s(detail['discKey']);
  int get paid => detail.containsKey('paid') ? _n(detail['paid']).round() : _n(dataset['paid177']).round();
  List<OrderItem> get items {
    var l = _list(detail['items']);
    if (l.isEmpty) {
      try {
        l = _list(_jsonDecodeSafe(_s(dataset['items'])));
      } catch (_) {}
    }
    return l.map((e) => OrderItem.fromJson(_map(e))).toList();
  }

  List<Map<String, dynamic>> get history => _list(detail['hist']).map(_map).toList();
  List<Map<String, dynamic>> get payments {
    try {
      return _list(_jsonDecodeSafe(_s(dataset['payments178']))).map(_map).toList();
    } catch (_) {
      return [];
    }
  }

  Totals get totals => calcTotals(items, discKey, ongkir);
  int get total => totals.total;
  int get remaining => (total - paid).clamp(0, total).toInt();
  bool get isPaid => total > 0 && paid >= total;
  bool get isCancelled => status == 'batal';

  /// Label pembayaran di kartu: "Lunas", "Belum Bayar", "DP Rp5.000".
  String get paymentLabel {
    if (isPaid) return 'Lunas';
    if (paid > 0) return 'DP ${rp(paid)}';
    return 'Belum Bayar';
  }

  bool isLate(DateTime now) {
    final d = due;
    return d != null && now.isAfter(d) && !['siap', 'diantar', 'diambil', 'batal'].contains(status);
  }
}

dynamic _jsonDecodeSafe(String s) {
  if (s.isEmpty) return const [];
  try {
    return jsonDecode(s);
  } catch (_) {
    return const [];
  }
}

/// Diskon: "p10" = 10%, "n5000" = Rp5.000; tidak melebihi subtotal. Total = sub − diskon + ongkir.
Totals calcTotals(List<OrderItem> items, String discKey, int ongkir) {
  final sub = items.fold<int>(0, (a, it) => a + it.subtotal);
  final m = RegExp(r'^([pn])(\d+)$').firstMatch(discKey);
  var disc = 0.0;
  if (m != null) disc = m.group(1) == 'p' ? sub * int.parse(m.group(2)!) / 100 : double.parse(m.group(2)!);
  final d = disc.round().clamp(0, sub).toInt();
  return Totals(sub, d, sub - d + ongkir);
}

String isoString(DateTime d) => _iso(d);

class Outlet {
  Outlet(this.raw);
  final Map<String, dynamic> raw;
  String get id => _s(raw['id']);
  String get name => _s(raw['name']);
  String get address => _s(raw['address']);
  String get phone => _s(raw['phone']);
}
