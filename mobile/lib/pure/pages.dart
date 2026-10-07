// Halaman formulir mode murni: Pengaturan, Profil Struk, Printer, QRIS, Rekening, Layanan, Parfum, Kas, Tutup Kasir.
// Tiap halaman membangun butir formulir (NativeForm) dan menangani aksinya sendiri dengan logika Dart.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/business.dart';
import '../core/models.dart' show durationOverrides;
import '../core/money.dart';
import '../core/qris.dart';
import '../core/receipt.dart';
import '../core/settings.dart';
import '../core/stock.dart';
import '../core/store.dart';
import '../native/form_page.dart' show FormActions;
import '../native/duration_page.dart';
import '../native/perfume_page.dart';
import 'mirror_pages.dart';

/// Yang dibutuhkan halaman dari shell.
abstract class PureHost {
  void openOrder(String id);
  KvStore get kv;
  Business get business;
  AppSettings get settings;
  DateTime get now;
  void toast(String text);
  void go(String page);
  void refresh();
  Future<void> saveAll();
  void exitPure();
  MethodChannel get device;
  void openFormSheet(FormSheetDef def);
  void closeFormSheet();
}

/// Isian popup serbaguna (formSheet107 di HTML): judul, keterangan, isian teks/angka atau pilihan warna.
class FormSheetField {
  const FormSheetField(this.label, {this.placeholder = '', this.value = '', this.numeric = false, this.required = false, this.colors});
  final String label, placeholder, value;
  final bool numeric, required;
  /// Bila diisi: pilihan warna (hex); [value] = warna terpilih.
  final List<String>? colors;
}

class FormSheetDef {
  FormSheetDef(this.title, this.fields, this.okText, this.onOk, {this.sub = '', this.danger = false});
  final String title, sub, okText;
  final List<FormSheetField> fields;
  final bool danger;
  /// Mengembalikan false bila popup harus tetap terbuka.
  final bool? Function(List<String> values) onOk;
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
  /// Jika tidak null, dipakai menggantikan NativeForm (halaman cermin yang sama dengan Hibrida).
  Widget? custom(BuildContext context, FormActions actions) => null;
}

Map<String, dynamic> card(String t, String s, String ic, int i) => {'type': 'card', 't': t, 's': s, 'ic': ic, 'i': i};

class SettingsPage extends PurePage {
  SettingsPage(super.host);
  @override
  String get title => 'Pengaturan';
  @override
  String get back => 'home';
  static const _pages = ['receipt', 'printer', 'qris', 'bank', 'services', 'perfume', 'kas', 'customers', 'outlet', 'data', 'stock', 'couriers', 'discounts', 'employees', 'help',
    'crm', 'whatsapp', 'outlets', 'notif', 'plan'];
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
      card('Pusat Data', 'Ekspor Excel/CSV & cadangan data', '☁', 9),
      card('Stok Bahan', 'Bahan, mutasi, opname', '📦', 10),
      card('Kurir', 'Tugas antar-jemput & data kurir', '🛵', 11),
      card('Diskon', 'Potongan yang bisa dipilih kasir', '🏷', 12),
      card('Pegawai & PIN', 'Kunci aplikasi, nama kasir di riwayat', '👤', 13),
      card('CRM Pelanggan', 'Pengingat cucian, poin member, voucher', '💌', 15),
      card('WhatsApp', 'Template nota & pengingat', '💬', 16),
      card('Cabang & Monitoring', '${host.business.outlets.length} outlet', '🏬', 17),
      card('Notifikasi', 'Terlambat, siap diambil, piutang', '🔔', 18),
      card('Paket GOYANA', 'Lihat & aktifkan paket', '⭐', 19),
      card('Pusat Bantuan', 'Panduan & hubungi support', '❓', 14),
      {'type': 'title', 't': 'Lainnya'},
      card('Versi lama (HTML)', 'Cadangan sementara · data tetap sama', '↩', 99),
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
  static const colors = ['#e9b949', '#5aa9e6', '#9b7ae0', '#2bb3a3', '#f07aa0', '#E8493F', '#8A8FA3'];
  @override
  String get title => 'Parfum';

  static String _hex(String css) {
    final m = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(css);
    if (m == null) return css.startsWith('#') ? css : '#e8493f';
    String h(int k) => int.parse(m.group(k)!).toRadixString(16).padLeft(2, '0');
    return '#${h(1)}${h(2)}${h(3)}';
  }

  static String _rgb(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return hex;
    return 'rgb(${int.parse(h.substring(0, 2), radix: 16)}, ${int.parse(h.substring(2, 4), radix: 16)}, ${int.parse(h.substring(4, 6), radix: 16)})';
  }

  /// Botol parfum yang sama dengan ikon HTML; badan botol berwarna label.
  static String bottle(String color) =>
      '<svg viewBox="0 0 48 48" width="28" height="28" aria-hidden="true"><rect x="19" y="4" width="10" height="7" rx="2" fill="#ffc857"></rect><rect x="21" y="10" width="6" height="5" fill="#e8a93a"></rect><rect x="10" y="15" width="28" height="28" rx="7" fill="${_hex(color)}"></rect><rect x="10" y="15" width="28" height="28" rx="7" fill="#ffffff" opacity=".15"></rect><rect x="15" y="25" width="18" height="10" rx="2" fill="#ffffff"></rect><path d="M18 30h12" stroke="#9b7ae0" stroke-width="2"></path><path d="M14 20a4 4 0 0 1 4-2" stroke="#ffffff" stroke-width="2" fill="none" stroke-linecap="round"></path></svg>';

  @override
  List<Map<String, dynamic>> items() => const [];

  @override
  Widget? custom(BuildContext context, FormActions actions) => NativePerfumePage(
        key: const ValueKey('pure-perfume'),
        model: perfumeMirror(host.settings.perfumes, bottle),
        onButton: button,
        onNav: actions.nav,
        onHeaderScan: actions.scan,
      );

  @override
  void button(int i) {
    final p = host.settings.perfumes;
    if (i == 1) return host.go('settings');
    if (i == 2) {
      return host.openFormSheet(FormSheetDef(
        'Tambah Parfum',
        [
          const FormSheetField('Nama parfum', placeholder: 'Contoh: Vanilla', required: true),
          const FormSheetField('Warna label', value: '#E8493F', colors: colors),
        ],
        'Tambah',
        (v) {
          p.add([v[0], _rgb(v[1])]);
          _persist();
          host.toast('Parfum "${v[0]}" ditambahkan');
          return null;
        },
      ));
    }
    final k = (i - 3) ~/ 2;
    if (k < 0 || k >= p.length) return;
    final name = p[k][0];
    if (i.isEven) {
      return host.openFormSheet(FormSheetDef(
        'Hapus "$name"?',
        const [],
        'Ya, Hapus',
        (_) {
          p.removeAt(k);
          _persist();
          host.toast('$name dihapus');
          return null;
        },
        sub: 'Data yang sudah dipakai di transaksi lama tetap tersimpan di laporan.',
        danger: true,
      ));
    }
    final cur = p[k].length > 1 ? _hex(p[k][1]).toLowerCase() : '#9b7ae0';
    host.openFormSheet(FormSheetDef(
      'Edit Parfum',
      [
        FormSheetField('Nama parfum', value: name, required: true),
        FormSheetField('Warna label', value: colors.map((c) => c.toLowerCase()).contains(cur) ? colors.firstWhere((c) => c.toLowerCase() == cur) : '#9b7ae0', colors: colors),
      ],
      'Simpan',
      (v) {
        p[k] = [v[0], _rgb(v[1])];
        _persist();
        host.toast('Parfum diperbarui');
        return null;
      },
    ));
  }

  void _persist() async {
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


class TodayPage extends PurePage {
  TodayPage(super.host);
  @override
  String get title => 'Harus Selesai Hari Ini';
  @override
  String get back => 'home';
  @override
  int get navActive => 1;
  List<String> ids = [];
  @override
  List<Map<String, dynamic>> items() {
    final n = host.now;
    final list = host.business.orders.where((o) => !o.isCancelled && !['siap', 'diantar', 'diambil'].contains(o.status) && o.due != null &&
        !o.due!.isAfter(DateTime(n.year, n.month, n.day, 23, 59, 59))).toList()
      ..sort((a, b) => a.due!.compareTo(b.due!));
    ids = list.map((o) => o.id).toList();
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return [
      {'type': 'hint', 't': 'Pesanan yang masih perlu diselesaikan hari ini (termasuk yang terlambat).'},
      if (list.isEmpty) {'type': 'hint', 't': 'Tidak ada pesanan yang harus diselesaikan hari ini.'},
      for (var k = 0; k < list.length; k++)
        {'type': 'card', 't': list[k].name, 's': '${list[k].id} · ${list[k].isLate(n) ? 'terlambat sejak' : 'estimasi'} ${hm(list[k].due!)}',
          'badge': list[k].isLate(n) ? 'Terlambat' : (list[k].status == 'antrian' ? 'Antrian' : 'Proses'), 'ic': '🧺', 'i': k},
    ];
  }

  @override
  void button(int i) {
    if (i >= 0 && i < ids.length) host.openOrder(ids[i]);
  }
}

class DataPage extends PurePage {
  DataPage(super.host);
  @override
  String get title => 'Pusat Data';
  @override
  List<Map<String, dynamic>> items() {
    final b = host.business;
    return [
      {'type': 'stats', 'cells': [
        {'v': '${b.customers.length}', 't': 'Pelanggan'}, {'v': '${b.orders.length}', 't': 'Transaksi'}, {'v': '${b.services.length}', 't': 'Layanan'},
      ]},
      {'type': 'title', 't': 'Ekspor'},
      card('Export Pesanan', 'CSV · bisa dibuka di Excel / Google Sheets', '↓', 0),
      card('Export Pelanggan', 'CSV · nama, telepon, alamat, saldo', '↓', 1),
      {'type': 'title', 't': 'Cadangan'},
      card('Backup Database', 'Simpan semua data ke folder Download/GOYANA', '☁', 2),
      card('Bagikan Backup', 'Kirim file cadangan ke WA / Drive', '⇪', 3),
      {'type': 'hint', 't': 'File cadangan berisi seluruh data usaha. Simpan di tempat aman.'},
    ];
  }

  Future<void> _save(String name, String mime, String text) async {
    try {
      final r = await host.device.invokeMethod<dynamic>('Files.save', {'name': name, 'mime': mime, 'data': base64Encode(utf8.encode(text))});
      host.toast('Tersimpan di ${r is Map ? r['path'] ?? 'Download/GOYANA' : 'Download/GOYANA'}');
    } on PlatformException catch (e) {
      host.toast(e.message ?? 'Gagal menyimpan file');
    } catch (_) {
      host.toast('Gagal menyimpan file');
    }
  }

  String _backup() => jsonEncode({
        'app': 'GOYANA', 'version': 1, 'at': host.now.toIso8601String(),
        'business': host.business.raw, 'services': host.business.services.map((e) => e.raw).toList(),
        'outlets': host.business.outlets.map((e) => e.raw).toList(), 'settings': host.settings.raw, 'perfumes': host.settings.perfumes,
      });

  @override
  void button(int i) async {
    final d = host.now.toIso8601String().substring(0, 10);
    switch (i) {
      case 0:
        return _save('goyana-pesanan-$d.csv', 'text/csv', '\uFEFF${host.business.ordersCsv()}');
      case 1:
        return _save('goyana-pelanggan-$d.csv', 'text/csv', '\uFEFF${host.business.customersCsv()}');
      case 2:
        return _save('goyana-backup-$d.json', 'application/json', _backup());
      case 3:
        try {
          await host.device.invokeMethod('Files.share', {
            'title': 'Backup GOYANA',
            'files': [{'name': 'goyana-backup-$d.json', 'mime': 'application/json', 'data': base64Encode(utf8.encode(_backup()))}],
          });
        } catch (_) {
          host.toast('Gagal membagikan file');
        }
    }
  }
}

class StockPage extends PurePage {
  StockPage(super.host);
  StockBook? book;
  String mode = ''; // '', 'add', 'move:<id>', 'opname:<id>'
  final Map<String, String> f = {};
  @override
  String get title => 'Stok Bahan';
  @override
  void opened() {
    mode = '';
    StockBook.load(host.kv).then((b) {
      book = b;
      host.refresh();
    });
  }

  String get outletId => host.business.activeOutlet;

  @override
  List<Map<String, dynamic>> items() {
    final b = book;
    if (b == null) return [{'type': 'hint', 't': 'Memuat…'}];
    if (mode == 'add') {
      return [
        {'type': 'title', 't': 'Tambah Bahan'},
        {'type': 'input', 'v': f['name'] ?? '', 'ph': 'Nama bahan, contoh: Deterjen', 'i': 0},
        {'type': 'input', 'v': f['unit'] ?? '', 'ph': 'Satuan, contoh: liter / kg / pcs', 'i': 1},
        {'type': 'input', 'label': 'Stok minimum', 'v': f['min'] ?? '', 'numeric': true, 'i': 2},
        {'type': 'input', 'label': 'Harga per satuan', 'pre': 'Rp', 'v': f['cost'] ?? '', 'numeric': true, 'i': 3},
        {'type': 'input', 'label': 'Stok awal', 'v': f['initial'] ?? '', 'numeric': true, 'i': 4},
        {'type': 'button', 't': 'Simpan Bahan', 'primary': true, 'i': 10},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 11},
      ];
    }
    if (mode.startsWith('move:') || mode.startsWith('opname:')) {
      final id = mode.split(':')[1];
      final it = b.items.firstWhere((e) => e['id'] == id, orElse: () => const {});
      final opname = mode.startsWith('opname:');
      return [
        {'type': 'title', 't': '${opname ? 'Stock Opname' : 'Mutasi Stok'} · ${it['name']}'},
        {'type': 'pair', 't': 'Stok sistem', 'v': '${qtyText(b.balance(id, outletId))} ${it['unit']}'},
        if (!opname) {'type': 'buttons', 'options': [{'t': 'Stok Masuk', 'on': f['dir'] != 'out', 'i': 20}, {'t': 'Pemakaian', 'on': f['dir'] == 'out', 'i': 21}]},
        {'type': 'input', 'label': opname ? 'Stok fisik' : 'Jumlah', 'suf': '${it['unit'] ?? ''}', 'v': f['qty'] ?? '', 'numeric': true, 'i': 5},
        {'type': 'input', 'v': f['note'] ?? '', 'ph': 'Catatan', 'i': 6},
        {'type': 'button', 't': 'Simpan', 'primary': true, 'i': opname ? 13 : 12},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 11},
      ];
    }
    final list = b.items;
    final low = list.where((e) => b.balance('${e['id']}', outletId) <= ((e['min'] as num?) ?? 0)).length;
    final value = list.fold<double>(0, (a, e) => a + b.balance('${e['id']}', outletId) * ((e['cost'] as num?) ?? 0));
    return [
      {'type': 'stats', 'cells': [{'v': '${list.length}', 't': 'Jenis bahan'}, {'v': '$low', 't': 'Stok menipis', 'tone': low > 0 ? 'r' : ''}, {'v': rp(value), 't': 'Nilai stok'}]},
      {'type': 'button', 't': '+ Tambah Bahan', 'primary': true, 'i': 1},
      if (list.isEmpty) {'type': 'hint', 't': 'Belum ada bahan.'},
      for (var k = 0; k < list.length; k++)
        {
          'type': 'entry', 't': '${list[k]['name']}',
          'lines': ['Stok ${qtyText(b.balance('${list[k]['id']}', outletId))} ${list[k]['unit']} · min ${qtyText((list[k]['min'] as num?) ?? 0)}'],
          'badge': b.balance('${list[k]['id']}', outletId) <= ((list[k]['min'] as num?) ?? 0) ? 'Menipis' : '',
          'btns': [{'t': 'Mutasi', 'i': 100 + k}, {'t': 'Opname', 'i': 200 + k}],
        },
      {'type': 'hint', 't': 'Stok memakai catatan mutasi. Opname mencatat selisih sebagai penyesuaian, bukan menimpa angka lama.'},
    ];
  }

  @override
  void input(int i, Object value) => f[const ['name', 'unit', 'min', 'cost', 'initial', 'qty', 'note'][i.clamp(0, 6)]] = '$value';

  void _mode(String m) {
    mode = m;
    f.clear();
    host.refresh();
  }

  @override
  void button(int i) async {
    final b = book;
    if (b == null) return;
    final list = b.items;
    if (i == 1) return _mode('add');
    if (i == 11) return _mode('');
    if (i == 20 || i == 21) {
      f['dir'] = i == 21 ? 'out' : 'in';
      return host.refresh();
    }
    if (i >= 200 && i - 200 < list.length) return _mode('opname:${list[i - 200]['id']}');
    if (i >= 100 && i - 100 < list.length) return _mode('move:${list[i - 100]['id']}');
    String? err;
    final now = host.now;
    if (i == 10) {
      err = b.addItem(name: f['name'] ?? '', unit: f['unit'] ?? '', min: parseQty(f['min']), cost: parseRupiah(f['cost']), initial: parseQty(f['initial']), outletId: outletId, now: now);
    } else if (i == 12) {
      final q = parseQty(f['qty']);
      err = b.move(itemId: mode.split(':')[1], qty: f['dir'] == 'out' ? -q : q, outletId: outletId, note: f['note'] ?? '', now: now);
    } else if (i == 13) {
      if ((f['qty'] ?? '').isEmpty) return host.toast('Isi stok fisik');
      b.opname(itemId: mode.split(':')[1], physical: parseQty(f['qty']), outletId: outletId, note: f['note'] ?? '', now: now);
    }
    if (err != null) return host.toast(err);
    await b.save();
    host.toast('Stok tersimpan');
    _mode('');
  }
}

class CourierPage extends PurePage {
  CourierPage(super.host);
  Couriers? c;
  String name = '', phone = '';
  @override
  String get title => 'Kurir';
  @override
  String get back => 'home';
  @override
  void opened() => Couriers.load(host.kv).then((v) {
        c = v;
        host.refresh();
      });

  @override
  List<Map<String, dynamic>> items() {
    final list = c?.list ?? const [];
    final tasks = host.business.orders.where((o) => o.status == 'jemput' || o.status == 'diantar' || (o.status == 'siap' && o.antar)).toList();
    return [
      {'type': 'title', 't': 'Tugas antar-jemput', 's': '${tasks.length} tugas'},
      if (tasks.isEmpty) {'type': 'hint', 't': 'Tidak ada tugas kurir. Pesanan antar-jemput muncul otomatis.'},
      for (var k = 0; k < tasks.length; k++)
        {'type': 'card', 't': tasks[k].name, 's': '${tasks[k].id} · ${tasks[k].status == 'jemput' ? 'Jemput cucian' : 'Antar cucian'}', 'ic': tasks[k].status == 'jemput' ? '🛵' : '📦', 'i': 500 + k},
      {'type': 'title', 't': 'Kurir', 's': '${list.length} orang'},
      for (var k = 0; k < list.length; k++)
        {'type': 'entry', 't': '${list[k]['name']}', 'lines': ['${list[k]['phone']}'], 'avatar': '${list[k]['name']}'.isEmpty ? '' : '${list[k]['name']}'.substring(0, 1).toUpperCase(),
          'badge': list[k]['active'] == false ? '' : 'Aktif', 'btns': [{'t': list[k]['active'] == false ? 'Aktifkan' : 'Nonaktifkan', 'i': 100 + k}]},
      {'type': 'input', 'v': name, 'ph': 'Nama kurir', 'i': 0},
      {'type': 'input', 'v': phone, 'ph': 'No WhatsApp kurir', 'numeric': true, 'i': 1},
      {'type': 'button', 't': '+ Tambah Kurir', 'primary': true, 'i': 1},
    ];
  }

  @override
  void input(int i, Object value) => i == 0 ? name = '$value' : phone = '$value';
  @override
  void button(int i) async {
    final v = c;
    if (v == null) return;
    if (i >= 500) {
      final tasks = host.business.orders.where((o) => o.status == 'jemput' || o.status == 'diantar' || (o.status == 'siap' && o.antar)).toList();
      if (i - 500 < tasks.length) host.openOrder(tasks[i - 500].id);
      return;
    }
    if (i >= 100 && i - 100 < v.list.length) {
      v.list[i - 100]['active'] = v.list[i - 100]['active'] == false;
    } else {
      final err = v.add(name, phone, host.business.activeOutlet, host.now);
      if (err != null) return host.toast(err);
      name = '';
      phone = '';
      host.toast('Kurir ditambahkan');
    }
    await v.save();
    host.refresh();
  }
}

class DiscountPage extends PurePage {
  DiscountPage(super.host);
  String name = '', value = '';
  bool percent = true;
  @override
  String get title => 'Diskon';
  List<dynamic> get _list => (host.settings.raw['discounts'] as List?) ?? (host.settings.raw['discounts'] = <dynamic>[]);
  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'hint', 't': 'Diskon aktif muncul sebagai pilihan saat kasir membuat pesanan.'},
        for (var k = 0; k < _list.length; k++)
          {'type': 'entry', 't': '${(_list[k] as List)[0]}', 'lines': <String>[], 'compact': true, 'btns': [{'t': '×', 'i': 100 + k}]},
        {'type': 'input', 'v': name, 'ph': 'Nama diskon, contoh: Member', 'i': 0},
        {'type': 'buttons', 'options': [{'t': 'Persen (%)', 'on': percent, 'i': 1}, {'t': 'Nominal (Rp)', 'on': !percent, 'i': 2}]},
        {'type': 'input', 'label': percent ? 'Besar potongan (%)' : 'Besar potongan', 'pre': percent ? '' : 'Rp', 'suf': percent ? '%' : '', 'v': value, 'numeric': true, 'i': 1},
        {'type': 'button', 't': 'Simpan Diskon', 'primary': true, 'i': 3},
      ];
  @override
  void input(int i, Object value) => i == 0 ? name = '$value' : this.value = '$value';
  @override
  void button(int i) async {
    if (i == 1 || i == 2) {
      percent = i == 1;
      return host.refresh();
    }
    if (i >= 100) {
      if (i - 100 < _list.length) _list.removeAt(i - 100);
    } else {
      final n = parseRupiah(value);
      if (name.trim().isEmpty || n <= 0 || (percent && n > 100)) return host.toast('Isi nama dan besar potongan yang benar');
      _list.add(['${name.trim()} (${percent ? '$n%' : rp(n)})', percent ? 'p$n' : 'n$n']);
      name = '';
      value = '';
    }
    await host.saveAll();
    host.toast('Diskon tersimpan');
    host.refresh();
  }
}

class EmployeesPage extends PurePage {
  EmployeesPage(super.host);
  String name = '', phone = '', pin = '';
  @override
  String get title => 'Pegawai & PIN';
  List<dynamic> get _list => (host.settings.raw['employees'] as List?) ?? (host.settings.raw['employees'] = <dynamic>[]);
  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'toggle', 't': 'Kunci aplikasi dengan PIN', 's': 'Saat dibuka, kasir memasukkan PIN. Namanya tercatat di riwayat pesanan.', 'on': host.settings.raw['pinLock'] == true, 'i': 0},
        for (var k = 0; k < _list.length; k++)
          {'type': 'entry', 't': '${(_list[k] as Map)['name']}', 'lines': ['${(_list[k] as Map)['phone']} · PIN ••••'], 'avatar': '👤', 'btns': [{'t': 'Hapus', 'i': 100 + k}]},
        {'type': 'title', 't': 'Tambah pegawai'},
        {'type': 'input', 'v': name, 'ph': 'Nama pegawai', 'i': 0},
        {'type': 'input', 'v': phone, 'ph': 'No handphone', 'numeric': true, 'i': 1},
        {'type': 'input', 'v': pin, 'ph': 'PIN 4–6 angka', 'numeric': true, 'secret': true, 'i': 2},
        {'type': 'button', 't': 'Simpan Pegawai', 'primary': true, 'i': 1},
      ];
  @override
  void input(int i, Object value) {
    if (i == 0) name = '$value';
    if (i == 1) phone = '$value';
    if (i == 2) pin = '$value'.replaceAll(RegExp(r'\D'), '');
  }

  @override
  void toggle(int i) {
    if (_list.isEmpty && host.settings.raw['pinLock'] != true) return host.toast('Tambah pegawai dengan PIN dulu');
    host.settings.raw['pinLock'] = host.settings.raw['pinLock'] != true;
    host.saveAll();
  }

  @override
  void button(int i) async {
    if (i >= 100) {
      if (i - 100 < _list.length) _list.removeAt(i - 100);
      if (_list.isEmpty) host.settings.raw['pinLock'] = false;
    } else {
      if (name.trim().isEmpty || pin.length < 4 || pin.length > 6) return host.toast('Isi nama dan PIN 4–6 angka');
      if (_list.any((e) => e is Map && e['pin'] == pin)) return host.toast('PIN sudah dipakai pegawai lain');
      _list.add({'name': name.trim(), 'phone': phone.trim(), 'pin': pin});
      name = '';
      phone = '';
      pin = '';
      host.toast('Pegawai tersimpan');
    }
    await host.saveAll();
    host.refresh();
  }
}

class HelpPage extends PurePage {
  HelpPage(super.host);
  @override
  String get title => 'Pusat Bantuan';
  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'title', 't': 'Ada yang bisa kami bantu?'},
        card('Membuat Pesanan', 'Tambah Transaksi → pelanggan → durasi → layanan → bayar', '🧾', 0),
        card('Status Laundry', 'Tekan tombol di kartu pesanan untuk lanjut ke tahap berikutnya', '🧺', 1),
        card('Pembayaran & QRIS', 'Atur QRIS & rekening di Pengaturan', '▦', 2),
        card('Printer & Struk', 'Pasangkan printer di Bluetooth HP, lalu Pengaturan → Printer', '🖨', 3),
        {'type': 'button', 't': 'Hubungi Support GOYANA', 'primary': true, 'i': 10},
        {'type': 'hint', 't': 'Jangan pernah membagikan password, PIN, atau kode OTP.'},
      ];
  @override
  void button(int i) {
    if (i == 10) {
      host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/6281234567890?text=${Uri.encodeComponent('Halo GOYANA, saya butuh bantuan')}'}).catchError((_) => null);
    } else {
      host.toast(const ['Tambah Transaksi ada di Beranda', 'Tombol merah di kartu = tahap berikutnya', 'Pengaturan → QRIS Outlet / Rekening', 'Pengaturan → Printer Bluetooth'][i.clamp(0, 3)]);
    }
  }
}

/// Kirim pesan WA lewat aplikasi WhatsApp HP (tanpa server).
void openWa(PureHost host, String phone, String text) {
  var p = phone.replaceAll(RegExp(r'\D'), '');
  if (p.startsWith('0')) p = '62${p.substring(1)}';
  host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/$p?text=${Uri.encodeComponent(text)}'}).catchError((_) => null);
}

String fillTemplate(String t, Map<String, String> v) => t.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => v[m.group(1)] ?? m.group(0)!);

const defaultReminder = 'Halo {nama}, cucian Anda ({kode}) sudah siap sejak {hari} hari lalu. Total {total}. Silakan diambil di {outlet} ya 🙏';
const defaultNota = 'Halo {nama}, terima kasih sudah laundry di {outlet}.\nNo. pesanan: {kode}\nTotal: {total} ({bayar})\nEstimasi selesai: {estimasi}';

class CrmPage extends PurePage {
  CrmPage(super.host);
  int tab = 0; // 0 pengingat, 1 poin member, 2 voucher
  String code = '', vname = '', amount = '';
  bool percent = true;
  @override
  String get title => 'CRM Pelanggan';
  @override
  String get back => 'customers';
  @override
  int get navActive => 0;
  Map<String, dynamic> get raw => host.settings.raw;
  int get remindDays => (raw['remindDays'] as num?)?.toInt() ?? 3;
  String get template => '${raw['remindTpl'] ?? defaultReminder}';
  List<dynamic> get vouchers => (raw['vouchers'] as List?) ?? (raw['vouchers'] = <dynamic>[]);

  List<dynamic> _unpicked() {
    final n = host.now;
    return host.business.orders.where((o) => o.status == 'siap' && o.due != null && n.difference(o.due!).inDays >= remindDays).toList();
  }

  @override
  List<Map<String, dynamic>> items() {
    final out = <Map<String, dynamic>>[
      {'type': 'buttons', 'options': [for (final (k, t) in const ['Pengingat', 'Poin Member', 'Voucher'].indexed) {'t': t, 'on': tab == k, 'i': k}]},
    ];
    if (tab == 0) {
      final list = _unpicked();
      out.addAll([
        {'type': 'title', 't': 'Cucian belum diambil', 's': '${list.length} pesanan'},
        for (var k = 0; k < list.length; k++)
          {'type': 'entry', 't': list[k].name, 'lines': ['${list[k].id} · siap ${host.now.difference(list[k].due!).inDays} hari · ${rp(list[k].total)}'], 'btns': [{'t': 'Kirim WA', 'i': 100 + k}]},
        if (list.isEmpty) {'type': 'hint', 't': 'Tidak ada cucian yang terlambat diambil.'},
        {'type': 'input', 'label': 'Ingatkan setelah', 'suf': 'hari', 'v': '$remindDays', 'numeric': true, 'i': 0},
        {'type': 'label', 't': 'Template pesan pengingat'},
        {'type': 'input', 'v': template, 'multiline': true, 'i': 1},
        {'type': 'hint', 't': 'Kata kunci: {nama} {kode} {hari} {total} {outlet}'},
        {'type': 'button', 't': 'Simpan Template', 'primary': false, 'i': 10},
      ]);
    } else if (tab == 1) {
      // 1 poin tiap Rp10.000 belanja (pesanan tidak batal).
      final pts = <String, int>{};
      for (final o in host.business.orders.where((o) => !o.isCancelled)) {
        pts[o.name] = (pts[o.name] ?? 0) + o.total ~/ 10000;
      }
      final top = pts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      out.addAll([
        {'type': 'hint', 't': '1 poin setiap belanja Rp10.000. Tukarkan poin dengan diskon/voucher sesuai kebijakan outlet.'},
        {'type': 'table', 'rows': [
          [{'t': 'Pelanggan', 'h': true, 'b': true}, {'t': 'Poin', 'h': true, 'b': true, 'n': true}],
          for (final e in top.take(50)) [{'t': e.key}, {'t': '${e.value}', 'n': true}],
        ]},
      ]);
    } else {
      out.addAll([
        for (var k = 0; k < vouchers.length; k++)
          {'type': 'entry', 't': '${(vouchers[k] as Map)['code']}', 'lines': ['${(vouchers[k] as Map)['name']}'], 'compact': true, 'btns': [{'t': '×', 'i': 200 + k}]},
        if (vouchers.isEmpty) {'type': 'hint', 't': 'Belum ada voucher.'},
        {'type': 'title', 't': 'Buat voucher'},
        {'type': 'input', 'v': code, 'ph': 'Kode, contoh: KANGEN15', 'i': 2},
        {'type': 'input', 'v': vname, 'ph': 'Nama voucher', 'i': 3},
        {'type': 'buttons', 'options': [{'t': 'Persen (%)', 'on': percent, 'i': 20}, {'t': 'Nominal (Rp)', 'on': !percent, 'i': 21}]},
        {'type': 'input', 'label': 'Besar potongan', 'pre': percent ? '' : 'Rp', 'suf': percent ? '%' : '', 'v': amount, 'numeric': true, 'i': 4},
        {'type': 'button', 't': 'Buat Voucher', 'primary': true, 'i': 11},
        {'type': 'hint', 't': 'Voucher aktif bisa dipilih kasir di pilihan Diskon saat membuat pesanan.'},
      ]);
    }
    return out;
  }

  @override
  void input(int i, Object value) {
    switch (i) {
      case 0:
        raw['remindDays'] = int.tryParse('$value') ?? 3;
      case 1:
        raw['remindTpl'] = '$value';
      case 2:
        code = '$value'.toUpperCase().replaceAll(' ', '');
      case 3:
        vname = '$value';
      case 4:
        amount = '$value';
    }
  }

  @override
  void button(int i) async {
    if (i < 3) {
      tab = i;
      return host.refresh();
    }
    if (i == 20 || i == 21) {
      percent = i == 20;
      return host.refresh();
    }
    if (i == 10) {
      await host.saveAll();
      return host.toast('Template tersimpan');
    }
    if (i == 11) {
      final n = parseRupiah(amount);
      if (code.isEmpty || n <= 0 || (percent && n > 100)) return host.toast('Isi kode dan besar potongan');
      if (vouchers.any((e) => e is Map && e['code'] == code)) return host.toast('Kode sudah ada');
      vouchers.add({'code': code, 'name': vname.isEmpty ? code : vname, 'key': percent ? 'p$n' : 'n$n'});
      code = '';
      vname = '';
      amount = '';
      await host.saveAll();
      host.toast('Voucher dibuat');
      return host.refresh();
    }
    if (i >= 200) {
      if (i - 200 < vouchers.length) vouchers.removeAt(i - 200);
      await host.saveAll();
      return host.refresh();
    }
    if (i >= 100) {
      final list = _unpicked();
      if (i - 100 >= list.length) return;
      final o = list[i - 100];
      final c = host.business.customerByName(o.name);
      final outlet = host.business.outlets.isEmpty ? 'GOYANA' : host.business.outlets.first.name;
      openWa(host, o.phone.isNotEmpty ? o.phone : (c?.phone ?? ''), fillTemplate(template, {
        'nama': o.name, 'kode': o.id, 'hari': '${host.now.difference(o.due!).inDays}', 'total': rp(o.total), 'outlet': outlet,
      }));
    }
  }
}

class WhatsAppPage extends PurePage {
  WhatsAppPage(super.host);
  @override
  String get title => 'WhatsApp';
  Map<String, dynamic> get raw => host.settings.raw;
  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'entry', 't': 'Kirim lewat WhatsApp HP', 'lines': ['Nota & pengingat dibuka di aplikasi WhatsApp, kasir tinggal tekan Kirim.'], 'avatar': '💬'},
        {'type': 'toggle', 't': 'Tawarkan kirim nota setelah transaksi', 'on': raw['autoNota'] != false, 'i': 0},
        {'type': 'label', 't': 'Template nota'},
        {'type': 'input', 'v': '${raw['notaTpl'] ?? defaultNota}', 'multiline': true, 'i': 0},
        {'type': 'hint', 't': 'Kata kunci: {nama} {kode} {total} {bayar} {estimasi} {outlet}'},
        {'type': 'button', 't': 'Simpan', 'primary': true, 'i': 0},
        {'type': 'title', 't': 'Otomatis tanpa kasir (chatbot, nota otomatis, blast)'},
        {'type': 'hint', 't': 'Butuh nomor WhatsApp terhubung ke server GOYANA (CHATKU). Akan aktif setelah server online.'},
      ];
  @override
  void input(int i, Object value) => raw['notaTpl'] = '$value';
  @override
  void toggle(int i) => raw['autoNota'] = raw['autoNota'] == false;
  @override
  void button(int i) async {
    await host.saveAll();
    host.toast('Pengaturan WhatsApp tersimpan');
    host.go('settings');
  }
}

class OutletsPage extends PurePage {
  OutletsPage(super.host);
  String name = '';
  @override
  String get title => 'Cabang & Monitoring';
  @override
  List<Map<String, dynamic>> items() {
    final b = host.business, n = host.now;
    bool today(DateTime? d) => d != null && d.year == n.year && d.month == n.month && d.day == n.day;
    final list = b.outlets;
    return [
      {'type': 'hint', 't': 'Order baru masuk ke outlet aktif. Ganti outlet aktif untuk bekerja di cabang lain.'},
      for (var k = 0; k < list.length; k++) ...[
        () {
          final orders = b.orders.where((o) => !o.isCancelled && (o.outlet == list[k].id || (o.outlet.isEmpty && k == 0))).toList();
          final omzet = orders.where((o) => today(o.created)).fold<int>(0, (a, o) => a + o.total);
          final active = orders.where((o) => !['diambil', 'batal'].contains(o.status)).length;
          final late = orders.where((o) => o.isLate(n)).length;
          return {
            'type': 'entry', 't': list[k].name, 'lines': ['Omzet hari ini ${rp(omzet)} · $active aktif · $late terlambat', if (list[k].address.isNotEmpty) list[k].address],
            'badge': list[k].id == b.activeOutlet ? 'Aktif' : '',
            'btns': [if (list[k].id != b.activeOutlet) {'t': 'Jadikan Aktif', 'i': 100 + k}],
          };
        }(),
      ],
      {'type': 'input', 'v': name, 'ph': 'Nama cabang baru', 'i': 0},
      {'type': 'button', 't': '+ Tambah Cabang', 'primary': true, 'i': 1},
    ];
  }

  @override
  void input(int i, Object value) => name = '$value'.trim();
  @override
  void button(int i) async {
    final b = host.business;
    if (i >= 100) {
      if (i - 100 < b.outlets.length) await b.setActiveOutlet(b.outlets[i - 100].id);
      host.toast('Outlet aktif diganti');
    } else {
      if (name.isEmpty) return host.toast('Isi nama cabang');
      await b.addOutlet(name);
      name = '';
      host.toast('Cabang ditambahkan');
    }
    host.refresh();
  }
}

class NotifPage extends PurePage {
  NotifPage(super.host);
  List<String> ids = [];
  @override
  String get title => 'Notifikasi';
  @override
  String get back => 'home';
  @override
  int get navActive => 0;
  @override
  List<Map<String, dynamic>> items() {
    final n = host.now;
    final late = host.business.orders.where((o) => o.isLate(n)).toList();
    final ready = host.business.orders.where((o) => o.status == 'siap').toList();
    final unpaid = host.business.orders.where((o) => !o.isCancelled && o.status == 'diambil' && !o.isPaid).toList();
    ids = [...late.map((o) => o.id), ...ready.map((o) => o.id), ...unpaid.map((o) => o.id)];
    var k = 0;
    return [
      if (ids.isEmpty) {'type': 'hint', 't': 'Tidak ada notifikasi.'},
      for (final o in late) {'type': 'card', 't': 'Pesanan terlambat', 's': '${o.id} · ${o.name}', 'ic': '!', 'badge': 'Terlambat', 'i': k++},
      for (final o in ready) {'type': 'card', 't': 'Siap diambil', 's': '${o.id} · ${o.name}', 'ic': '✓', 'i': k++},
      for (final o in unpaid) {'type': 'card', 't': 'Sudah diambil, belum lunas', 's': '${o.id} · ${o.name} · sisa ${rp(o.remaining)}', 'ic': 'Rp', 'badge': 'Piutang', 'i': k++},
    ];
  }

  @override
  void button(int i) {
    if (i >= 0 && i < ids.length) host.openOrder(ids[i]);
  }
}

class PlanPage extends PurePage {
  PlanPage(super.host);
  @override
  String get title => 'Paket GOYANA';
  static const plans = [
    ['FREE', 'Gratis', '2 bulan', 'Trial seluruh fitur Basic selama 2 bulan'],
    ['BASIC', 'Rp30.000', '/bulan', 'Kasir harian, kurir, peta pelanggan dan monitoring cabang'],
    ['SILVER', 'Rp65.000', '/bulan', 'Operasional lengkap, stok, HPP dan Balasan Cepat & Trigger'],
    ['GOLD', 'Rp100.000', '/bulan', 'Nota WhatsApp otomatis dan Chatbot AI dengan top-up terpisah'],
    ['PLATINUM', 'Rp350.000', '/bulan', 'Seluruh fitur Goyana, termasuk WhatsApp Blast & Promo'],
  ];
  @override
  List<Map<String, dynamic>> items() => [
        for (var k = 0; k < plans.length; k++) {'type': 'plan', 't': plans[k][0], 'price': plans[k][1], 'per': plans[k][2], 's': plans[k][3], 'more': 'Pilih', 'i': k},
        {'type': 'hint', 't': 'Pembayaran paket online menunggu server akun. Sementara aktivasi lewat admin GOYANA.'},
      ];
  @override
  void button(int i) => openWa(host, '6281234567890', 'Halo GOYANA, saya ingin aktifkan paket ${plans[i.clamp(0, plans.length - 1)][0]}');
}


/// Pengaturan → Durasi: sama dengan HTML v199 (3 durasi utama, jam bisa diubah, tidak bisa dihapus;
/// durasi tambahan hanya tampil selama halaman terbuka, seperti di HTML).
class DurationPage extends PurePage {
  DurationPage(super.host);
  static const key = 'goyana-durations199';
  static const base = [MapEntry('Reguler', 72), MapEntry('Express', 24), MapEntry('Kilat', 6)];
  final List<MapEntry<String, int>> extra = [];
  @override
  String get title => 'Durasi';

  List<MapEntry<String, int>> get rows => [
        for (final b in base) MapEntry(b.key, durationOverrides[b.key] ?? b.value),
        ...extra,
      ];

  @override
  void opened() => extra.clear();

  @override
  List<Map<String, dynamic>> items() => const [];

  @override
  Widget? custom(BuildContext context, FormActions actions) => NativeDurationPage(
        key: const ValueKey('pure-duration'),
        model: durationMirror(rows),
        onButton: button,
        onNav: actions.nav,
        onHeaderScan: actions.scan,
      );

  Future<void> _save() async {
    await host.kv.set(key, jsonEncode(durationOverrides));
    host.refresh();
  }

  @override
  void button(int i) {
    if (i == 1) return host.go('settings');
    if (i == 3) {
      return host.openFormSheet(FormSheetDef(
        'Tambah Durasi',
        const [
          FormSheetField('Nama durasi', placeholder: 'Contoh: Super Kilat', required: true),
          FormSheetField('Lama pengerjaan (jam)', placeholder: 'Contoh: 3', numeric: true, required: true),
        ],
        'Tambah',
        (v) {
          extra.add(MapEntry(v[0], int.tryParse(v[1]) ?? 1));
          host.toast('Durasi "${v[0]}" ditambahkan');
          host.refresh();
          return null;
        },
        sub: 'Durasi otomatis muncul sebagai varian di semua kategori layanan',
      ));
    }
    final k = (i - 4) ~/ 2;
    final all = rows;
    if (k < 0 || k >= all.length) return;
    final isBase = k < base.length;
    final name = all[k].key;
    if (i.isOdd) {
      if (isBase) {
        return host.toast('Durasi $name tidak bisa dihapus. Matikan per layanan di Pengaturan → Layanan & Harga.');
      }
      return host.openFormSheet(FormSheetDef(
        'Hapus durasi?',
        const [],
        'Ya, Hapus',
        (_) {
          extra.removeAt(k - base.length);
          host.toast('Durasi $name dihapus');
          host.refresh();
          return null;
        },
        sub: '"$name" tidak bisa dipakai untuk pesanan baru. Pesanan lama tetap aman.',
        danger: true,
      ));
    }
    host.openFormSheet(FormSheetDef(
      isBase ? 'Edit Durasi $name' : 'Edit Durasi',
      [
        if (!isBase) FormSheetField('Nama durasi', value: name, required: true),
        FormSheetField('Lama pengerjaan (jam)', value: '${all[k].value}', numeric: true, required: true),
      ],
      'Simpan',
      (v) {
        final n = int.tryParse(v[isBase ? 0 : 1]) ?? 0;
        if (n <= 0) {
          host.toast('Isi jam dengan angka lebih dari 0');
          return false;
        }
        if (isBase) {
          durationOverrides[name] = n;
          _save();
          host.toast('Durasi $name jadi $n jam');
        } else {
          extra[k - base.length] = MapEntry(v[0], n);
          host.toast('Durasi diperbarui');
          host.refresh();
        }
        return null;
      },
    ));
  }
}
