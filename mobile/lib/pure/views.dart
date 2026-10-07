// Mode murni: data tampilan (JSON yang sama dengan model halaman native) dibangun dari logika Dart,
// bukan dari HTML. Widget halaman native yang sudah ada dipakai ulang apa adanya.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../logic/home.dart';
import '../logic/orders.dart' as lo;

Map<String, String> chip(String t, String bg, String c) => {'t': t, 'bg': bg, 'c': c};

/// Tab Pesanan (sama dengan HTML): label & kunci status.
const orderTabs = lo.orderTabs;

/// Beranda: model yang sama dengan HTML (lib/logic/home.dart).
Map<String, dynamic> homeJson(Business b, DateTime now) => homeModel(b, now);

/// Pesanan: model yang sama dengan HTML (lib/logic/orders.dart). [auto] = aturan status otomatis (v133).
Map<String, dynamic> ordersJson(Business b, {required int tab, required String search, required DateTime now, Map auto = const {}, Map<String, dynamic> reminderLog = const {}}) =>
    lo.ordersModel(b, tab: tab, search: search, now: now, queueEnabled: auto['q'] != false, queueMinutes: autoQueueMinutes(auto), reminderLog: reminderLog)
      ..['auto'] = {'t': 'Otomatis', 'on': auto['q'] != false || auto['p'] == true};

/// Menit tunggu Antrian → Proses dari aturan tersimpan ({q, qv, qu, p, step}).
double autoQueueMinutes(Map auto) {
  final v = num.tryParse('${auto['qv'] ?? 1}') ?? 1;
  final u = num.tryParse('${auto['qu'] ?? 60}') ?? 60;
  final m = (v <= 0 ? 1 : v) * u;
  return m < 1 ? 1 : m.toDouble();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Link Google Maps dari titik / link / alamat pelanggan.
String mapsLink(Customer? c) {
  if (c == null) return '';
  final m = c.maps.trim();
  if (m.startsWith('http')) return m;
  final coord = RegExp(r'^\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$').firstMatch(m);
  if (coord != null) return 'https://maps.google.com/?q=${coord.group(1)},${coord.group(2)}';
  if (c.address.trim().isNotEmpty) return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.address.trim())}';
  return '';
}

const custAvatarMale = "<svg viewBox=\"0 0 64 64\" aria-hidden=\"true\"><path d=\"M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54\" fill=\"#5C97F8\"></path><circle cx=\"32\" cy=\"26\" r=\"11\" fill=\"#FFD6B3\"></circle><path d=\"M21 24.5c0-8.5 4.5-13.5 11-13.5 6.6 0 11 5 11 13.5v2.1H21v-2.1z\" fill=\"#26384D\"></path><circle cx=\"28\" cy=\"26\" r=\"1.3\" fill=\"#26384D\"></circle><circle cx=\"36\" cy=\"26\" r=\"1.3\" fill=\"#26384D\"></circle><path d=\"M29 31c1.6 1.6 4.4 1.6 6 0\" stroke=\"#D58A78\" stroke-width=\"1.7\" fill=\"none\" stroke-linecap=\"round\"></path></svg>";
const custAvatarFemale = "<svg viewBox=\"0 0 64 64\" aria-hidden=\"true\"><path d=\"M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54\" fill=\"#E56A8C\"></path><circle cx=\"32\" cy=\"26\" r=\"11\" fill=\"#FFD8C7\"></circle><path d=\"M18.5 26.2c0-9.6 5.1-15 13.5-15s13.5 5.4 13.5 15c0 4.5-1.7 8.4-4.4 11-1.1-6.9-4.3-10.6-9.1-10.6s-8 3.7-9.1 10.6c-2.7-2.6-4.4-6.5-4.4-11z\" fill=\"#6D4A3C\"></path><circle cx=\"28\" cy=\"26\" r=\"1.3\" fill=\"#453126\"></circle><circle cx=\"36\" cy=\"26\" r=\"1.3\" fill=\"#453126\"></circle><path d=\"M29 31c1.6 1.6 4.4 1.6 6 0\" stroke=\"#D88A86\" stroke-width=\"1.7\" fill=\"none\" stroke-linecap=\"round\"></path></svg>";

/// Jumlah baris pelanggan per halaman (HTML v138).
const custPerPage = 10;

/// Daftar pelanggan (model halaman Pelanggan, bentuk sama dengan HTML).
/// Beda yang disengaja: jumlah order, belanja dan transaksi terakhir dihitung dari pesanan asli
/// (HTML selalu menampilkan 0 / "Baru").
Map<String, dynamic> customersJson(Business b, String search, {bool open = false, int page = 0, String sort = '', bool crm = true}) {
  final q = search.trim().toLowerCase();
  final orders = b.orders;
  final list = b.customers;
  final all = <Map<String, dynamic>>[];
  for (var i = 0; i < list.length; i++) {
    final c = list[i];
    final mine = orders.where((o) => o.name.trim().toLowerCase() == c.name.trim().toLowerCase() && !o.isCancelled).toList();
    final spend = mine.fold<int>(0, (a, o) => a + o.total);
    final last = mine.map((o) => o.created).whereType<DateTime>().fold<DateTime?>(null, (a, d) => a == null || d.isAfter(a) ? d : a);
    final line = [c.phone, if (c.address.isNotEmpty) c.address].join(' · ');
    if (q.isNotEmpty && !'${c.name} ${c.phone} $line'.toLowerCase().contains(q)) continue;
    all.add({
      'i': i, 'name': c.name, 'avatar': c.gender == 'female' ? custAvatarFemale : custAvatarMale, 'lines': [line],
      'spend': 'Belanja ${rp(spend)}', 'orders': '${mine.length}', 'last': last == null ? 'Baru' : '${_two(last.day)}/${_two(last.month)}',
      'balance': 'Saldo ${rp(b.depositOf(c.name))}', 'topup': 'Top Up Saldo', 'edit': 'Edit',
    });
  }
  if (sort == 'name') all.sort((x, y) => '${x['name']}'.toLowerCase().compareTo('${y['name']}'.toLowerCase()));
  if (sort == 'order') all.sort((x, y) => int.parse('${y['orders']}').compareTo(int.parse('${x['orders']}')));
  final pages = all.isEmpty ? 1 : ((all.length + custPerPage - 1) ~/ custPerPage);
  final pg = page.clamp(0, pages - 1);
  final shown = q.isNotEmpty || open;
  return {
    'title': 'PELANGGAN', 'sub': 'Kelola data pelanggan laundry', 'search': {'v': search, 'ph': 'Cari nama / no handphone'},
    'deposit': 'Saldo Pelanggan · Top Up & Riwayat', 'add': 'Tambah Pelanggan',
    'db': {'t': 'Database Pelanggan', 's': '${list.length} pelanggan tersimpan', 'open': shown},
    'rank': {'t': 'Ranking Pelanggan', 's': 'Transaksi terbanyak & belanja terbesar', 'icon': '🏆'},
    if (crm) 'crm': {'t': 'CRM Pelanggan', 'badge': 'PLATINUM', 's': 'Pengingat cucian · Poin member · Voucher kode unik', 'icon': '💎'},
    'rows': shown ? all.skip(pg * custPerPage).take(custPerPage).toList() : <Map<String, dynamic>>[],
    'empty': '',
    'pager': shown && pages > 1 ? {'prev': '‹ Sebelumnya', 'next': 'Berikutnya ›', 'info': 'Hal ${pg + 1} dari $pages', 'canPrev': pg > 0, 'canNext': pg < pages - 1} : null,
    if (shown) ...{'dbTitle': 'Daftar Pelanggan', 'dbSub': 'Database pelanggan outlet', 'filter': 'Filter ▾'},
  };
}
