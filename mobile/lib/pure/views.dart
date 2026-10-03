// Mode murni: data tampilan (JSON yang sama dengan model halaman native) dibangun dari logika Dart,
// bukan dari HTML. Widget halaman native yang sudah ada dipakai ulang apa adanya.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';

Map<String, String> chip(String t, String bg, String c) => {'t': t, 'bg': bg, 'c': c};

const _statusColors = {
  'jemput': ['#eef4ff', '#3b6fd8'], 'antrian': ['#fff0f1', '#e8493f'], 'cuci': ['#eef4ff', '#5275bd'], 'kering': ['#eef4ff', '#5275bd'],
  'setrika': ['#eef4ff', '#5275bd'], 'packing': ['#eef4ff', '#5275bd'], 'siap': ['#e8f8f0', '#15885d'], 'diantar': ['#e6f7f5', '#1f8f82'],
  'diambil': ['#f1f3f6', '#5b6479'], 'batal': ['#f1f3f6', '#9aa1ad'], 'telat': ['#fff0f1', '#d8323f'],
};

/// Tab Pesanan (sama dengan HTML): label & kunci status.
const orderTabs = [
  ['Penjemputan', 'jemput'], ['Antrian', 'antrian'], ['Proses', 'proses'], ['Siap Ambil', 'siap'], ['Diantar', 'diantar'],
  ['Diambil', 'diambil'], ['Batal', 'batal'], ['Telat Ambil', 'telat'],
];

/// "Telat Ambil": sudah siap lebih dari 2 hari setelah estimasi.
bool lateToCollect(Order o, DateTime now) => o.status == 'siap' && o.due != null && now.isAfter(o.due!.add(const Duration(days: 2)));

bool inTab(Order o, String key, DateTime now) {
  switch (key) {
    case 'proses':
      return procStages.contains(o.status);
    case 'telat':
      return lateToCollect(o, now);
    default:
      return o.status == key;
  }
}

/// Teks tombol aksi di kartu (null bila selesai/batal).
String? actionLabel(Order o) {
  switch (o.status) {
    case 'jemput':
      return 'Sudah Dijemput';
    case 'antrian':
      return 'Proses';
    case 'cuci':
    case 'kering':
    case 'setrika':
    case 'packing':
      return 'Siap Ambil';
    case 'siap':
    case 'telat':
      return o.antar ? 'Antar' : 'Diambil';
    case 'diantar':
      return 'Diterima';
  }
  return null;
}

Map<String, String> payChip(Order o) {
  if (o.isCancelled) return chip('Batal', '#f1f3f6', '#9aa1ad');
  if (o.isPaid) return chip('Lunas', '#eaf7e4', '#3e8a2e');
  if (o.paid > 0) return chip(o.paymentLabel, '#fff6e5', '#b7791f');
  return chip('Belum Bayar', '#fff0f1', '#d8323f');
}

Map<String, dynamic> homeJson(Business b, DateTime now) {
  final t = b.today(now);
  final dueToday = b.orders.where((o) => !o.isCancelled && o.status != 'diambil' && o.due != null &&
      o.due!.year == now.year && o.due!.month == now.month && o.due!.day == now.day).length;
  return {
    'statIn': '${t.inCount}', 'statReady': '${t.ready}', 'statLate': '${t.late}',
    'labelIn': 'Masuk', 'labelReady': 'Siap diambil', 'labelLate': 'Terlambat',
    'today': rpSpaced(t.income), 'todayLabel': 'Omset hari ini', 'badge': '$dueToday', 'showBadge': true,
  };
}

Map<String, dynamic> ordersJson(Business b, {required int tab, required String search, required DateTime now}) {
  final all = b.orders;
  final q = search.trim().toLowerCase();
  final key = orderTabs[tab][1];
  final list = q.isEmpty
      ? all.where((o) => inTab(o, key, now)).toList()
      : all.where((o) => '${o.id} ${o.name} ${o.phone}'.toLowerCase().contains(q)).toList();
  final cards = <Map<String, dynamic>>[];
  for (final o in list.take(300)) {
    final cust = b.customerByName(o.name);
    final st = lateToCollect(o, now) ? 'telat' : o.status;
    final sc = _statusColors[st] ?? _statusColors['antrian']!;
    final action = actionLabel(o);
    final ready = o.status == 'siap' || o.status == 'packing';
    final due = o.due;
    cards.add({
      'i': all.indexOf(o), 'id': o.id, 'name': o.name, 'amount': rp(o.total), 'st': o.status,
      'dur': chip(o.dur, '#f1f2f5', '#5b5f6e'), 'status': chip(statusLabel[st] ?? st, sc[0], sc[1]), 'pay': payChip(o),
      'action': action == null ? null : chip(action, ready ? '#15885d' : '#e8493f', '#ffffff'),
      'lines': [if (due != null && !['diambil', 'batal'].contains(o.status)) 'Estimasi · ${_dm(due)}', if (o.handover != 'Datang Langsung') o.handover],
      'gender': cust?.gender ?? 'male', 'maps': mapsLink(cust), 'addr': cust?.address ?? '',
    });
  }
  return {
    'title': 'Pesanan', 'search': search, 'placeholder': 'Cari nama / ID / no HP',
    'tabs': [
      for (var i = 0; i < orderTabs.length; i++)
        {'t': orderTabs[i][0], 'n': '${all.where((o) => inTab(o, orderTabs[i][1], now)).length}', 'on': q.isEmpty && i == tab},
    ],
    'cards': cards,
    'empty': cards.isEmpty ? (q.isEmpty ? 'Belum ada pesanan di tab ini.' : 'Pesanan tidak ditemukan.') : '',
  };
}

String _two(int n) => n.toString().padLeft(2, '0');
String _dm(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} · ${_two(d.hour)}:${_two(d.minute)}';

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

/// Rincian pesanan sebagai butir formulir (digambar NativeSheet).
/// Kode tombol: 0 tutup, 1 status berikut, 2 bayar, 3 batalkan, 4 kirim WA, 5 buka maps.
List<Map<String, dynamic>> orderDetailItems(Business b, Order o, DateTime now) {
  final cust = b.customerByName(o.name);
  final idx = o.status == 'antrian' || o.status == 'jemput'
      ? 0
      : procStages.contains(o.status)
          ? 1
          : (o.status == 'siap' || o.status == 'diantar')
              ? 2
              : 3;
  final t = o.totals;
  final action = actionLabel(o);
  return [
    {'type': 'entry', 't': 'Rincian Pesanan', 'lines': ['${o.id} · ${o.dur}'], 'compact': true, 'btns': [{'t': '×', 'i': 0}]},
    {
      'type': 'entry', 't': o.name, 'lines': [[o.phone, cust?.address ?? ''].where((e) => e.isNotEmpty).join(' · ')],
      'btns': [
        if (o.phone.isNotEmpty || (cust?.phone ?? '').isNotEmpty) {'t': 'Kirim nota WA', 'i': 4},
        {'t': 'Cetak Struk', 'i': 6},
        if (mapsLink(cust).isNotEmpty) {'t': 'Maps', 'i': 5},
      ],
    },
    if (!o.isCancelled)
      {'type': 'steps', 'steps': [
        for (final (k, s) in [('1', 'Diterima'), ('2', 'Proses'), ('3', 'Siap Ambil'), ('4', 'Diambil')].indexed) {'n': s.$1, 't': s.$2, 'on': k <= idx},
      ]},
    for (final it in o.items)
      {'type': 'entry', 't': '${it.name} (${o.dur})', 'lines': ['${qtyText(it.qty)} ${it.unit} × ${rpSpaced(it.price)}'], 'amount': rpSpaced(it.subtotal), 'avatar': '🧺'},
    if (o.items.isEmpty) {'type': 'hint', 't': 'Belum ditimbang · layanan diisi setelah cucian dijemput'},
    if (t.disc > 0) {'type': 'pair', 't': 'Diskon', 'v': '-${rpSpaced(t.disc)}'},
    if (o.ongkir > 0) {'type': 'pair', 't': 'Ongkos kirim', 'v': rpSpaced(o.ongkir)},
    {'type': 'pair', 't': 'Status', 'v': statusLabel[o.status] ?? o.status, 'tone': 'p'},
    {'type': 'pair', 't': 'Penyerahan', 'v': o.handover},
    if (o.masuk != null) {'type': 'pair', 't': 'Tanggal Masuk', 'v': _dm(o.masuk!)},
    if (o.due != null) {'type': 'pair', 't': 'Estimasi Selesai', 'v': _dm(o.due!), 'tone': o.isLate(now) ? 'r' : ''},
    {'type': 'pair', 't': 'Parfum', 'v': o.perfume.isEmpty ? 'Tanpa Parfum' : o.perfume},
    {'type': 'pair', 't': 'Keterangan', 'v': o.note.isEmpty ? '-' : o.note},
    {'type': 'pair', 't': 'Status Pembayaran', 'v': o.isPaid ? 'Lunas' : (o.paid > 0 ? 'DP ${rpSpaced(o.paid)} · sisa ${rpSpaced(o.remaining)}' : 'Belum Bayar'), 'tone': o.isPaid ? 'g' : 'r'},
    if (action != null) {'type': 'button', 't': action, 'primary': true, 'i': 1},
    if (!o.isCancelled && o.status != 'diambil') {'type': 'button', 't': 'Batalkan Pesanan', 'primary': false, 'i': 3},
    {'type': 'total', 't': 'Total', 'v': rpSpaced(o.total), 's': o.isPaid ? 'Lunas' : (o.isCancelled ? 'Batal' : 'Belum dibayar'), 'btn': o.isPaid || o.isCancelled ? 'Tutup' : 'Bayar', 'i': o.isPaid || o.isCancelled ? 0 : 2},
  ];
}

/// Daftar pelanggan (model halaman Pelanggan).
Map<String, dynamic> customersJson(Business b, String search) {
  final q = search.trim().toLowerCase();
  final orders = b.orders;
  final rows = <Map<String, dynamic>>[];
  final list = b.customers;
  for (var i = 0; i < list.length; i++) {
    final c = list[i];
    if (q.isNotEmpty && !'${c.name} ${c.phone}'.toLowerCase().contains(q)) continue;
    final mine = orders.where((o) => o.name.trim().toLowerCase() == c.name.trim().toLowerCase() && !o.isCancelled).toList();
    final spend = mine.fold<int>(0, (a, o) => a + o.total);
    final last = mine.map((o) => o.created).whereType<DateTime>().fold<DateTime?>(null, (a, d) => a == null || d.isAfter(a) ? d : a);
    final dep = b.depositOf(c.name);
    rows.add({
      'i': i, 'name': c.name, 'lines': [c.phone, if (c.address.isNotEmpty) c.address], 'spend': rp(spend), 'orders': '${mine.length}',
      'last': last == null ? '—' : '${_two(last.day)}/${_two(last.month)}', 'balance': dep > 0 ? rp(dep) : '', 'edit': 'Edit',
    });
  }
  return {
    'title': 'Pelanggan', 'sub': '${list.length} pelanggan tersimpan', 'search': {'v': search, 'ph': 'Cari nama / no HP'},
    'add': 'Tambah Pelanggan', 'db': {'t': 'Database Pelanggan', 's': '${list.length} data', 'open': true},
    'dbTitle': 'Database Pelanggan', 'dbSub': 'Urut terbaru', 'rows': rows,
    'empty': rows.isEmpty ? (q.isEmpty ? 'Belum ada pelanggan. Tekan Tambah Pelanggan.' : 'Pelanggan tidak ditemukan.') : '',
  };
}
