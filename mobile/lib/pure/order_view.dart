// Mode murni: Rincian Pesanan (#g62-order-detail) dan popup-nya dibangun dari data Dart,
// dengan bentuk model yang sama dengan yang dikirim HTML ke NativeOrderDetail (capacitor.js orderDetailModel).
// Aturan baris diambil dari index.html v115 render() + v142 tidy() + v183 renderTimeline/renderTransportDetail.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'service_icons.dart';
import 'views.dart';

const _proc = ['cuci', 'kering', 'setrika', 'packing'];

String _two(int n) => n.toString().padLeft(2, '0');
String fmtDateTime(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} · ${_two(d.hour)}:${_two(d.minute)}';

/// Nomor HP disamarkan seperti contoh HTML: "0852 •••• 8626".
String maskPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length < 9) return phone;
  return '${d.substring(0, 4)} •••• ${d.substring(d.length - 4)}';
}

/// [label, warna pil, teks tombol utama] per status.
List<String> orderStatusView(String st, bool antar) {
  if (st == 'batal') return const ['Batal', 'rgb(255, 240, 241)', 'PESANAN DIBATALKAN'];
  if (st == 'jemput') return const ['Penjemputan', 'rgb(238, 241, 245)', 'JEMPUT'];
  if (st == 'antrian') return const ['Antrian', 'rgb(238, 241, 245)', 'MULAI PROSES'];
  if (_proc.contains(st)) return const ['Proses', 'rgb(234, 242, 253)', 'TANDAI SIAP'];
  if (st == 'siap') return ['Siap Ambil', 'rgb(232, 248, 240)', antar ? 'ANTAR' : 'SERAHKAN'];
  if (st == 'telat') return ['Telat Ambil', 'rgb(255, 240, 241)', antar ? 'ANTAR' : 'SERAHKAN'];
  if (st == 'diantar') return const ['Diantar', 'rgb(234, 242, 253)', 'TANDAI DIAMBIL'];
  return const ['Diambil', 'rgb(241, 243, 246)', 'SELESAI ✓'];
}

List<Map<String, dynamic>> _steps(String st, bool antar) {
  final labels = antar
      ? const ['Penjemputan', 'Diterima Outlet', 'Proses', 'Siap', 'Pengantaran', 'Diterima Pelanggan']
      : const ['Diterima', 'Proses', 'Siap Ambil', 'Diambil'];
  final int idx;
  if (antar) {
    idx = st == 'jemput' ? 0 : st == 'antrian' ? 1 : _proc.contains(st) ? 2 : (st == 'siap' || st == 'telat') ? 3 : st == 'diantar' ? 4 : 5;
  } else {
    idx = (st == 'antrian' || st == 'jemput') ? 0 : _proc.contains(st) ? 1 : (st == 'siap' || st == 'telat' || st == 'diantar') ? 2 : 3;
  }
  final done = st == 'diambil';
  return [
    for (var k = 0; k < labels.length; k++)
      {'n': '${k + 1}', 't': labels[k], 'on': st != 'batal' && !done && k == idx, 'done': st != 'batal' && (done || k < idx)},
  ];
}

/// Teks baris "Penyerahan" (HTML: antar → "Diantar kurir", selain itu gabungan chip kartu).
String handoverText(Order o) {
  if (o.antar) return 'Diantar kurir';
  final chips = [
    for (final ch in (o.card['chips'] as List? ?? const []).whereType<Map>())
      if (ch['hidden'] != true && '${ch['text'] ?? ''}'.trim().isNotEmpty) '${ch['text']}'.trim(),
  ].where((t) => !t.startsWith('⏰') && !t.startsWith('💬') && !t.startsWith('✓')).toList();
  final v = chips.isEmpty ? 'Datang Langsung' : chips.join(' · ');
  return v.startsWith('Prioritas · ') ? '⚡ $v' : v;
}

/// Model `od` untuk NativeOrderDetail. [banner] = baru saja disimpan (kotak "Pesanan tersimpan").
/// Indeks tombol (`b`) sama dengan HTML: tanpa banner semua indeks ≥ 3 turun satu.
Map<String, dynamic> orderDetailOd(Business b, Order o, {bool banner = false}) {
  final st = o.status, antar = o.antar;
  final view = orderStatusView(st, antar);
  final shift = banner ? 0 : -1;
  final cust = b.customerByName(o.name);
  final phone = o.phone.isNotEmpty ? o.phone : (cust?.phone ?? '');
  final total = o.total, paid = o.isPaid;
  final photos = o.detail['photos'];
  final nPh = photos is Map ? ((photos['in'] as List?)?.length ?? 0) + ((photos['out'] as List?)?.length ?? 0) : 0;
  Map<String, dynamic> row(String k, String v, {bool pill = false, String bg = 'rgba(0, 0, 0, 0)', String c = 'rgb(30, 30, 30)', bool line = false, int tap = -1}) =>
      {'k': k, 'v': v, 'pill': pill, 'bg': bg, 'c': c, 'line': line, 'tap': tap};
  final hand = handoverText(o);
  final note = o.note.trim();
  final type = '${o.dataset['transportType183'] ?? 'roundtrip'}';
  final fee = int.tryParse('${o.dataset['transport183'] ?? ''}') ?? o.ongkir;
  return {
    'title': 'RINCIAN PESANAN', 'sub': '${o.id} · ${o.dur}',
    'head': [{'t': '⋯', 'b': 1}, {'t': '×', 'b': 2}],
    'banner': !banner
        ? null
        : paid
            ? {
                'bg': 'rgb(239, 250, 244)', 'line': 'rgb(215, 240, 227)', 'ic': 'rgb(21, 163, 107)', 'c': 'rgb(15, 95, 63)', 'icon': '✓',
                't': 'Pesanan tersimpan · Lunas via ${o.method}', 's': '', 'ok': true, 'label': {'t': '🏷 Label kantong', 'b': 3},
              }
            : {
                'bg': 'rgb(255, 248, 236)', 'line': 'rgb(255, 230, 194)', 'ic': 'rgb(224, 161, 0)', 'c': 'rgb(138, 75, 15)', 'icon': '!',
                't': 'Pesanan tersimpan · Belum dibayar', 's': '', 'ok': false, 'label': {'t': '🏷 Label kantong', 'b': 3},
              },
    'customer': {
      'svg': cust?.gender == 'female' ? custAvatarFemale : custAvatarMale, 'name': o.name,
      'sub': [if (phone.isNotEmpty) maskPhone(phone), if ((cust?.address ?? '').isNotEmpty) cust!.address].join(' · '),
      'wa': {'t': '', 'b': 4 + shift}, 'print': {'t': '', 'b': 5 + shift},
    },
    'steps': _steps(st, antar),
    'itemsTitle': 'Detail Order', 'edit': {'t': 'Edit', 'b': 7 + shift},
    'items': [
      for (final it in o.items)
        {'svg': serviceIconSvg(it.icon.isEmpty ? it.name : it.icon, 30), 't': '${it.name} (${o.dur})', 's': '${qtyText(it.qty)} ${it.unit} × ${rpSpaced(it.price)}', 'v': rpSpaced(it.subtotal)},
    ],
    'rows': [
      row('Status', view[0], pill: true, bg: view[1]),
      if (hand != 'Datang Langsung') row('Penyerahan', hand),
      if (note.isNotEmpty && note != '-') row('Keterangan', note),
      if (o.masuk != null) row('Tanggal Masuk', fmtDateTime(o.masuk!)),
      if (o.due != null) row('Estimasi Selesai', fmtDateTime(o.due!)),
      if (o.perfume.isNotEmpty && o.perfume != 'Tanpa Parfum') row('Parfum', o.perfume),
      if (nPh > 0) row('Foto Dokumentasi', '$nPh foto ›', c: 'rgb(43, 106, 166)', tap: 0),
      if (antar)
        row(type == 'pickup' ? 'Transportasi Jemput' : type == 'delivery' ? 'Transportasi Antar' : 'Transportasi Jemput + Antar', fee > 0 ? rpSpaced(fee) : 'GRATIS',
            c: 'rgb(32, 36, 43)', line: true),
    ],
    'actions': [
      {'t': view[2], 'b': 8 + shift, 'green': false, 'primary': true},
      {'t': 'KIRIM NOTA WA', 'b': 9 + shift, 'green': true, 'primary': false},
    ],
    'total': {
      'label': 'Total', 'v': rpSpaced(total), 's': paid ? 'Lunas' : (o.paid > 0 ? 'Sisa ${rpSpaced(o.remaining)}' : 'Belum dibayar'),
      'c': paid ? 'rgb(21, 136, 93)' : 'rgb(216, 50, 63)', 'paid': paid, 'pay': {'t': paid ? 'LUNAS ✓' : 'BAYAR', 'b': 12 + shift},
    },
  };
}

/// Menu ⋯ (HTML act115).
const _menu = [
  ["Foto Dokumentasi", "Foto cucian saat masuk & saat diambil", "<svg viewBox=\"0 0 24 24\"><path d=\"M4 8h3l2-3h6l2 3h3v11H4z\" fill=\"currentColor\"></path><circle cx=\"12\" cy=\"13\" r=\"3.4\" fill=\"#fff\"></circle></svg>"],
  ["Edit Transaksi", "Layanan, berat, estimasi, parfum, diskon", "<svg viewBox=\"0 0 24 24\"><path d=\"M4 20h4L19 9l-4-4L4 16z\" fill=\"currentColor\"></path></svg>"],
  ["Riwayat Status", "Waktu & pegawai di setiap tahap", "<svg viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"8\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.4\"></circle><path d=\"M12 7.5V12l3 2\" stroke=\"currentColor\" stroke-width=\"2.4\" fill=\"none\" stroke-linecap=\"round\"></path></svg>"],
  ["Label & Cek Kantong", "Cetak label per kantong · scan saat diambil", "<svg viewBox=\"0 0 24 24\"><path d=\"M3 12V4h8l10 10-8 8z\" fill=\"currentColor\"></path><circle cx=\"7.5\" cy=\"8.5\" r=\"1.8\" fill=\"#fff\"></circle></svg>"],
  ["Ralat Pembayaran", "Salah metode / nominal · khusus Admin Utama", "<svg viewBox=\"0 0 24 24\"><path d=\"M4 7h16v11H4z\" fill=\"currentColor\" opacity=\".25\"></path><path d=\"M4 7h16v11H4zM4 11h16\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"></path><path d=\"M15 3l2 2-6 6H9V9z\" fill=\"currentColor\"></path></svg>"],
  ["Batalkan Pesanan", "Wajib pilih alasan · tercatat di audit", "<svg viewBox=\"0 0 24 24\"><path d=\"M6 6l12 12M18 6L6 18\" stroke=\"currentColor\" stroke-width=\"2.6\" stroke-linecap=\"round\"></path></svg>"],
];

List<Map<String, dynamic>> orderMenuItems() => [
      for (final (i, r) in _menu.indexed) {'type': 'card', 't': r[0], 's': r[1], 'svg': r[2], 'ic': '', 'badge': '', 'meta': '', 'on': false, 'i': i},
      {'type': 'button', 't': 'Tutup', 'primary': false, 'file': '', 'after': false, 'i': 6},
    ];

/// Riwayat Status (HTML hist115): nomor, status, "oleh <pegawai>", waktu.
List<Map<String, dynamic>> orderHistoryItems(Order o) {
  String label(String st) => _proc.contains(st)
      ? 'Proses · ${st[0].toUpperCase()}${st.substring(1)}'
      : const {'jemput': 'Penjemputan', 'antrian': 'Antrian', 'siap': 'Siap Ambil', 'telat': 'Telat Ambil', 'diantar': 'Diantar', 'diambil': 'Diambil', 'batal': 'Batal'}[st] ?? st;
  final h = o.history;
  return [
    {'type': 'title', 't': 'Riwayat Status', 's': ''},
    {'type': 'hint', 't': '${o.id} · ${o.name}'},
    for (var k = 0; k < h.length; k++) ...[
      {
        'type': 'entry', 't': label('${h[k]['st']}'), 'compact': true, 'badge': '${k + 1}',
        'lines': [
          'oleh ${h[k]['by'] ?? 'Kasir'}${'${h[k]['note'] ?? ''}'.isEmpty ? '' : ' · ${h[k]['note']}'}',
          if (DateTime.tryParse('${h[k]['at'] ?? h[k]['t'] ?? ''}')?.toLocal() case final d?) fmtDateTime(d),
        ],
      },
    ],
    {'type': 'button', 't': 'Tutup', 'primary': false, 'i': 0},
  ];
}

/// Teks nota WhatsApp (HTML wa131), isi dari data pesanan & profil outlet.
String orderNotaText(Business b, Order o, {required String outlet, String address = '', String phone = '', String kasir = '-'}) {
  String dt(DateTime? d) => d == null ? '-' : '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
  const line = '━━━━━━━━━━━━━━━━━━━━';
  final t = o.totals;
  final status = o.isPaid ? 'LUNAS (${o.method})' : (o.paid > 0 ? 'DP ${rp(o.paid)} · SISA ${rp(o.remaining)}' : 'BELUM LUNAS (${o.method})');
  return [
    'NOTA ELEKTRONIK',
    outlet.toUpperCase(),
    if (address.isNotEmpty) address,
    if (phone.isNotEmpty) 'WA $phone',
    line,
    'No Nota : ${o.id}',
    'Pelanggan : ${o.name}',
    'Masuk : ${dt(o.masuk)}',
    'Selesai : ${dt(o.due)}',
    'Layanan : ${o.dur}',
    'Kasir : $kasir',
    line,
    'Rincian Layanan',
    for (final (i, it) in o.items.indexed) '${i + 1}. ${it.name}\n   ${qtyText(it.qty)} ${it.unit} × ${thousands(it.price)} = ${rp(it.subtotal)}',
    line,
    'Parfum : ${o.perfume.isEmpty ? 'Tanpa Parfum' : o.perfume}',
    'Penyerahan : ${o.antar ? 'Diantar kurir' : o.handover}',
    'Catatan : ${o.note.isEmpty ? '-' : o.note}',
    'Status : $status',
    line,
    'Subtotal : ${rp(t.sub)}',
    'Diskon : ${rp(t.disc)}',
    if (o.ongkir > 0) 'Ongkir : ${rp(o.ongkir)}',
    'TOTAL : ${rp(t.total)}',
    line,
    '- Harap membawa nota ini saat mengambil pakaian',
    '- Pisahkan pakaian luntur dan tidak luntur',
    '- Kelunturan di mesin cuci bukan tanggung jawab kami',
    '- Sprei, selimut, sepatu & bed cover dihitung satuan',
    '- Kiloan minimal 2 kg',
    '- Cucian yang tidak diambil lebih dari 30 hari dikenakan biaya simpan Rp1.000/hari.',
    '',
    'Terima kasih 🙏',
  ].join('\n');
}

/// Popup Nota WhatsApp (HTML wa131) sebagai butir lembar.
List<Map<String, dynamic>> orderNotaItems(Order o, String text) => [
      {'type': 'title', 't': 'Nota WhatsApp', 's': ''},
      {'type': 'hint', 't': 'Pratinjau · ${o.id}'},
      {'type': 'hint', 't': text},
      {'type': 'button', 't': 'Kirim ke WhatsApp Pelanggan', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Salin Teks Nota', 'primary': false, 'i': 2},
      {'type': 'button', 't': 'Kembali', 'primary': false, 'i': 3},
    ];
