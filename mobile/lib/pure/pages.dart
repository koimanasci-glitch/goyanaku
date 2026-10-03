// Halaman formulir mode murni: Pengaturan, Profil Struk, Printer, QRIS, Rekening, Layanan, Parfum, Kas, Tutup Kasir.
// Tiap halaman membangun butir formulir (NativeForm) dan menangani aksinya sendiri dengan logika Dart.

import 'package:flutter/services.dart';

import '../core/business.dart';
import '../core/money.dart';
import '../core/qris.dart';
import '../core/receipt.dart';
import '../core/settings.dart';

/// Yang dibutuhkan halaman dari shell.
abstract class PureHost {
  Business get business;
  AppSettings get settings;
  DateTime get now;
  void toast(String text);
  void go(String page);
  void refresh();
  Future<void> saveAll();
  void exitPure();
  MethodChannel get device;
}

abstract class PurePage {
  PurePage(this.host);
  final PureHost host;
  String get title;
  String get back => 'settings';
  int get navActive => 3;
  List<Map<String, dynamic>> items();
  void input(int i, Object value) {}
  void toggle(int i) {}
  void radio(int i) {}
  void button(int i) {}
  void opened() {}
}

Map<String, dynamic> card(String t, String s, String ic, int i) => {'type': 'card', 't': t, 's': s, 'ic': ic, 'i': i};

class SettingsPage extends PurePage {
  SettingsPage(super.host);
  @override
  String get title => 'Pengaturan';
  @override
  String get back => 'home';
  static const _pages = ['receipt', 'printer', 'qris', 'bank', 'services', 'perfume', 'kas', 'customers', 'outlet'];
  @override
  List<Map<String, dynamic>> items() {
    final s = host.settings;
    return [
      {'type': 'entry', 't': 'GOYANA Mode Murni (beta)', 'lines': ['Tanpa WebView · lebih ringan & cepat'], 'avatar': '⚡'},
      {'type': 'title', 't': 'Toko & Struk'},
      card('Profil Outlet', host.business.outlets.isEmpty ? 'Belum diatur' : host.business.outlets.first.name, '🏪', 8),
      card('Profil Struk', s.receipt.header, '🧾', 0),
      card('Printer Bluetooth', s.printerName.isEmpty ? 'Belum terhubung' : s.printerName, '🖨', 1),
      {'type': 'title', 't': 'Pembayaran'},
      card('QRIS Outlet', s.qrisText.isEmpty ? 'Belum diatur' : (qrisValid(s.qrisText) ? 'Aktif · ${qrisMerchant(s.qrisText).name}' : 'QRIS tidak valid'), '▦', 2),
      card('Rekening Transfer', s.bank.isEmpty ? 'Belum diatur' : '${s.bank} · ${s.account}', '⇄', 3),
      {'type': 'title', 't': 'Operasional'},
      card('Layanan & Harga', '${host.business.services.length} layanan', '🧺', 4),
      card('Parfum', '${s.perfumes.length} parfum', '🌸', 5),
      card('Kas & Tutup Kasir', 'Kas masuk, pengeluaran, tutup shift', '💰', 6),
      card('Pelanggan', '${host.business.customers.length} pelanggan', '👥', 7),
      {'type': 'title', 't': 'Lainnya'},
      card('Kembali ke versi lengkap', 'Menu yang belum dipindahkan · data tetap sama', '↩', 99),
    ];
  }

  @override
  void button(int i) {
    if (i == 99) return host.exitPure();
    if (i >= 0 && i < _pages.length) host.go(_pages[i]);
  }
}

class ReceiptPage extends PurePage {
  ReceiptPage(super.host);
  late Map<String, Object> f;
  @override
  String get title => 'Profil Struk';
  @override
  void opened() {
    final r = host.settings.receipt;
    f = {'header': r.header, 'address': r.address, 'phone': r.phone, 'footer': r.footer, 'width': r.width, 'showDue': r.showDue};
  }

  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'label', 't': 'Nama di struk (header)'},
        {'type': 'input', 'v': '${f['header']}', 'ph': 'Contoh: Goyana Laundry', 'i': 0},
        {'type': 'label', 't': 'Alamat outlet'},
        {'type': 'input', 'v': '${f['address']}', 'ph': 'Alamat', 'multiline': true, 'i': 1},
        {'type': 'label', 't': 'No. WhatsApp outlet'},
        {'type': 'input', 'v': '${f['phone']}', 'ph': '08…', 'numeric': true, 'i': 2},
        {'type': 'label', 't': 'Catatan bawah struk'},
        {'type': 'input', 'v': '${f['footer']}', 'ph': 'Terima kasih', 'i': 3},
        {'type': 'hint', 't': 'Hindari emoji pada struk agar terbaca di printer thermal.'},
        {'type': 'toggle', 't': 'Tampilkan estimasi selesai', 'on': f['showDue'] == true, 'i': 0},
        {'type': 'choice', 't': 'Ukuran printer', 'options': [{'t': '58 mm', 'on': f['width'] == 32, 'i': 0}, {'t': '80 mm', 'on': f['width'] == 48, 'i': 1}]},
        {'type': 'button', 't': 'SIMPAN', 'primary': true, 'i': 0},
      ];
  @override
  void input(int i, Object value) => f[const ['header', 'address', 'phone', 'footer'][i.clamp(0, 3)]] = '$value';
  @override
  void toggle(int i) => f['showDue'] = f['showDue'] != true;
  @override
  void radio(int i) => f['width'] = i == 1 ? 48 : 32;
  @override
  void button(int i) {
    host.settings.receipt = ReceiptSettings(header: '${f['header']}', address: '${f['address']}', phone: '${f['phone']}', footer: '${f['footer']}',
        width: f['width'] as int, showDue: f['showDue'] == true);
    host.saveAll();
    host.toast('Profil struk tersimpan');
    host.go('settings');
  }
}

class PrinterPage extends PurePage {
  PrinterPage(super.host);
  List<Map<String, String>> paired = [];
  String status = 'Memuat…';
  bool connected = false;
  @override
  String get title => 'Printer Bluetooth';
  @override
  void opened() => load();

  Future<void> load() async {
    try {
      final st = await host.device.invokeMapMethod<String, dynamic>('GoyanaDevice.printerStatus');
      connected = st?['connected'] == true;
      final perm = await host.device.invokeMapMethod<String, dynamic>('GoyanaDevice.requestAccess', {'alias': 'bluetooth'});
      if (perm != null && perm['granted'] == false) {
        status = 'Izin perangkat sekitar (Bluetooth) belum diberikan';
      } else {
        final list = await host.device.invokeListMethod<dynamic>('GoyanaDevice.pairedPrinters');
        paired = (list ?? const []).whereType<Map>().map((e) => {'name': '${e['name']}', 'address': '${e['address']}'}).toList();
        status = paired.isEmpty ? 'Belum ada printer yang dipasangkan di Bluetooth HP' : 'Pilih printer';
      }
    } on PlatformException catch (e) {
      status = e.message ?? 'Bluetooth tidak tersedia';
    } catch (_) {
      status = 'Bluetooth tidak tersedia';
    }
    host.refresh();
  }

  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'pair', 't': 'Status', 'v': connected ? 'Terhubung · ${host.settings.printerName}' : 'Tidak terhubung', 'tone': connected ? 'g' : 'r'},
        {'type': 'hint', 't': status},
        for (var k = 0; k < paired.length; k++)
          {'type': 'entry', 't': paired[k]['name'], 'lines': [paired[k]['address']], 'btns': [{'t': host.settings.printerAddress == paired[k]['address'] && connected ? 'Terhubung' : 'Hubungkan', 'i': 10 + k}]},
        {'type': 'button', 't': 'Cari Ulang Printer', 'primary': false, 'i': 0},
        {'type': 'button', 't': 'Tes Cetak', 'primary': true, 'i': 1},
        {'type': 'hint', 't': 'Pasangkan printer dulu di Pengaturan Bluetooth HP, lalu tekan Hubungkan.'},
      ];

  @override
  void button(int i) async {
    if (i == 0) return load();
    if (i == 1) {
      try {
        await host.device.invokeMethod('GoyanaDevice.testPrint');
        host.toast('Tes cetak dikirim');
      } on PlatformException catch (e) {
        host.toast(e.message ?? 'Printer belum terhubung');
      }
      return;
    }
    final k = i - 10;
    if (k < 0 || k >= paired.length) return;
    host.toast('Menghubungkan ${paired[k]['name']}…');
    try {
      await host.device.invokeMethod('GoyanaDevice.connectPrinter', {'address': paired[k]['address']});
      host.settings.setPrinter(paired[k]['address']!, paired[k]['name']!);
      await host.saveAll();
      connected = true;
      host.toast('Printer terhubung');
    } on PlatformException catch (e) {
      host.toast(e.message ?? 'Gagal menghubungkan printer');
    }
    host.refresh();
  }
}

class QrisPage extends PurePage {
  QrisPage(super.host);
  String text = '';
  @override
  String get title => 'QRIS Outlet';
  @override
  void opened() => text = host.settings.qrisText;
  @override
  List<Map<String, dynamic>> items() {
    final ok = qrisValid(text);
    return [
      {'type': 'hint', 't': 'Tempel teks QRIS outlet (isi kode QR). Nominal transaksi diisi otomatis saat kasir memilih QRIS.'},
      if (ok) {'type': 'qr', 'data': text, 'size': 200},
      {'type': 'pair', 't': 'Status', 'v': text.isEmpty ? 'Belum diatur' : (ok ? 'Valid · ${qrisMerchant(text).name}' : 'Tidak valid'), 'tone': ok ? 'g' : 'r'},
      {'type': 'input', 'v': text, 'ph': '00020101021126…', 'multiline': true, 'i': 0},
      {'type': 'buttons', 'options': [{'t': '📋 Tempel', 'i': 1}, {'t': 'Hapus', 'i': 2}]},
      {'type': 'button', 't': 'Simpan QRIS', 'primary': true, 'i': 0},
    ];
  }

  @override
  void input(int i, Object value) {
    text = '$value'.trim();
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 1) {
      final d = await Clipboard.getData('text/plain');
      text = (d?.text ?? '').trim();
      return host.refresh();
    }
    if (i == 2) {
      text = '';
      return host.refresh();
    }
    if (text.isNotEmpty && !qrisValid(text)) return host.toast('Teks QRIS tidak valid');
    host.settings.qrisText = text;
    await host.saveAll();
    host.toast('QRIS tersimpan');
    host.go('settings');
  }
}

class BankPage extends PurePage {
  BankPage(super.host);
  late List<String> f;
  @override
  String get title => 'Rekening Transfer';
  @override
  void opened() => f = [host.settings.bank, host.settings.account, host.settings.holder];
  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'hint', 't': 'Ditampilkan saat kasir memilih Transfer.'},
        {'type': 'input', 'v': f[0], 'ph': 'Nama bank, contoh BCA', 'i': 0},
        {'type': 'input', 'v': f[1], 'ph': 'Nomor rekening', 'numeric': true, 'i': 1},
        {'type': 'input', 'v': f[2], 'ph': 'Nama pemilik rekening', 'i': 2},
        {'type': 'button', 't': 'Simpan', 'primary': true, 'i': 0},
      ];
  @override
  void input(int i, Object value) => f[i.clamp(0, 2)] = '$value'.trim();
  @override
  void button(int i) {
    host.settings.setBank(f[0], f[1], f[2]);
    host.saveAll();
    host.toast('Rekening tersimpan');
    host.go('settings');
  }
}

class ServicesPage extends PurePage {
  ServicesPage(super.host);
  final Map<int, String> _price = {};
  @override
  String get title => 'Layanan & Harga';
  static const durs = ['Reguler', 'Express', 'Kilat'];
  String newName = '', newUnit = 'kg', newPrice = '';

  @override
  List<Map<String, dynamic>> items() {
    final list = host.business.services;
    final out = <Map<String, dynamic>>[];
    for (var s = 0; s < list.length; s++) {
      out.add({'type': 'title', 't': list[s].name, 's': 'per ${list[s].unit}'});
      for (var d = 0; d < durs.length; d++) {
        final idx = s * 10 + d;
        out.add({'type': 'input', 'label': durs[d], 'pre': 'Rp', 'v': _price[idx] ?? '${list[s].priceFor(durs[d])}', 'numeric': true, 'i': idx});
        out.add({'type': 'toggle', 't': '${durs[d]} aktif', 'on': list[s].enabledFor(durs[d]), 'i': idx});
      }
    }
    out.addAll([
      {'type': 'title', 't': 'Tambah layanan'},
      {'type': 'input', 'v': newName, 'ph': 'Nama layanan, contoh: Cuci Sepatu', 'i': 9000},
      {'type': 'choice', 't': 'Satuan', 'options': [
        for (final (k, u) in const ['kg', 'pcs', 'm'].indexed) {'t': u, 'on': newUnit == u, 'i': k},
      ]},
      {'type': 'input', 'label': 'Harga Reguler', 'pre': 'Rp', 'v': newPrice, 'numeric': true, 'i': 9001},
      {'type': 'button', 't': '+ Tambah Layanan', 'primary': false, 'i': 1},
      {'type': 'button', 't': 'Simpan Harga', 'primary': true, 'i': 0},
    ]);
    return out;
  }

  @override
  void input(int i, Object value) {
    if (i == 9000) {
      newName = '$value';
    } else if (i == 9001) {
      newPrice = '$value';
    } else {
      _price[i] = '$value';
    }
  }

  @override
  void toggle(int i) {
    final list = host.business.services;
    final s = i ~/ 10, d = i % 10;
    if (s < list.length && d < durs.length) host.business.toggleService(list[s], durs[d]);
    host.refresh();
  }

  @override
  void radio(int i) {
    newUnit = const ['kg', 'pcs', 'm'][i.clamp(0, 2)];
    host.refresh();
  }

  @override
  void button(int i) async {
    final b = host.business;
    if (i == 1) {
      final err = b.addService(newName, newUnit, parseRupiah(newPrice));
      if (err != null) return host.toast(err);
      newName = '';
      newPrice = '';
      await b.saveServices();
      host.toast('Layanan ditambahkan');
      return host.refresh();
    }
    _price.forEach((idx, v) {
      final s = idx ~/ 10, d = idx % 10;
      if (s < b.services.length && d < durs.length) b.setServicePrice(b.services[s], durs[d], parseRupiah(v));
    });
    _price.clear();
    await b.saveServices();
    host.toast('Harga layanan tersimpan');
    host.go('settings');
  }
}

class PerfumePage extends PurePage {
  PerfumePage(super.host);
  String name = '';
  static const colors = ['rgb(233, 185, 73)', 'rgb(90, 169, 230)', 'rgb(155, 122, 224)', 'rgb(43, 179, 163)', 'rgb(240, 122, 160)', 'rgb(232, 73, 63)'];
  @override
  String get title => 'Parfum';
  @override
  List<Map<String, dynamic>> items() {
    final p = host.settings.perfumes;
    return [
      for (var k = 0; k < p.length; k++)
        {'type': 'entry', 't': p[k][0], 'lines': <String>[], 'compact': true, 'color': p[k].length > 1 ? p[k][1] : '', 'btns': [{'t': '×', 'i': 100 + k}]},
      {'type': 'input', 'v': name, 'ph': 'Nama parfum baru', 'i': 0},
      {'type': 'button', 't': '+ Tambah Parfum', 'primary': true, 'i': 1},
      {'type': 'hint', 't': 'Warna label membantu kasir & bagian produksi mengenali parfum dengan cepat.'},
    ];
  }

  @override
  void input(int i, Object value) => name = '$value'.trim();
  @override
  void button(int i) async {
    final p = host.settings.perfumes;
    if (i >= 100) {
      if (i - 100 < p.length) p.removeAt(i - 100);
    } else {
      if (name.isEmpty) return host.toast('Isi nama parfum');
      p.add([name, colors[p.length % colors.length]]);
      name = '';
    }
    await host.saveAll();
    host.refresh();
  }
}

class KasPage extends PurePage {
  KasPage(super.host);
  @override
  String get title => 'Kas & Tutup Kasir';
  @override
  int get navActive => 2;
  String mode = ''; // '', 'in', 'out', 'close'
  String type = '', amount = '', note = '', physical = '';
  static const inTypes = ['Modal awal', 'Setoran owner', 'Pemasukan lain'];
  static const outTypes = ['Gaji', 'Bahan baku', 'Listrik', 'Air', 'Sewa', 'Lain-lain'];

  @override
  List<Map<String, dynamic>> items() {
    final s = host.business.shift();
    if (mode == 'in' || mode == 'out') {
      final types = mode == 'in' ? inTypes : outTypes;
      return [
        {'type': 'title', 't': mode == 'in' ? 'Kas Masuk' : 'Pengeluaran'},
        {'type': 'select', 'options': ['Pilih jenis…', ...types], 'index': type.isEmpty ? 0 : types.indexOf(type) + 1, 'i': 0},
        {'type': 'input', 'label': 'Jumlah', 'pre': 'Rp', 'v': amount, 'numeric': true, 'i': 1},
        {'type': 'input', 'v': note, 'ph': 'Keterangan', 'i': 2},
        {'type': 'button', 't': 'SIMPAN', 'primary': true, 'i': 10},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 11},
      ];
    }
    if (mode == 'close') {
      final p = parseRupiah(physical);
      return [
        {'type': 'title', 't': 'Tutup Kasir'},
        {'type': 'pair', 't': 'Kas tunai seharusnya', 'v': rpSpaced(s.cashExpected)},
        {'type': 'input', 'label': 'Uang fisik di laci', 'pre': 'Rp', 'v': physical, 'numeric': true, 'i': 3},
        {'type': 'pair', 't': 'Selisih', 'v': physical.isEmpty ? '—' : (p == s.cashExpected ? 'Pas' : (p > s.cashExpected ? 'Lebih ${rp(p - s.cashExpected)}' : 'Kurang ${rp(s.cashExpected - p)}')),
          'tone': physical.isEmpty || p == s.cashExpected ? 'g' : 'r'},
        {'type': 'input', 'v': note, 'ph': 'Catatan (wajib bila ada selisih)', 'i': 2},
        {'type': 'button', 't': 'TUTUP KASIR', 'primary': true, 'i': 12},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 11},
      ];
    }
    final hist = (host.business.kas['hist'] as List? ?? const []).whereType<Map>().take(10).toList();
    return [
      {'type': 'hero', 't': 'Penjualan shift ini', 'v': rpSpaced(s.sales), 's': 'Kas tunai seharusnya ${rpSpaced(s.cashExpected)}'},
      {'type': 'stats', 'cells': [
        for (final m in s.byMethod.entries) {'v': rp(m.value), 't': m.key},
      ]},
      {'type': 'pair', 't': 'Modal awal', 'v': rpSpaced(s.start)},
      {'type': 'pair', 't': 'Kas masuk', 'v': rpSpaced(s.ins), 'tone': 'g'},
      {'type': 'pair', 't': 'Pengeluaran', 'v': rpSpaced(s.outs), 'tone': 'r'},
      {'type': 'buttons', 'options': [{'t': '+ Kas Masuk', 'i': 1}, {'t': '− Pengeluaran', 'i': 2}]},
      {'type': 'button', 't': 'Tutup Kasir', 'primary': true, 'i': 3},
      if (hist.isNotEmpty) {'type': 'title', 't': 'Riwayat shift'},
      for (final h in hist)
        {'type': 'pair', 't': '${DateTime.tryParse('${h['at']}')?.toLocal().toString().substring(0, 16) ?? ''} · ${h['kasir']}', 'v': (h['diff'] as num? ?? 0) == 0 ? 'Pas' : 'Selisih ${rp(h['diff'] as num)}', 'tone': (h['diff'] as num? ?? 0) == 0 ? 'g' : 'r'},
    ];
  }

  @override
  void input(int i, Object value) {
    switch (i) {
      case 0:
        final types = mode == 'in' ? inTypes : outTypes;
        final k = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
        type = k > 0 && k <= types.length ? types[k - 1] : '';
      case 1:
        amount = '$value';
      case 2:
        note = '$value';
      case 3:
        physical = '$value';
        host.refresh();
    }
  }

  void _reset(String m) {
    mode = m;
    type = '';
    amount = '';
    note = '';
    physical = '';
    host.refresh();
  }

  @override
  void button(int i) async {
    final b = host.business;
    switch (i) {
      case 1:
        return _reset('in');
      case 2:
        return _reset('out');
      case 3:
        return _reset('close');
      case 11:
        return _reset('');
      case 10:
        if (type.isEmpty || parseRupiah(amount) <= 0) return host.toast('Pilih jenis dan isi jumlah');
        b.kasEntry(income: mode == 'in', type: type, amount: parseRupiah(amount), note: note, now: host.now);
        if (mode == 'in' && type == 'Modal awal') b.kas['start'] = parseRupiah(b.kas['start']) + parseRupiah(amount);
        await host.saveAll();
        host.toast(mode == 'in' ? 'Kas masuk tersimpan' : 'Pengeluaran tersimpan');
        return _reset('');
      case 12:
        if (physical.isEmpty) return host.toast('Hitung uang fisik dulu');
        final s = b.shift();
        if (parseRupiah(physical) != s.cashExpected && note.trim().isEmpty) return host.toast('Isi catatan karena ada selisih');
        b.closeShift(physical: parseRupiah(physical), note: note, now: host.now);
        await host.saveAll();
        host.toast('Kas ditutup · shift baru dimulai');
        return _reset('');
    }
  }
}

class ReportsPage extends PurePage {
  ReportsPage(super.host);
  int period = 2; // 0 hari ini, 1 7 hari, 2 30 hari, 3 bulan ini
  static const periods = ['Hari ini', '7 hari', '30 hari', 'Bulan ini'];
  @override
  String get title => 'Laporan';
  @override
  String get back => 'home';
  @override
  int get navActive => 2;

  DateTime get _from {
    final n = host.now, d = DateTime(n.year, n.month, n.day);
    return switch (period) { 0 => d, 1 => d.subtract(const Duration(days: 6)), 3 => DateTime(n.year, n.month), _ => d.subtract(const Duration(days: 29)) };
  }

  @override
  List<Map<String, dynamic>> items() {
    final b = host.business, from = _from;
    bool inRange(DateTime? t) => t != null && !t.isBefore(from);
    final orders = b.orders.where((o) => !o.isCancelled && inRange(o.created)).toList();
    final omzet = orders.fold<int>(0, (a, o) => a + o.total);
    final piutang = b.orders.where((o) => !o.isCancelled).fold<int>(0, (a, o) => a + o.remaining);
    // Pemasukan dari pembayaran pesanan (semua shift, menurut tanggal bayar).
    final byMethod = <String, int>{'Tunai': 0, 'QRIS': 0, 'Transfer': 0, 'Deposit': 0};
    for (final o in b.orders) {
      for (final p in o.payments) {
        final at = DateTime.tryParse('${p['at']}')?.toLocal();
        if (inRange(at)) byMethod['${p['m']}'] = (byMethod['${p['m']}'] ?? 0) + parseRupiah(p['a']);
      }
    }
    final income = byMethod.values.fold<int>(0, (a, v) => a + v);
    var expense = 0;
    for (final e in (b.kas['outs'] as List? ?? const []).whereType<Map>()) {
      if (inRange(DateTime.tryParse('${e['at']}')?.toLocal())) expense += parseRupiah(e['a']);
    }
    // Per layanan & per hari.
    final perService = <String, List<num>>{};
    for (final o in orders) {
      for (final it in o.items) {
        final r = perService.putIfAbsent(it.name, () => [0, 0]);
        r[0] += it.qty;
        r[1] += it.subtotal;
      }
    }
    final days = period == 0 ? 1 : (host.now.difference(from).inDays + 1).clamp(1, 31);
    final perDay = List<int>.filled(days, 0);
    for (final o in orders) {
      final i = o.created!.difference(from).inDays;
      if (i >= 0 && i < days) perDay[i] += o.total;
    }
    final maxDay = perDay.fold<int>(1, (a, v) => v > a ? v : a);
    final maxMethod = byMethod.values.fold<int>(1, (a, v) => v > a ? v : a);
    return [
      {'type': 'buttons', 'options': [for (var k = 0; k < periods.length; k++) {'t': periods[k], 'on': k == period, 'i': k}]},
      {'type': 'stats', 'cells': [
        {'v': rp(omzet), 't': 'Omset'}, {'v': rp(income), 't': 'Pemasukan', 'tone': 'g'}, {'v': rp(piutang), 't': 'Piutang', 'tone': 'r'},
        {'v': rp(expense), 't': 'Pengeluaran', 'tone': 'r'}, {'v': rp(income - expense), 't': 'Laba (kas)', 'tone': income >= expense ? 'g' : 'r'}, {'v': '${orders.length}', 't': 'Pesanan'},
      ]},
      if (days > 1) ...[
        {'type': 'title', 't': 'Omset per hari'},
        {'type': 'bars', 'bars': [
          for (var k = 0; k < days; k++)
            {'v': perDay[k] == 0 ? '' : thousands(perDay[k] ~/ 1000), 't': days <= 7 || k % 5 == 0 ? '${from.add(Duration(days: k)).day}' : '', 'h': perDay[k] / maxDay},
        ]},
      ],
      {'type': 'title', 't': 'Per metode bayar'},
      {'type': 'hbars', 'bars': [for (final m in byMethod.entries) {'t': m.key, 'v': rp(m.value), 'w': m.value / maxMethod}]},
      {'type': 'title', 't': 'Per layanan', 's': '${perService.length} layanan'},
      if (perService.isEmpty) {'type': 'hint', 't': 'Belum ada transaksi di periode ini.'},
      if (perService.isNotEmpty)
        {'type': 'table', 'rows': [
          [{'t': 'Layanan', 'h': true, 'b': true}, {'t': 'Jumlah', 'h': true, 'b': true, 'n': true}, {'t': 'Nilai', 'h': true, 'b': true, 'n': true}],
          for (final e in (perService.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]))))
            [{'t': e.key}, {'t': qtyText(e.value[0]), 'n': true}, {'t': rp(e.value[1]), 'n': true}],
        ]},
      {'type': 'title', 't': 'Pesanan terbaru'},
      {'type': 'table', 'rows': [
        [{'t': 'ID', 'h': true, 'b': true}, {'t': 'Pelanggan', 'h': true, 'b': true}, {'t': 'Total', 'h': true, 'b': true, 'n': true}],
        for (final o in orders.take(30)) [{'t': o.id}, {'t': o.name}, {'t': rp(o.total), 'n': true}],
      ]},
      {'type': 'card', 't': 'Kas & Tutup Kasir', 's': 'Kas masuk, pengeluaran, tutup shift', 'ic': '💰', 'i': 20},
    ];
  }

  @override
  void button(int i) {
    if (i == 20) return host.go('kas');
    if (i >= 0 && i < periods.length) {
      period = i;
      host.refresh();
    }
  }
}

class OutletPage extends PurePage {
  OutletPage(super.host);
  late List<String> f;
  @override
  String get title => 'Profil Outlet';
  @override
  void opened() {
    final o = host.business.outlets.isEmpty ? null : host.business.outlets.firstWhere((x) => x.id == host.business.activeOutlet, orElse: () => host.business.outlets.first);
    f = [o?.name ?? '', o?.address ?? '', o?.phone ?? ''];
  }

  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'label', 't': 'Nama Outlet'},
        {'type': 'input', 'v': f[0], 'ph': 'Nama outlet', 'i': 0},
        {'type': 'label', 't': 'Alamat'},
        {'type': 'input', 'v': f[1], 'ph': 'Alamat outlet', 'multiline': true, 'i': 1},
        {'type': 'label', 't': 'No. WhatsApp Outlet'},
        {'type': 'input', 'v': f[2], 'ph': '08…', 'numeric': true, 'i': 2},
        {'type': 'button', 't': 'Simpan Perubahan', 'primary': true, 'i': 0},
      ];
  @override
  void input(int i, Object value) => f[i.clamp(0, 2)] = '$value'.trim();
  @override
  void button(int i) async {
    if (f[0].isEmpty) return host.toast('Nama outlet wajib diisi');
    if (f[2].isNotEmpty && f[2].replaceAll(RegExp(r'[^0-9]'), '').length < 10) return host.toast('Nomor WA minimal 10 digit');
    await host.business.saveOutlet(name: f[0], address: f[1], phone: f[2]);
    host.toast('Outlet tersimpan');
    host.go('settings');
  }
}
