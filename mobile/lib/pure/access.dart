// Akses paket (v190) + Mode Uji (v192): fitur mana yang terbuka pada paket/trial saat ini.
import 'dart:convert';
import 'dart:typed_data';

import '../core/store.dart';

const trialKey = 'goyana-trial190';

/// [id paket, rank, jumlah cabang].
const planCatalog = [
  ['BASIC', 1, 1],
  ['SILVER', 2, 2],
  ['GOLD', 3, 3],
  ['PLATINUM', 4, 5],
];

const _need = {'export': 2, 'opname': 2, 'quick': 2, 'ai': 3, 'messages': 3, 'blast': 4, 'stock': 2, 'crm': 3, 'transfer': 4, 'employees': 1};
const _labels = {
  'export': 'Ekspor Data', 'opname': 'Stok Opname', 'quick': 'Balasan Cepat', 'ai': 'Chatbot AI', 'messages': 'Pesan otomatis',
  'blast': 'WhatsApp Blast', 'stock': 'Stok bahan', 'crm': 'Loyalitas pelanggan', 'transfer': 'Transfer stok', 'employees': 'Pegawai',
};

/// Halaman Mode Murni yang dikunci paket (sama dengan `gates` di HTML).
const pageGates = {'quickreply': 'quick', 'stock': 'stock', 'inventory': 'stock', 'crm': 'crm', 'employees': 'employees'};

class PlanAccess {
  DateTime? trialUntil;
  /// Mode Uji: paket yang sedang dicoba (null = tidak aktif). Hanya di memori, seperti HTML.
  String? testPlan;

  Future<void> load(KvStore kv, DateTime now) async {
    trialUntil = null;
    try {
      final v = jsonDecode(await kv.get(trialKey) ?? 'null');
      if (v is Map) trialUntil = DateTime.tryParse('${v['until']}');
    } catch (_) {}
    if (trialUntil == null) {
      final end = DateTime(now.year, now.month + 2, now.day, now.hour, now.minute, now.second);
      trialUntil = end;
      await kv.set(trialKey, jsonEncode({'start': now.toUtc().toIso8601String(), 'until': end.toUtc().toIso8601String()}));
    }
  }

  /// Belum ada pembayaran paket (menunggu server), jadi: Mode Uji → paket uji; trial aktif → rank 1; selain itu 0.
  int rank(DateTime now) {
    final t = testPlan;
    if (t != null) return planCatalog.firstWhere((p) => p[0] == t, orElse: () => planCatalog.last)[1] as int;
    return trialUntil != null && trialUntil!.isAfter(now) ? 1 : 0;
  }

  String id(DateTime now) => testPlan ?? (rank(now) > 0 ? 'TRIAL' : 'FREE');
  bool has(String feature, DateTime now) => rank(now) >= (_need[feature] ?? 99);

  /// Pesan saat fitur terkunci, sama dengan HTML.
  String lockedText(String feature) =>
      '${_labels[feature] ?? 'Fitur'} membutuhkan paket ${const ['ai', 'messages', 'crm'].contains(feature) ? 'Gold' : (const ['blast', 'transfer'].contains(feature) ? 'Platinum' : 'Silver')}';

  /// 1 pusat + cabang sesuai paket.
  int outletLimit(DateTime now) {
    final r = rank(now);
    final p = planCatalog.where((p) => p[1] == r).firstOrNull;
    return ((p?[2] as int?) ?? 1) + 1;
  }

  String outletLimitText(DateTime now) => 'Batas paket: 1 pusat + ${outletLimit(now) - 1} cabang. Pilih paket lebih tinggi.';

  static const testHash = '0ddd6fd844301b89f79bb436d837b6add16e36a2541af7e9ae46a0bc195e8bdf';
  bool unlockTest(String password) {
    if (sha256Hex(utf8.encode(password)) != testHash) return false;
    testPlan = 'PLATINUM';
    return true;
  }
}

final planAccess = PlanAccess();

/// SHA-256 (untuk mencocokkan password Mode Uji tanpa paket tambahan).
String sha256Hex(List<int> data) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
  final h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  final bits = data.length * 8;
  final padded = <int>[...data, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    padded.add((bits >> (8 * i)) & 0xff);
  }
  final bytes = ByteData.sublistView(Uint8List.fromList(padded));
  final w = List<int>.filled(64, 0);
  for (var off = 0; off < padded.length; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = bytes.getUint32(off + 4 * i);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    final v = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + v[i]) & 0xffffffff;
    }
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}
