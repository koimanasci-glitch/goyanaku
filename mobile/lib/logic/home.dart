// Beranda dihitung Dart, aturan sama persis dengan HTML (index.html summary(), openPage('home'), v187 dueCards()).
// Dicek terhadap tangkapan HTML di test/parity_test.dart.

import '../core/business.dart';
import '../core/money.dart';
import 'cash_day.dart';

const _slides = [
  {'brand': 'GOYANA SMART SERVICE', 'title': 'Chatbot Pintar\nLayani Pelanggan 24 Jam', 'sub': 'Balasan cepat & otomatis'},
  {'brand': 'KONTROL BISNIS', 'title': 'Pantau Semua Cabang\nDari Satu Dashboard', 'sub': 'Omzet • transaksi • performa'},
  {'brand': 'CRM & PELANGGAN', 'title': 'Kelola Pelanggan\nFollow-up Jadi Lebih Rapi', 'sub': 'Lead • pelanggan • histori'},
];

/// Tanggal kalender di Asia/Jakarta (UTC+7), seperti Intl.DateTimeFormat timeZone Asia/Jakarta di HTML.
String _jktDay(DateTime d) {
  final j = d.toUtc().add(const Duration(hours: 7));
  return '${j.year}-${j.month}-${j.day}';
}

bool _sameLocalDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Map<String, dynamic> homeModel(Business b, DateTime now) {
  final orders = b.orders;
  // Masuk: pesanan (bukan batal) yang dibuat hari ini.
  final inCount = orders.where((o) => o.status != 'batal' && o.created != null && _sameLocalDay(o.created!.toLocal(), now.toLocal())).length;
  // Siap diambil / Terlambat: jumlah kartu berstatus siap / telat.
  final ready = orders.where((o) => o.status == 'siap').length;
  final late = orders.where((o) => o.status == 'telat').length;
  final omzet = cashDayRevenue(b.kas, now, business: b.raw);
  // Lencana "Hari Ini": jatuh tempo hari ini (WIB), status belum selesai, di outlet aktif.
  const excluded = {'siap', 'telat', 'diantar', 'diambil', 'selesai', 'batal'};
  final today = _jktDay(now);
  final active = b.activeOutlet;
  final due = orders.where((o) => o.due != null && _jktDay(o.due!) == today && !excluded.contains(o.status) && (active.isEmpty || o.outlet == active)).length;
  return {
    'statIn': '$inCount', 'statReady': '$ready', 'statLate': '$late',
    'labelIn': 'Masuk', 'labelReady': 'Siap diambil', 'labelLate': 'Terlambat',
    'today': 'Rp ${thousands(omzet)}', 'todayLabel': 'Omset hari ini',
    'badge': '$due', 'showBadge': true,
    'slides': _slides,
    'helpTitle': 'Butuh bantuan?', 'helpText': 'Tim GOYANA siap bantu setup, printer & kendala aplikasi lewat WhatsApp.',
  };
}
