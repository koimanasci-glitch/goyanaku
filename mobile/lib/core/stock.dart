// Stok bahan & kurir — format sama dengan HTML ("goyana-stock181", "goyana-couriers181").

import 'dart:convert';

import 'models.dart';
import 'store.dart';

class StockBook {
  StockBook._(this.store, this.raw);
  static const key = 'goyana-stock181';
  final KvStore store;
  final Map<String, dynamic> raw;

  static Future<StockBook> load(KvStore store) async {
    Map<String, dynamic> raw = {};
    try {
      final v = jsonDecode(await store.get(key) ?? '{}');
      if (v is Map) raw = Map<String, dynamic>.from(v);
    } catch (_) {}
    for (final k in ['items', 'ledger', 'suppliers', 'purchases']) {
      if (raw[k] is! List) raw[k] = <dynamic>[];
    }
    return StockBook._(store, raw);
  }

  List<Map<String, dynamic>> get items => (raw['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  List<dynamic> get _ledger => raw['ledger'] as List;

  double balance(String itemId, String outletId) => _ledger
      .whereType<Map>()
      .where((x) => x['itemId'] == itemId && '${x['outletId']}' == outletId)
      .fold<double>(0, (a, x) => a + ((x['qty'] as num?)?.toDouble() ?? double.tryParse('${x['qty']}') ?? 0));

  void _led(Map<String, dynamic> x, DateTime now) =>
      _ledger.add({'id': 'mut-${now.microsecondsSinceEpoch}-${_ledger.length}', 'at': isoString(now), ...x});

  String? addItem({required String name, required String unit, required double min, required int cost, required double initial, required String outletId, required DateTime now}) {
    if (name.trim().isEmpty || unit.trim().isEmpty) return 'Isi nama dan satuan bahan';
    final id = 'bahan-${now.microsecondsSinceEpoch}';
    (raw['items'] as List).add({'id': id, 'name': name.trim(), 'unit': unit.trim(), 'min': min, 'cost': cost});
    if (initial > 0) _led({'itemId': id, 'outletId': outletId, 'type': 'Stok Awal', 'qty': initial, 'note': 'Stok awal'}, now);
    return null;
  }

  /// Stok masuk (qty > 0) atau pemakaian (qty < 0). Pemakaian tidak boleh melebihi saldo.
  String? move({required String itemId, required double qty, required String outletId, String note = '', required DateTime now}) {
    if (qty == 0) return 'Isi jumlah';
    if (qty < 0 && balance(itemId, outletId) + qty < 0) return 'Stok tidak cukup';
    _led({'itemId': itemId, 'outletId': outletId, 'type': qty > 0 ? 'Stok Masuk' : 'Pemakaian', 'qty': qty, 'note': note}, now);
    return null;
  }

  /// Stock opname: selisih dicatat sebagai penyesuaian (tidak menimpa angka lama).
  void opname({required String itemId, required double physical, required String outletId, String note = '', required DateTime now}) {
    final sys = balance(itemId, outletId);
    _led({'itemId': itemId, 'outletId': outletId, 'type': 'Stock Opname', 'qty': physical - sys, 'note': note.isEmpty ? (physical == sys ? 'Stok cocok' : 'Selisih') : note,
      'systemQty': sys, 'physicalQty': physical}, now);
  }

  Future<bool> save() => store.set(key, jsonEncode(raw));
}

class Couriers {
  Couriers._(this.store, this.list);
  static const key = 'goyana-couriers181';
  final KvStore store;
  final List<Map<String, dynamic>> list;

  static Future<Couriers> load(KvStore store) async {
    var list = <Map<String, dynamic>>[];
    try {
      final v = jsonDecode(await store.get(key) ?? '[]');
      if (v is List) list = v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    return Couriers._(store, list);
  }

  String? add(String name, String phone, String outletId, DateTime now) {
    if (name.trim().isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 10) return 'Isi nama dan nomor WA (min. 10 digit)';
    list.add({'id': 'kurir-${now.microsecondsSinceEpoch}', 'name': name.trim(), 'phone': phone.trim(), 'email': '', 'outlets': [outletId], 'active': true});
    return null;
  }

  Future<bool> save() => store.set(key, jsonEncode(list));
}
