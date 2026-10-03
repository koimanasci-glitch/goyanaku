// Pengaturan aplikasi mode murni (struk, printer, rekening, QRIS) — satu kunci JSON di database HP.

import 'dart:convert';

import 'receipt.dart';
import 'store.dart';

class AppSettings {
  AppSettings._(this.store, this.raw, this.qrisText, this.perfumes);

  static const key = 'goyana-pure-settings';
  final KvStore store;
  final Map<String, dynamic> raw;
  String qrisText;
  List<List<String>> perfumes; // [nama, warna css]

  static Future<AppSettings> load(KvStore store) async {
    Map<String, dynamic> raw = {};
    try {
      final v = jsonDecode(await store.get(key) ?? '{}');
      if (v is Map) raw = Map<String, dynamic>.from(v);
    } catch (_) {}
    var perfumes = <List<String>>[];
    try {
      final v = jsonDecode(await store.get(Keys.perfumes) ?? '[]');
      if (v is List) perfumes = v.whereType<List>().map((e) => e.map((x) => '$x').toList()).where((e) => e.isNotEmpty).toList();
    } catch (_) {}
    if (perfumes.isEmpty) {
      perfumes = [['Akasia', 'rgb(233, 185, 73)'], ['Junjung Buih', 'rgb(90, 169, 230)'], ['Lavender', 'rgb(155, 122, 224)'], ['Ocean', 'rgb(43, 179, 163)'], ['Sakura', 'rgb(240, 122, 160)']];
    }
    return AppSettings._(store, raw, await store.get(Keys.qrisText) ?? '', perfumes);
  }

  ReceiptSettings get receipt => ReceiptSettings.fromJson(raw['receipt'] is Map ? Map<String, dynamic>.from(raw['receipt'] as Map) : const {});
  set receipt(ReceiptSettings r) => raw['receipt'] = r.toJson();

  String get bank => '${raw['bank'] ?? ''}';
  String get account => '${raw['account'] ?? ''}';
  String get holder => '${raw['holder'] ?? ''}';
  void setBank(String bank, String account, String holder) => raw..['bank'] = bank..['account'] = account..['holder'] = holder;

  String get printerAddress => '${raw['printer'] ?? ''}';
  String get printerName => '${raw['printerName'] ?? ''}';
  void setPrinter(String address, String name) => raw..['printer'] = address..['printerName'] = name;

  Future<void> save() async {
    await store.set(key, jsonEncode(raw));
    await store.set(Keys.qrisText, qrisText);
    await store.set(Keys.perfumes, jsonEncode(perfumes));
  }
}
