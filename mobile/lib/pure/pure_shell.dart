// GOYANA mode murni Flutter: tanpa WebView. Semua hitungan & penyimpanan oleh logika Dart (lib/core),
// halaman memakai widget native yang sama dengan mode hybrid.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/business.dart';
import '../core/models.dart';
import '../core/qris.dart';
import '../core/receipt.dart';
import '../core/settings.dart';
import '../core/money.dart';
import '../core/store.dart';
import '../native/addorder_page.dart';
import '../native/common.dart';
import '../native/customers_page.dart';
import '../native/form_page.dart';
import '../native/home_page.dart';
import '../native/orders_page.dart';
import '../native/settings_page.dart';
import 'pages.dart';
import 'scan_page.dart';
import 'settings_menu.dart';
import 'views.dart';

/// Kunci penanda mode (dibaca main.dart).
const pureModeKey = 'goyana-pure-mode';

class PureShell extends StatefulWidget {
  const PureShell({super.key, required this.store, this.clock, this.onExit});
  final KvStore store;
  final DateTime Function()? clock;
  /// Kembali ke versi lama (hybrid).
  final VoidCallback? onExit;
  @override
  State<PureShell> createState() => PureShellState();
}

class _Sheet {
  _Sheet(this.id, this.items, {this.full = false});
  final String id;
  final List<Map<String, dynamic>> items;
  final bool full;
}

class PureShellState extends State<PureShell> implements HomeActions, OrdersActions, AddOrderActions, CustomersActions, FormActions, SettingsActions, PureHost {
  static const _device = MethodChannel('id.goyana/device');
  Business? _b;
  AppSettings? _settings;
  late final Map<String, PurePage> _pages = {
    'settings': SettingsPage(this), 'receipt': ReceiptPage(this), 'printer': PrinterPage(this), 'qris': QrisPage(this),
    'bank': BankPage(this), 'services': ServicesPage(this), 'perfume': PerfumePage(this), 'kas': KasPage(this),
    'reports': ReportsPage(this), 'outlet': OutletPage(this), 'today': TodayPage(this), 'data': DataPage(this),
    'stock': StockPage(this), 'couriers': CourierPage(this), 'discounts': DiscountPage(this), 'employees': EmployeesPage(this), 'help': HelpPage(this),
    'crm': CrmPage(this), 'whatsapp': WhatsAppPage(this), 'outlets': OutletsPage(this), 'notif': NotifPage(this), 'plan': PlanPage(this),
  };

  @override
  KvStore get kv => widget.store;

  /// Kasir yang sedang login (PIN); dicatat di riwayat pesanan.
  String _kasir = 'Kasir';
  bool _locked = false;
  String _pin = '';

  @override
  void openOrder(String id) {
    nav('orders');
    _showDetail(id);
  }

  // PureHost
  @override
  Business get business => _b!;
  @override
  AppSettings get settings => _settings!;
  @override
  MethodChannel get device => _device;
  @override
  void go(String page) => nav(page);
  @override
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Future<void> saveAll() async {
    await _save();
    await _settings!.save();
  }

  @override
  void exitPure() => widget.onExit?.call();
  String _page = 'home';
  String _toast = '';
  Timer? _toastTimer;

  // Pesanan
  int _tab = 1;
  String _search = '';
  String? _detailId;
  String _payMethod = 'Tunai';
  final Map<String, Object> _form = {};

  // Pelanggan
  String _custSearch = '';

  // Tambah transaksi
  String _aoStage = 'customer';
  String _aoCustSearch = '';
  String _aoCustomer = '';
  String _aoDur = 'Reguler';
  String _aoSvcSearch = '';
  int _aoCat = 0;
  final Map<String, double> _cart = {}; // nama layanan → jumlah
  String? _aoSheet; // 'options' | 'payment'
  final Map<String, Object> _opt = {'perfume': 0, 'disc': 0, 'hand': 0, 'prio': false, 'note': ''};

  final List<_Sheet> _sheets = [];

  @override
  DateTime get now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    Future.wait([Business.load(widget.store), AppSettings.load(widget.store)]).then((r) {
      if (mounted) {
        setState(() {
          _b = r[0] as Business;
          _settings = r[1] as AppSettings;
          _locked = _settings!.raw['pinLock'] == true && (_settings!.raw['employees'] as List? ?? const []).isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void toast(String t) {
    _toastTimer?.cancel();
    setState(() => _toast = t);
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  Future<void> _save() async {
    final ok = await _b!.save();
    if (!ok) toast('Penyimpanan perangkat penuh. Data belum tersimpan permanen.');
  }

  void _open(_Sheet s) => setState(() {
        _sheets.removeWhere((e) => e.id == s.id);
        _sheets.add(s);
      });
  void _close(String id) => setState(() => _sheets.removeWhere((e) => e.id == id));

  // ---------------- navigasi ----------------
  @override
  void nav(String pageId) {
    setState(() {
      _sheets.clear();
      _page = pageId;
      if (pageId == 'orders') _search = '';
    });
    _pages[pageId]?.opened();
  }
  /// Scan barcode/QR struk atau label: buka rincian pesanan yang cocok.
  @override
  Future<void> scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));
    if (code == null || !mounted) return;
    final m = RegExp(r'GY-\d{6}-\d+').firstMatch(code);
    final id = m?.group(0) ?? code.trim();
    if (_b!.orderById(id) == null) return toast('Pesanan $id tidak ditemukan');
    nav('orders');
    _showDetail(id);
  }

  // ---------------- Beranda ----------------
  @override
  void slide(int index) => toast('Segera hadir');
  @override
  void tile(int index) {
    // Ikon Beranda: 0 Tambah Transaksi, 1 Cari Transaksi, 2 Kurir, 3 Pelanggan, 4 Hari Ini, 5 Chatbot.
    switch (index) {
      case 0:
        _startOrder();
      case 1:
        nav('orders');
      case 3:
        nav('customers');
      case 2:
        nav('couriers');
      case 4:
        nav('today');
      case 5:
        nav('whatsapp');
      default:
        toast('Menu ini sedang dipindahkan ke mode murni');
    }
  }

  @override
  void manageOutlet() => nav('outlets');
  @override
  void qr() => scan();
  @override
  void monthly() => nav('reports');

  // ---------------- Pengaturan (menu sama persis dengan HTML) ----------------
  final Set<int> _stOpen = {};
  Map<String, dynamic> _settingsJson() {
    final m = jsonDecode(settingsMenuJson) as Map<String, dynamic>;
    for (final g in (m['groups'] as List).cast<Map<String, dynamic>>()) {
      final i = (g['i'] as num).toInt();
      g['open'] = _stOpen.contains(i);
      if (!_stOpen.contains(i)) g['items'] = <dynamic>[];
    }
    return m;
  }

  /// Item menu HTML → halaman mode murni. null = belum dipindah.
  static const Map<String, String> _stRoutes = {
    '0/0': 'outlet', '1/0': 'outlet', '1/1': 'outlets',
    '2/0': 'services', '2/1': 'services', '2/2': 'perfume', '2/3': 'discounts', '2/4': 'couriers',
    '3/0': 'employees', '3/1': 'employees', '3/3': 'couriers',
    '4/0': 'customers', '4/1': 'crm', '4/2': 'whatsapp', '4/3': 'whatsapp', '4/4': 'whatsapp', '4/5': 'whatsapp',
    '5': 'whatsapp', '6': 'whatsapp', '7': 'whatsapp', '8': 'whatsapp',
    '9/0': 'qris', '9/1': 'kas', '9/3': 'stock', '9/4': 'notif', '9/5': 'reports', '9/6': 'customers', '9/7': 'stock',
    '10/0': 'printer', '10/1': 'receipt', '11': 'data', '12/0': 'help', '12/1': 'help',
  };
  void _stGo(String key) {
    final r = _stRoutes[key];
    if (r == null) return toast('Halaman ini sedang dipindahkan');
    nav(r);
  }

  @override
  void stGroup(int index, bool accordion) {
    if (!accordion) return _stGo('$index');
    setState(() => _stOpen.contains(index) ? _stOpen.remove(index) : _stOpen.add(index));
  }
  @override
  void stItem(int group, int item) => _stGo('$group/$item');
  @override
  void stSyncUrl(String url) {}
  @override
  void stSyncSave() => toast('Server GOYANA belum aktif');
  @override
  void stSyncNow() => toast('Server GOYANA belum aktif');
  @override
  void stAcctGo() => nav('plan');
  @override
  void stAcctAction(int index) => nav('plan');
  @override
  void stAcctLink() => nav('plan');
  @override
  void stLogout() => toast('Akun server belum aktif');
  @override
  void stTutorial() => nav('help');

  // ---------------- Cetak struk ----------------
  Future<void> _print(Order o) => _printRaw(receiptText(o, _settings!.receipt, printedAt: now), o.id, 'Struk dicetak');

  Future<void> _printRaw(String text, String title, String done) async {
    final addr = _settings!.printerAddress;
    if (addr.isNotEmpty) {
      try {
        final st = await _device.invokeMapMethod<String, dynamic>('GoyanaDevice.printerStatus');
        if (st?['connected'] != true) await _device.invokeMethod('GoyanaDevice.connectPrinter', {'address': addr});
        await _device.invokeMethod('GoyanaDevice.printText', {'text': text});
        return toast(done);
      } on PlatformException catch (e) {
        toast(e.message ?? 'Printer tidak terhubung');
      } catch (_) {}
    }
    // Tanpa printer Bluetooth: dialog cetak Android (PDF / printer Wi-Fi).
    final esc = const HtmlEscape().convert(text);
    try {
      await _device.invokeMethod('Print.html', {'html': '<pre style="font:12px monospace">$esc</pre>', 'title': title});
    } catch (_) {
      toast('Atur printer di Pengaturan → Printer Bluetooth');
    }
  }
  @override
  void helpChat() => _device.invokeMethod('App.openUrl', {'url': 'https://wa.me/6281234567890'}).catchError((_) => null);

  // ---------------- Pesanan ----------------
  @override
  void autoSettings() => toast('Aturan status otomatis menyusul');
  @override
  void addOrder() => _startOrder();
  @override
  void search(String text) => setState(() => _search = text);
  @override
  void tab(int index) => setState(() {
        _tab = index;
        _search = '';
      });
  @override
  void openCard(int index) {
    final list = _b!.orders;
    if (index < 0 || index >= list.length) return;
    _showDetail(list[index].id);
  }

  @override
  void cardAction(int index) {
    final list = _b!.orders;
    if (index < 0 || index >= list.length) return;
    _next(list[index]);
  }

  @override
  void openMaps(String url) => _device.invokeMethod('App.openUrl', {'url': url}).catchError((_) => null);

  void _next(Order o) {
    final n = _b!.advance(o, now: now, by: _kasir);
    if (n == null) return;
    _save();
    toast(const {
          'antrian': 'Cucian sudah dijemput · masuk antrian', 'cuci': 'Pesanan masuk Proses', 'siap': 'Siap Ambil',
          'diantar': 'Kurir mengantar pesanan', 'diambil': 'Pesanan selesai',
        }[n] ??
        'Status diperbarui');
    _refreshDetail();
  }

  void _showDetail(String id) {
    _detailId = id;
    final o = _b!.orderById(id);
    if (o == null) return;
    _open(_Sheet('detail', orderDetailItems(_b!, o, now), full: true));
  }

  void _refreshDetail() {
    if (_detailId != null && _sheets.any((s) => s.id == 'detail')) {
      _showDetail(_detailId!);
    } else {
      setState(() {});
    }
  }

  void _openPay(Order o) {
    _form
      ..clear()
      ..['amount'] = '${o.remaining}';
    _payMethod = 'Tunai';
    _open(_Sheet('pay', _payItems(o)));
  }

  List<Map<String, dynamic>> _payItems(Order o) {
    const methods = ['Tunai', 'QRIS', 'Transfer', 'Deposit'];
    final dep = _b!.depositOf(o.name);
    return [
      {'type': 'title', 't': 'Terima Pembayaran', 's': o.id},
      {'type': 'pair', 't': 'Sisa tagihan', 'v': rpSpaced(o.remaining), 'tone': 'r'},
      {'type': 'label', 't': 'Nominal diterima'},
      {'type': 'input', 'v': '${_form['amount'] ?? ''}', 'ph': '0', 'numeric': true, 'pre': 'Rp', 'label': ' ', 'i': 0},
      {'type': 'label', 't': 'Metode'},
      {'type': 'buttons', 'options': [for (var k = 0; k < methods.length; k++) {'t': methods[k] == 'Deposit' ? 'Deposit (${rp(dep)})' : methods[k], 'on': _payMethod == methods[k], 'i': 10 + k}]},
      {'type': 'button', 't': 'Simpan Pembayaran', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
    ];
  }

  static const cancelReasons = ['Pilih alasan…', 'Pelanggan membatalkan', 'Salah input pesanan', 'Pakaian tidak jadi dicuci', 'Lainnya'];

  void _openCancel(Order o) {
    _form
      ..clear()
      ..['reason'] = 0
      ..['note'] = '';
    _open(_Sheet('cancel', [
      {'type': 'title', 't': 'Batalkan Pesanan?', 's': o.id},
      {'type': 'hint', 't': 'Pembatalan tidak bisa diurungkan dan tercatat di riwayat pesanan.'},
      {'type': 'label', 't': 'Alasan pembatalan'},
      {'type': 'select', 'options': cancelReasons, 'index': 0, 'i': 0},
      {'type': 'input', 'v': '', 'ph': 'Keterangan tambahan (opsional)', 'multiline': true, 'i': 1},
      {'type': 'button', 't': 'Ya, Batalkan Pesanan', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Kembali', 'primary': false, 'i': 2},
    ]));
  }

  void _openEdit(Order o) {
    final disc = _discs.indexWhere((d) => d[1] == o.discKey);
    final per = _perfumes.indexOf(o.perfume);
    _form
      ..clear()
      ..['note'] = o.note == '-' ? '' : o.note
      ..['perfume'] = per < 0 ? 0 : per
      ..['disc'] = disc < 0 ? 0 : disc;
    final days = o.due != null && o.masuk != null ? o.due!.difference(o.masuk!).inHours / 24 : 3;
    _open(_Sheet('edit', [
      {'type': 'title', 't': 'Edit Transaksi', 's': o.id},
      {'type': 'label', 't': 'Keterangan'},
      {'type': 'input', 'v': '${_form['note']}', 'ph': 'Contoh: 12 pcs · rak B2', 'i': 0},
      {'type': 'label', 't': 'Parfum'},
      {'type': 'select', 'options': _perfumes, 'index': _form['perfume'], 'i': 1},
      {'type': 'label', 't': 'Diskon'},
      {'type': 'select', 'options': [for (final d in _discs) d[0]], 'index': _form['disc'], 'i': 2},
      {'type': 'label', 't': 'Estimasi selesai (hari setelah masuk)'},
      {'type': 'input', 'v': days == days.roundToDouble() ? '${days.round()}' : '', 'ph': 'Contoh: 3', 'numeric': true, 'i': 3},
      {'type': 'button', 't': 'Simpan Perubahan', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
    ]));
  }

  final Map<int, String> _itemQty = {};

  void _openItems(Order o) {
    _itemQty.clear();
    for (final it in o.items) {
      final k = _b!.services.indexWhere((s) => s.name == it.name);
      if (k >= 0) _itemQty[k] = qtyText(it.qty);
    }
    _open(_Sheet('items', _itemsList(o)));
  }

  List<Map<String, dynamic>> _itemsList(Order o) => [
        {'type': 'title', 't': 'Isi Layanan & Berat', 's': '${o.id} · ${o.dur}'},
        for (var k = 0; k < _b!.services.length; k++)
          if (_b!.services[k].enabledFor(o.dur))
            {'type': 'input', 'label': '${_b!.services[k].name} · ${rp(_b!.services[k].priceFor(o.dur))}', 'suf': _b!.services[k].unit, 'v': _itemQty[k] ?? '', 'ph': '0', 'numeric': true, 'i': k},
        {'type': 'button', 't': 'Simpan Layanan', 'primary': true, 'i': 1001},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1002},
      ];

  void _itemsButton(int index) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null || index != 1001) return _close('items');
    final items = <OrderItem>[];
    _itemQty.forEach((k, v) {
      final q = parseQty(v);
      if (q > 0 && k < _b!.services.length) {
        final sv = _b!.services[k];
        items.add(OrderItem(name: sv.name, icon: sv.unit == 'kg' ? 'Kiloan' : (sv.unit == 'm' ? 'Meteran' : 'Satuan'), unit: sv.unit, price: sv.priceFor(o.dur), qty: q));
      }
    });
    if (items.isEmpty) return toast('Isi jumlah minimal satu layanan');
    _b!.setItems(o, items);
    _save();
    _close('items');
    toast('Layanan tersimpan · total ${rp(o.total)}');
    _refreshDetail();
  }

  void _openHistory(Order o) {
    String fmt(Object? v) {
      final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
      return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    _open(_Sheet('history', [
      {'type': 'title', 't': 'Riwayat Status', 's': o.id},
      for (final h in o.history.reversed) {'type': 'pair', 't': '${statusLabel['${h['st']}'] ?? h['st']} · ${h['by'] ?? ''}', 'v': fmt(h['at'] ?? h['t'])},
      if (o.payments.isNotEmpty) {'type': 'title', 't': 'Pembayaran'},
      for (final p in o.payments) {'type': 'pair', 't': '${p['m']} · ${fmt(p['at'])}', 'v': rp(parseRupiah(p['a'])), 'tone': 'g'},
      if ('${o.detail['cancelReason'] ?? ''}'.isNotEmpty) {'type': 'pair', 't': 'Alasan batal', 'v': '${o.detail['cancelReason']}', 'tone': 'r'},
      {'type': 'button', 't': 'Tutup', 'primary': false, 'i': 0},
    ]));
  }

  String _phoneOf(Order o) => o.phone.isNotEmpty ? o.phone : (_b!.customerByName(o.name)?.phone ?? '');

  List<Map<String, dynamic>> _labelItems(Order o) => [
        {'type': 'title', 't': 'Cetak Label Kantong', 's': '${o.id} · ${o.name}'},
        {'type': 'input', 'label': 'Jumlah kantong', 'v': '${_form['labels']}', 'numeric': true, 'i': 0},
        {'type': 'hint', 't': 'Satu label per kantong, berisi kode pesanan, nama, dan nomor kantong.'},
        {'type': 'button', 't': 'Cetak Label', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 0},
      ];

  void _sendWa(Order o) {
    var phone = _phoneOf(o).replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
    final tpl = _settings!.raw['notaTpl'];
    if (tpl is String && tpl.trim().isNotEmpty) {
      final d = o.due;
      return openMaps('https://wa.me/$phone?text=${Uri.encodeComponent(fillTemplate(tpl, {
        'nama': o.name, 'kode': o.id, 'total': rp(o.total), 'bayar': o.paymentLabel, 'outlet': _outletName(),
        'estimasi': d == null ? '-' : '${d.day}/${d.month}/${d.year}',
      }))}');
    }
    final lines = [
      'Halo ${o.name}, terima kasih sudah laundry di ${_outletName()}.',
      'No. pesanan: ${o.id}',
      for (final it in o.items) '- ${it.name}: ${qtyText(it.qty)} ${it.unit} × ${rp(it.price)} = ${rp(it.subtotal)}',
      'Total: ${rp(o.total)} (${o.paymentLabel})',
      if (o.due != null) 'Estimasi selesai: ${o.due!.day}/${o.due!.month}/${o.due!.year}',
    ];
    openMaps('https://wa.me/$phone?text=${Uri.encodeComponent(lines.join('\n'))}');
  }

  String _outletName() {
    for (final o in _b!.outlets) {
      if (o.id == _b!.activeOutlet) return o.name;
    }
    return _b!.outlets.isNotEmpty ? _b!.outlets.first.name : 'GOYANA';
  }

  // ---------------- lembar (sheet) ----------------
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {
    final b = _b;
    if (b == null) return;
    if (scope == 'pin') {
      if (kind == 'input') _pin = '${value ?? ''}'.replaceAll(RegExp(r'\D'), '');
      if (kind == 'button') {
        final emp = (_settings!.raw['employees'] as List? ?? const []).whereType<Map>().where((e) => e['pin'] == _pin).firstOrNull;
        if (emp == null) return toast('PIN salah');
        setState(() {
          _kasir = '${emp['name']}';
          _locked = false;
          _pin = '';
        });
        toast('Halo, $_kasir');
      }
      return;
    }
    if (kind == 'close') {
      _close(scope);
      if (scope == 'detail') _detailId = null;
      return;
    }
    if (kind == 'input') {
      final key = switch (scope) {
        'custform' => const ['name', 'phone', 'address'][index.clamp(0, 2)],
        'cancel' => index == 0 ? 'reason' : 'note',
        'edit' => const ['note', 'perfume', 'disc', 'dueDays'][index.clamp(0, 3)],
        'items' => 'item$index',
        'label' => 'labels',
        'setup' => const ['oname', 'oaddr', 'ophone'][index.clamp(0, 2)],
        _ => 'amount',
      };
      _form[key] = value ?? '';
      if (scope == 'items') _itemQty[index] = '${value ?? ''}';
      // Lembar yang menampilkan hitungan (kembalian, subtotal, sisa) ikut diperbarui.
      if (scope == 'cash') _open(_Sheet('cash', _cashItems()));
      if (scope == 'qty' && _qtyService != null) _open(_Sheet('qty', _qtyItems()));
      if (scope == 'dp') _open(_Sheet('dp', _dpItems()));
      return;
    }
    if (kind != 'button') return;
    final o = _detailId == null ? null : b.orderById(_detailId!);
    switch (scope) {
      case 'detail':
        if (o == null) return;
        switch (index) {
          case 0:
            fmScoped('detail', 'close', 0);
          case 1:
            _next(o);
          case 2:
            _openPay(o);
          case 3:
            _openCancel(o);
          case 4:
            _sendWa(o);
          case 5:
            openMaps(mapsLink(b.customerByName(o.name)));
          case 6:
            _print(o);
          case 7:
            _openEdit(o);
          case 8:
            _openHistory(o);
          case 9:
            _openItems(o);
          case 10:
            _form['labels'] = '${o.items.isEmpty ? 1 : o.items.length}';
            _open(_Sheet('label', _labelItems(o)));
        }
      case 'pay':
        if (o == null) return;
        if (index >= 10) {
          _payMethod = const ['Tunai', 'QRIS', 'Transfer', 'Deposit'][index - 10];
          _open(_Sheet('pay', _payItems(o)));
        } else if (index == 1) {
          final err = b.pay(o, method: _payMethod, amount: parseRupiah(_form['amount']), now: now);
          if (err != null) return toast(err);
          _save();
          _close('pay');
          toast('Pembayaran ${_payMethod.toLowerCase()} tersimpan');
          _refreshDetail();
        } else {
          _close('pay');
        }
      case 'cancel':
        if (o == null) return;
        if (index == 1) {
          final r = (_form['reason'] as num?)?.toInt() ?? int.tryParse('${_form['reason']}') ?? 0;
          final reason = r > 0 ? cancelReasons[r] : '';
          final note = '${_form['note'] ?? ''}'.trim();
          final err = b.cancel(o, reason: note.isEmpty ? reason : (reason.isEmpty ? '' : '$reason · $note'), now: now);
          if (err != null) return toast(err);
          _save();
          _close('cancel');
          toast('Pesanan dibatalkan');
          _refreshDetail();
        } else {
          _close('cancel');
        }
      case 'edit':
        if (o == null) return;
        if (index == 1) {
          final dueDays = int.tryParse('${_form['dueDays'] ?? ''}');
          b.edit(o,
              note: '${_form['note'] ?? o.note}',
              perfume: _perfumes[((_form['perfume'] as int?) ?? 0).clamp(0, _perfumes.length - 1)],
              discKey: _discs[((_form['disc'] as int?) ?? 0).clamp(0, _discs.length - 1)][1],
              due: dueDays == null ? null : (o.masuk ?? now).add(Duration(days: dueDays)));
          _save();
          _close('edit');
          toast('Perubahan tersimpan');
          _refreshDetail();
        } else {
          _close('edit');
        }
      case 'history':
        _close('history');
      case 'custform':
        _saveCustomerForm(index);
      case 'dur':
        _aoPickDuration(index);
      case 'qty':
        _qtyButton(index);
      case 'cash':
        _cashButton(index);
      case 'dp':
        _dpButton(index);
      case 'topup':
        if (index >= 20) {
          _form['dpMethod'] = const ['Tunai', 'QRIS', 'Transfer'][index - 20];
          _open(_Sheet('topup', _topUpItems()));
        } else if (index == 1) {
          final err = b.topUpDeposit(_topUpName, parseRupiah(_form['amount']), method: '${_form['dpMethod']}', now: now);
          if (err != null) return toast(err);
          _save();
          _close('topup');
          toast('Saldo $_topUpName bertambah');
        } else {
          _close('topup');
        }
      case 'setup':
        final name = '${_form['oname'] ?? ''}'.trim();
        if (name.isEmpty) return toast('Isi nama outlet');
        b.saveOutlet(name: name, address: '${_form['oaddr'] ?? ''}'.trim(), phone: '${_form['ophone'] ?? ''}'.trim()).then((_) {
          if (!mounted) return;
          _settings!.receipt = ReceiptSettings(header: name, address: '${_form['oaddr'] ?? ''}'.trim(), phone: '${_form['ophone'] ?? ''}'.trim());
          _settings!.save();
          _form.clear();
          setState(() {});
          toast('Outlet siap. Selamat bekerja!');
        });
      case 'label':
        _close('label');
        if (index == 1 && o != null) {
          final n = (int.tryParse('${_form['labels']}') ?? 1).clamp(1, 20);
          _printRaw(labelText(o, _settings!.receipt, n), '${o.id} label', '$n label dicetak');
        }
      case 'nota':
        _close('nota');
        if (index == 1 && o != null) _sendWa(o);
      case 'pickup':
        _close('pickup');
        if (index == 1) {
          _opt['hand'] = 2; // Jemput & Antar
          _finishOrder('Bayar Nanti');
        }
      case 'items':
        _itemsButton(index);
      case 'confirm':
        if (index == 1) _finishOrder(_pendingMethod);
        _close('confirm');
    }
  }

  // FormActions untuk halaman formulir di mode murni (Pengaturan dll.).
  @override
  void fmBack() => nav(_pages[_page]?.back ?? 'home');
  @override
  void fmInput(int index, Object value) => _pages[_page]?.input(index, value);
  @override
  void fmToggle(int index) {
    _pages[_page]?.toggle(index);
    refresh();
  }

  @override
  void fmRadio(int index) {
    _pages[_page]?.radio(index);
    refresh();
  }

  @override
  void fmButton(int index) => _pages[_page]?.button(index);

  @override
  void fmFile(String inputId) {}
  @override
  void fmTap(int index) {}

  // ---------------- Pelanggan ----------------
  @override
  void cuBack() => nav('home');
  @override
  void cuSearch(String text) => setState(() => _custSearch = text);
  @override
  void cuDeposit() => toast('Pilih pelanggan lalu tekan Isi Saldo');
  @override
  void cuAdd() => _openCustomerForm(null);
  @override
  void cuToggleDb() {}
  @override
  void cuFilter() {}
  @override
  void cuTopUp(int index) {
    final list = _b!.customers;
    if (index < 0 || index >= list.length) return;
    _topUpName = list[index].name;
    _form
      ..clear()
      ..['amount'] = ''
      ..['dpMethod'] = 'Tunai';
    _open(_Sheet('topup', _topUpItems()));
  }

  String _topUpName = '';
  List<Map<String, dynamic>> _topUpItems() => [
        {'type': 'title', 't': 'Isi Saldo Deposit', 's': _topUpName},
        {'type': 'pair', 't': 'Saldo sekarang', 'v': rpSpaced(_b!.depositOf(_topUpName))},
        {'type': 'input', 'v': '${_form['amount']}', 'ph': '0', 'numeric': true, 'pre': 'Rp', 'label': 'Nominal', 'i': 0},
        {'type': 'buttons', 'options': [for (var k = 0; k < 3; k++) {'t': const ['Tunai', 'QRIS', 'Transfer'][k], 'on': _form['dpMethod'] == const ['Tunai', 'QRIS', 'Transfer'][k], 'i': 20 + k}]},
        {'type': 'button', 't': 'Simpan Tambah Saldo', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Tutup', 'primary': false, 'i': 2},
      ];
  @override
  void cuEdit(int index) {
    final list = _b!.customers;
    if (index >= 0 && index < list.length) _openCustomerForm(list[index]);
  }

  @override
  void cuPage(int delta) {}
  @override
  void cuRank() {
    (_pages['crm'] as CrmPage).tab = 1;
    nav('crm');
  }
  @override
  void cuCrm() => nav('crm');

  String? _editingCustomer;
  bool _custForOrder = false;

  void _openCustomerForm(Customer? c, {bool forOrder = false}) {
    _editingCustomer = c?.name;
    _custForOrder = forOrder;
    _form
      ..clear()
      ..['name'] = c?.name ?? ''
      ..['phone'] = c?.phone ?? ''
      ..['address'] = c?.address ?? ''
      ..['gender'] = c?.gender ?? 'male';
    _open(_Sheet('custform', _customerItems()));
  }

  List<Map<String, dynamic>> _customerItems() => [
        {'type': 'title', 't': _editingCustomer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan', 's': ''},
        {'type': 'input', 'v': '${_form['name']}', 'ph': 'Nama Pelanggan', 'i': 0},
        {'type': 'input', 'v': '${_form['phone']}', 'ph': 'No Handphone', 'numeric': true, 'i': 1},
        {'type': 'input', 'v': '${_form['address']}', 'ph': 'Alamat (opsional)', 'i': 2},
        {'type': 'buttons', 'options': [
          {'t': 'Pria', 'on': _form['gender'] != 'female', 'i': 10},
          {'t': 'Wanita', 'on': _form['gender'] == 'female', 'i': 11},
        ]},
        {'type': 'button', 't': _editingCustomer == null ? 'Tambahkan' : 'Simpan', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
        {'type': 'hint', 't': 'Nama dan no handphone wajib diisi. Alamat boleh dikosongkan.'},
      ];

  void _saveCustomerForm(int index) {
    if (index == 10 || index == 11) {
      _form['gender'] = index == 11 ? 'female' : 'male';
      return _open(_Sheet('custform', _customerItems()));
    }
    if (index != 1) return _close('custform');
    final c = Customer(name: '${_form['name']}'.trim(), phone: '${_form['phone']}'.trim(), address: '${_form['address']}'.trim(), gender: '${_form['gender']}');
    final err = _b!.saveCustomer(c, originalName: _editingCustomer);
    if (err != null) return toast(err);
    _save();
    _close('custform');
    toast(_editingCustomer == null ? 'Pelanggan ${c.name} ditambahkan' : 'Data pelanggan disimpan');
    if (_custForOrder) _aoPickName(c.name);
  }

  // ---------------- Tambah Transaksi ----------------
  void _startOrder() => setState(() {
        _sheets.clear();
        _page = 'addorder';
        _aoStage = 'customer';
        _aoCustSearch = '';
        _aoCustomer = '';
        _aoSvcSearch = '';
        _aoCat = 0;
        _aoSheet = null;
        _cart.clear();
        _opt
          ..['perfume'] = 0
          ..['disc'] = 0
          ..['hand'] = 0
          ..['prio'] = false
          ..['note'] = '';
      });

  List<String> get _durations {
    final keys = <String>[];
    for (final s in _b!.services) {
      for (final k in s.prices.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys.isEmpty ? const ['Reguler', 'Express', 'Kilat'] : keys;
  }

  static const _cats = [['Semua', ''], ['Kiloan', 'kg'], ['Satuan', 'pcs'], ['Meteran', 'm']];

  List<Service> get _visibleServices {
    final unit = _cats[_aoCat][1];
    final q = _aoSvcSearch.trim().toLowerCase();
    return _b!.services.where((s) => s.enabledFor(_aoDur) && (unit.isEmpty || s.unit == unit) && (q.isEmpty || s.name.toLowerCase().contains(q))).toList();
  }

  List<OrderItem> get _cartItems => [
        for (final e in _cart.entries)
          for (final s in _b!.services.where((s) => s.name == e.key))
            OrderItem(name: s.name, icon: s.unit == 'kg' ? 'Kiloan' : (s.unit == 'm' ? 'Meteran' : 'Satuan'), unit: s.unit, price: s.priceFor(_aoDur), qty: e.value),
      ];

  static const _baseDiscs = [['Tanpa diskon', '0'], ['Diskon 5%', 'p5'], ['Diskon 10%', 'p10'], ['Potongan Rp5.000', 'n5000'], ['Potongan Rp10.000', 'n10000']];
  List<List<String>> get _discs => [
        ..._baseDiscs,
        for (final d in (_settings!.raw['discounts'] as List? ?? const []))
          if (d is List && d.length > 1) ['${d[0]}', '${d[1]}'],
        for (final v in (_settings!.raw['vouchers'] as List? ?? const []))
          if (v is Map && v['key'] != null) ['Voucher ${v['code']}', '${v['key']}'],
      ];
  static const _hands = ['Datang Langsung', 'Antar ke rumah', 'Jemput & Antar'];

  Map<String, dynamic> _addOrderJson() {
    final b = _b!;
    final m = <String, dynamic>{'title': 'Tambah Transaksi', 'stage': _aoStage};
    if (_aoStage == 'customer') {
      final q = _aoCustSearch.trim().toLowerCase();
      final list = b.customers;
      m['step'] = 'Langkah 1 dari 4 · Pilih pelanggan';
      m['search'] = {'v': _aoCustSearch, 'ph': 'Cari nama / no HP'};
      m['add'] = 'Tambah Pelanggan Baru';
      m['people'] = [
        for (var i = 0; i < list.length; i++)
          if (q.isEmpty || '${list[i].name} ${list[i].phone}'.toLowerCase().contains(q))
            {'i': i, 'name': list[i].name, 'lines': ['☎ ${list[i].phone}', '⌖ ${list[i].address.isEmpty ? '—' : list[i].address}'], 'btn': 'Pilih'},
      ];
      m['empty'] = (m['people'] as List).isEmpty ? (q.isEmpty ? 'Belum ada pelanggan. Tambahkan pelanggan baru.' : 'Pelanggan tidak ditemukan.') : '';
      return m;
    }
    final t = calcTotals(_cartItems, _discs[(_opt['disc'] as int)][1], 0);
    m['step'] = 'Langkah 2 dari 4 · Pilih layanan';
    m['customer'] = {'name': _aoCustomer, 'sub': b.customerByName(_aoCustomer)?.phone ?? ''};
    m['durations'] = [for (final d in _durations) {'t': d, 's': '${durationHours(d)} Jam', 'on': d == _aoDur}];
    m['cats'] = [for (var i = 0; i < _cats.length; i++) {'t': _cats[i][0], 'on': i == _aoCat}];
    m['search'] = {'v': _aoSvcSearch, 'ph': 'Cari layanan'};
    final items = <Map<String, dynamic>>[];
    final svcs = _visibleServices;
    for (final cat in _cats.skip(1)) {
      final group = svcs.where((s) => s.unit == cat[1]).toList();
      if (group.isEmpty) continue;
      items.add({'h': 1, 't': cat[0]});
      for (final s in group) {
        final q = _cart[s.name];
        items.add({'i': b.services.indexOf(s), 't': s.name, 's': '${rpSpaced(s.priceFor(_aoDur))} / ${s.unit}', 'btn': q == null ? '+ Tambah' : '${qtyText(q)} ${s.unit}', 'on': q != null});
      }
    }
    m['items'] = items;
    m['footer'] = {'name': _aoCustomer, 'sum': '${_cart.length} layanan', 'label': 'Total', 'total': rpSpaced(t.total), 'btn': 'Lanjut'};
    if (_aoSheet == 'options') {
      m['sheet'] = {
        'kind': 'options', 'title': 'Atur Pesanan',
        'fields': [
          {'k': 0, 'type': 'select', 'label': 'Parfum', 'options': _perfumes, 'index': _opt['perfume']},
          {'k': 1, 'type': 'select', 'label': 'Diskon', 'options': [for (final d in _discs) d[0]], 'index': _opt['disc']},
          {'k': 2, 'type': 'select', 'label': 'Penyerahan', 'options': _hands, 'index': _opt['hand']},
          {'k': 3, 'type': 'switch', 'label': 'Prioritas', 'sub': 'Dikerjakan lebih dulu', 'on': _opt['prio'] == true},
        ],
        'note': {'v': '${_opt['note']}', 'ph': 'Catatan (contoh: 12 pcs, rak B2)'},
        'main': 'Lanjut ke Pembayaran',
      };
    } else if (_aoSheet == 'payment') {
      m['sheet'] = {
        'kind': 'payment', 'title': 'Pembayaran', 'label': 'Total Tagihan', 'total': rpSpaced(t.total), 'id': b.nextOrderId(now),
        'methods': [for (var i = 0; i < _payMethods.length; i++) {'i': i, 't': _payMethods[i][0], 'icon': _payMethods[i][1], 'ic': '#e8493f', 'bg': '#fff0f1', 's': _payMethods[i][2]}],
        'cancel': 'Kembali',
      };
    }
    return m;
  }

  List<String> get _perfumes => ['Tanpa Parfum', for (final p in _settings!.perfumes) p.first];

  static const _payMethods = [
    ['Tunai', '💵', 'Bayar di kasir'], ['QRIS', '▦', 'Scan QR'], ['Transfer', '⇄', 'Transfer bank'],
    ['Bayar Nanti', '⏱', 'Belum dibayar'], ['DP / Uang Muka', '½', 'Bayar sebagian'], ['Saldo Deposit', '◈', 'Potong saldo'],
  ];

  @override
  void aoBack() {
    if (_aoStage == 'services') {
      setState(() => _aoStage = 'customer');
    } else {
      nav('home');
    }
  }

  @override
  void aoSearchCustomer(String text) => setState(() => _aoCustSearch = text);
  @override
  void aoAddCustomer() => _openCustomerForm(null, forOrder: true);
  @override
  void aoPickCustomer(int index) {
    final list = _b!.customers;
    if (index >= 0 && index < list.length) _aoPickName(list[index].name);
  }

  void _aoPickName(String name) {
    _aoCustomer = name;
    final d = _durations;
    _open(_Sheet('dur', [
      {'type': 'title', 't': 'Pilih Durasi', 's': name},
      for (var i = 0; i < d.length; i++) {'type': 'card', 't': d[i], 's': '${durationHours(d[i])} Jam', 'ic': '⏱', 'i': i},
    ]));
  }

  void _aoPickDuration(int index) {
    final d = _durations;
    if (index < 0 || index >= d.length) return;
    _close('dur');
    setState(() {
      _aoDur = d[index];
      _aoStage = 'services';
    });
  }

  @override
  void aoDuration(int index) {
    final d = _durations;
    if (index >= 0 && index < d.length) setState(() => _aoDur = d[index]);
  }

  @override
  void aoSearchService(String text) => setState(() => _aoSvcSearch = text);
  @override
  void aoCategory(int index) => setState(() => _aoCat = index);

  Service? _qtyService;
  @override
  void aoService(int index) {
    final list = _b!.services;
    if (index < 0 || index >= list.length) return;
    _qtyService = list[index];
    final q = _cart[_qtyService!.name];
    _form
      ..clear()
      ..['amount'] = q == null ? '' : qtyText(q);
    _open(_Sheet('qty', _qtyItems()));
  }

  List<Map<String, dynamic>> _qtyItems() {
    final s = _qtyService!;
    final chips = s.unit == 'kg' ? [1, 2, 3, 5] : [1, 2, 3, 4];
    final q = parseQty(_form['amount']);
    return [
      {'type': 'title', 't': '${s.name} · $_aoDur', 's': ''},
      {'type': 'hint', 't': '${rpSpaced(s.priceFor(_aoDur))} / ${s.unit} · selesai ${durationHours(_aoDur)} Jam'},
      {'type': 'input', 'v': '${_form['amount']}', 'ph': '0', 'numeric': true, 'suf': s.unit, 'label': 'Jumlah (${s.unit})', 'i': 0},
      {'type': 'buttons', 'options': [for (var k = 0; k < chips.length; k++) {'t': '${chips[k]} ${s.unit}', 'i': 10 + k}]},
      {'type': 'pair', 't': 'Subtotal', 'v': rpSpaced((q * s.priceFor(_aoDur)).round())},
      {'type': 'button', 't': 'SIMPAN', 'primary': true, 'i': 1},
      if (_cart.containsKey(s.name)) {'type': 'button', 't': 'Hapus layanan ini', 'primary': false, 'i': 2},
      {'type': 'button', 't': 'BATAL', 'primary': false, 'i': 3},
    ];
  }

  void _qtyButton(int index) {
    final s = _qtyService;
    if (s == null) return;
    if (index >= 10) {
      final chips = s.unit == 'kg' ? [1, 2, 3, 5] : [1, 2, 3, 4];
      _form['amount'] = '${chips[index - 10]}';
      return _open(_Sheet('qty', _qtyItems()));
    }
    if (index == 1) {
      final q = parseQty(_form['amount']);
      if (q <= 0) return toast('Isi jumlah dulu');
      setState(() => _cart[s.name] = q);
      _close('qty');
      toast('${s.name} ditambahkan');
    } else if (index == 2) {
      setState(() => _cart.remove(s.name));
      _close('qty');
    } else {
      _close('qty');
    }
  }

  @override
  void aoNext() {
    if (_cart.isEmpty) {
      // Tanpa layanan: pesanan jemput, ditimbang setelah cucian diambil kurir.
      return _open(_Sheet('pickup', [
        {'type': 'title', 't': 'Belum ada layanan', 's': ''},
        {'type': 'hint', 't': 'Buat pesanan Jemput? Layanan & berat diisi setelah cucian dijemput dan ditimbang.'},
        {'type': 'button', 't': 'Buat Pesanan Jemput', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Pilih layanan dulu', 'primary': false, 'i': 2},
      ]));
    }
    setState(() => _aoSheet = 'options');
  }

  @override
  void aoSheetSelect(int field, int option) => setState(() => _opt[const ['perfume', 'disc', 'hand'][field]] = option);
  @override
  void aoSheetSwitch(int field) => setState(() => _opt['prio'] = _opt['prio'] != true);
  @override
  void aoSheetNote(String text) => _opt['note'] = text;
  @override
  void aoSheetMain() => setState(() => _aoSheet = 'payment');
  @override
  void aoSheetClose() => setState(() => _aoSheet = null);
  @override
  void aoPayCancel() => setState(() => _aoSheet = 'options');

  String _pendingMethod = '';

  int get _cartTotal => calcTotals(_cartItems, _discs[(_opt['disc'] as int)][1], 0).total;

  @override
  void aoPay(int index) {
    final m = _payMethods[index][0];
    switch (m) {
      case 'Tunai':
        _form
          ..clear()
          ..['amount'] = '';
        _open(_Sheet('cash', _cashItems()));
      case 'Bayar Nanti':
        _finishOrder('Bayar Nanti');
      case 'DP / Uang Muka':
        _form
          ..clear()
          ..['amount'] = ''
          ..['dpMethod'] = 'Tunai';
        _open(_Sheet('dp', _dpItems()));
      case 'Saldo Deposit':
        final bal = _b!.depositOf(_aoCustomer);
        if (bal < _cartTotal) return toast('Saldo deposit $_aoCustomer ${rp(bal)} tidak cukup');
        _confirm('Saldo Deposit', 'Potong saldo deposit ${rp(_cartTotal)}?');
      default:
        _confirm(m, m == 'QRIS' ? 'Periksa pembayaran QRIS ${rp(_cartTotal)} sudah masuk.' : 'Cek mutasi bank: transfer ${rp(_cartTotal)} sudah masuk.');
    }
  }

  void _confirm(String method, String text) {
    _pendingMethod = method;
    final qris = _settings!.qrisText;
    final st = _settings!;
    _open(_Sheet('confirm', [
      {'type': 'title', 't': method == 'QRIS' ? 'Pembayaran QRIS' : (method == 'Transfer' ? 'Transfer Bank' : method), 's': ''},
      if (method == 'QRIS' && qrisValid(qris)) {'type': 'qr', 'data': qrisDynamic(qris, _cartTotal), 'size': 230},
      if (method == 'QRIS' && !qrisValid(qris)) {'type': 'hint', 't': 'QRIS outlet belum diatur. Atur di Pengaturan → QRIS Outlet.'},
      if (method == 'Transfer' && st.bank.isNotEmpty) {'type': 'pair', 't': st.bank, 'v': st.account},
      if (method == 'Transfer' && st.holder.isNotEmpty) {'type': 'pair', 't': 'Atas nama', 'v': st.holder},
      if (method == 'Transfer' && st.bank.isEmpty) {'type': 'hint', 't': 'Rekening belum diatur. Atur di Pengaturan → Rekening Transfer.'},
      {'type': 'pair', 't': 'Total Tagihan', 'v': rpSpaced(_cartTotal)},
      {'type': 'hint', 't': text},
      {'type': 'button', 't': method == 'Transfer' ? 'SUDAH DITRANSFER' : 'SUDAH LUNAS', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'BATAL', 'primary': false, 'i': 2},
    ]));
  }

  List<Map<String, dynamic>> _cashItems() {
    final total = _cartTotal, got = parseRupiah(_form['amount']);
    return [
      {'type': 'title', 't': 'Pembayaran Tunai', 's': ''},
      {'type': 'pair', 't': 'Total Tagihan', 'v': rpSpaced(total)},
      {'type': 'input', 'v': '${_form['amount']}', 'ph': '0', 'numeric': true, 'pre': 'Rp', 'label': 'Uang diterima', 'i': 0},
      {'type': 'buttons', 'options': [{'t': 'Uang pas', 'i': 10}, {'t': '50rb', 'i': 11}, {'t': '100rb', 'i': 12}]},
      {'type': 'pair', 't': 'Kembalian', 'v': got >= total && got > 0 ? rpSpaced(got - total) : '—', 'tone': got >= total && got > 0 ? 'g' : ''},
      {'type': 'button', 't': got == 0 || got == total ? 'SUDAH DIBAYAR (UANG PAS)' : 'SUDAH DIBAYAR', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'BATAL', 'primary': false, 'i': 2},
    ];
  }

  void _cashButton(int index) {
    if (index >= 10) {
      _form['amount'] = '${index == 10 ? _cartTotal : (index == 11 ? 50000 : 100000)}';
      return _open(_Sheet('cash', _cashItems()));
    }
    if (index == 1) {
      final got = parseRupiah(_form['amount']);
      if (got > 0 && got < _cartTotal) return toast('Uang diterima kurang dari total');
      _close('cash');
      _finishOrder('Tunai', change: got > _cartTotal ? got - _cartTotal : 0);
    } else {
      _close('cash');
    }
  }

  List<Map<String, dynamic>> _dpItems() => [
        {'type': 'title', 't': 'DP / Uang Muka', 's': ''},
        {'type': 'hint', 't': 'Total tagihan ${rpSpaced(_cartTotal)}'},
        {'type': 'input', 'v': '${_form['amount']}', 'ph': '0', 'numeric': true, 'pre': 'Rp', 'label': 'Jumlah DP', 'i': 0},
        {'type': 'buttons', 'options': [{'t': '30%', 'i': 10}, {'t': '50%', 'i': 11}, {'t': '70%', 'i': 12}]},
        {'type': 'buttons', 'options': [for (var k = 0; k < 3; k++) {'t': const ['Tunai', 'QRIS', 'Transfer'][k], 'on': _form['dpMethod'] == const ['Tunai', 'QRIS', 'Transfer'][k], 'i': 20 + k}]},
        {'type': 'pair', 't': 'Sisa tagihan (piutang)', 'v': rpSpaced((_cartTotal - parseRupiah(_form['amount'])).clamp(0, _cartTotal))},
        {'type': 'button', 't': 'Simpan DP', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
      ];

  void _dpButton(int index) {
    if (index >= 20) {
      _form['dpMethod'] = const ['Tunai', 'QRIS', 'Transfer'][index - 20];
      return _open(_Sheet('dp', _dpItems()));
    }
    if (index >= 10) {
      _form['amount'] = '${(_cartTotal * const [0.3, 0.5, 0.7][index - 10]).round()}';
      return _open(_Sheet('dp', _dpItems()));
    }
    if (index == 1) {
      final a = parseRupiah(_form['amount']);
      if (a <= 0 || a >= _cartTotal) return toast('DP harus lebih dari Rp0 dan kurang dari total');
      _close('dp');
      _finishOrder('DP', dp: a, dpMethod: '${_form['dpMethod']}');
    } else {
      _close('dp');
    }
  }

  void _finishOrder(String method, {int change = 0, int? dp, String dpMethod = 'Tunai'}) {
    final b = _b!;
    final cust = b.customerByName(_aoCustomer);
    final hand = _hands[_opt['hand'] as int];
    final o = b.createOrder(
      customer: _aoCustomer, phone: cust?.phone ?? '', dur: _aoDur, items: _cartItems,
      discKey: _discs[(_opt['disc'] as int)][1], perfume: _perfumes[(_opt['perfume'] as int).clamp(0, _perfumes.length - 1)],
      note: '${_opt['note']}'.trim(), handover: hand, priority: _opt['prio'] == true,
      payMethod: method == 'DP' ? 'DP' : method, dpMethod: dpMethod, payAmount: dp, kasir: _kasir, now: now,
    );
    if (method == 'Saldo Deposit') {
      // Saldo deposit dipotong lewat pembayaran (bukan kas tunai).
      o.detail['paid'] = 0;
      b.pay(o, method: 'Deposit', amount: o.total, now: now);
    }
    _save();
    setState(() {
      _aoSheet = null;
      _sheets.clear();
      _page = 'orders';
      _tab = o.status == 'jemput' ? 0 : 1;
      _search = '';
    });
    toast(method == 'Bayar Nanti' ? 'Pesanan tersimpan · Belum dibayar' : (change > 0 ? 'Lunas · kembalian ${rp(change)}' : 'Pesanan tersimpan · ${o.paymentLabel}'));
    _showDetail(o.id);
    if (_settings!.raw['autoNota'] != false && _phoneOf(o).isNotEmpty) {
      _open(_Sheet('nota', [
        {'type': 'title', 't': 'Kirim nota ke pelanggan?', 's': '${o.name} · ${_phoneOf(o)}'},
        {'type': 'hint', 't': 'WhatsApp akan terbuka dengan nota terisi. Tinggal tekan Kirim.'},
        {'type': 'button', 't': 'Kirim Nota WA', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Nanti saja', 'primary': false, 'i': 0},
      ]));
    }
  }

  // ---------------- Pengaturan & Laporan (sementara) ----------------
  // ---------------- tampilan ----------------
  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null || _settings == null) return const Material(color: Colors.white, child: Center(child: CircularProgressIndicator(color: gBrand)));
    final n = now;
    if (b.outlets.isEmpty) {
      return NativeSheet(id: 'setup', screen: true, actions: this, items: [
        {'type': 'title', 't': 'Selamat datang di GOYANA', 's': 'Isi data outlet untuk mulai'},
        {'type': 'input', 'label': 'Nama outlet', 'v': '${_form['oname'] ?? ''}', 'ph': 'Contoh: Goyana Laundry Cibubur', 'i': 0},
        {'type': 'input', 'label': 'Alamat', 'v': '${_form['oaddr'] ?? ''}', 'ph': 'Alamat outlet (tampil di struk)', 'i': 1},
        {'type': 'input', 'label': 'Nomor WhatsApp outlet', 'v': '${_form['ophone'] ?? ''}', 'ph': '08…', 'numeric': true, 'i': 2},
        {'type': 'button', 't': 'Mulai', 'primary': true, 'i': 1},
        {'type': 'hint', 't': 'Bisa diubah nanti di Pengaturan → Profil Outlet.'},
      ]);
    }
    if (_locked) {
      return NativeSheet(id: 'pin', screen: true, actions: this, items: [
        {'type': 'title', 't': 'GOYANA'},
        {'type': 'title', 't': 'Masukkan PIN', 's': ''},
        {'type': 'hint', 't': 'PIN pegawai untuk membuka aplikasi.'},
        {'type': 'input', 'v': _pin, 'ph': 'PIN', 'numeric': true, 'secret': true, 'i': 0},
        {'type': 'button', 't': 'Masuk', 'primary': true, 'i': 1},
      ]);
    }
    Widget page;
    switch (_page) {
      case 'orders':
        page = NativeOrders(model: OrdersModel.fromJson(ordersJson(b, tab: _tab, search: _search, now: n)), actions: this);
      case 'customers':
        page = NativeCustomers(model: CustomersModel.fromJson(customersJson(b, _custSearch)), actions: this);
      case 'addorder':
        page = NativeAddOrder(model: AddOrderModel.fromJson(_addOrderJson()), actions: this);
      case 'settings':
        page = NativeSettings(model: SettingsModel.fromJson(_settingsJson()), actions: this);
      default:
        final pp = _pages[_page];
        page = pp != null
            ? NativeForm(key: ValueKey(_page), model: FormModel(page: _page, title: pp.title, items: pp.items()), actions: this, navActive: pp.navActive)
            : NativeHome(model: HomeModel.fromJson(homeJson(b, n)), actions: this);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheets.isNotEmpty) return fmScoped(_sheets.last.id, 'close', 0);
        if (_aoSheet != null) return aoSheetClose();
        if (_page == 'addorder' && _aoStage == 'services') return aoBack();
        if (_page != 'home') return nav('home');
        SystemNavigator.pop();
      },
      child: Stack(children: [
        Positioned.fill(child: page),
        for (final s in _sheets)
          Positioned.fill(child: NativeSheet(key: ValueKey('pure-${s.id}-${s.items.length}'), id: s.id, items: s.items, actions: this, full: s.full)),
        if (_toast.isNotEmpty)
          Positioned(left: 24, right: 24, bottom: 130, child: IgnorePointer(child: Center(child: NativeToast(text: _toast)))),
      ]),
    );
  }
}

/// Mode tersimpan di database yang sama: "1" = murni.
Future<bool> pureModeEnabled(KvStore store) async {
  try {
    return (await store.get(pureModeKey)) == '1';
  } catch (_) {
    return false;
  }
}

Future<void> setPureMode(KvStore store, bool on) async {
  try {
    await store.set(pureModeKey, on ? '1' : '0');
  } catch (_) {}
}

String debugJson(Object o) => const JsonEncoder.withIndent(' ').convert(o);
