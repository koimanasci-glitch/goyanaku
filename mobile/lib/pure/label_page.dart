// Cetak Label Cucian (HTML v137 #printlabel): pilih pesanan, jumlah kantong, ukuran label,
// pratinjau per kantong (barcode Code128 "ID/k"), Cek Kantong (bg137) dan Cetak Label.

import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/receipt.dart';
import 'pages.dart';
import 'receipt_image.dart';

const _proc = ['cuci', 'kering', 'setrika', 'packing'];
const labelSizes = ['50×30 mm', '40×30 mm', 'Struk 58 mm'];

/// Barcode Code128 sebagai SVG (lebar modul 1, tepi kosong 10).
String code128Svg(String text) {
  final pat = code128Pattern(text);
  final rects = StringBuffer();
  var x = 10;
  for (var j = 0; j < pat.length; j++) {
    final w = int.parse(pat[j]);
    if (j.isEven) rects.write('<rect x="$x" y="0" width="$w" height="40"></rect>');
    x += w;
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${x + 10} 40" preserveAspectRatio="none" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"></rect><g fill="#000">$rects</g></svg>';
}

class LabelPage extends PurePage {
  LabelPage(super.host);
  String query = '';
  String? orderId;
  int bags = 1;
  int size = 0;
  final Set<String> scanned = {};
  String scanText = '';

  @override
  String get title => 'CETAK LABEL CUCIAN';
  @override
  String get back => 'orders';
  @override
  int get navActive => 1;

  List<Order> get _orders {
    final q = query.trim().toLowerCase();
    return [
      for (final o in host.business.orders)
        if (!o.isCancelled && o.status != 'diambil' && (q.isEmpty || '${o.name} ${o.id}'.toLowerCase().contains(q))) o,
    ];
  }

  Order? get _order => orderId == null ? _orders.firstOrNull : (host.business.orderById(orderId!) ?? _orders.firstOrNull);

  /// Buka dari Rincian Pesanan dengan pesanan ini terpilih.
  void select(Order o) {
    orderId = o.id;
    bags = _printed(o) > 0 ? _printed(o) : suggest(o);
    scanned.clear();
  }

  /// Saran jumlah kantong dari berat cucian (± 5 kg per kantong).
  static int suggest(Order o) {
    final kg = o.items.where((it) => it.unit == 'kg').fold<double>(0, (a, it) => a + it.qty);
    return (kg / 5).ceil().clamp(1, 20);
  }

  int _printed(Order o) => int.tryParse('${o.dataset['bags137'] ?? ''}') ?? 0;

  String _status(Order o) => _proc.contains(o.status)
      ? 'Proses'
      : const {'jemput': 'Penjemputan', 'antrian': 'Antrian', 'siap': 'Siap Ambil', 'telat': 'Telat Ambil', 'diantar': 'Diantar'}[o.status] ?? o.status;

  String _outlet() {
    final b = host.business;
    final o = b.outlets.where((x) => x.id == b.activeOutlet).firstOrNull ?? b.outlets.firstOrNull;
    return (o?.name ?? 'GOYANA').toUpperCase();
  }

  @override
  void opened() {
    final o = _order;
    if (o != null && orderId == null) select(o);
  }

  @override
  List<Map<String, dynamic>> items() {
    final list = _orders, o = _order;
    String two(int n) => n.toString().padLeft(2, '0');
    final est = o?.due == null ? '-' : '${two(o!.due!.day)}/${two(o.due!.month)}/${o.due!.year} · ${two(o.due!.hour)}:${two(o.due!.minute)}';
    return [
      {'type': 'title', 't': '🏷️'},
      {'type': 'hint', 't': 'Anti tertukar. Setiap kantong dapat label sendiri (1/3, 2/3, 3/3) dengan barcode Order ID. Saat diambil, scan semua kantong supaya tidak ada yang tertinggal atau tertukar.'},
      {'type': 'title', 't': '1. Pilih pesanan'},
      {'type': 'input', 'v': query, 'ph': 'Nama / Order ID…', 'i': 0},
      {'type': 'button', 't': 'Scan', 'primary': false, 'i': 0},
      for (var k = 0; k < list.length && k < 30; k++)
        {
          'type': 'card', 't': list[k].name, 's': '${list[k].id} · ${list[k].dur} · ${_status(list[k])}', 'svg': '', 'ic': '',
          'badge': _printed(list[k]) > 0 ? '🏷 ${_printed(list[k])} kantong' : 'Belum label', 'meta': '', 'on': list[k].id == o?.id, 'i': 100 + k,
        },
      if (list.isEmpty) {'type': 'hint', 't': 'Belum ada pesanan aktif.'},
      if (o != null) ...[
        {'type': 'title', 't': '2. Jumlah kantong'},
        {'type': 'stepper', 'v': '$bags', 'minus': 2, 'plus': 3, 'mt': '−', 'pt': '+', 't': '$bags kantong', 's': 'Saran otomatis dari berat cucian'},
        {'type': 'buttons', 'options': [for (var k = 0; k < labelSizes.length; k++) {'t': labelSizes[k], 'on': size == k, 'i': 4 + k}]},
        {'type': 'title', 't': '3. Pratinjau label', 's': 'geser →'},
        for (var k = 1; k <= bags; k++)
          {
            'type': 'labelprev',
            'lines': ['GOYANA · ${_outlet()}', o.name, '$k/$bags KANTONG', '${o.dur} · Est $est · ${o.isPaid ? 'LUNAS' : 'BELUM BAYAR'}', '${o.id}/$k'],
            'svg': code128Svg('${o.id}/$k'),
          },
        {'type': 'buttons', 'options': [{'t': '✓ Cek Kantong', 'on': false, 'i': 7}, {'t': '🖨 Cetak Label', 'on': false, 'i': 8}]},
      ],
      {'type': 'button', 't': 'Lewati, kembali ke pesanan', 'primary': false, 'i': 9},
    ];
  }

  @override
  void input(int i, Object value) {
    query = '$value';
    host.refresh();
  }

  @override
  void button(int i) {
    final o = _order;
    if (i >= 100) {
      final list = _orders;
      if (i - 100 < list.length) select(list[i - 100]);
      return host.refresh();
    }
    switch (i) {
      case 0:
        host.scanCode();
      case 2:
        bags = (bags - 1).clamp(1, 20);
        scanned.clear();
      case 3:
        bags = (bags + 1).clamp(1, 20);
        scanned.clear();
      case 4:
      case 5:
      case 6:
        size = i - 4;
      case 7:
        if (o == null) return host.toast('Pilih pesanan dulu');
        scanText = '';
        return host.openPageSheet('bg137');
      case 8:
        if (o == null) return host.toast('Pilih pesanan dulu');
        o.dataset['bags137'] = '$bags';
        host.saveAll();
        host.printText(labelText(o, host.settings.receipt, bags), '${o.id} label', '$bags label kantong dicetak · ${o.id}');
      case 9:
        return host.go('orders');
    }
    host.refresh();
  }

  // ---------- Cek Kelengkapan Kantong (bg137) ----------
  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    final o = _order;
    if (id != 'bg137' || o == null) return null;
    return [
      {'type': 'title', 't': 'Cek Kelengkapan Kantong', 's': ''},
      {'type': 'hint', 't': '${o.id} · ${o.name} · ${scanned.length}/$bags kantong terscan'},
      {'type': 'buttons', 'options': [for (var k = 1; k <= bags; k++) {'t': '${scanned.contains('$k') ? '✓ ' : ''}$k/$bags', 'on': scanned.contains('$k'), 'i': 10 + k}]},
      {'type': 'input', 'v': scanText, 'ph': 'Scan / ketik kode label', 'i': 0},
      {'type': 'button', 't': '📷', 'primary': false, 'i': 0},
      {'type': 'button', 't': 'Selesai', 'primary': true, 'i': 1},
    ];
  }

  void _mark(String k) {
    final o = _order;
    if (o == null) return;
    final n = int.tryParse(k) ?? 0;
    if (n < 1 || n > bags) return host.toast('Label bukan milik pesanan ini');
    if (!scanned.add('$n')) return host.toast('Kantong $n/$bags sudah terscan');
    HapticFeedback.selectionClick();
    host.toast(scanned.length == bags ? 'Lengkap ✓ · $bags/$bags kantong ${o.id}' : 'Kantong $n/$bags ✓ · kurang ${bags - scanned.length}');
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    final o = _order;
    if (id != 'bg137' || o == null) return;
    if (kind == 'input') {
      scanText = '${value ?? ''}'.trim();
      final m = RegExp('^${RegExp.escape(o.id)}/(\\d+)\$', caseSensitive: false).firstMatch(scanText);
      if (m != null) {
        _mark(m.group(1)!);
        scanText = '';
        host.refresh();
      }
      return;
    }
    if (kind != 'button') return;
    if (index > 10) {
      _mark('${index - 10}');
      return host.refresh();
    }
    if (index == 0) return host.scanCode();
    if (scanned.length < bags && scanned.isNotEmpty) host.toast('Masih kurang ${bags - scanned.length} kantong');
    host.closePageSheet('bg137');
  }
}
