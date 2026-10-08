// Mode murni: Rincian Pesanan (#g62-order-detail) dan popup-nya dibangun dari data Dart,
// dengan bentuk model yang sama dengan yang dikirim HTML ke NativeOrderDetail (capacitor.js orderDetailModel).
// Aturan baris diambil dari index.html v115 render() + v142 tidy() + v183 renderTimeline/renderTransportDetail.

import 'dart:convert';

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'page_templates.dart';
import 'service_icons.dart';
import 'views.dart';

const _proc = ['cuci', 'kering', 'setrika', 'packing', doneStage];

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
/// [detailed] = akun masuk ke server: pil status menyebut tahapnya (Cuci, Kering, …, Selesai Proses).
/// [staff] = akun pegawai: tombol utama memajukan satu tahap menurut alur layanan, sampai Selesai Proses.
Map<String, dynamic> orderDetailOd(Business b, Order o, {bool banner = false, bool detailed = false, bool staff = false}) {
  final st = o.status, antar = o.antar;
  final base = orderStatusView(st, antar);
  final stage = detailed ? stageName[st] : null;
  final next = staff ? b.nextStage(o) : null;
  final view = [
    stage == null ? base[0] : (st == doneStage ? stage : 'Proses · $stage'),
    base[1],
    !staff
        ? base[2]
        : next == null
            ? (st == doneStage ? 'MENUNGGU KASIR' : base[2])
            : next == doneStage
                ? 'SELESAI PROSES'
                : '${st == 'antrian' ? 'MULAI' : 'LANJUT'} ${stageName[next]!.toUpperCase()}',
  ];
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

// ---------- popup dengan widget khusus Hibrida (pohon tampilan HTML, teks diisi Dart) ----------

Map<String, dynamic> _tpl(String id) => Map<String, dynamic>.from(jsonDecode(jsonEncode((jsonDecode(popupMirrors) as Map)[id])) as Map);
Map<String, dynamic> _clone(Object? n) => Map<String, dynamic>.from(jsonDecode(jsonEncode(n)) as Map);

/// Ganti teks sebuah simpul (gaya span pertama dipertahankan).
void _text(Object? node, String t) {
  final n = node as Map;
  final first = Map<String, dynamic>.from((n['spans'] as List).first as Map)..['t'] = t;
  n['spans'] = [first];
  n.remove('h');
}

String historyLabel(String st) => st == doneStage
    ? 'Selesai Proses'
    : _proc.contains(st)
    ? 'Proses'
    : const {'jemput': 'Penjemputan', 'antrian': 'Antrian', 'siap': 'Siap Ambil', 'telat': 'Telat Ambil', 'diantar': 'Diantar', 'diambil': 'Diambil', 'batal': 'Batal'}[st] ?? st;

/// Riwayat Status (HTML hist115): nomor, status, "oleh pegawai", waktu. Baris terakhir = status sekarang (merah).
Map<String, dynamic> orderHistoryMirror(Order o) {
  final m = _tpl('hist115');
  final box = m['box'] as Map, ch = box['ch'] as List;
  _text(ch[2], '${o.id} · ${o.name}');
  final list = ch[3] as Map, rows = list['ch'] as List;
  final past = rows[0], cur = rows[1];
  final h = o.history;
  list['ch'] = [
    for (var k = 0; k < h.length; k++)
      () {
        final row = _clone(k == h.length - 1 ? cur : past);
        final rc = row['ch'] as List, body = (rc[1] as Map)['ch'] as List;
        final at = DateTime.tryParse('${h[k]['at'] ?? h[k]['t'] ?? ''}')?.toLocal();
        final note = '${h[k]['note'] ?? ''}';
        _text(rc[0], '${k + 1}');
        _text(body[0], historyLabel('${h[k]['st']}'));
        _text(body[1], 'oleh ${h[k]['by'] ?? 'Kasir'}${note.isEmpty ? '' : ' · $note'}');
        _text(rc[2], at == null ? '' : fmtDateTime(at));
        row.remove('h');
        return row;
      }(),
  ];
  list.remove('h');
  box.remove('h');
  return m;
}

/// Foto Dokumentasi (HTML photo115): foto tampil sebagai kotak 74px sebelum tombol ＋Foto.
Map<String, dynamic> orderPhotoMirror(Order o) {
  final m = _tpl('photo115');
  final box = m['box'] as Map, ch = box['ch'] as List;
  final ph = o.detail['photos'];
  for (final (i, slot) in const ['in', 'out'].indexed) {
    final row = (ch[3 + i] as Map)['ch'][1] as Map, add = (row['ch'] as List).first as Map;
    final list = ph is Map ? (ph[slot] as List? ?? const []) : const [];
    row['ch'] = [
      for (final src in list)
        {'s': {'m': [0, 0, 0, 0], 'p': [0, 0, 0, 0], 'br': [12, 12, 12, 12]}, 'w': 74, 'h': 74, 'fixed': 1, 'img': '$src'},
      add,
    ];
    row.remove('h');
    (ch[3 + i] as Map).remove('h');
  }
  box.remove('h');
  return m;
}

String _pad(String s, int n) => s.padRight(n);

/// Teks nota WhatsApp (HTML waNota131): *tebal* dan ```rata kolom``` format WhatsApp.
String orderNotaWa(Order o, {required String outlet, String address = '', String phone = '', String kasir = '-', String footer = ''}) {
  String dt(DateTime? d) => d == null ? '-' : '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
  const line = '━━━━━━━━━━━━━━━━━━━━';
  final t = o.totals;
  final status = o.isPaid ? 'LUNAS' : (o.paid > 0 ? 'DP ${rp(o.paid)} · SISA ${rp(o.remaining)}' : 'BELUM LUNAS');
  String cols(List<List<String>> rows) => '```${rows.map((r) => '${_pad(r[0], 11)}: ${r[1]}').join('\n')}```';
  final foot = [
    for (final l in footer.split('\n'))
      if (l.trim().isNotEmpty && l.trim() != '-') l.trim().startsWith('-') ? l.trim() : '- ${l.trim()}',
  ];
  return [
    '*NOTA ELEKTRONIK*', '', '*${outlet.toUpperCase()}*', address, 'WA $phone', line,
    cols([['No Nota', o.id], ['Pelanggan', o.name], ['Masuk', dt(o.masuk)], ['Selesai', dt(o.due)], ['Layanan', o.dur], ['Kasir', kasir]]),
    line,
    '*Rincian Layanan*',
    for (final (i, it) in o.items.indexed) '${i + 1}. ${it.name}\n   ${qtyText(it.qty)} ${it.unit} × ${thousands(it.price)} = ${rp(it.subtotal)}',
    line,
    cols([['Parfum', o.perfume.isEmpty ? 'Tanpa Parfum' : o.perfume], ['Penyerahan', o.antar ? 'Diantar kurir' : o.handover], ['Catatan', o.note.isEmpty ? '-' : o.note]]),
    'Status : *$status* (${o.method})',
    line,
    '```${[['Subtotal', rp(t.sub)], ['Diskon', t.disc > 0 ? '-${rp(t.disc)}' : 'Rp0'], if (o.ongkir > 0) ['Ongkir', rp(o.ongkir)]].map((r) => '${_pad(r[0], 11)}: ${r[1].padLeft(12)}').join('\n')}```',
    '*TOTAL : ${rp(t.total)}*',
    line,
    ...foot,
    if (foot.isNotEmpty) '',
    'Cek status & struk:', 'https://goyana.id/s/${o.id}', '', 'Terima kasih 🙏',
  ].join('\n');
}

/// Popup Nota WhatsApp (HTML wa131): pratinjau gelembung hijau dari teks [wa].
Map<String, dynamic> orderNotaMirror(Order o, String wa) {
  final m = _tpl('wa131');
  final box = m['box'] as Map, ch = box['ch'] as List;
  _text(ch[2], 'Pratinjau · ${o.id}');
  final bubble = ch[3] as Map, blk = (bubble['ch'] as List).first as Map, nodes = blk['ch'] as List;
  final plain = nodes[0], mono = nodes[1];
  final bold = Map<String, dynamic>.from(((plain as Map)['spans'] as List).first as Map);
  final parts = wa.split('```');
  blk['ch'] = [
    for (var i = 0; i < parts.length; i++)
      if (i.isOdd)
        _clone(mono)
          ..['spans'] = [{'t': parts[i]}]
          ..remove('h')
      else if ((i == 0 ? parts[i] : parts[i].replaceFirst(RegExp(r'^\n'), '')).isNotEmpty)
        _clone(plain)
          ..['spans'] = [
            for (final (k, seg) in (i == 0 ? parts[i] : parts[i].replaceFirst(RegExp(r'^\n'), '')).split('*').indexed)
              if (seg.isNotEmpty) k.isOdd ? {...bold, 't': seg} : {'t': seg},
          ]
          ..remove('h'),
  ];
  blk.remove('h');
  bubble.remove('h');
  box.remove('h');
  return m;
}
