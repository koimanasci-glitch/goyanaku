// Antar-Jemput (dl109) + Tarif Transportasi (v183/v184): pengaturan dan hitungan ongkir.
import 'dart:convert';

import '../core/store.dart';

const transportKey = 'goyana-transport183';

/// Isi kunci goyana-transport183: {idOutlet: {mode, fixed, pickup, delivery, roundtrip, perKm, freeRadius, manual}}.
final Map<String, dynamic> transportAll = {};

Future<void> loadTransport(KvStore kv) async {
  transportAll.clear();
  try {
    final v = jsonDecode(await kv.get(transportKey) ?? '{}');
    if (v is Map) transportAll.addAll(Map<String, dynamic>.from(v));
  } catch (_) {}
}

Map<String, dynamic> transportCfg(String outletId) => {
      'mode': 'free', 'fixed': 0, 'pickup': 0, 'delivery': 0, 'roundtrip': 0, 'perKm': 0, 'freeRadius': 0, 'manual': false,
      if (transportAll[outletId.isEmpty ? 'default' : outletId] case final Map m) ...Map<String, dynamic>.from(m),
    };

Future<bool> saveTransport(KvStore kv, String outletId, Map<String, dynamic> cfg) {
  transportAll[outletId.isEmpty ? 'default' : outletId] = cfg;
  return kv.set(transportKey, jsonEncode(transportAll));
}

int _n(Object? v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  return n < 0 ? 0 : n.round();
}

/// none / pickup / delivery / roundtrip dari teks penyerahan.
String transportType(String handover) {
  final pick = RegExp('jemput', caseSensitive: false).hasMatch(handover);
  final delivery = RegExp('antar|diantar', caseSensitive: false).hasMatch(handover);
  if (pick && delivery) return 'roundtrip';
  if (pick) return 'pickup';
  if (delivery) return 'delivery';
  return 'none';
}

/// Ongkir pesanan (sama dengan v183; mode jarak belum ditagih).
int transportFee(String handover, Map<String, dynamic> cfg) {
  final type = transportType(handover), mode = '${cfg['mode'] ?? 'free'}';
  if (type == 'none' || mode == 'free') return 0;
  if (mode == 'fixed') return _n(cfg['fixed']);
  if (mode == 'split') {
    if (type == 'pickup') return _n(cfg['pickup']);
    if (type == 'delivery') return _n(cfg['delivery']);
    return _n(cfg['pickup']) + _n(cfg['delivery']);
  }
  if (mode == 'roundtrip') {
    if (type == 'roundtrip') return _n(cfg['roundtrip']);
    return type == 'pickup' ? _n(cfg['pickup']) : _n(cfg['delivery']);
  }
  return 0;
}

const transportModes = [
  ['free', '1. Gratis Transportasi', 'Default. Tidak menambah biaya ke pesanan.'],
  ['fixed', 'Tarif Tetap', 'Satu tarif untuk order yang memakai transportasi.'],
  ['split', 'Tarif Jemput & Antar Terpisah', 'Tarif penjemputan dan pengantaran dapat berbeda.'],
  ['roundtrip', 'Tarif Jemput & Antar', 'Satu tarif khusus untuk perjalanan pulang-pergi.'],
  ['distance', 'Tarif per Jarak', 'Disiapkan untuk Maps API/Laravel.'],
];

/// Isian tarif per mode: [kunci cfg, label].
const transportFields = <String, List<List<String>>>{
  'free': [],
  'fixed': [['fixed', 'Tarif transportasi per order']],
  'split': [['pickup', 'Tarif penjemputan'], ['delivery', 'Tarif pengantaran']],
  'roundtrip': [['roundtrip', 'Tarif Jemput & Antar'], ['pickup', 'Jika hanya jemput'], ['delivery', 'Jika hanya antar']],
  'distance': [['perKm', 'Tarif per km'], ['freeRadius', 'Radius gratis (km)']],
};

/// Pengaturan layanan antar-jemput (Mode Murni menyimpannya; di HTML hilang saat aplikasi ditutup).
Map<String, dynamic> deliveryOf(Map<String, dynamic> raw) {
  final d = raw['delivery'] is Map ? Map<String, dynamic>.from(raw['delivery'] as Map) : <String, dynamic>{};
  d['on'] = d['on'] != false;
  d['jemput'] = d['jemput'] != false;
  d['antar'] = d['antar'] != false;
  d['hJemput'] = d['hJemput'] ?? '08:00 – 17:00';
  d['hAntar'] = d['hAntar'] ?? '10:00 – 20:00';
  d['couriers'] = d['couriers'] is List ? d['couriers'] : <dynamic>[];
  raw['delivery'] = d;
  return d;
}

bool deliveryJemput(Map<String, dynamic> raw) {
  final d = deliveryOf(raw);
  return d['on'] == true && d['jemput'] == true;
}

bool deliveryAntar(Map<String, dynamic> raw) {
  final d = deliveryOf(raw);
  return d['on'] == true && d['antar'] == true;
}

/// Teks kecil di menu Pengaturan.
String deliverySub(Map<String, dynamic> raw) {
  final d = deliveryOf(raw);
  if (d['on'] != true) return 'Nonaktif · hanya datang langsung';
  final j = d['jemput'] == true, a = d['antar'] == true;
  return j && a ? 'Aktif · jemput & antar' : (j ? 'Aktif · jemput saja' : (a ? 'Aktif · antar saja' : 'Nonaktif'));
}

/// Pilihan penyerahan di Atur Pesanan: Jemput & Antar butuh keduanya aktif, Antar butuh antar aktif.
List<String> handoverOptions(Map<String, dynamic> raw) => [
      'Datang Langsung',
      if (deliveryAntar(raw)) 'Antar ke Pelanggan',
      if (deliveryAntar(raw) && deliveryJemput(raw)) 'Jemput & Antar',
    ];
