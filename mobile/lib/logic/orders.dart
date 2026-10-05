// Halaman Pesanan dihitung Dart, aturan sama dengan HTML (v108 TAG/NEXT, v133 hitung mundur otomatis, v138 telat ambil,
// v141 kabari WA, v144 chip ringkas, v188 teks ringkas). Dicek terhadap tangkapan HTML di test/parity_test.dart.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';

Map<String, String> _c(String t, String bg, String c) => {'t': t, 'bg': bg, 'c': c};

const _proc = ['cuci', 'kering', 'setrika', 'packing'];

/// Tab Pesanan (urutan & kunci sama dengan HTML tabs108).
const orderTabs = [
  ['Penjemputan', 'jemput'], ['Antrian', 'antrian'], ['Proses', 'proses'], ['Siap Ambil', 'siap'],
  ['Diantar', 'diantar'], ['Diambil', 'diambil'], ['Batal', 'batal'], ['Telat Ambil', 'telat'],
  ['Belum Bayar', 'unpaid'], // keputusan Koko 4 Okt: semua pesanan belum lunas kecuali batal
];

const _status = {
  'jemput': ['Penjemputan', 'rgb(238, 244, 255)', 'rgb(59, 111, 216)'],
  'antrian': ['Antrian', 'rgb(255, 240, 241)', 'rgb(232, 73, 63)'],
  'proses': ['Proses', 'rgb(238, 244, 255)', 'rgb(82, 117, 189)'],
  'siap': ['Siap Ambil', 'rgb(232, 248, 240)', 'rgb(21, 136, 93)'],
  'diantar': ['Diantar', 'rgb(230, 247, 245)', 'rgb(31, 143, 130)'],
  'diambil': ['Diambil', 'rgb(241, 243, 246)', 'rgb(91, 100, 121)'],
  'batal': ['Batal', 'rgb(241, 243, 246)', 'rgb(154, 161, 173)'],
  'telat': ['Telat Ambil', 'rgb(255, 240, 241)', 'rgb(216, 50, 63)'],
};

/// Pengaturan status otomatis (HTML v133: Antrian → Proses setelah 60 menit).
const autoQueueMinutes = 60;

String _fmtMinutes(double min) {
  final m0 = min.ceil() < 0 ? 0 : min.ceil();
  final h = m0 ~/ 60, m = m0 % 60;
  return '${h > 0 ? '${h}j ' : ''}${(m > 0 || h == 0) ? '${m}m' : ''}'.trim();
}

bool _inTab(Order o, String key) {
  final st = o.status;
  if (key == 'proses') return _proc.contains(st);
  if (key == 'unpaid') return st != 'batal' && !o.isPaid;
  return st == key;
}

String _compact(String t) => t.replaceAll(RegExp('Antar ke Pelanggan', caseSensitive: false), 'Antar');

Map<String, dynamic> _card(Business b, Order o, int index, DateTime now, {required int lateDays, required bool queueEnabled, required double queueMinutes, required Map<String, dynamic> reminderLog}) {
  final st = o.status;
  final key = _proc.contains(st) ? 'proses' : st;
  final tag = _status[key] ?? _status['antrian']!;
  final cust = b.customerByName(o.name);
  final ds = o.dataset;
  // Hitung mundur Antrian → Proses.
  Map<String, String>? auto;
  if (st == 'antrian' && queueEnabled) {
    final ts = int.tryParse('${ds['ts133'] ?? ''}');
    final left = queueMinutes - (now.millisecondsSinceEpoch - (ts == null || ts == 0 ? now.millisecondsSinceEpoch : ts)) / 60000;
    auto = _c('⏱ ${left > 0 ? _fmtMinutes(left) : '…'}', 'rgb(238, 244, 255)', 'rgb(43, 106, 166)');
  }
  final chips = <Map<String, String>>[];
  // Telat ambil: hari sejak Siap Ambil.
  final siapAt = int.tryParse('${ds['siap138'] ?? ''}');
  if ((st == 'siap' || st == 'telat') && siapAt != null) {
    final days = ((now.millisecondsSinceEpoch - siapAt) / 86400000).floor();
    if (days >= lateDays) chips.add(_c('⏰ $days hari', 'rgb(255, 240, 241)', 'rgb(216, 50, 63)'));
  }
  // Chip tersimpan di kartu: Prioritas & cara penyerahan ("Datang Langsung" tidak ditampilkan).
  for (final ch in (o.card['chips'] as List? ?? const []).whereType<Map>()) {
    final t = '${ch['text'] ?? ''}'.trim();
    if (t.isEmpty || t.startsWith('⏰') || t.startsWith('💬') || t.startsWith('✓')) continue;
    if (t == 'Datang Langsung' || ch['hidden'] == true) continue;
    if (t == 'Prioritas') {
      chips.add(_c(t, 'rgb(255, 240, 241)', 'rgb(232, 73, 63)'));
      continue;
    }
    chips.add(_c(_compact(t), 'rgb(243, 244, 247)', 'rgb(91, 95, 110)'));
  }
  if (st == 'siap') chips.add(_c(ds['kb141'] == '1' ? '✓ Sudah dikabari' : '💬 Kabari WA', 'rgb(232, 250, 240)', 'rgb(18, 138, 74)'));
  if (st == 'telat') {
    final sent = reminderLog[o.id] as List?;
    chips.add(sent == null ? _c('💬 Ingatkan', 'rgb(232, 250, 240)', 'rgb(18, 138, 74)') : _c('✓ Diingatkan ${sent.length}×', 'rgb(241, 243, 246)', 'rgb(107, 114, 128)'));
  }
  // Tombol tahap berikutnya.
  final antar = o.antar;
  const off = ['rgb(241, 242, 245)', 'rgb(154, 160, 172)'];
  const on = ['rgb(232, 73, 63)', 'rgb(255, 255, 255)'];
  final next = switch (key) {
    'jemput' => ['Jemput ›', ...on],
    'antrian' => ['Proses', ...on],
    'proses' => ['Tandai Siap ›', ...on],
    'siap' || 'telat' => [antar ? 'Antar ›' : 'Serahkan ›', ...on],
    'diantar' => ['Diterima ›', ...on],
    'diambil' => ['Selesai ✓', ...off],
    'batal' => ['Dibatalkan', ...off],
    _ => ['Proses', ...on],
  };
  final pay = o.paymentLabel;
  final payC = pay == 'Lunas' ? _c('Lunas', 'rgb(234, 247, 228)', 'rgb(62, 138, 46)') : _c(pay, 'rgb(255, 240, 241)', 'rgb(216, 50, 63)');
  final addr = cust?.address ?? '';
  final maps = (cust?.maps ?? '').isNotEmpty
      ? cust!.maps
      : (addr.isNotEmpty ? 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}' : '');
  return {
    'i': index, 'id': o.id,
    'dur': _c(o.dur.isEmpty ? 'Reguler' : o.dur, 'rgb(241, 242, 245)', 'rgb(91, 95, 110)'),
    'status': _c(tag[0], tag[1], tag[2]),
    'name': o.name, 'lines': <String>[],
    'amount': 'Rp${thousands(o.total)}', 'pay': payC,
    'gender': cust?.gender == 'female' ? 'female' : 'male',
    'auto': auto, 'chips': chips,
    'action': _c(next[0], next[1], next[2]),
    'maps': maps, 'st': st, 'addr': addr,
  };
}

/// Model halaman Pesanan untuk tab [tab] (indeks [orderTabs]) dan kata pencarian [search].
Map<String, dynamic> ordersModel(Business b, {required int tab, String search = '', required DateTime now, int lateDays = 7, bool queueEnabled = true, double queueMinutes = 60, Map<String, dynamic> reminderLog = const {}}) {
  final all = b.orders;
  final key = orderTabs[tab.clamp(0, orderTabs.length - 1)][1];
  final q = search.trim().toLowerCase();
  bool match(Order o) {
    if (q.isEmpty) return _inTab(o, key);
    final phone = (o.phone.isNotEmpty ? o.phone : (b.customerByName(o.name)?.phone ?? '')).toLowerCase();
    return o.name.toLowerCase().contains(q) || o.id.toLowerCase().contains(q) || phone.contains(q);
  }

  final cards = <Map<String, dynamic>>[];
  for (var i = 0; i < all.length; i++) {
    if (match(all[i])) cards.add(_card(b, all[i], i, now, lateDays: lateDays, queueEnabled: queueEnabled, queueMinutes: queueMinutes, reminderLog: reminderLog));
  }
  final label = orderTabs[tab.clamp(0, orderTabs.length - 1)][0];
  return {
    'title': 'PESANAN', 'auto': {'t': 'Otomatis', 'on': queueEnabled},
    'search': search, 'placeholder': 'Cari nama / ID / no HP',
    'tabs': [
      for (var k = 0; k < orderTabs.length; k++)
        {'t': orderTabs[k][0], 'n': '${all.where((o) => _inTab(o, orderTabs[k][1])).length}', 'on': k == tab},
    ],
    'cards': cards,
    'empty': cards.isEmpty && q.isEmpty ? 'Belum ada pesananPesanan dengan status "$label" akan muncul di sini.' : '',
  };
}
