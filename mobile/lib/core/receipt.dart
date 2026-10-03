// Struk pesanan untuk printer thermal (58 mm = 32 kolom, 80 mm = 48 kolom) dan untuk dibagikan (WA).

import 'models.dart';
import 'money.dart';

class ReceiptSettings {
  const ReceiptSettings({this.header = 'GOYANA Laundry', this.address = '', this.phone = '', this.footer = 'Terima kasih 🙏', this.width = 32, this.showDue = true});
  factory ReceiptSettings.fromJson(Map<String, dynamic> j) => ReceiptSettings(
        header: '${j['header'] ?? 'GOYANA Laundry'}', address: '${j['address'] ?? ''}', phone: '${j['phone'] ?? ''}',
        footer: '${j['footer'] ?? 'Terima kasih'}', width: (j['width'] as num?)?.toInt() == 48 ? 48 : 32, showDue: j['showDue'] != false,
      );
  final String header, address, phone, footer;
  final int width;
  final bool showDue;
  Map<String, dynamic> toJson() => {'header': header, 'address': address, 'phone': phone, 'footer': footer, 'width': width, 'showDue': showDue};
}

String _two(int n) => n.toString().padLeft(2, '0');
String _dt(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Printer thermal umumnya tidak punya emoji/simbol khusus: buang karakter di luar Latin-1.
String _plain(String s) => String.fromCharCodes(s.runes.where((r) => r < 256)).replaceAll(RegExp(r'\s+'), ' ').trim();

String _center(String s, int w) {
  s = _plain(s);
  if (s.length >= w) return s.substring(0, w);
  final pad = (w - s.length) ~/ 2;
  return '${' ' * pad}$s';
}

String _lr(String l, String r, int w) {
  l = _plain(l);
  r = _plain(r);
  final space = w - l.length - r.length;
  if (space >= 1) return '$l${' ' * space}$r';
  final cut = (w - r.length - 1).clamp(0, l.length);
  return '${l.substring(0, cut)} $r';
}

List<String> _wrap(String s, int w) {
  final out = <String>[];
  var line = '';
  for (final word in _plain(s).split(' ')) {
    if (line.isEmpty) {
      line = word;
    } else if (line.length + 1 + word.length <= w) {
      line = '$line $word';
    } else {
      out.add(line);
      line = word;
    }
    while (line.length > w) {
      out.add(line.substring(0, w));
      line = line.substring(w);
    }
  }
  if (line.isNotEmpty) out.add(line);
  return out;
}

/// Teks struk siap kirim ke printer Bluetooth (GoyanaDevice.printText).
String receiptText(Order o, ReceiptSettings s, {DateTime? printedAt}) {
  final w = s.width, rule = '-' * w;
  final t = o.totals;
  final lines = <String>[
    _center(s.header, w),
    for (final a in _wrap(s.address, w)) _center(a, w),
    if (s.phone.isNotEmpty) _center('WA ${s.phone}', w),
    rule,
    _lr('No', o.id, w),
    _lr('Pelanggan', o.name, w),
    if (o.masuk != null) _lr('Masuk', _dt(o.masuk!), w),
    if (s.showDue && o.due != null) _lr('Estimasi', _dt(o.due!), w),
    _lr('Layanan', o.dur, w),
    rule,
    for (final it in o.items) ...[
      ..._wrap(it.name, w),
      _lr('  ${qtyText(it.qty)} ${it.unit} x ${thousands(it.price)}', thousands(it.subtotal), w),
    ],
    rule,
    _lr('Subtotal', thousands(t.sub), w),
    if (t.disc > 0) _lr('Diskon', '-${thousands(t.disc)}', w),
    if (o.ongkir > 0) _lr('Ongkir', thousands(o.ongkir), w),
    _lr('TOTAL', rp(t.total), w),
    _lr('Dibayar', rp(o.paid), w),
    if (!o.isPaid) _lr('Sisa', rp(o.remaining), w),
    _lr('Status', o.isPaid ? 'LUNAS' : (o.paid > 0 ? 'DP' : 'BELUM BAYAR'), w),
    if (o.perfume.isNotEmpty && o.perfume != 'Tanpa Parfum') _lr('Parfum', o.perfume, w),
    if (o.note.isNotEmpty && o.note != '-') ..._wrap('Catatan: ${o.note}', w),
    rule,
    for (final f in _wrap(s.footer, w)) _center(f, w),
    if (printedAt != null) _center('Dicetak ${_dt(printedAt)}', w),
  ];
  return lines.join('\n');
}

/// Label kantong: satu label per kantong ("1/3", "2/3", ...), ditempel di plastik cucian.
String labelText(Order o, ReceiptSettings s, int count) {
  final w = s.width, rule = '=' * w;
  final n = count.clamp(1, 20);
  final out = <String>[];
  for (var k = 1; k <= n; k++) {
    out.addAll([
      rule,
      _center(o.id, w),
      _center(o.name.length > w ? o.name.substring(0, w) : o.name, w),
      _center('${o.dur} · Kantong $k/$n', w),
      if (o.due != null) _center('Selesai ${o.due!.day}/${o.due!.month} ${o.due!.hour.toString().padLeft(2, '0')}:${o.due!.minute.toString().padLeft(2, '0')}', w),
      if (o.perfume.isNotEmpty && o.perfume != '-') _center('Parfum: ${o.perfume}', w),
      rule,
      '',
      '',
    ]);
  }
  return out.join('\n');
}
