// Struk gambar (HTML v106 draw()): logo, kepala outlet, rincian, barcode Code128, QR status.
// Ukuran, urutan baris dan teks mengikuti kanvas HTML (lebar 576 px).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/models.dart';
import '../core/money.dart';
import '../native/common.dart';

const _c128 = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213', '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211',
  '221132', '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211', '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113',
  '132311', '211313', '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331', '231131', '213113', '213311', '213131', '311123', '311321', '331121',
  '312113', '312311', '332111', '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214', '112412', '122114', '122411', '142112', '142211', '241211',
  '221114', '413111', '241112', '134111', '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141', '214121', '412121', '111143', '111341', '131141',
  '114113', '114311', '411113', '411311', '113141', '114131', '311141', '411131', '211412', '211214', '211232',
];

/// Pola lebar batang Code 128 set B (mulai 104, cek jumlah mod 103, penutup).
String code128Pattern(String txt) {
  final codes = [104];
  var sum = 104;
  for (var i = 0; i < txt.length; i++) {
    final v = (txt.codeUnitAt(i) - 32).clamp(0, 94);
    codes.add(v);
    sum += v * (i + 1);
  }
  codes.add(sum % 103);
  return '${codes.map((c) => _c128[c]).join()}2331112';
}

class ReceiptData {
  const ReceiptData({
    required this.outlet, this.address = '', this.wa = '', required this.id, required this.customer, this.phone = '-', required this.masuk, required this.due,
    required this.dur, required this.items, required this.sub, required this.disc, required this.total, required this.status, required this.method,
    this.perfume = 'Tanpa Parfum', this.handover = 'Datang Langsung', this.note = '', this.priority = false, this.kasir = '-',
  });

  /// Data struk dari pesanan (HTML collect()): ongkir tampil sebagai baris "Transportasi".
  factory ReceiptData.of(Order o, {required String outlet, String address = '', String wa = '', String phone = '', String kasir = '-'}) {
    String two(int n) => n.toString().padLeft(2, '0');
    String dt(DateTime? d) => d == null ? '-' : '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    final t = o.totals;
    return ReceiptData(
      outlet: outlet, address: address, wa: wa, id: o.id, customer: o.name, phone: phone.isEmpty ? '-' : phone, masuk: dt(o.masuk), due: dt(o.due), dur: o.dur.isEmpty ? 'Reguler' : o.dur,
      items: [
        for (final it in o.items) [it.name, '${qtyText(it.qty)} ${it.unit}', it.price, it.subtotal, it.qty, it.unit],
        if (o.ongkir > 0) ['Transportasi', '1 layanan', o.ongkir, o.ongkir, 1, 'layanan'],
      ],
      sub: t.sub + o.ongkir, disc: t.disc, total: t.total,
      status: o.isPaid ? 'LUNAS' : (o.paid > 0 ? 'DP ${rpSpaced(o.paid)} · SISA ${rpSpaced(o.remaining)}' : 'BELUM LUNAS'),
      method: o.method, perfume: o.perfume.isEmpty ? 'Tanpa Parfum' : o.perfume, handover: o.antar ? 'Diantar kurir' : o.handover,
      note: o.note == '-' ? '' : o.note,
      priority: (o.card['chips'] as List? ?? const []).whereType<Map>().any((c) => c['text'] == 'Prioritas' && c['hidden'] != true), kasir: kasir,
    );
  }

  final String outlet, address, wa, id, customer, phone, masuk, due, dur, status, method, perfume, handover, note, kasir;
  /// [nama, "2,5 kg", harga, subtotal, qty, satuan]
  final List<List<Object>> items;
  final int sub, disc, total;
  final bool priority;
}

const _w = 576.0, _p = 28.0;
const _mono = 'monospace';

/// Menggambar struk ke kanvas; mengembalikan tinggi yang terpakai.
double paintReceipt(Canvas x, ReceiptData d) {
  var y = 26.0;
  TextPainter tp(String s, double sz, FontWeight wt, Color col, String? font, [TextAlign align = TextAlign.left]) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontFamily: font ?? gFont, fontSize: sz, fontWeight: wt, color: col, height: 1)),
        textDirection: TextDirection.ltr, textAlign: align, maxLines: 1,
      )..layout(maxWidth: _w - 2 * _p);
  void center(String s, double sz, FontWeight wt, [Color col = const Color(0xff111111), String? font]) {
    final t = tp(s, sz, wt, col, font);
    t.paint(x, Offset((_w - t.width) / 2, y));
  }

  void row(String l, String r, double sz, [FontWeight wt = FontWeight.w400]) {
    tp(l, sz, wt, const Color(0xff111111), _mono).paint(x, Offset(_p, y));
    final t = tp(r, sz, wt, const Color(0xff111111), _mono);
    t.paint(x, Offset(_w - _p - t.width, y));
    y += sz + 10;
  }

  void dash() {
    final paint = Paint()
      ..color = const Color(0xff999999)
      ..strokeWidth = 2;
    for (var dx = _p; dx < _w - _p; dx += 14) {
      x.drawLine(Offset(dx, y + 6), Offset(dx + 8 > _w - _p ? _w - _p : dx + 8, y + 6), paint);
    }
    y += 22;
  }

  final short = d.outlet.replaceFirst(RegExp(r'^Outlet\s+'), '');
  // logo
  x.drawCircle(Offset(_w / 2, y + 34), 32, Paint()..color = const Color(0xfffff0f2));
  x.drawCircle(
      Offset(_w / 2, y + 34),
      32,
      Paint()
        ..color = const Color(0xffe8493f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
  y += 16;
  center(short.isEmpty ? 'G' : short.substring(0, 1), 34, FontWeight.w900, const Color(0xffe8493f));
  y += 64;
  center(d.outlet.toUpperCase(), 28, FontWeight.w800);
  y += 36;
  center(d.address, 20, FontWeight.w400, const Color(0xff444444));
  y += 28;
  center('WA ${d.wa}', 20, FontWeight.w400, const Color(0xff444444));
  y += 30;
  dash();
  center(d.id, 34, FontWeight.w800, const Color(0xff111111), _mono);
  y += 46;
  if (d.priority) {
    x.drawRect(Rect.fromLTWH(_w / 2 - 70, y, 140, 32), Paint()..color = const Color(0xff111111));
    y += 6;
    center('PRIORITAS', 20, FontWeight.w800, Colors.white);
    y += 38;
  }
  row('Pelanggan', d.customer, 22, FontWeight.w700);
  row('No HP', d.phone, 20);
  row('Masuk', d.masuk, 20);
  row('Estimasi', d.due, 20);
  row('Layanan', d.dur, 20);
  row('Kasir', d.kasir, 20);
  dash();
  row('ITEM / QTY x HARGA', 'SUBTOTAL', 18, FontWeight.w800);
  y += 2;
  final qty = <String, double>{};
  for (final it in d.items) {
    tp('${it[0]}', 22, FontWeight.w700, const Color(0xff111111), _mono).paint(x, Offset(_p, y));
    y += 30;
    row('  ${it[1]} x ${thousands(it[2] as num)}', rpSpaced(it[3] as num), 20);
    qty['${it[5]}'] = (qty['${it[5]}'] ?? 0) + (it[4] as num).toDouble();
  }
  dash();
  row('Jumlah item', '${d.items.length} layanan', 20, FontWeight.w700);
  row('Total qty', qty.isEmpty ? '-' : qty.entries.map((e) => '${qtyText(e.value)} ${e.key}').join(' · '), 20);
  row('Subtotal', rpSpaced(d.sub), 20);
  row('Diskon', d.disc > 0 ? '- ${rpSpaced(d.disc)}' : 'Rp 0', 20);
  dash();
  row('Parfum', d.perfume, 20);
  row('Penyerahan', d.handover, 20);
  if (d.note.isNotEmpty) {
    row('Catatan', '', 20);
    y -= 4;
    tp(d.note.length > 44 ? d.note.substring(0, 44) : d.note, 19, FontWeight.w400, const Color(0xff111111), _mono).paint(x, Offset(_p, y));
    y += 28;
  }
  dash();
  row('TOTAL', rpSpaced(d.total), 30, FontWeight.w800);
  row('Status', d.status, 22, FontWeight.w800);
  row('Metode', d.method, 20);
  dash();
  // barcode
  final pat = code128Pattern(d.id);
  var mod = 0;
  for (var i = 0; i < pat.length; i++) {
    mod += int.parse(pat[i]);
  }
  final raw = ((_w - 2 * _p - 40) / mod).floorToDouble();
  final bw = raw < 2 ? 2.0 : raw;
  var cx = (_w - mod * bw) / 2;
  final black = Paint()..color = Colors.black;
  for (var j = 0; j < pat.length; j++) {
    final w = int.parse(pat[j]) * bw;
    if (j.isEven) x.drawRect(Rect.fromLTWH(cx, y, w, 90), black);
    cx += w;
  }
  y += 98;
  center(d.id, 20, FontWeight.w700, const Color(0xff111111), _mono);
  y += 36;
  // QR
  const qs = 232.0;
  x.save();
  x.translate((_w - qs) / 2, y);
  QrPainter(data: 'https://goyana.id/s/${d.id}', version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.M, gapless: true).paint(x, const Size(qs, qs));
  x.restore();
  y += qs + 14;
  center('Scan QR untuk cek status cucian', 21, FontWeight.w700);
  y += 30;
  center('goyana.id/s/${d.id}', 18, FontWeight.w400, const Color(0xff555555), _mono);
  y += 34;
  dash();
  center('Terima kasih telah mencuci di $short', 20, FontWeight.w400, const Color(0xff333333));
  y += 28;
  center('Simpan struk ini untuk pengambilan cucian', 18, FontWeight.w400, const Color(0xff666666));
  y += 34;
  center('Dibuat dengan GOYANA', 16, FontWeight.w700, const Color(0xffe8493f));
  y += 40;
  return y;
}

/// PNG struk (lebar 576 px).
Future<Uint8List> receiptPng(ReceiptData d) async {
  // Langkah 1: ukur tinggi; langkah 2: gambar di atas latar putih setinggi itu.
  final probe = ui.PictureRecorder();
  final h = paintReceipt(Canvas(probe), d);
  probe.endRecording().dispose();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, _w, h), Paint()..color = Colors.white);
  paintReceipt(canvas, d);
  final pic = rec.endRecording();
  final img = await pic.toImage(_w.toInt(), h.ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  pic.dispose();
  img.dispose();
  return bytes!.buffer.asUint8List();
}
