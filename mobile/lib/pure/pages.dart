// Halaman formulir mode murni: Pengaturan, Profil Struk, Printer, QRIS, Rekening, Layanan, Parfum, Kas, Tutup Kasir.
// Tiap halaman membangun butir formulir (NativeForm) dan menangani aksinya sendiri dengan logika Dart.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/business.dart';
import '../core/models.dart' show Order, durationOverrides;
import '../core/money.dart';
import '../core/qris.dart';
import '../core/receipt.dart';
import '../core/settings.dart';
import '../core/stock.dart';
import '../core/store.dart';
import '../native/form_page.dart' show FormActions;
import '../native/guide135_sheet.dart';
import '../native/popup_components.dart';
import '../native/crm_page.dart';
import '../native/duration_page.dart';
import '../native/perfume_page.dart';
import 'access.dart';
import 'delivery.dart';
import 'discounts.dart';
import 'mirror_pages.dart';
import 'page_templates.dart';
import 'qr_decode.dart';
import 'views.dart' show mapsLink;

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
  void openPageSheet(String id);
  void closePageSheet(String id);
  /// Mulai Tambah Transaksi dengan pelanggan ini sudah terpilih (Antar Jemput → Sampai Lokasi).
  void startOrderFor(String customerName);
  /// Cetak teks ke printer Bluetooth (atau dialog cetak Android bila belum ada printer).
  Future<void> printText(String text, String title, String done);
  /// Buka pemindai barcode/QR.
  void scanCode();
  /// Buka Rincian Pesanan lalu lembar Pembayaran untuk sisa tagihannya.
  void payOrder(String id);
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
  /// Popup milik halaman (butir NativeForm); null = popup tidak dikenal.
  List<Map<String, dynamic>>? sheetItems(String id) => null;
  void sheetEvent(String id, String kind, int index, Object? value) {}
  /// File yang dipilih pengguna untuk tombol ber-'file' (data = base64).
  void file(String inputId, String name, String mime, String data) {}
  /// Popup dengan widget khusus (sama dengan Hibrida); null = pakai butir [sheetItems].
  Widget? sheetWidget(String id, BuildContext context) => null;
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

const _printerSvg = '<svg viewBox="0 0 24 24"><path d="M7 8V3h10v5M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><path d="M7 15h10v6H7z"></path></svg>';

/// Pengaturan → Printer & Nota: Profil Nota (dipakai sungguhan saat mencetak; di HTML tidak tersimpan) + tautan Printer Bluetooth.
class PrinterNotaPage extends PurePage {
  PrinterNotaPage(super.host);
  late List<String> f;
  late int width;
  late bool showDue;
  @override
  String get title => 'PRINTER & NOTA';
  Map<String, dynamic> get _x => ((host.settings.raw.putIfAbsent('nota', () => <String, dynamic>{})) as Map).cast<String, dynamic>();

  @override
  void opened() {
    final r = host.settings.receipt;
    f = [r.header, r.address, r.phone, r.footer, '${_x['footerWa'] ?? '-'}',
      '${_x['readyMsg'] ?? 'Format resmi GOYANA (otomatis): Nota, Pelanggan, Layanan, Tagihan, Jam buka, Alamat, link cek status.'}'];
    width = r.width;
    showDue = r.showDue;
  }

  @override
  List<Map<String, dynamic>> items() {
    Map<String, dynamic> inp(int i, {bool multi = false}) =>
        {'type': 'input', 'v': f[i], 'ph': '', 'multiline': multi, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    Map<String, dynamic> tg(String t, int i, bool def) => {'type': 'toggle', 't': t, 's': '', 'on': i == 1 ? showDue : (_x['t$i'] as bool? ?? def), 'i': i};
    return [
      {'type': 'card', 't': 'Printer Bluetooth', 's': 'Hubungkan printer thermal dan cek izin perangkat', 'svg': _printerSvg, 'ic': '', 'badge': '', 'meta': '', 'on': false, 'i': 0},
      {'type': 'title', 't': 'Profil Nota'},
      {'type': 'label', 't': 'Profil Nota (Header)'},
      inp(0),
      {'type': 'label', 't': 'Alamat Outlet'},
      inp(1, multi: true),
      {'type': 'label', 't': 'No Handphone'},
      inp(2),
      {'type': 'hint', 't': 'Catatan: hindari emoticon pada teks nota agar kompatibel dengan printer thermal.'},
      {'type': 'label', 't': 'Footer Nota'},
      inp(3, multi: true),
      {'type': 'label', 't': 'Footer Nota WA'},
      inp(4, multi: true),
      {'type': 'label', 't': 'Pesan Notifikasi Siap Ambil WA'},
      inp(5, multi: true),
      {'type': 'hint', 't': 'Tag yang tersedia: {{nama_customer}}, {{no_invoice}}, {{nama_outlet}}.'},
      {'type': 'row', 't': 'Menampilkan Logo', 'btn': 'Konfigurasi', 'i': 1},
      tg('Menampilkan QR Code', 0, false),
      tg('Menampilkan Estimasi Selesai', 1, true),
      tg('Menampilkan Nama Kasir', 2, true),
      tg('Menampilkan Keterangan', 3, false),
      tg('Menampilkan Footer Nota', 4, true),
      tg('Menampilkan Footer Nota WA', 5, false),
      tg('Format Angka Ribuan Nota', 6, true),
      {'type': 'choice', 't': 'Ukuran Printer', 'options': [{'t': '58 mm', 's': '', 'on': width != 48, 'i': 0}, {'t': '80 mm', 's': '', 'on': width == 48, 'i': 1}]},
      {'type': 'choice', 't': 'Type Nota', 'options': [{'t': 'Type A', 's': '', 'on': _x['type'] != 'B', 'i': 2}, {'t': 'Type B', 's': '', 'on': _x['type'] == 'B', 'i': 3}]},
      {'type': 'button', 't': 'SIMPAN', 'primary': true, 'file': '', 'after': false, 'i': 2},
    ];
  }

  @override
  void input(int i, Object value) => f[i.clamp(0, 5)] = '$value';
  @override
  void toggle(int i) {
    if (i == 1) {
      showDue = !showDue;
    } else {
      _x['t$i'] = !(_x['t$i'] as bool? ?? const [false, true, true, false, true, false, true][i.clamp(0, 6)]);
    }
    host.refresh();
  }

  @override
  void radio(int i) {
    if (i < 2) {
      width = i == 1 ? 48 : 32;
    } else {
      _x['type'] = i == 3 ? 'B' : 'A';
    }
    host.refresh();
  }

  @override
  void button(int i) {
    if (i == 0) return host.go('printerconnect');
    if (i == 1) return host.toast('Konfigurasi logo nota');
    host.settings.receipt = ReceiptSettings(header: f[0], address: f[1], phone: f[2], footer: f[3], width: width, showDue: showDue);
    _x
      ..['footerWa'] = f[4]
      ..['readyMsg'] = f[5];
    host.saveAll();
    host.toast('Pengaturan printer & nota tersimpan');
  }
}

/// Printer Bluetooth (pc90): status, Pengaturan Bluetooth HP, perangkat terpasang, Cari Ulang, Tes Cetak.
class PrinterPage extends PurePage {
  PrinterPage(super.host);
  List<Map<String, String>> paired = [];
  String note = 'Pasangkan printer di Bluetooth HP, lalu Cari Ulang Printer.';
  bool connected = false;
  @override
  String get title => 'PRINTER BLUETOOTH';
  @override
  String get back => 'printer';
  @override
  void opened() {
    host.device.invokeMapMethod<String, dynamic>('GoyanaDevice.printerStatus').then((st) {
      connected = st?['connected'] == true;
      host.refresh();
    }).catchError((_) {});
  }

  Future<void> scan() async {
    try {
      final perm = await host.device.invokeMapMethod<String, dynamic>('GoyanaDevice.requestAccess', {'alias': 'bluetooth'});
      if (perm != null && perm['granted'] == false) return host.toast('Izin perangkat sekitar (Bluetooth) belum diberikan');
      final list = await host.device.invokeListMethod<dynamic>('GoyanaDevice.pairedPrinters');
      paired = (list ?? const []).whereType<Map>().map((e) => {'name': '${e['name']}', 'address': '${e['address']}'}).toList();
      note = paired.isEmpty ? 'Belum ada perangkat dipasangkan. Buka Pengaturan Bluetooth HP.' : '';
    } on PlatformException catch (e) {
      host.toast(e.message ?? 'Printer Bluetooth tersedia di APK Android.');
    } catch (_) {
      host.toast('Printer Bluetooth tersedia di APK Android.');
    }
    host.refresh();
  }

  @override
  List<Map<String, dynamic>> items() {
    final n = paired.length;
    return [
      {'type': 'entry', 't': connected ? 'Terhubung ke ${host.settings.printerName}' : 'Belum terhubung', 'lines': ['Nyalakan printer thermal & Bluetooth HP Anda'], 'badge': '', 'avatar': '', 'svg': _printerSvg, 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'title', 't': 'Akses Printer', 's': ''},
      {'type': 'button', 't': 'Pengaturan Bluetooth HP', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'title', 't': 'Perangkat Ditemukan', 's': ''},
      if (n == 0) {'type': 'hint', 't': note},
      for (var k = 0; k < n; k++) {'type': 'card', 't': paired[k]['name'], 's': paired[k]['address'], 'svg': '', 'ic': '🖨', 'badge': '', 'meta': '', 'on': false, 'i': 1 + k},
      {'type': 'button', 't': '↻ Cari Ulang Printer', 'primary': false, 'file': '', 'after': false, 'i': 1 + n},
      {'type': 'button', 't': 'Tes Cetak', 'primary': true, 'file': '', 'after': false, 'i': 2 + n},
    ];
  }

  @override
  void button(int i) async {
    final n = paired.length;
    if (i == 0) {
      try {
        await host.device.invokeMethod('GoyanaDevice.bluetoothSettings');
      } catch (_) {
        host.toast('Printer Bluetooth tersedia di APK Android.');
      }
      return;
    }
    if (i == 1 + n) return scan();
    if (i == 2 + n) {
      try {
        await host.device.invokeMethod('GoyanaDevice.testPrint');
        host.toast('Tes cetak dikirim');
      } on PlatformException catch (e) {
        host.toast(e.message ?? 'Printer belum terhubung');
      } catch (_) {
        host.toast('Tes cetak tersedia di APK Android.');
      }
      return;
    }
    final k = i - 1;
    if (k < 0 || k >= n) return;
    try {
      await host.device.invokeMethod('GoyanaDevice.connectPrinter', {'address': paired[k]['address']});
      host.settings.setPrinter(paired[k]['address']!, paired[k]['name']!);
      await host.saveAll();
      connected = true;
      host.toast('Printer berhasil terhubung');
    } on PlatformException catch (e) {
      host.toast(e.message ?? 'Gagal menghubungkan printer');
    } catch (_) {
      host.toast('Gagal menghubungkan printer');
    }
    host.refresh();
  }
}

/// Pengaturan → Pembayaran (qris/v185/gy154): QRIS outlet, QRIS dinamis, metode pembayaran, rekening transfer.
/// Kunci sama dengan Hibrida: goyana-qris-text, goyana-qris-image, goyana-qris-options185, gy154-bank/account/holder.
class QrisPage extends PurePage {
  QrisPage(super.host);
  static const optionsKey = 'goyana-qris-options185';
  String _paste = '', _image = '';
  List<String> _bank = ['', '', ''];
  @override
  String get title => 'PEMBAYARAN';

  Map<String, dynamic> get _tg => ((host.settings.raw.putIfAbsent('payToggles', () => <String, dynamic>{})) as Map).cast<String, dynamic>();
  bool get _dynamic => host.settings.raw['qrisDynamic'] != false;

  @override
  void opened() {
    _paste = host.settings.qrisText;
    _bank = [host.settings.bank, host.settings.account, host.settings.holder];
    Future.wait([host.kv.get(Keys.qrisImage), host.kv.get('gy154-bank'), host.kv.get('gy154-account'), host.kv.get('gy154-holder'), host.kv.get(optionsKey)]).then((v) {
      _image = v[0] ?? '';
      // Data rekening/opsi yang dibuat di Hibrida dipakai bila Mode Murni belum punya.
      for (var k = 0; k < 3; k++) {
        if (_bank[k].isEmpty && (v[k + 1] ?? '').isNotEmpty) _bank[k] = _unq(v[k + 1]!);
      }
      try {
        final o = jsonDecode(v[4] ?? 'null');
        if (o is Map && host.settings.raw['qrisDynamic'] == null) host.settings.raw['qrisDynamic'] = o['dynamic'] != false;
      } catch (_) {}
      host.refresh();
    });
  }

  static String _unq(String v) {
    try {
      final d = jsonDecode(v);
      return d is String ? d : v;
    } catch (_) {
      return v;
    }
  }

  String get _status {
    if (qrisValid(host.settings.qrisText)) return 'QRIS tersimpan · siap digunakan';
    if (_image.isEmpty) return 'Upload QRIS outlet terlebih dahulu';
    return _dynamic ? 'Gambar tersimpan · kode perlu terbaca untuk nominal otomatis' : 'Gambar QRIS statis tersimpan · pelanggan mengisi nominal';
  }

  @override
  List<Map<String, dynamic>> items() {
    final o = host.business.outlets;
    final name = (o.where((x) => x.id == host.business.activeOutlet).firstOrNull ?? o.firstOrNull)?.name ?? 'Outlet';
    Map<String, dynamic> inp(String v, String ph, int i, {bool multi = false, bool numeric = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': multi, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    Map<String, dynamic> tg(String t, int i, {String s = '', bool def = true, bool? on}) => {'type': 'toggle', 't': t, 's': s, 'on': on ?? (_tg['$i'] as bool? ?? def), 'i': i};
    return [
      {'type': 'entry', 't': 'Outlet $name', 'lines': ['QRIS statis untuk pembayaran outlet'], 'badge': '', 'avatar': name.isEmpty ? '' : name[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'image', 'src': _image, 'svg': '', 'mark': _image.isEmpty ? '▦' : '', 't': 'QRIS Outlet', 's': 'Upload QRIS untuk menerima pembayaran'},
      {'type': 'button', 't': 'Upload / Ganti QRIS', 'primary': true, 'file': 'qris-file', 'after': false, 'i': 0},
      {'type': 'title', 't': 'QRIS Nominal Otomatis'},
      {'type': 'hint', 't': 'Pelanggan scan, nominal langsung terisi sesuai total. Uang tetap masuk ke QRIS outlet.'},
      {'type': 'title', 't': _status},
      tg('QRIS dinamis · isi nominal transaksi otomatis', 0, on: _dynamic),
      tg('Nominal unik', 1, s: 'tambah Rp1–99 acak supaya mudah dicocokkan dengan mutasi', def: false),
      {'type': 'label', 't': 'QR tidak terbaca? Tempel teks QRIS'},
      inp(_paste, '00020101021126...', 1, multi: true),
      {'type': 'button', 't': 'Pakai teks ini', 'primary': false, 'file': '', 'after': false, 'i': 1},
      {'type': 'title', 't': 'Pengaturan QRIS Statis'},
      {'type': 'hint', 't': 'Atur penggunaan QRIS pada transaksi dan nota.'},
      tg('Aktifkan QRIS statis untuk pembayaran', 2),
      tg('Tampilkan QRIS pada Nota', 3),
      tg('Tampilkan logo outlet di halaman bayar', 4),
      tg('Cetak total pembayaran bersama QRIS', 5),
      {'type': 'title', 't': 'Metode Pembayaran'},
      {'type': 'hint', 't': 'Metode yang tersedia untuk kasir.'},
      tg('Tunai', 6),
      tg('QRIS', 7),
      tg('Transfer Bank', 8),
      {'type': 'title', 't': 'Rekening Transfer Outlet'},
      {'type': 'hint', 't': 'Ditampilkan saat kasir memilih Transfer.'},
      inp(_bank[0], 'Nama bank, contoh BCA', 2),
      inp(_bank[1], 'Nomor rekening', 3, numeric: true),
      inp(_bank[2], 'Nama pemilik rekening', 4),
      {'type': 'button', 't': 'Simpan Pengaturan', 'primary': true, 'file': '', 'after': false, 'i': 2},
    ];
  }

  @override
  void input(int i, Object value) {
    if (i == 1) _paste = '$value';
    if (i >= 2 && i <= 4) _bank[i - 2] = '$value';
  }

  @override
  void toggle(int i) {
    if (i == 0) {
      host.settings.raw['qrisDynamic'] = !_dynamic;
      host.kv.set(optionsKey, jsonEncode({'dynamic': _dynamic}));
    } else {
      _tg['$i'] = !(_tg['$i'] as bool? ?? i != 1);
    }
    host.saveAll();
    host.refresh();
  }

  @override
  void file(String inputId, String name, String mime, String data) async {
    if (!RegExp(r'^image/(png|jpeg|webp)$').hasMatch(mime)) return host.toast('Pilih gambar PNG, JPG, atau WebP');
    if (data.length * 3 ~/ 4 > 3 * 1024 * 1024) return host.toast('Gambar QRIS maksimal 3 MB');
    final url = 'data:$mime;base64,$data';
    if (!await host.kv.set(Keys.qrisImage, url)) return host.toast('Penyimpanan penuh. Gunakan gambar QRIS lebih kecil.');
    _image = url;
    host.settings.qrisText = '';
    _paste = '';
    await host.saveAll();
    host.toast('Gambar QRIS tersimpan · bisa langsung dipakai');
    host.refresh();
    // Baca isi QR dari gambar agar nominal otomatis bisa dipakai (di HTML: ZXing).
    final text = await decodeQrImage(base64Decode(data), mime);
    if (text != null && qrisValid(text) && _image == url) {
      host.settings.qrisText = text;
      _paste = text;
      await host.saveAll();
      host.refresh();
    }
  }

  @override
  void button(int i) async {
    if (i == 0) return; // pemilih file (fmFile)
    if (i == 1) {
      final text = _paste.replaceAll(RegExp(r'[\r\n\t]'), '').trim();
      if (!qrisValid(text)) return host.toast('Teks QRIS tidak valid. Periksa kode yang ditempel.');
      host.settings.qrisText = text;
      _paste = text;
      await host.saveAll();
      host.toast('QRIS outlet tersimpan');
      return host.refresh();
    }
    final bank = _bank[0].trim(), account = _bank[1].replaceAll(RegExp(r'\D'), ''), holder = _bank[2].trim();
    if ((bank.isNotEmpty || account.isNotEmpty || holder.isNotEmpty) && (bank.isEmpty || account.length < 6 || holder.isEmpty)) {
      return host.toast('Lengkapi nama bank, nomor rekening, dan nama pemilik');
    }
    host.settings.setBank(bank, account, holder);
    _bank = [bank, account, holder];
    await Future.wait([host.kv.set('gy154-bank', bank), host.kv.set('gy154-account', account), host.kv.set('gy154-holder', holder)]);
    await host.saveAll();
    host.toast('Pengaturan pembayaran tersimpan');
    host.refresh();
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
        addAudit(host, '✓', 'Tutup kas', 'omset ${rp(s.sales)}');
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
  String get title => 'HARUS SELESAI HARI INI';
  @override
  String get back => 'home';
  @override
  int get navActive => 1;
  List<String> ids = [];
  @override
  List<Map<String, dynamic>> items() {
    // Aturan sama dengan lencana "Hari Ini" di Beranda (HTML v187 dueCards): jatuh tempo hari ini (WIB),
    // status belum siap/selesai, outlet aktif.
    final b = host.business;
    String day(DateTime d) {
      final j = d.toUtc().add(const Duration(hours: 7));
      return '${j.year}-${j.month}-${j.day}';
    }

    const done = {'siap', 'telat', 'diantar', 'diambil', 'selesai', 'batal'};
    final today = day(host.now), active = b.activeOutlet;
    final list = b.orders.where((o) => o.due != null && day(o.due!) == today && !done.contains(o.status) && (active.isEmpty || o.outlet == active)).toList();
    ids = list.map((o) => o.id).toList();
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
    String st(String s) => const {'jemput': 'Penjemputan', 'antrian': 'Antrian'}[s] ?? 'Proses';
    return [
      {'type': 'hint', 't': 'Pesanan outlet aktif yang masih perlu diselesaikan hari ini.'},
      if (list.isEmpty) {'type': 'hint', 't': 'Tidak ada pesanan yang harus diselesaikan hari ini.'},
      for (var k = 0; k < list.length; k++)
        {'type': 'card', 't': list[k].name, 's': '${list[k].id} · ${hm(list[k].due!)}', 'badge': st(list[k].status), 'i': k},
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

/// Stok & Bahan (inventory v181/v190): ledger stok, opname, supplier, pembelian/hutang, transfer cabang.
/// Data di `goyana-stock181` (sama dengan Hibrida). Semua popup memakai id `g181-modal` seperti HTML.
class StockPage extends PurePage {
  StockPage(super.host);
  StockBook? book;
  String tab = 'stock'; // stock / debt / hist
  String tool = ''; // add / move / op / tr / sup / buy / recv:<id>
  final Map<int, String> f = {};
  final Map<int, int> sel = {};
  @override
  String get title => 'STOK & BAHAN';

  @override
  void opened() {
    tab = 'stock';
    StockBook.load(host.kv).then((b) {
      book = b;
      host.refresh();
    });
  }

  String get outletId => host.business.activeOutlet.isNotEmpty ? host.business.activeOutlet : (host.business.outlets.isEmpty ? 'default' : host.business.outlets.first.id);
  List<List<String>> get _outs => host.business.outlets.isEmpty ? [['default', 'Outlet Aktif']] : [for (final o in host.business.outlets) [o.id, o.name]];
  String _outName(String id) => _outs.where((o) => o[0] == id).firstOrNull?[1] ?? id;
  List<Map<String, dynamic>> _l(String k) => ((book?.raw[k] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  static String _js(Object? v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? '${n.round()}' : '$n';
  }

  static double _num(String? v) => parseQty(v);

  @override
  List<Map<String, dynamic>> items() {
    final b = book;
    if (b == null) return const [];
    final its = b.items, o = outletId;
    final low = its.where((e) => b.balance('${e['id']}', o) <= ((e['min'] as num?) ?? 0)).length;
    final value = its.fold<double>(0, (a, e) {
      final bal = b.balance('${e['id']}', o);
      return a + (bal < 0 ? 0 : bal) * ((e['cost'] as num?) ?? 0);
    });
    Map<String, dynamic> toolCard(String t, String sub, String ic, int i) => {'type': 'card', 't': t, 's': sub, 'svg': '', 'ic': ic, 'badge': '', 'meta': '', 'on': false, 'i': i};
    Map<String, dynamic> row(String t, String line, String amount, [List<Map<String, dynamic>> btns = const []]) =>
        {'type': 'entry', 't': t, 'lines': [line], 'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': amount, 'btns': btns};
    final list = <Map<String, dynamic>>[];
    var next = 10;
    if (tab == 'stock') {
      if (its.isEmpty) list.add({'type': 'title', 't': 'Belum ada bahan.'});
      for (final e in its) {
        list.add(row('${e['name']}', 'Minimum ${_js(e['min'])} ${e['unit']} · ${_outName(o)}', '${qtyText(b.balance('${e['id']}', o))} ${e['unit']}'));
      }
    } else if (tab == 'debt') {
      final debts = _debts;
      if (debts.isEmpty) list.add({'type': 'title', 't': 'Tidak ada hutang supplier.'});
      for (final p in debts) {
        final item = its.where((e) => e['id'] == p['itemId']).firstOrNull;
        final sup = _l('suppliers').where((x) => x['id'] == p['supplierId']).firstOrNull;
        final due = '${p['due'] ?? ''}';
        list.add(row('${item?['name'] ?? 'Bahan'} · Sisa ${rp(((p['total'] as num?) ?? 0) - ((p['paid'] as num?) ?? 0))}', '${sup?['name'] ?? 'Supplier'} · jatuh tempo ${due.isEmpty ? '-' : due}', '',
            [{'t': 'Tandai Lunas', 'on': false, 'i': next++}]));
      }
    } else {
      final led = _l('ledger').reversed.toList();
      if (led.isEmpty) list.add({'type': 'title', 't': 'Belum ada mutasi.'});
      for (final x in led) {
        final item = its.where((e) => e['id'] == x['itemId']).firstOrNull;
        final at = DateTime.tryParse('${x['at']}')?.toLocal();
        final when = at == null ? '' : '${at.day}/${at.month}/${at.year}, ${at.hour.toString().padLeft(2, '0')}.${at.minute.toString().padLeft(2, '0')}.${at.second.toString().padLeft(2, '0')}';
        final q = (x['qty'] as num?) ?? 0;
        list.add(row('${x['type']} · ${item?['name'] ?? 'Bahan'}', '$when · ${x['note'] ?? ''}', '${q > 0 ? '+' : ''}${_js(q)} ${item?['unit'] ?? ''}'));
      }
    }
    final transfers = _l('transfers').where((t) => t['from'] == o || t['to'] == o).toList().reversed;
    return [
      {'type': 'stats', 'cells': [
        {'v': '${its.length}', 't': 'Jenis bahan', 'n': '', 'tone': ''}, {'v': '$low', 't': 'Stok menipis', 'n': '', 'tone': ''}, {'v': rp(value), 't': 'Nilai stok', 'n': '', 'tone': ''},
      ]},
      toolCard('Tambah Bahan', 'Stok awal, minimum, harga', '＋', 0),
      toolCard('Mutasi Stok', 'Masuk / pemakaian', '↕', 1),
      toolCard('Stock Opname', 'Fisik vs sistem', '✓', 2),
      toolCard('Transfer Cabang', 'Antar outlet', '⇄', 3),
      toolCard('Supplier', 'Tambah pemasok', '🏭', 4),
      toolCard('Pembelian', 'Lunas / hutang supplier', '🛒', 5),
      toolCard('Resep HPP', 'Pemakaian saat mulai produksi', '🫧', 6),
      {'type': 'buttons', 'options': [
        for (final (k, t) in const [['stock', 'Stok'], ['debt', 'Hutang'], ['hist', 'Riwayat']].indexed) {'t': t[1], 'svg': '', 'file': '', 'after': false, 'on': tab == t[0], 'i': 7 + k},
      ]},
      ...list,
      {'type': 'hint', 't': 'Stok memakai ledger. Opname mencatat selisih sebagai adjustment, bukan menimpa angka lama.'},
      for (final t in transfers)
        row('${its.where((e) => e['id'] == t['itemId']).firstOrNull?['name'] ?? 'Bahan'} · ${_js(t['qty'])}',
            '${_outName('${t['from']}')} → ${_outName('${t['to']}')} · ${t['status'] == 'received' ? 'Diterima' : 'Dalam perjalanan'}', '',
            [if (t['status'] == 'sent' && t['to'] == o) {'t': 'Konfirmasi diterima lengkap', 'on': false, 'i': 1000 + _l('transfers').indexWhere((x) => x['id'] == t['id'])}]),
    ];
  }

  List<Map<String, dynamic>> get _debts => _l('purchases').where((p) => ((p['total'] as num?) ?? 0) > ((p['paid'] as num?) ?? 0)).toList();

  void _open(String t) {
    tool = t;
    f.clear();
    sel.clear();
    host.openPageSheet('g181-modal');
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    final b = book;
    if (id != 'g181-modal' || b == null) return null;
    Map<String, dynamic> inp(String ph, int i, {bool numeric = false, bool decimal = false}) =>
        {'type': 'input', 'v': f[i] ?? '', 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': decimal, 'ro': false, 'secret': false, 'email': false, 'i': i};
    Map<String, dynamic> pick(List<String> options, int i) => {'type': 'select', 'options': options, 'index': sel[i] ?? 0, 'i': i};
    final itemOpt = [for (final e in b.items) '${e['name']} · ${e['unit']}'];
    final outOpt = [for (final o in _outs) o[1]];
    const ok = [
      {'type': 'button', 't': 'Simpan', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ];
    Map<String, dynamic> title(String t) => {'type': 'title', 't': t, 's': ''};
    return switch (tool) {
      'add' => [title('Tambah Bahan'), inp('Nama bahan', 0), inp('Stok awal', 1, numeric: true, decimal: true), inp('Satuan', 2), inp('Minimum', 3, numeric: true, decimal: true), inp('Harga/unit', 4, numeric: true), ...ok],
      'move' => [title('Mutasi Stok'), pick(itemOpt, 0), pick(const ['Stok Masuk', 'Pemakaian / Keluar'], 1), inp('Jumlah', 2, numeric: true, decimal: true), inp('Catatan', 3), ...ok],
      'op' => [title('Stock Opname'), pick(itemOpt, 0), inp('Stok fisik', 1, numeric: true, decimal: true), inp('Alasan jika ada selisih', 2),
          {'type': 'hint', 't': 'Sistem akan mencatat selisih, bukan mengganti histori stok.'}, ...ok],
      'tr' => [title('Kirim Transfer Cabang'), {'type': 'label', 't': 'Bahan'}, pick(itemOpt, 0), {'type': 'label', 't': 'Cabang asal'}, pick(outOpt, 1), {'type': 'label', 't': 'Cabang tujuan'}, pick(outOpt, 2),
          inp('Jumlah dikirim', 3, numeric: true, decimal: true), {'type': 'hint', 't': 'Stok tujuan bertambah setelah cabang tujuan menerima barang.'}, ...ok],
      'sup' => [title('Tambah Supplier'), inp('Nama supplier', 0), inp('WhatsApp', 1), ...ok],
      'buy' => [title('Pembelian Bahan'), pick(['Tanpa supplier', for (final x in _l('suppliers')) '${x['name']}'], 0), pick(itemOpt, 1), inp('Jumlah', 2, numeric: true, decimal: true), inp('Harga/unit', 3, numeric: true),
          pick(const ['Lunas', 'Hutang Supplier'], 4), {'type': 'date', 'v': f[5] ?? '', 'i': 5}, ...ok],
      _ => [title('Terima transfer'), {'type': 'hint', 't': 'Pastikan seluruh jumlah kiriman sudah diterima. Jika ada selisih, jangan konfirmasi dulu.'}, ...ok],
    };
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    final b = book;
    if (b == null) return;
    if (kind == 'input') {
      if (value is int) {
        sel[index] = value;
        return host.refresh();
      }
      f[index] = '$value';
      if (index == 5 && tool == 'buy') host.refresh();
      return;
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet('g181-modal');
    final its = b.items, o = outletId, now = host.now;
    String itemId(int k) => its.isEmpty ? '' : '${its[(sel[k] ?? 0).clamp(0, its.length - 1)]['id']}';
    void led(Map<String, dynamic> x) => (b.raw['ledger'] as List).add({'id': 'mut-${now.microsecondsSinceEpoch}-${(b.raw['ledger'] as List).length}', 'at': now.toUtc().toIso8601String(), ...x});
    switch (tool) {
      case 'add':
        final n = (f[0] ?? '').trim(), q = _num(f[1]), u = (f[2] ?? '').trim(), m = _num(f[3]), c = parseRupiah(f[4]);
        if (n.isEmpty || u.isEmpty || q < 0 || m < 0) return host.toast('Isi nama, satuan dan jumlah stok yang benar');
        final iid = 'bahan-${now.microsecondsSinceEpoch}';
        (b.raw['items'] as List).add({'id': iid, 'name': n, 'unit': u, 'min': m == m.roundToDouble() ? m.round() : m, 'cost': c});
        if (q != 0) led({'itemId': iid, 'outletId': o, 'type': 'Stok Awal', 'qty': q == q.roundToDouble() ? q.round() : q, 'note': 'Stok awal'});
      case 'move':
        final iid = itemId(0), q = _num(f[2]), out = (sel[1] ?? 0) == 1;
        if (q <= 0 || (out && q > b.balance(iid, o))) return host.toast('Jumlah tidak valid atau stok tidak cukup');
        led({'itemId': iid, 'outletId': o, 'type': out ? 'Pemakaian' : 'Stok Masuk', 'qty': out ? -q : q, 'note': f[3] ?? ''});
      case 'op':
        if (!planAccess.has('opname', now)) return host.toast(planAccess.lockedText('opname'));
        final iid = itemId(0), raw = (f[1] ?? '').trim(), phys = double.tryParse(raw.replaceAll(',', '.')), sys = b.balance(iid, o), note = (f[2] ?? '').trim();
        if (phys == null || phys < 0) return host.toast('Isi stok fisik');
        if (phys != sys && note.isEmpty) return host.toast('Isi alasan selisih');
        led({'itemId': iid, 'outletId': o, 'type': 'Stock Opname', 'qty': phys - sys, 'note': note.isEmpty ? 'Stok cocok' : note, 'systemQty': sys, 'physicalQty': phys});
      case 'tr':
        final outs = _outs, iid = itemId(0), from = outs[(sel[1] ?? 0).clamp(0, outs.length - 1)][0], to = outs[(sel[2] ?? 0).clamp(0, outs.length - 1)][0], q = _num(f[3]);
        if (from != o) return host.toast('Pilih cabang asal yang sedang aktif');
        if (from == to) return host.toast('Cabang tujuan tidak valid');
        if (q <= 0 || q > b.balance(iid, from)) return host.toast('Jumlah tidak valid atau stok tidak cukup');
        final tid = 'transfer-${now.microsecondsSinceEpoch}';
        ((b.raw['transfers'] ??= <dynamic>[]) as List).add({'id': tid, 'itemId': iid, 'from': from, 'to': to, 'qty': q, 'status': 'sent', 'sentAt': now.toUtc().toIso8601String()});
        led({'itemId': iid, 'outletId': from, 'type': 'Transfer Keluar', 'qty': -q, 'ref': tid, 'note': 'Dalam perjalanan ke $to'});
      case 'sup':
        final n = (f[0] ?? '').trim();
        if (n.isEmpty) return;
        (b.raw['suppliers'] as List).add({'id': 'sup-${now.microsecondsSinceEpoch}', 'name': n, 'phone': f[1] ?? ''});
      case 'buy':
        final sups = _l('suppliers'), si = (sel[0] ?? 0) - 1, iid = itemId(1), q = _num(f[2]), c = parseRupiah(f[3]);
        if (q <= 0 || c <= 0) return host.toast('Isi jumlah dan harga');
        final total = (q * c).round(), sup = si >= 0 && si < sups.length ? sups[si] : null;
        (b.raw['purchases'] as List).add({'id': 'buy-${now.microsecondsSinceEpoch}', 'itemId': iid, 'supplierId': sup?['id'] ?? '', 'qty': q, 'total': total, 'paid': (sel[4] ?? 0) == 0 ? total : 0, 'due': f[5] ?? '', 'at': now.toUtc().toIso8601String()});
        for (final e in (b.raw['items'] as List).whereType<Map>()) {
          if (e['id'] == iid) e['cost'] = c;
        }
        led({'itemId': iid, 'outletId': o, 'type': 'Pembelian', 'qty': q, 'note': '${sup?['name'] ?? 'Pembelian'}'});
      default:
        final tid = tool.startsWith('recv:') ? tool.substring(5) : '';
        final t = (b.raw['transfers'] as List? ?? const []).whereType<Map>().where((x) => x['id'] == tid).firstOrNull;
        if (t == null) return host.toast('Transfer tidak ditemukan');
        if (t['to'] != o) return host.toast('Hanya cabang tujuan dapat menerima');
        if (t['status'] == 'sent') {
          led({'itemId': t['itemId'], 'outletId': t['to'], 'type': 'Transfer Masuk', 'qty': t['qty'], 'ref': tid, 'note': 'Diterima dari ${t['from']}'});
          t['status'] = 'received';
          t['receivedAt'] = now.toUtc().toIso8601String();
        }
    }
    b.save();
    tab = 'stock';
    host.closePageSheet('g181-modal');
    host.refresh();
  }

  @override
  void button(int i) async {
    final b = book;
    if (b == null) return;
    if (i >= 7 && i <= 9) {
      tab = const ['stock', 'debt', 'hist'][i - 7];
      return host.refresh();
    }
    if (i >= 1000) {
      final tr = _l('transfers');
      if (i - 1000 < tr.length) _open('recv:${tr[i - 1000]['id']}');
      return;
    }
    if (i >= 10) {
      final debts = _debts;
      if (tab != 'debt' || i - 10 >= debts.length) return;
      final id = debts[i - 10]['id'];
      for (final p in (b.raw['purchases'] as List).whereType<Map>()) {
        if (p['id'] == id) {
          p['paid'] = p['total'];
          p['paidAt'] = host.now.toUtc().toIso8601String();
          p['method'] = 'Pelunasan Hutang';
        }
      }
      await b.save();
      return host.refresh();
    }
    if (i == 6) return host.toast('Resep HPP belum tersedia di Mode Murni');
    if (i == 0) return _open('add');
    if (b.items.isEmpty) return host.toast('Tambahkan bahan dulu');
    if (i == 2 && !planAccess.has('opname', host.now)) return host.toast(planAccess.lockedText('opname'));
    if (i == 3) {
      if (!planAccess.has('transfer', host.now)) return host.toast(planAccess.lockedText('transfer'));
      if (_outs.length < 2) return host.toast('Minimal 2 outlet');
    }
    _open(const ['add', 'move', 'op', 'tr', 'sup', 'buy'][i]);
  }
}

/// Kurir (courier181): tab Tugas dan Management Kurir; data di `goyana-couriers181` (sama dengan Hibrida).
/// Catatan: kartu tugas masih versi ringkas Mode Murni (buka pesanan); pilih kurir/Navigasi/WA per tugas belum dipindah.
class CourierPage extends PurePage {
  CourierPage(super.host);
  Couriers? c;
  bool manage = false;
  String? _editId;
  String _name = '', _phone = '', _email = '';
  final Set<String> _outs = {};
  @override
  String get title => 'KURIR';

  @override
  void opened() {
    manage = false;
    Couriers.load(host.kv).then((v) {
      c = v;
      host.refresh();
    });
  }

  List<Map<String, dynamic>> get _live => [for (final k in c?.list ?? const <Map<String, dynamic>>[]) if (k['deleted'] != true) k];
  List<Order> get _tasks => host.business.orders.where((o) => o.status == 'jemput' || o.status == 'diantar' || (o.status == 'siap' && o.antar)).toList();
  /// Outlet pilihan hak akses; tanpa outlet tersimpan HTML memakai satu "Outlet Aktif".
  List<List<String>> get _outlets => host.business.outlets.isEmpty ? [['default', 'Outlet Aktif']] : [for (final o in host.business.outlets) [o.id, o.name]];

  @override
  List<Map<String, dynamic>> items() {
    final tabs = {
      'type': 'buttons',
      'options': [
        {'t': 'Tugas', 'svg': '', 'file': '', 'after': false, 'on': !manage, 'i': 0},
        {'t': 'Management Kurir', 'svg': '', 'file': '', 'after': false, 'on': manage, 'i': 1},
      ],
    };
    if (!manage) {
      final tasks = _tasks;
      return [
        tabs,
        if (tasks.isEmpty) {'type': 'hint', 't': 'Tidak ada tugas kurir. Pesanan antar-jemput akan muncul otomatis.'},
        // Kartu tugas (HTML v181 renderCourier): pilih kurir, Navigasi, WhatsApp, Bayar (bila belum lunas), tahap berikut.
        for (var k = 0; k < tasks.length; k++) ...[
          {'type': 'title', 't': '${tasks[k].status == 'jemput' ? '📍 Penjemputan' : (tasks[k].status == 'siap' ? '📦 Siap Diantar' : '🚚 Pengantaran')} · ${tasks[k].name}'},
          {'type': 'hint', 't': '${tasks[k].id} · ${_map(tasks[k]).isNotEmpty ? 'Lokasi Maps tersedia' : 'Lokasi belum diisi'}'},
          {
            'type': 'select', 'options': ['Pilih kurir', for (final x in _for(tasks[k])) '${x['name']}'],
            'index': _for(tasks[k]).indexWhere((x) => '${x['id']}' == '${tasks[k].dataset['courier181'] ?? ''}') + 1, 'i': k,
          },
          {'type': 'buttons', 'options': [
            {'t': 'Navigasi', 'on': false, 'i': 1000 + 10 * k},
            {'t': 'WhatsApp', 'on': false, 'i': 1001 + 10 * k},
            if (tasks[k].status != 'jemput' && !tasks[k].isPaid) {'t': 'Bayar', 'on': false, 'i': 1002 + 10 * k},
            {'t': tasks[k].status == 'jemput' ? 'Sudah Dijemput' : (tasks[k].status == 'siap' ? 'Mulai Antar' : 'Sudah Diterima'), 'on': true, 'i': 1003 + 10 * k},
          ]},
        ],
      ];
    }
    final live = _live, outs = _outlets;
    return [
      tabs,
      {'type': 'button', 't': '+ Tambah Kurir', 'primary': true, 'file': '', 'after': false, 'i': 2},
      for (var k = 0; k < live.length; k++)
        {
          'type': 'entry', 't': '${live[k]['name']}',
          'lines': [
            '${live[k]['phone']} · ${live[k]['active'] == false ? 'Nonaktif' : 'Aktif'}',
            'Akses: ${() {
              final ids = (live[k]['outlets'] as List? ?? const []).map((e) => '$e').toList();
              return ids.isEmpty ? 'Semua Outlet' : ids.map((id) => outs.where((o) => o[0] == id).firstOrNull?[1] ?? 'Semua').join(', ');
            }()}',
          ],
          'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
          'btns': [
            {'t': 'Edit', 'on': false, 'i': 3 + 3 * k},
            {'t': live[k]['active'] == false ? 'Aktifkan' : 'Nonaktifkan', 'on': false, 'i': 4 + 3 * k},
            {'t': 'Hapus', 'on': false, 'i': 5 + 3 * k},
          ],
        },
    ];
  }

  String _map(Order o) => mapsLink(host.business.customerByName(o.name));
  /// Kurir aktif yang boleh mengambil tugas outlet pesanan ini.
  List<Map<String, dynamic>> _for(Order o) {
    final out = o.outlet.isNotEmpty ? o.outlet : host.business.activeOutlet;
    return [
      for (final k in _live)
        if (k['active'] != false && ((k['outlets'] as List? ?? const []).isEmpty || (k['outlets'] as List).map((e) => '$e').contains(out))) k,
    ];
  }

  @override
  void input(int i, Object value) {
    final tasks = _tasks;
    if (manage || i < 0 || i >= tasks.length) return;
    final opts = _for(tasks[i]);
    final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    tasks[i].dataset['courier181'] = n >= 1 && n <= opts.length ? '${opts[n - 1]['id']}' : '';
    host.saveAll();
    host.refresh();
  }

  void _task(Order o, int act) {
    switch (act) {
      case 0:
        final m = _map(o);
        if (m.isEmpty) return host.toast('Lokasi belum tersedia');
        host.device.invokeMethod('App.openUrl', {'url': m}).catchError((_) => null);
      case 1:
        var p = (o.phone.isNotEmpty ? o.phone : (host.business.customerByName(o.name)?.phone ?? '')).replaceAll(RegExp(r'\D'), '');
        if (p.startsWith('0')) p = '62${p.substring(1)}';
        if (p.isEmpty) return host.toast('Nomor WA belum ada');
        host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/$p'}).catchError((_) => null);
      case 2:
        host.payOrder(o.id);
      default:
        final id = '${o.dataset['courier181'] ?? ''}';
        if (id.isEmpty) return host.toast('Pilih kurir dulu');
        final by = '${_live.where((k) => '${k['id']}' == id).firstOrNull?['name'] ?? 'Kurir'}';
        final st = o.status;
        host.business.advance(o, now: host.now, by: by);
        host.saveAll();
        host.toast(st == 'jemput' ? 'Sudah dijemput · masuk Antrian' : (st == 'siap' ? 'Pengantaran dimulai' : 'Sudah diterima pelanggan · selesai'));
        host.refresh();
    }
  }

  void _form(Map<String, dynamic>? k) {
    _editId = k == null ? null : '${k['id']}';
    _name = '${k?['name'] ?? ''}';
    _phone = '${k?['phone'] ?? ''}';
    _email = '${k?['email'] ?? ''}';
    final have = (k?['outlets'] as List? ?? const []).map((e) => '$e').toSet();
    _outs
      ..clear()
      ..addAll([for (final o in _outlets) if (k == null || have.isEmpty || have.contains(o[0])) o[0]]);
    host.openPageSheet('g181-modal');
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id != 'g181-modal') return null;
    Map<String, dynamic> inp(String v, String ph, int i, {bool email = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': email, 'i': i};
    final outs = _outlets;
    return [
      {'type': 'title', 't': _editId == null ? 'Tambah Kurir' : 'Edit Kurir', 's': ''},
      inp(_name, 'Nama kurir', 0),
      inp(_phone, 'WhatsApp', 1),
      inp(_email, 'Email login (server nanti)', 2, email: true),
      {'type': 'title', 't': 'Hak akses outlet'},
      for (var k = 0; k < outs.length; k++) {'type': 'toggle', 't': outs[k][1], 's': '', 'on': _outs.contains(outs[k][0]), 'i': k},
      {'type': 'button', 't': 'Simpan', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    final v = c;
    if (v == null) return;
    if (kind == 'input') {
      if (index == 0) _name = '$value';
      if (index == 1) _phone = '$value';
      if (index == 2) _email = '$value';
      return;
    }
    if (kind == 'toggle') {
      final o = _outlets;
      if (index < 0 || index >= o.length) return;
      _outs.contains(o[index][0]) ? _outs.remove(o[index][0]) : _outs.add(o[index][0]);
      return host.refresh();
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet('g181-modal');
    final n = _name.trim(), p = _phone.trim();
    if (n.isEmpty || p.replaceAll(RegExp(r'\D'), '').length < 9) return host.toast('Lengkapi nama dan WhatsApp');
    final outs = [for (final o in _outlets) if (_outs.contains(o[0])) o[0]];
    final cur = v.list.where((k) => '${k['id']}' == _editId).firstOrNull;
    if (cur != null) {
      cur.addAll({'name': n, 'phone': p, 'email': _email.trim(), 'outlets': outs});
    } else {
      v.list.add({'id': 'kurir-${host.now.microsecondsSinceEpoch}', 'name': n, 'phone': p, 'email': _email.trim(), 'outlets': outs, 'active': true});
    }
    v.save();
    host.closePageSheet('g181-modal');
    host.refresh();
  }

  @override
  void button(int i) async {
    final v = c;
    if (i == 0 || i == 1) {
      manage = i == 1;
      return host.refresh();
    }
    if (v == null) return;
    if (i >= 1000) {
      final tasks = _tasks, k = (i - 1000) ~/ 10;
      if (!manage && k < tasks.length) _task(tasks[k], (i - 1000) % 10);
      return;
    }
    if (i == 2) return _form(null);
    final live = _live, k = (i - 3) ~/ 3;
    if (k < 0 || k >= live.length) return;
    final row = live[k];
    switch ((i - 3) % 3) {
      case 0:
        return _form(row);
      case 1:
        row['active'] = row['active'] == false;
        await v.save();
        return host.refresh();
      default:
        host.openFormSheet(FormSheetDef(
          'Hapus kurir ${row['name']}?',
          const [],
          'Ya, Hapus',
          (_) {
            row['deleted'] = true;
            row['active'] = false;
            v.save();
            host.toast('Kurir dihapus');
            host.refresh();
            return null;
          },
          sub: 'Riwayat tugasnya tetap tercatat.',
          danger: true,
        ));
    }
  }
}

/// Pengaturan → Diskon: butir dan popup sama dengan yang dikirim HTML (v127) ke Mode Hibrida.
class DiscountPage extends PurePage {
  DiscountPage(super.host);
  int? _editId;
  String _name = '', _val = '', _min = '', _until = '';
  bool _percent = true;
  int _scope = 0;
  @override
  String get title => 'PENGATURAN DISKON';
  List<Map<String, dynamic>> get _list => discountsOf(host.settings.raw);
  Map<String, dynamic> get _cfg => discCfgOf(host.settings.raw);

  @override
  List<Map<String, dynamic>> items() {
    final list = _list;
    return [
      {'type': 'button', 't': '+ Tambah Diskon', 'primary': false, 'file': '', 'after': false, 'i': 0},
      if (list.isEmpty) {'type': 'title', 't': 'Belum ada diskon. Tekan + Tambah Diskon.'},
      for (var k = 0; k < list.length; k++) ...[
        {'type': 'title', 't': discLabel(list[k])},
        {'type': 'title', 't': '${list[k]['name']}'},
        {'type': 'hint', 't': discDesc(list[k])},
        if (discExpired(list[k], host.now)) {'type': 'hint', 't': 'Sudah berakhir'},
        {'type': 'toggle', 't': '✎🗑', 's': '', 'on': list[k]['on'] != false, 'i': k},
        {
          'type': 'buttons',
          'options': [
            {'t': '✎', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1 + 2 * k},
            {'t': '🗑', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 2 + 2 * k},
          ],
        },
      ],
      {'type': 'title', 't': 'Aturan Kasir'},
      {'type': 'hint', 't': 'Kasir boleh isi diskon manualPotongan Rp bebas saat membuat pesanan'},
      {'type': 'toggle', 't': 'Kasir boleh isi diskon manual', 's': '', 'on': _cfg['manual'] == true, 'i': list.length},
      {'type': 'input', 'label': 'Maksimal diskon kasir', 'sub': 'Diskon di atas batas ini harus oleh owner/admin', 'pre': '', 'suf': '', 'v': '${_cfg['maxPct']}', 'ph': '', 'numeric': false, 'decimal': false, 'ro': false, 'i': 0},
      {'type': 'hint', 't': 'Semua diskon tercatat di Audit AktivitasSiapa memberi diskon, berapa, di pesanan mana'},
      {'type': 'title', 't': 'Aktif'},
    ];
  }

  Future<void> _persist() async {
    await host.saveAll();
    host.refresh();
  }

  @override
  void toggle(int i) {
    final list = _list;
    if (i == list.length) {
      _cfg['manual'] = _cfg['manual'] != true;
      host.toast('Aturan diskon tersimpan');
    } else if (i >= 0 && i < list.length) {
      list[i]['on'] = list[i]['on'] == false;
      host.toast(list[i]['on'] == true ? 'Diskon diaktifkan' : 'Diskon dinonaktifkan');
    }
    _persist();
  }

  @override
  void input(int i, Object value) {
    // Disimpan tiap ketikan tanpa toast (HTML baru menyimpan saat isian ditinggalkan).
    _cfg['maxPct'] = parseRupiah('$value').clamp(0, 100);
    host.saveAll();
  }

  @override
  void button(int i) {
    final list = _list;
    if (i == 0) return _open(null);
    final k = (i - 1) ~/ 2;
    if (k < 0 || k >= list.length) return;
    final d = list[k];
    if (i.isOdd) return _open(d);
    host.openFormSheet(FormSheetDef(
      'Hapus diskon?',
      const [],
      'Ya, Hapus',
      (_) {
        list.remove(d);
        _persist();
        host.toast('Diskon dihapus');
        return null;
      },
      sub: 'Diskon "${d['name']}" tidak bisa dipilih lagi. Pesanan lama tidak berubah.',
      danger: true,
    ));
  }

  void _open(Map<String, dynamic>? d) {
    _editId = d == null ? null : d['id'] as int?;
    _name = '${d?['name'] ?? ''}';
    _percent = (d?['type'] ?? 'p') == 'p';
    final v = d?['val'], m = d?['min'];
    _val = v is num && v > 0 ? '${v.round()}' : '';
    _min = m is num && m > 0 ? '${m.round()}' : '';
    _until = '${d?['until'] ?? ''}';
    final sc = discScopes.indexOf('${d?['scope'] ?? discScopes[0]}');
    _scope = sc < 0 ? 0 : sc;
    host.openPageSheet('disc127');
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) => id != 'disc127'
      ? null
      : [
          {'type': 'title', 't': _editId == null ? 'Tambah Diskon' : 'Edit Diskon', 's': ''},
          {'type': 'hint', 't': 'Diskon aktif muncul sebagai pilihan saat kasir membuat pesanan'},
          {'type': 'label', 't': 'Nama diskon'},
          {'type': 'input', 'v': _name, 'ph': 'Contoh: Member, Promo Jumat', 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': 0},
          {'type': 'label', 't': 'Jenis potongan'},
          {
            'type': 'buttons',
            'options': [
              {'t': 'Persen (%)', 'svg': '', 'file': '', 'after': false, 'on': _percent, 'i': 0},
              {'t': 'Nominal (Rp)', 'svg': '', 'file': '', 'after': false, 'on': !_percent, 'i': 1},
            ],
          },
          {'type': 'label', 't': _percent ? 'Besar potongan (%)' : 'Besar potongan (Rp)'},
          {'type': 'input', 'v': _val, 'ph': _percent ? '10' : '5000', 'multiline': false, 'numeric': true, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': 1},
          {'type': 'label', 't': 'Berlaku untuk'},
          {'type': 'select', 'options': discScopes, 'index': _scope, 'i': 2},
          {'type': 'label', 't': 'Minimal transaksi (opsional)'},
          {'type': 'input', 'v': _min, 'ph': 'Contoh: 50000', 'multiline': false, 'numeric': true, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': 3},
          {'type': 'label', 't': 'Berlaku sampai (opsional)'},
          {'type': 'date', 'v': _until, 'i': 4},
          {'type': 'button', 't': 'Simpan Diskon', 'primary': true, 'file': '', 'after': false, 'i': 2},
        ];

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (kind == 'input') {
      final v = '${value ?? ''}';
      switch (index) {
        case 0:
          _name = v;
        case 1:
          _val = v;
        case 2:
          _scope = (value is int ? value : int.tryParse(v) ?? 0).clamp(0, discScopes.length - 1);
          host.refresh();
        case 3:
          _min = v;
        case 4:
          _until = v;
          host.refresh();
      }
      return;
    }
    if (kind != 'button') return;
    if (index == 0 || index == 1) {
      _percent = index == 0;
      return host.refresh();
    }
    final name = _name.trim(), val = parseRupiah(_val);
    if (name.isEmpty) return host.toast('Isi nama diskon');
    if (val == 0) return host.toast('Isi besar potongan');
    if (_percent && val > 100) return host.toast('Persen maksimal 100');
    final o = <String, dynamic>{'name': name, 'type': _percent ? 'p' : 'n', 'val': val, 'scope': discScopes[_scope], 'min': parseRupiah(_min), 'until': _until};
    final list = _list;
    final cur = list.where((d) => d['id'] == _editId).firstOrNull;
    if (cur != null) {
      cur.addAll(o);
    } else {
      list.add({...o, 'id': nextDiscId(list), 'on': true});
    }
    host.closePageSheet('disc127');
    _persist();
    host.toast('Diskon "$name" tersimpan');
  }
}

/// Kunci PIN kasir rancangan Mode Murni lama (tidak ada di HTML); hanya ditautkan bila masih dipakai.
class PinLockPage extends PurePage {
  PinLockPage(super.host);
  String name = '', phone = '', pin = '';
  @override
  String get back => 'employees';
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

/// Pengaturan → Outlet: daftar outlet (v180). Tombol: 1 tambah, lalu tiap outlet Monitoring 2+2k dan Edit 3+2k.
class OutletsPage extends PurePage {
  OutletsPage(super.host);
  @override
  String get title => 'OUTLET';
  @override
  List<Map<String, dynamic>> items() {
    final list = host.business.outlets;
    return [
      {'type': 'hint', 't': '${list.length} outlet tersimpan'},
      {'type': 'button', 't': '+ Tambah Outlet', 'primary': true, 'file': '', 'after': false, 'i': 1},
      {'type': 'hint', 't': 'Logo cabang bisa di-upload di Edit Outlet. Jika belum ada, tampil ikon toko. Nomor WA divalidasi minimal 10 digit.'},
      if (list.isEmpty) {'type': 'hint', 't': 'Belum ada data. Gunakan tombol tambah untuk mulai.'},
      for (var k = 0; k < list.length; k++)
        {
          'type': 'entry', 't': list[k].name, 'lines': [list[k].address, 'WA ${list[k].phone}'], 'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
          'btns': [{'t': 'Monitoring', 'on': false, 'i': 2 + 2 * k}, {'t': 'Edit', 'on': false, 'i': 3 + 2 * k}],
        },
    ];
  }

  @override
  void button(int i) {
    final list = host.business.outlets;
    if (i == 1) {
      OutletEditPage.editId = null;
      return host.go('outletedit');
    }
    final k = (i - 2) ~/ 2;
    if (k < 0 || k >= list.length) return;
    if (i.isEven) {
      BranchMonitorPage.outletId = list[k].id;
      return host.go('branchmonitor58');
    }
    OutletEditPage.editId = list[k].id;
    host.go('outletedit');
  }
}

/// Edit Outlet (v180): logo, nama, alamat, nomor WA; validasi dan pesan sama dengan HTML.
class OutletEditPage extends PurePage {
  OutletEditPage(super.host);
  static String? editId;
  String _name = '', _address = '', _phone = '', _logo = '';
  @override
  String get title => 'EDIT OUTLET';
  @override
  String get back => 'outlets';

  @override
  void opened() {
    final o = host.business.outlets.where((x) => x.id == editId).firstOrNull;
    _name = o?.name ?? '';
    _address = o?.address ?? '';
    _phone = o?.phone ?? '';
    _logo = '${o?.raw['logo'] ?? ''}';
  }

  Map<String, dynamic> get _use => (host.settings.raw.putIfAbsent('logoUse', () => <String, dynamic>{}) as Map).cast<String, dynamic>();

  @override
  List<Map<String, dynamic>> items() {
    Map<String, dynamic> inp(String v, int i, {bool multi = false, bool numeric = false, String ph = ''}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': multi, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    const uses = ['Tampilkan di Beranda', 'Tampilkan di Nota', 'Tampilkan di Invoice', 'Tampilkan di Label Barcode', 'Tampilkan di Pembayaran QRIS'];
    return [
      {'type': 'title', 't': 'Logo Outlet'},
      {'type': 'hint', 't': 'Logo ini dapat tampil di Beranda, Nota, Invoice dan Label.'},
      {'type': 'image', 'src': _logo, 'svg': '', 'mark': _logo.isEmpty ? '▦' : '', 't': '', 's': ''},
      {
        'type': 'buttons',
        'options': [
          {'t': '↑ Upload Logo', 'svg': '', 'file': 'outlet-logo-file', 'after': false, 'on': false, 'i': 0},
          {'t': 'Hapus Logo', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1},
        ],
      },
      {'type': 'hint', 't': 'PNG/JPG/WebP · disarankan logo persegi · maks. 2 MB'},
      {'type': 'label', 't': 'Nama Outlet'},
      inp(_name, 1),
      {'type': 'label', 't': 'Alamat'},
      inp(_address, 2, multi: true),
      {'type': 'label', 't': 'No. WhatsApp Outlet'},
      inp(_phone, 3, numeric: true, ph: 'Masukkan nomor WhatsApp'),
      {'type': 'title', 't': 'Penggunaan Logo'},
      for (var k = 0; k < uses.length; k++) {'type': 'toggle', 't': uses[k], 's': '', 'on': _use['$k'] != false, 'i': k},
      {'type': 'button', 't': 'Simpan Perubahan', 'primary': true, 'file': '', 'after': false, 'i': 2},
    ];
  }

  @override
  void input(int i, Object value) {
    if (i == 1) _name = '$value';
    if (i == 2) _address = '$value';
    if (i == 3) _phone = '$value';
  }

  @override
  void toggle(int i) {
    _use['$i'] = _use['$i'] == false;
    host.saveAll();
    host.refresh();
  }

  @override
  void file(String inputId, String name, String mime, String data) {
    if (!RegExp(r'^image/(png|jpeg|webp)$').hasMatch(mime) || data.length * 3 ~/ 4 > 2 * 1024 * 1024) {
      return host.toast('Gunakan PNG/JPG/WebP maksimal 2 MB');
    }
    _logo = 'data:$mime;base64,$data';
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 0) return; // pemilihan file ditangani shell (fmFile)
    if (i == 1) {
      _logo = '';
      return host.refresh();
    }
    final b = host.business;
    final name = _name.trim(), address = _address.trim(), phone = _phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (name.isEmpty || address.isEmpty || !RegExp(r'^\+?\d{10,15}$').hasMatch(phone)) return host.toast('Lengkapi nama, alamat, dan nomor WA outlet');
    if (b.outlets.any((o) => o.id != editId && o.name.trim().toLowerCase() == name.toLowerCase() && o.address.trim().toLowerCase() == address.toLowerCase())) {
      return host.toast('Outlet dengan nama dan alamat ini sudah ada. Gunakan Edit.');
    }
    if (editId == null && b.outlets.length >= planAccess.outletLimit(host.now)) return host.toast(planAccess.outletLimitText(host.now));
    final id = await b.upsertOutlet(id: editId, name: name, address: address, phone: phone, logo: _logo);
    if (id == null) return host.toast('Penyimpanan perangkat penuh');
    editId = id;
    host.toast('Outlet tersimpan');
    host.go('outlets');
  }
}

/// Monitoring cabang sementara (rancangan Mode Murni lama) sampai branchmonitor58/superbilling dipindah.
class BranchesPage extends PurePage {
  BranchesPage(super.host);
  String name = '';
  @override
  String get title => 'Cabang & Monitoring';
  @override
  String get back => 'outlets';
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


/// Halaman yang susunannya tetap: butir diambil dari tangkapan HTML ([pageTemplates]) sehingga tampilannya
/// sama persis dengan Mode Hibrida; isian dan saklar disimpan di pengaturan Mode Murni.
class TemplatePage extends PurePage {
  TemplatePage(super.host, this.id, {this.onButton, this.onTap, this.transient = const {}, this.backTo = 'settings'});
  final String id, backTo;
  /// Indeks isian yang tidak disimpan (mis. password).
  final Set<int> transient;
  final void Function(TemplatePage page, int index)? onButton;
  final void Function(TemplatePage page, int index)? onTap;
  final Map<int, String> _temp = {};
  late final Map<String, dynamic> _tpl = jsonDecode(pageTemplates[id]!) as Map<String, dynamic>;

  @override
  String get title => '${_tpl['title']}';
  @override
  String get back => backTo;

  Map<String, dynamic> get _state {
    final all = host.settings.raw.putIfAbsent('tpl', () => <String, dynamic>{}) as Map;
    return (all.putIfAbsent(id, () => <String, dynamic>{}) as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> _bag(String k) => ((_state.putIfAbsent(k, () => <String, dynamic>{})) as Map).cast<String, dynamic>();

  String inputValue(int i) {
    if (transient.contains(i)) return _temp[i] ?? '';
    final v = _bag('in')['$i'];
    if (v != null) return '$v';
    for (final it in (_tpl['items'] as List).whereType<Map>()) {
      if (it['type'] == 'input' && it['i'] == i) return '${it['v'] ?? ''}';
    }
    return '';
  }

  void setInput(int i, String v) => transient.contains(i) ? _temp[i] = v : _bag('in')['$i'] = v;

  bool toggleValue(int i) {
    final v = _bag('tg')['$i'];
    if (v is bool) return v;
    for (final it in (_tpl['items'] as List).whereType<Map>()) {
      if (it['type'] == 'toggle' && it['i'] == i) return it['on'] == true;
    }
    return false;
  }

  @override
  List<Map<String, dynamic>> items() {
    final out = (jsonDecode(jsonEncode(_tpl['items'])) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    for (final it in out) {
      final i = it['i'];
      if (i is! int) continue;
      if (it['type'] == 'input') it['v'] = inputValue(i);
      if (it['type'] == 'toggle') it['on'] = toggleValue(i);
    }
    return out;
  }

  @override
  void input(int i, Object value) {
    setInput(i, '$value');
    if (!transient.contains(i)) host.saveAll();
  }

  @override
  void toggle(int i) {
    _bag('tg')['$i'] = !toggleValue(i);
    host.saveAll();
    host.refresh();
  }

  @override
  void button(int i) => onButton?.call(this, i);
}

/// Halaman berpola tetap beserta aksi tombolnya (teks toast sama dengan HTML).
Map<String, PurePage> templatePages(PureHost host) => {
      'profile': TemplatePage(host, 'profile', transient: const {2}, onButton: (p, i) {
        if (p.inputValue(0).trim().isEmpty) return host.toast('Nama wajib diisi');
        final email = p.inputValue(1), pass = p.inputValue(2);
        if (email.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return host.toast('Format email belum benar');
        if (pass.isNotEmpty && pass.length < 6) return host.toast('Password minimal 6 karakter');
        p.setInput(2, '');
        host.saveAll();
        host.toast('Profil tersimpan');
        host.refresh();
      }),
      'reminder': TemplatePage(host, 'reminder'),
      'upgrade': UpgradePage(host),
      'helpcenter': HelpCenterPage(host),
      'datacenter': DataCenterPage(host),
      'aboutgoyana': TemplatePage(host, 'aboutgoyana'),
      'cashier': TemplatePage(host, 'cashier', onButton: (p, i) => host.go('employees')),
      'barcode': TemplatePage(host, 'barcode', onButton: (p, i) => i == 0 ? host.go('printer') : host.toast('Label test dikirim ke printer')),
    };


/// Pusat Bantuan: pencarian menyaring kartu topik, tiap topik membuka popup panduan (guide135) yang sama dengan Hibrida.
class HelpCenterPage extends TemplatePage {
  // ignore: use_super_parameters
  HelpCenterPage(PureHost host) : super(host, 'helpcenter');
  static const supportWa = '6280000000000'; // sama dengan CS_WA100 di HTML (masih nomor contoh)
  late final List<dynamic> _guides = jsonDecode(guideSheets) as List;
  int _guide = 0;
  String _q = '';

  @override
  List<Map<String, dynamic>> items() {
    final q = _q.trim().toLowerCase();
    return [
      for (final it in super.items())
        if (it['type'] != 'card' || q.isEmpty || '${it['t']} ${it['s']}'.toLowerCase().contains(q)) it,
    ];
  }

  @override
  String inputValue(int i) => _q;
  @override
  void input(int i, Object value) {
    _q = '$value';
    host.refresh();
  }

  @override
  void button(int i) {
    if (i >= 0 && i < _guides.length) {
      _guide = i;
      return host.openPageSheet('guide135');
    }
    final outlet = host.business.outlets.isEmpty ? 'Outlet' : host.business.outlets.first.name;
    host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/$supportWa?text=${Uri.encodeComponent('Halo tim GOYANA, saya butuh bantuan. Outlet: $outlet. Kendala: ')}'}).catchError((_) => null);
    host.toast('Membuka WhatsApp CS GOYANA…');
  }

  @override
  Widget? sheetWidget(String id, BuildContext context) {
    if (id != 'guide135') return null;
    void close() => host.closePageSheet('guide135');
    return NativeGuide135Sheet(
      key: ValueKey('pure-guide135-$_guide'),
      model: Map<String, dynamic>.from((_guides[_guide] as Map)['mirror'] as Map),
      actions: PopupActions(
        id: 'guide135',
        onButton: (b) {
          close();
          if (b == 0) host.go(guideTarget(_guide));
        },
        onTap: (_) {},
        onInput: (_, _) {},
        onClose: close,
      ),
    );
  }

  /// Halaman tujuan "Coba Sekarang" (nama halaman Mode Murni).
  String guideTarget(int k) {
    final go = '${(_guides[k] as Map)['go']}';
    return const {'whatsappbot': 'whatsapp'}[go] ?? go;
  }
}


/// Pusat Data: tampilan dari HTML, tetapi ekspor/backup/hapus trial sungguhan
/// (di HTML semuanya masih contoh: CSV berisi data contoh, backup & hapus trial tidak menyentuh data).
class DataCenterPage extends TemplatePage {
  // ignore: use_super_parameters
  DataCenterPage(PureHost host) : super(host, 'datacenter');
  String _preview = '';

  String get _lastBackup {
    final at = DateTime.tryParse('${_state['backupAt'] ?? ''}');
    if (at == null) return 'Belum ada backup';
    final n = host.now;
    final hm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final today = at.year == n.year && at.month == n.month && at.day == n.day;
    return 'Backup terakhir: ${today ? 'Hari ini' : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}'} $hm';
  }

  @override
  List<Map<String, dynamic>> items() {
    final out = super.items();
    final b = host.business;
    (out[0]['cells'] as List)
      ..[0]['v'] = '${b.customers.length}'
      ..[1]['v'] = '${b.orders.length}'
      ..[2]['v'] = '${_state['backups'] ?? 0}';
    for (final it in out) {
      if (it['type'] == 'card' && it['i'] == 4) it['s'] = _lastBackup;
    }
    if (_preview.isNotEmpty) {
      final k = out.indexWhere((e) => e['t'] == 'Preview Import');
      if (k >= 0 && k + 1 < out.length) {
        out[k]['t'] = _preview;
        out[k + 1]['t'] = 'File belum dipilih. Pada sistem final: pilih CSV/Excel → mapping kolom → preview → deteksi duplikat/error → konfirmasi import.';
      }
    }
    return out;
  }

  @override
  void opened() => _preview = '';

  Future<bool> _save(String name, String mime, String text) async {
    try {
      await host.device.invokeMethod<dynamic>('Files.save', {'name': name, 'mime': mime, 'data': base64Encode(utf8.encode(text))});
      return true;
    } on PlatformException catch (e) {
      host.toast(e.message ?? 'Gagal menyimpan file');
    } catch (_) {
      host.toast('Gagal menyimpan file');
    }
    return false;
  }

  @override
  void button(int i) async {
    final d = host.now.toIso8601String().substring(0, 10);
    switch (i) {
      case 0 || 1 || 2:
        _preview = const ['Import Pelanggan', 'Import Layanan & Harga', 'Import Transaksi Lama'][i];
        return host.refresh();
      case 3:
        if (!planAccess.has('export', host.now)) return host.toast(planAccess.lockedText('export'));
        final a = await _save('goyana-pesanan-$d.csv', 'text/csv', '﻿${host.business.ordersCsv()}');
        final c = a && await _save('goyana-pelanggan-$d.csv', 'text/csv', '﻿${host.business.customersCsv()}');
        if (c) host.toast('Data diekspor ke CSV (bisa dibuka di Excel)');
      case 4:
        final ok = await _save('goyana-backup-$d.json', 'application/json', jsonEncode({
          'app': 'GOYANA', 'version': 1, 'at': host.now.toIso8601String(),
          'business': host.business.raw, 'services': host.business.services.map((e) => e.raw).toList(),
          'outlets': host.business.outlets.map((e) => e.raw).toList(), 'settings': host.settings.raw, 'perfumes': host.settings.perfumes,
        }));
        if (!ok) return;
        _state['backupAt'] = host.now.toIso8601String();
        _state['backups'] = ((_state['backups'] as num?)?.toInt() ?? 0) + 1;
        await host.saveAll();
        host.toast('Backup tersimpan di folder Download/GOYANA');
        host.refresh();
      case 5:
        host.toast('Restore dari file cadangan belum tersedia di Mode Murni');
      case 6:
        host.openFormSheet(FormSheetDef(
          'Hapus data trial?',
          const [FormSheetField('Ketik HAPUS', placeholder: 'HAPUS', required: true)],
          'Hapus Data Trial',
          (v) {
            if (v[0].toUpperCase() != 'HAPUS') {
              host.toast('Ketik HAPUS untuk konfirmasi');
              return false;
            }
            final raw = host.business.raw;
            (raw['orders'] as List?)?.clear();
            (raw['customers'] as List?)?.clear();
            (raw['details'] as Map?)?.clear();
            (raw['deposits178'] as Map?)?.clear();
            host.saveAll();
            host.toast('Data trial dihapus · siap mulai dari nol');
            host.refresh();
            return null;
          },
          sub: 'Semua order, pelanggan dan laporan selama trial dihapus permanen. Outlet, layanan, harga & pegawai tetap. Ketik HAPUS untuk lanjut.',
          danger: true,
        ));
    }
  }
}


/// Keuangan & Kas → Kategori Pengeluaran (sama dengan HTML; di HTML daftar ini tidak tersimpan, di sini tersimpan).
class FinancePage extends PurePage {
  FinancePage(super.host);
  @override
  String get title => 'KATEGORI PENGELUARAN';
  List<dynamic> get _cats => host.settings.raw.putIfAbsent('expenseCats', () => <dynamic>[]) as List;

  @override
  List<Map<String, dynamic>> items() => [
        for (var k = 0; k < _cats.length; k++)
          {
            'type': 'entry', 't': '${_cats[k]}', 'lines': <String>[], 'badge': '', 'avatar': '', 'svg': '', 'color': '', 'compact': true,
            'btns': [{'t': '✎', 'on': false, 'i': 2 * k}, {'t': '×', 'on': false, 'i': 2 * k + 1}],
          },
        {'type': 'button', 't': '+ Tambah Kategori', 'primary': true, 'file': '', 'after': false, 'i': 2 * _cats.length},
      ];

  void _done(String toast) {
    host.saveAll();
    host.toast(toast);
    host.refresh();
  }

  @override
  void button(int i) {
    final c = _cats;
    if (i == 2 * c.length) {
      return host.openFormSheet(FormSheetDef(
        'Tambah Kategori',
        const [FormSheetField('Nama kategori', placeholder: 'Contoh: Perawatan Mesin', required: true)],
        'Tambah',
        (v) {
          c.add(v[0]);
          _done('Kategori "${v[0]}" ditambahkan');
          return null;
        },
        sub: 'Kategori untuk mencatat pengeluaran',
      ));
    }
    final k = i ~/ 2;
    if (k < 0 || k >= c.length) return;
    final name = '${c[k]}';
    if (i.isOdd) {
      return host.openFormSheet(FormSheetDef(
        'Hapus "$name"?',
        const [],
        'Ya, Hapus',
        (_) {
          c.removeAt(k);
          _done('$name dihapus');
          return null;
        },
        sub: 'Data yang sudah dipakai di transaksi lama tetap tersimpan di laporan.',
        danger: true,
      ));
    }
    host.openFormSheet(FormSheetDef('Edit', [FormSheetField('Nama', value: name, required: true)], 'Simpan', (v) {
      c[k] = v[0];
      _done('Perubahan tersimpan');
      return null;
    }));
  }
}


/// Pengaturan → Antar-Jemput: tarif transportasi (v184), layanan jemput/antar, jam kurir, daftar kurir.
class DeliveryPage extends PurePage {
  DeliveryPage(super.host);
  String? _mode;
  final Map<String, String> _vals = {};
  bool? _manual;
  @override
  String get title => 'ANTAR-JEMPUT';

  String get _outletId => host.business.activeOutlet.isNotEmpty ? host.business.activeOutlet : (host.business.outlets.isEmpty ? '' : host.business.outlets.first.id);
  String get _outletName {
    final o = host.business.outlets;
    return (o.where((x) => x.id == _outletId).firstOrNull ?? o.firstOrNull)?.name ?? 'Outlet Aktif';
  }

  Map<String, dynamic> get _cfg => transportCfg(_outletId);
  Map<String, dynamic> get _d => deliveryOf(host.settings.raw);
  String get _curMode => _mode ?? '${_cfg['mode']}';
  List<List<String>> get _fields => transportFields[_curMode] ?? const [];

  @override
  void opened() {
    _mode = null;
    _manual = null;
    _vals.clear();
  }

  @override
  List<Map<String, dynamic>> items() {
    final cfg = _cfg, d = _d, f = _fields;
    Map<String, dynamic> fld(String key, int i) => {
          'type': 'input', 'v': _vals[key] ?? '${(cfg[key] as num? ?? 0).round()}', 'ph': '', 'multiline': false, 'numeric': true, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i,
        };
    final couriers = (d['couriers'] as List).whereType<Map>().toList();
    return [
      {'type': 'title', 't': 'Tarif Transportasi', 's': ''},
      {'type': 'hint', 't': 'Diatur oleh owner untuk $_outletName. Pilihan pertama selalu Gratis Transportasi.'},
      {'type': 'choice', 't': '', 'options': [for (var k = 0; k < transportModes.length; k++) {'t': transportModes[k][1], 's': transportModes[k][2], 'on': transportModes[k][0] == _curMode, 'i': k}]},
      if (_curMode == 'free') {'type': 'hint', 't': 'Tidak ada biaya transportasi. Order Jemput & Antar tetap berjalan, tetapi ongkir Rp0.'},
      for (var k = 0; k < f.length; k++) ...[
        {'type': 'label', 't': f[k][1]},
        fld(f[k][0], k),
      ],
      if (_curMode == 'distance') {'type': 'hint', 't': 'Perhitungan jarak otomatis diaktifkan setelah Maps API + Laravel tersedia. Prototype tidak menagih berdasarkan jarak agar tidak salah hitung.'},
      {'type': 'toggle', 't': 'Izinkan kasir mengubah ongkir manual', 's': 'Nanti wajib tercatat di Audit Log.', 'on': _manual ?? cfg['manual'] == true, 'i': 0},
      {'type': 'button', 't': 'SIMPAN TARIF', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'toggle', 't': 'Layanan Antar-Jemput', 's': 'Matikan jika outlet hanya melayani pelanggan datang langsung', 'on': d['on'] == true, 'i': 1},
      {'type': 'toggle', 't': 'Layanan jemput cucian', 's': 'tab Penjemputan di Pesanan', 'on': d['jemput'] == true, 'i': 2},
      {'type': 'toggle', 't': 'Layanan antar cucian', 's': 'tab Diantar di Pesanan', 'on': d['antar'] == true, 'i': 3},
      {'type': 'title', 't': 'Jam layanan kurir'},
      // Indeks isian jam = jumlah isian tarif + 4 (kartu "Ongkos kirim" lama di HTML tersembunyi tetapi tetap terhitung).
      {'type': 'input', 'label': 'Jemput', 'sub': '', 'pre': '', 'suf': '', 'v': '${d['hJemput']}', 'ph': '', 'numeric': false, 'decimal': false, 'ro': false, 'i': f.length + 4},
      {'type': 'input', 'label': 'Antar', 'sub': '', 'pre': '', 'suf': '', 'v': '${d['hAntar']}', 'ph': '', 'numeric': false, 'decimal': false, 'ro': false, 'i': f.length + 5},
      {'type': 'title', 't': 'Kurir'},
      for (final c in couriers)
        {'type': 'entry', 't': '${c['n']}', 'lines': ['${c['p']} · motor'], 'badge': 'Aktif', 'avatar': '${c['n']}'.isEmpty ? '' : '${c['n']}'[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'button', 't': '+ Tambah Kurir', 'primary': false, 'file': '', 'after': false, 'i': 1},
      {'type': 'button', 't': 'Simpan Pengaturan', 'primary': true, 'file': '', 'after': false, 'i': 2},
    ];
  }

  @override
  void radio(int i) {
    _mode = transportModes[i.clamp(0, transportModes.length - 1)][0];
    host.refresh();
  }

  @override
  void input(int i, Object value) {
    final f = _fields;
    if (i < f.length) {
      _vals[f[i][0]] = '$value';
    } else {
      _d[i == f.length + 4 ? 'hJemput' : 'hAntar'] = '$value';
      host.saveAll();
    }
  }

  @override
  void toggle(int i) {
    if (i == 0) {
      _manual = !(_manual ?? _cfg['manual'] == true);
      return host.refresh();
    }
    final d = _d, k = const ['on', 'jemput', 'antar'][(i - 1).clamp(0, 2)];
    d[k] = d[k] != true;
    host.saveAll();
    host.toast(d['on'] != true ? 'Antar-jemput dinonaktifkan · tab Penjemputan & Diantar disembunyikan' : 'Pengaturan antar-jemput diperbarui');
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 0) {
      // Tarif mode lain yang tidak sedang ditampilkan dipertahankan (di HTML ikut menjadi 0).
      final n = _cfg..['mode'] = _curMode;
      for (final f in _fields) {
        n[f[0]] = (num.tryParse(_vals[f[0]] ?? '${n[f[0]]}') ?? 0).clamp(0, double.infinity).round();
      }
      n['manual'] = _manual ?? n['manual'] == true;
      if (!await saveTransport(host.kv, _outletId, n)) return host.toast('Penyimpanan perangkat penuh');
      opened();
      host.toast(n['mode'] == 'free' ? 'Transportasi GRATIS tersimpan' : 'Tarif transportasi tersimpan');
      return host.refresh();
    }
    if (i == 1) {
      return host.openFormSheet(FormSheetDef(
        'Tambah Kurir',
        const [FormSheetField('Nama kurir', required: true), FormSheetField('No WhatsApp', numeric: true, required: true)],
        'Tambah',
        (v) {
          (_d['couriers'] as List).add({'n': v[0], 'p': v[1]});
          host.saveAll();
          host.toast('Kurir ${v[0]} ditambahkan');
          host.refresh();
          return null;
        },
      ));
    }
    await host.saveAll();
    host.toast('Pengaturan antar-jemput tersimpan');
    host.go('settings');
  }
}


/// Mode Uji (v192): coba akses paket premium dengan password; hanya berlaku sampai aplikasi ditutup.
class TestModePage extends PurePage {
  TestModePage(super.host);
  String _pass = '', _error = '';
  int _plan = 3;
  @override
  String get title => 'MODE UJI';

  @override
  void opened() {
    _pass = '';
    _error = '';
    final k = planCatalog.indexWhere((p) => p[0] == planAccess.testPlan);
    if (k >= 0) _plan = k;
  }

  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'hint', 't': 'GOYANA UJI · DATA PERANGKAT INI'},
        {'type': 'title', 't': 'Coba Paket Premium', 's': ''},
        {'type': 'hint', 't': 'Mode ini untuk menguji tampilan dan akses fitur. Tidak ada pembayaran atau perubahan paket pelanggan.'},
        if (planAccess.testPlan == null) ...[
          {'type': 'label', 't': 'Password Mode Uji'},
          {'type': 'input', 'v': _pass, 'ph': 'Masukkan password', 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': true, 'email': false, 'i': 0},
          {'type': 'button', 't': 'Buka Mode Uji', 'primary': true, 'file': '', 'after': false, 'i': 0},
          if (_error.isNotEmpty) {'type': 'hint', 't': _error},
        ] else ...[
          {'type': 'label', 't': 'Paket yang dicoba'},
          {'type': 'select', 'options': [for (final p in planCatalog) p[0]], 'index': _plan, 'i': 1},
          {'type': 'hint', 't': 'Mode Uji aktif: ${planAccess.testPlan} · tanpa pembayaran'},
          {'type': 'button', 't': 'Terapkan Paket Uji', 'primary': true, 'file': '', 'after': false, 'i': 1},
          {'type': 'button', 't': 'Keluar Mode Uji', 'primary': false, 'file': '', 'after': false, 'i': 2},
        ],
        {'type': 'hint', 't': 'AI dan pengiriman WhatsApp sungguhan tetap memerlukan server. Password ini mengunci menu uji; bukan sistem keamanan paket produksi.'},
      ];

  @override
  void input(int i, Object value) {
    if (i == 0) {
      _pass = '$value';
    } else {
      _plan = (value is int ? value : int.tryParse('$value') ?? 0).clamp(0, planCatalog.length - 1);
      host.refresh();
    }
  }

  @override
  void button(int i) {
    if (i == 0) {
      if (!planAccess.unlockTest(_pass)) {
        _error = 'Password salah.';
        return host.refresh();
      }
      opened();
      host.toast('Mode Uji Platinum aktif');
    } else if (i == 1) {
      planAccess.testPlan = planCatalog[_plan][0] as String;
      host.toast('Paket uji: ${planAccess.testPlan}');
    } else {
      planAccess.testPlan = null;
      opened();
      host.toast('Mode Uji ditutup · kembali ke paket asli');
    }
    host.refresh();
  }
}


/// Pengaturan → Pegawai (emp157/v158): data pegawai + hak akses di kunci `goyana_employees_v157` (sama dengan Hibrida).
/// Seperti HTML, password tidak disimpan di perangkat.
class EmployeesPage extends PurePage {
  EmployeesPage(super.host);
  static const key = 'goyana_employees_v157';
  static const perms = [
    ['order_create', 'Membuat Order / Transaksi'], ['order_backdate', 'Membuat Order Backdate (Tanggal Mundur)'], ['order_edit', 'Edit Order / Transaksi'],
    ['order_cancel', 'Membatalkan Order / Transaksi'], ['expense_create', 'Membuat Pengeluaran'], ['wash', 'Cuci (Khusus Paket Premium)'],
    ['dry', 'Kering (Khusus Paket Premium)'], ['iron', 'Setrika (Khusus Paket Premium)'], ['pack', 'Packing (Khusus Paket Premium)'],
    ['services', 'Mengelola Layanan / Produk'], ['customers', 'Mengelola Data Pelanggan'], ['employees', 'Mengelola Data Pegawai'],
    ['revenue', 'Menampilkan Nilai Omset'], ['transactions_report', 'Akses Laporan Transaksi'], ['finance_report', 'Akses Laporan Keuangan'],
    ['performance_report', 'Akses Laporan Kinerja'], ['customers_report', 'Akses Laporan Pelanggan'],
  ];
  List<Map<String, dynamic>> list = [];
  int _editing = -1;
  String _name = '', _phone = '', _email = '', _pass = '';
  final Set<String> _on = {};
  @override
  String get title => 'PENGATURAN PEGAWAI';

  void _reset() {
    _editing = -1;
    _name = _phone = _email = _pass = '';
    _on.clear();
  }

  @override
  void opened() {
    _reset();
    host.kv.get(key).then((raw) {
      try {
        final v = jsonDecode(raw ?? '[]');
        list = v is List ? [for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)] : [];
      } catch (_) {
        list = [];
      }
      host.refresh();
    });
  }

  @override
  List<Map<String, dynamic>> items() {
    Map<String, dynamic> inp(String v, String ph, int i, {bool numeric = false, bool secret = false, bool email = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': secret, 'email': email, 'i': i};
    final legacyPin = host.settings.raw['pinLock'] == true || ((host.settings.raw['employees'] as List?)?.isNotEmpty ?? false);
    return [
      {'type': 'label', 't': 'Nama Pegawai'},
      inp(_name, 'Masukkan Nama Pegawai', 0),
      {'type': 'label', 't': 'No Handphone'},
      inp(_phone, 'Masukkan No Handphone', 1, numeric: true),
      {'type': 'label', 't': 'Email'},
      inp(_email, 'Masukkan Alamat Email', 2, email: true),
      {'type': 'label', 't': 'Password'},
      inp(_pass, _editing < 0 ? 'Masukkan Password untuk pegawai login' : 'Kosongkan jika tidak diganti', 3, secret: true),
      {'type': 'title', 't': 'Hak Akses'},
      for (var k = 0; k < perms.length; k++) {'type': 'toggle', 't': perms[k][1], 's': '', 'on': _on.contains(perms[k][0]), 'i': k},
      {'type': 'button', 't': _editing < 0 ? 'SIMPAN DATA PEGAWAI' : 'SIMPAN PERUBAHAN PEGAWAI', 'primary': true, 'file': '', 'after': false, 'i': 0},
      if (list.isNotEmpty) {'type': 'title', 't': 'Pegawai tersimpan'},
      for (var k = 0; k < list.length; k++) {'type': 'row', 't': '${list[k]['name']} · ${list[k]['phone']}', 'btn': 'Edit', 'i': 1 + k},
      if (legacyPin) card('Kunci PIN kasir', 'Fitur Mode Murni lama · atur atau matikan', '🔒', 900),
    ];
  }

  @override
  void input(int i, Object value) {
    final v = '$value';
    if (i == 0) _name = v;
    if (i == 1) _phone = v;
    if (i == 2) _email = v;
    if (i == 3) _pass = v;
  }

  @override
  void toggle(int i) {
    if (i < 0 || i >= perms.length) return;
    final p = perms[i][0];
    _on.contains(p) ? _on.remove(p) : _on.add(p);
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 900) return host.go('pinlock');
    if (i >= 1) {
      final k = i - 1;
      if (k >= list.length) return;
      final row = list[k];
      _editing = k;
      _name = '${row['name']}';
      _phone = '${row['phone']}';
      _email = '${row['email'] ?? ''}';
      _pass = '';
      _on
        ..clear()
        ..addAll([for (final p in (row['permissions'] as List? ?? const [])) '$p']);
      return host.refresh();
    }
    final name = _name.trim(), phone = _phone.replaceAll(RegExp(r'[^0-9+]'), ''), email = _email.trim();
    if (name.isEmpty) return host.toast('Isi nama pegawai');
    if (!RegExp(r'^\+?\d{9,15}$').hasMatch(phone)) return host.toast('Periksa nomor handphone');
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return host.toast('Periksa alamat email');
    if ((_editing < 0 || _pass.isNotEmpty) && _pass.length < 6) return host.toast('Password minimal 6 karakter');
    for (var k = 0; k < list.length; k++) {
      if (k != _editing && '${list[k]['email']}'.toLowerCase() == email.toLowerCase()) return host.toast('Email pegawai sudah digunakan');
    }
    final row = <String, dynamic>{'name': name, 'phone': phone, 'email': email, 'permissions': [for (final p in perms) if (_on.contains(p[0])) p[0]]};
    final next = [...list];
    _editing < 0 ? next.add(row) : next[_editing] = row;
    if (!await host.kv.set(key, jsonEncode(next))) return host.toast('Penyimpanan perangkat penuh');
    list = next;
    _reset();
    host.toast('Data pegawai tersimpan di perangkat ini');
    host.refresh();
  }
}


/// Catat aktivitas ke Audit (di HTML hanya ada di memori; di sini tersimpan, paling banyak 300 terakhir).
void addAudit(PureHost host, String icon, String title, String sub) {
  final list = host.settings.raw.putIfAbsent('audit', () => <dynamic>[]) as List;
  list.insert(0, {'ic': icon, 't': title, 's': sub, 'at': host.now.toIso8601String()});
  if (list.length > 300) list.removeRange(300, list.length);
}

/// Pengaturan → Audit Aktivitas: cari, saring Semua/Transaksi/Kas/Login (aturan kata sama dengan HTML).
class AuditPage extends PurePage {
  AuditPage(super.host);
  String _q = '';
  int _chip = 0;
  static const _chips = ['Semua', 'Transaksi', 'Kas', 'Login'];
  static final _re = [null, RegExp('transaksi|pesanan|harga', caseSensitive: false), RegExp('kas|pengeluaran', caseSensitive: false), RegExp('login', caseSensitive: false)];
  @override
  String get title => 'AUDIT AKTIVITAS';

  @override
  void opened() {
    _q = '';
    _chip = 0;
  }

  @override
  List<Map<String, dynamic>> items() {
    final n = host.now;
    final rows = <Map<String, dynamic>>[];
    for (final e in (host.settings.raw['audit'] as List? ?? const []).whereType<Map>()) {
      final at = DateTime.tryParse('${e['at']}');
      final today = at != null && at.year == n.year && at.month == n.month && at.day == n.day;
      final sub = today || at == null ? '${e['s']}' : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} · ${e['s']}';
      final text = '${e['ic']}${e['t']}$sub';
      // Seperti HTML: pencarian (bila diisi) mengalahkan chip; selain itu chip menyaring dengan kata kunci.
      final show = _q.isNotEmpty ? text.toLowerCase().contains(_q.toLowerCase()) : (_re[_chip]?.hasMatch(text) ?? true);
      if (show) rows.add({'type': 'entry', 't': '${e['t']}', 'lines': [sub], 'badge': '', 'avatar': '${e['ic']}', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]});
    }
    return [
      {'type': 'title', 't': '⌕'},
      {'type': 'input', 'v': _q, 'ph': 'Cari pegawai / Order ID...', 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': 0},
      {'type': 'button', 't': '≡', 'primary': false, 'file': '', 'after': false, 'i': 0},
      {'type': 'buttons', 'options': [for (var k = 0; k < _chips.length; k++) {'t': _chips[k], 'svg': '', 'file': '', 'after': false, 'on': k == _chip, 'i': 1 + k}]},
      {'type': 'title', 't': 'HARI INI'},
      ...rows,
      {'type': 'hint', 't': 'Riwayat audit tidak dapat diedit oleh kasir. Owner dapat melakukan filter dan export untuk pemeriksaan.'},
    ];
  }

  @override
  void input(int i, Object value) {
    _q = '$value';
    host.refresh();
  }

  @override
  void button(int i) {
    if (i >= 1) {
      _chip = (i - 1).clamp(0, 3);
      _q = '';
      return host.refresh();
    }
    final d = host.now;
    host.openFormSheet(FormSheetDef(
      'Filter Audit',
      [
        FormSheetField('Dari tanggal', value: '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
        const FormSheetField('Nama pegawai (opsional)', placeholder: 'Contoh: Rani'),
      ],
      'Terapkan',
      (v) {
        if (v[1].isNotEmpty) _q = v[1];
        host.toast('Filter audit diterapkan');
        host.refresh();
        return null;
      },
    ));
  }
}


/// CRM Pelanggan: halaman Dart yang sama dengan Mode Hibrida (NativeCrm, data `goyana-crm203`).
class CrmNativePage extends PurePage {
  CrmNativePage(super.host);
  int _open = 0;
  @override
  String get title => 'CRM PELANGGAN';
  @override
  String get back => 'customers';
  @override
  void opened() => _open++;
  @override
  List<Map<String, dynamic>> items() => const [];
  @override
  Widget? custom(BuildContext context, FormActions actions) {
    final o = host.business.outlets;
    return NativeCrm(
      key: ValueKey('pure-crm-$_open'),
      store: host.kv,
      onBack: () => host.go(back),
      onNav: actions.nav,
      onScan: actions.scan,
      openUrl: (u) => host.device.invokeMethod('App.openUrl', {'url': u}).catchError((_) => null),
      outlet: (o.where((x) => x.id == host.business.activeOutlet).firstOrNull ?? o.firstOrNull)?.name ?? 'Outlet',
      now: () => host.now,
    );
  }
}


List<Order> _outletOrders(PureHost host, String outletId) {
  final first = host.business.outlets.isEmpty ? '' : host.business.outlets.first.id;
  return host.business.orders.where((o) => !o.isCancelled && (o.outlet == outletId || (o.outlet.isEmpty && outletId == first))).toList();
}

String _monSt(Order o, DateTime now) => o.isLate(now) ? 'telat' : o.status;
bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Manajemen Cabang (superbilling/v180): ringkasan semua outlet + tombol Monitor per cabang.
class ManageBranchesPage extends PurePage {
  ManageBranchesPage(super.host);
  @override
  String get title => 'MANAJEMEN CABANG';
  @override
  List<Map<String, dynamic>> items() {
    final b = host.business, n = host.now, outs = b.outlets;
    final cur = outs.where((o) => o.id == b.activeOutlet).firstOrNull ?? outs.firstOrNull;
    final all = [for (final o in outs) ..._outletOrders(host, o.id)];
    final omzet = all.where((o) => _sameDay(o.created, n)).fold<int>(0, (a, o) => a + o.total);
    Map<String, dynamic> mon(int k) => {'t': 'Monitor ${outs[k].name}', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1 + k};
    return [
      {'type': 'entry', 't': cur?.name ?? 'Belum ada outlet', 'lines': ['OUTLET OPERASIONAL', 'Akun ini selalu bekerja di outlet ini. Cabang lain hanya bisa dimonitor, tidak bisa dipindah.'], 'badge': '', 'avatar': '🔒', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'hero', 't': 'Outlet tersimpan', 'v': '${outs.length}', 's': 'Tambahkan dan kelola outlet usaha'},
      {'type': 'button', 't': '＋ Tambah Cabang', 'primary': false, 'file': '', 'after': false, 'i': 0},
      {'type': 'stats', 'cells': [
        {'v': rp(omzet), 't': 'Total Omzet Hari Ini', 'n': '', 'tone': ''},
        {'v': '${all.where((o) => !const ['selesai', 'diambil'].contains(_monSt(o, n))).length}', 't': 'Order Aktif', 'n': '', 'tone': ''},
        {'v': '${all.where((o) => o.isLate(n)).length}', 't': 'Terlambat', 'n': '', 'tone': ''},
      ]},
      {'type': 'title', 't': 'Monitoring Cabang'},
      {'type': 'hint', 't': 'Pilih cabang untuk melihat kondisi operasionalnya'},
      if (outs.isEmpty) {'type': 'hint', 't': 'Tambahkan outlet untuk mulai monitoring.'},
      if (outs.length == 1) {'type': 'button', 't': 'Monitor ${outs[0].name}', 'primary': true, 'file': '', 'after': false, 'i': 1},
      if (outs.length > 1) {'type': 'buttons', 'options': [for (var k = 0; k < outs.length; k++) mon(k)]},
    ];
  }

  @override
  void button(int i) {
    if (i == 0) {
      OutletEditPage.editId = null;
      return host.go('outletedit');
    }
    final outs = host.business.outlets;
    if (i - 1 >= outs.length) return;
    BranchMonitorPage.outletId = outs[i - 1].id;
    host.go('branchmonitor58');
  }
}

/// Monitor Cabang (branchmonitor58/v180): kondisi satu outlet dari data perangkat ini.
class BranchMonitorPage extends PurePage {
  BranchMonitorPage(super.host);
  static String outletId = '';
  @override
  String get title => 'MONITOR CABANG';
  @override
  String get back => 'superbilling';
  @override
  List<Map<String, dynamic>> items() {
    final n = host.now;
    final o = host.business.outlets.where((x) => x.id == outletId).firstOrNull ?? host.business.outlets.firstOrNull;
    final list = o == null ? <Order>[] : _outletOrders(host, o.id);
    final omzet = list.where((x) => _sameDay(x.created, n)).fold<int>(0, (a, x) => a + x.total);
    final paid = list.fold<int>(0, (a, x) => a + x.paid);
    Map<String, dynamic> cell(String v, String t) => {'v': v, 't': t, 'n': '', 'tone': ''};
    return [
      {'type': 'entry', 't': 'Mode Monitoring', 'lines': ['Anda sedang melihat data cabang. Transaksi outlet aktif tidak berpindah.'], 'badge': '', 'avatar': '👁', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'hero', 't': 'Omzet Hari Ini', 'v': rp(omzet), 's': o?.name ?? ''},
      {'type': 'stats', 'cells': [
        cell('${list.where((x) => !const ['antrian', 'siap', 'selesai', 'diambil'].contains(_monSt(x, n))).length}', 'Diproses'),
        cell('${list.where((x) => _monSt(x, n) == 'siap').length}', 'Siap Diambil'),
        cell('${list.where((x) => x.isLate(n)).length}', 'Terlambat'),
        cell(rp(paid), 'Pembayaran diterima'),
        cell('${list.where((x) => x.paid < x.total).length}', 'Belum Lunas'),
      ]},
      {'type': 'title', 't': 'Pesanan Cabang', 's': ''},
      if (list.isEmpty) {'type': 'hint', 't': 'Belum ada pesanan tercatat untuk outlet ini di perangkat ini.'},
      for (var k = 0; k < list.length; k++)
        {'type': 'entry', 't': list[k].name, 'lines': ['${list[k].id} · ${_monSt(list[k], n)}'], 'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      {'type': 'hint', 't': 'Monitoring data perangkat ini. Sinkron antar-HP memerlukan server GOYANA.'},
    ];
  }
}


/// Harga Paket (upgrade/v190): daftar paket dari HTML; pembayaran menunggu server, sama seperti HTML.
class UpgradePage extends TemplatePage {
  // ignore: use_super_parameters
  UpgradePage(PureHost host) : super(host, 'upgrade');
  @override
  List<Map<String, dynamic>> items() {
    final out = super.items();
    final n = host.now, tu = planAccess.trialUntil, test = planAccess.testPlan;
    if (out.isNotEmpty && out.first['type'] == 'hero') {
      out.first['v'] = test != null ? '$test · MODE UJI' : (planAccess.rank(n) > 0 ? 'FREE · TRIAL BASIC' : 'FREE');
      out.first['s'] = tu == null ? '' : (planAccess.rank(n) > 0 && test == null ? 'Trial Basic sampai ${tu.day}/${tu.month}/${tu.year}' : (test != null ? 'Mode Uji aktif · tanpa pembayaran' : 'Trial berakhir · pilih paket'));
    }
    return out;
  }

  @override
  void button(int i) => host.toast(i == 0 ? 'Belum ada riwayat transaksi paket' : 'Pembayaran Google Play dan verifikasi server belum terhubung. Paket belum diaktifkan.');
}
