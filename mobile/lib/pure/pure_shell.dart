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
import 'addorder_assets.dart';
import 'access.dart';
import 'addorder_popups.dart';
import 'cash_pages.dart';
import 'delivery.dart';
import 'discounts.dart';
import '../native/common.dart';
import '../native/customers_page.dart';
import '../native/form_page.dart';
import '../native/home_page.dart';
import '../logic/crm.dart';
import '../logic/reports_a8.dart';
import '../native/orders_page.dart';
import '../native/report_detail.dart';
import '../native/reports_page.dart';
import '../native/services_page.dart';
import '../native/settings_page.dart';
import '../logic/reports_catalog.dart';
import 'pages.dart';
import 'ralat.dart';
import 'reports_dart.dart';
import 'scan_page.dart';
import 'service_icons.dart';
import 'settings_menu.dart';
import 'views.dart';
import 'wa_pages.dart';

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

class PureShellState extends State<PureShell> implements HomeActions, OrdersActions, AddOrderActions, CustomersActions, FormActions, SettingsActions, ReportsActions, ReportDetailActions, ServicesActions, PureHost {
  static const _device = MethodChannel('id.goyana/device');
  Business? _b;
  AppSettings? _settings;
  late final Map<String, PurePage> _pages = {
    ...templatePages(this),
    ...whatsappPages(this),
    'settings': SettingsPage(this), 'receipt': ReceiptPage(this), 'printer': PrinterNotaPage(this), 'printerconnect': PrinterPage(this), 'qris': QrisPage(this),
    'bank': BankPage(this), 'perfume': PerfumePage(this), 'duration': DurationPage(this), 'kas': KasPage(this),
    'reports': ReportsPage(this), 'outlet': OutletPage(this), 'today': TodayPage(this), 'data': DataPage(this),
    'stock': StockPage(this), 'couriers': CourierPage(this), 'finance': FinancePage(this), 'delivery': DeliveryPage(this), 'discounts': DiscountPage(this), 'employees': EmployeesPage(this), 'pinlock': PinLockPage(this), 'cashin': CashEntryPage(this, income: true), 'cashout': CashEntryPage(this, income: false), 'cashclose': CashClosePage(this), 'ralat139': RalatPage(this), 'audit': AuditPage(this), 'help': HelpPage(this),
    'crm': CrmNativePage(this), 'whatsapp': WhatsAppPage(this), 'outlets': OutletsPage(this), 'outletedit': OutletEditPage(this), 'superbilling': ManageBranchesPage(this), 'branchmonitor58': BranchMonitorPage(this), 'testmode192': TestModePage(this), 'notif': NotifPage(this), 'plan': PlanPage(this),
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
  // ---- Laporan (A8): dihitung Dart dari database yang sama ----
  String _rpKey = '30', _rpCat = 'all', _rpQuery = '', _rpId = 'omzet';
  DateTime? _rpFrom, _rpTo;

  RepCtx _rpCtx() => RepCtx.fromJson(reportStateFromBusiness(_b!.raw, now: now));
  String _activeOutletName() {
    final b = _b;
    if (b == null) return '';
    for (final o in b.outlets) {
      if (o.id == b.activeOutlet) return o.name;
    }
    return b.outlets.isNotEmpty ? b.outlets.first.name : '';
  }

  Widget _rpDetail() {
    final ctx = _rpCtx();
    final range = ctx.range(_rpKey, from: _rpFrom, to: _rpTo);
    final ent = reportCatalogA8.firstWhere((e) => e.$1 == _rpId, orElse: () => reportCatalogA8.first);
    return NativeReportDetail(
      key: ValueKey('rp-$_rpId'),
      actions: this,
      model: ReportDetailModel(
        id: ent.$1, title: ent.$3, category: reportCategoryName(ent.$1), desc: ent.$5, periodKey: _rpKey,
        periodLabel: periodLabelA8(_rpKey, range), data: reportA8(ent.$1, ctx, range) ?? const {}, isExport: ent.$1.startsWith('x-'),
      ),
    );
  }

  Object? _rpData() {
    final ctx = _rpCtx();
    return reportA8(_rpId, ctx, ctx.range(_rpKey, from: _rpFrom, to: _rpTo));
  }

  @override
  void rpOutlet() {}
  @override
  void rpPeriod(int index) => rdPeriod(reportPeriodsA8[index].$1);
  @override
  void rpKpi(int index) {
    setState(() => _rpId = const ['keluar', 'laba', 'piutang', 'tumbuh'][index]);
    nav('rp');
  }

  @override
  void rpQuick(int index) {
    nav(const ['cashin', 'cashout', 'cashclose', 'ralat139'][index.clamp(0, 3)]);
  }

  @override
  void rpSearch(String text) => setState(() => _rpQuery = text);
  @override
  void rpCategory(int index) => setState(() => _rpCat = index == 0 ? 'all' : reportCategoryIds[index - 1]);
  @override
  void rpOpen(int index) {
    final ids = reportVisibleIds(cat: _rpCat, query: _rpQuery);
    if (index < 0 || index >= ids.length) return;
    final id = ids[index];
    if (id == 'tutup') return nav('cashclose');
    if (id == 'ralat') return nav('ralat139');
    setState(() => _rpId = id);
    nav('rp');
  }

  @override
  void rdBack() => nav('reports');
  @override
  void rdScan() => scan();
  @override
  void rdNav(String page) => nav(page);
  @override
  void rdOpen(String page) => nav(page);
  @override
  void rdPeriod(String key) {
    if (key == 'custom') {
      unawaited(_rpPick());
      return;
    }
    setState(() {
      _rpKey = key;
      _rpFrom = _rpTo = null;
    });
  }

  Future<void> _rpPick() async {
    final ctx = _rpCtx();
    final r = ctx.range(_rpKey, from: _rpFrom, to: _rpTo);
    DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime(ctx.t0.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: local(r.s), end: local(r.e.subtract(const Duration(days: 1)))), helpText: 'Pilih periode laporan',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rpKey = 'custom';
      _rpFrom = DateTime.utc(picked.start.year, picked.start.month, picked.start.day);
      _rpTo = DateTime.utc(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  @override
  void rdCsv() {
    final d = _rpData();
    if (d == null) return;
    Clipboard.setData(ClipboardData(text: reportCsvA8(d)));
    toast('Data CSV disalin · tempel di Excel / Google Sheets');
  }

  @override
  void rdShare() {
    final d = _rpData();
    if (d == null) return;
    final ctx = _rpCtx();
    final label = periodLabelA8(_rpKey, ctx.range(_rpKey, from: _rpFrom, to: _rpTo));
    final ent = reportCatalogA8.firstWhere((e) => e.$1 == _rpId);
    _device.invokeMethod('App.openUrl', {'url': 'https://wa.me/?text=${Uri.encodeComponent(reportShareTextA8(ent.$3, label, d))}'}).catchError((_) => null);
  }

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
    loadTransport(widget.store);
    planAccess.load(widget.store, now);
    widget.store.get(DurationPage.key).then((raw) {
      try {
        for (final e in (jsonDecode(raw ?? '{}') as Map).entries) {
          final n = int.tryParse('${e.value}') ?? 0;
          if (n > 0) durationOverrides['${e.key}'] = n;
        }
      } catch (_) {}
    });
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

  /// Untuk tes kesetaraan: butir halaman/popup aktif persis seperti yang digambar.
  @visibleForTesting
  List<Map<String, dynamic>> debugItems() => _pages[_page]?.items() ?? const [];
  @visibleForTesting
  List<Map<String, dynamic>>? debugSheet(String id) => _pages[_page]?.sheetItems(id) ?? _sheets.where((e) => e.id == id).firstOrNull?.items;
  @visibleForTesting
  List<String> debugDiscOptions() => [for (final d in _discs) d[0]];
  @visibleForTesting
  String get debugToast => _toast;

  // ---------------- Layanan (halaman & popup sama dengan HTML sv99/cat99) ----------------
  static const _svDurs = ['Reguler', 'Express', 'Kilat'];
  static const _svSteps = ['Cuci', 'Kering', 'Setrika', 'Packing'];
  static const _svUnits = ['kg', 'pcs', 'm'];
  String _svQuery = '';
  String _catName = '', _catPrice = '', _catScore = '';
  int _catIcon = 1, _catUnit = 0;
  final Set<int> _catProc = {0, 1, 3};

  @visibleForTesting
  Map<String, dynamic> servicesJson() {
    final list = _b!.services;
    final q = _svQuery.toLowerCase();
    return {
      'title': 'LAYANAN',
      'search': {'v': _svQuery, 'ph': 'Cari layanan…'},
      'add': '+ Kategori',
      'cats': [
        for (var i = 0; i < list.length; i++)
          if (list[i].name.toLowerCase().contains(q))
            {
              'i': i,
              'svg': serviceIconSvg('${list[i].raw['icon'] ?? 'Kiloan'}'),
              't': list[i].name,
              's': 'Per ${list[i].unit}',
              'edit': true,
              'chain': [for (final st in _svSteps) {'t': st, 'on': list[i].proc.contains(st)}],
              'vars': [
                for (var j = 0; j < _svDurs.length; j++)
                  {
                    'j': j,
                    't': _svDurs[j],
                    's': '${durationHours(_svDurs[j])} jam',
                    'price': list[i].enabledFor(_svDurs[j]) && list[i].priceFor(_svDurs[j]) > 0 ? '${rp(list[i].priceFor(_svDurs[j]))} / ${list[i].unit}' : (list[i].priceFor(_svDurs[j]) > 0 ? 'Nonaktif' : 'Isi harga'),
                    'on': list[i].enabledFor(_svDurs[j]) && list[i].priceFor(_svDurs[j]) > 0,
                    'toggle': true,
                  },
              ],
            },
      ],
      'empty': list.isEmpty ? 'Belum ada layanan. Tambahkan layanan pertama Anda.' : '',
      'note': 'Alur proses menentukan tahap produksi & hak akses pegawai. Varian Reguler / Express / Kilat otomatis dari menu Durasi — isi harga atau matikan.',
    };
  }

  @override
  void svBack() => nav('settings');
  @override
  void svSearch(String text) => setState(() => _svQuery = text.trim());
  @override
  void svToggle(int index, int variant) {
    final list = _b!.services;
    if (index < 0 || index >= list.length || variant < 0 || variant > 2) return;
    final s = list[index], d = _svDurs[variant];
    final on = s.enabledFor(d) && s.priceFor(d) > 0;
    (s.raw.putIfAbsent('enabled', () => <String, dynamic>{}) as Map)[d] = !on;
    _b!.saveServices();
    setState(() {});
  }

  @override
  void svEdit(int index) {
    final list = _b!.services;
    if (index < 0 || index >= list.length) return;
    final s = list[index];
    openFormSheet(FormSheetDef(
      'Edit Layanan',
      [
        FormSheetField('Nama layanan', value: s.name, required: true),
        for (final d in _svDurs) FormSheetField('Harga $d (0 untuk nonaktif)', value: '${s.priceFor(d)}', numeric: true),
      ],
      'Simpan',
      (v) {
        final prices = <String, int>{};
        for (var i = 0; i < 3; i++) {
          if (!RegExp(r'^\d+$').hasMatch(v[i + 1])) {
            toast('Harga harus berupa angka tanpa titik atau koma');
            return false;
          }
          prices[_svDurs[i]] = int.parse(v[i + 1]);
        }
        if (!prices.values.any((n) => n > 0)) {
          toast('Aktifkan minimal satu harga layanan');
          return false;
        }
        final name = v[0].trim();
        if (list.any((r) => r != s && r.name.toLowerCase() == name.toLowerCase())) {
          toast('Nama layanan sudah digunakan');
          return false;
        }
        s.raw
          ..['name'] = name
          ..['prices'] = Map<String, dynamic>.from(prices)
          ..['enabled'] = {for (final d in _svDurs) d: prices[d]! > 0};
        _b!.saveServices();
        toast('Layanan dan harga diperbarui');
        return null;
      },
      sub: 'Harga per ${s.unit}',
    ));
  }

  @override
  void svAdd() => _open(_Sheet('cat99', _catItems()));

  List<Map<String, dynamic>> _catItems() {
    Map<String, dynamic> input(String v, String ph, bool numeric, int i) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    Map<String, dynamic> opt(String t, String svg, bool on, int i) => {'t': t, 'svg': svg, 'file': '', 'after': false, 'on': on, 'i': i};
    final icons = serviceIcons.keys.toList();
    return [
      {'type': 'title', 't': 'Kategori Baru', 's': ''},
      {'type': 'hint', 't': 'Varian durasi dibuat otomatis dari menu Durasi'},
      {'type': 'label', 't': 'Nama kategori'},
      input(_catName, 'Contoh: Cuci Biasa', false, 0),
      {'type': 'label', 't': 'Pilih ikon'},
      {'type': 'buttons', 'options': [for (var k = 0; k < icons.length; k++) opt(icons[k], serviceIconSvg(icons[k], 30), k == _catIcon, k)]},
      {'type': 'label', 't': 'Satuan'},
      {'type': 'buttons', 'options': [for (var k = 0; k < 3; k++) opt(_svUnits[k], '', k == _catUnit, 22 + k)]},
      {'type': 'label', 't': 'Alur proses'},
      {'type': 'buttons', 'options': [for (var k = 0; k < 4; k++) opt(_svSteps[k], '', _catProc.contains(k), 25 + k)]},
      {'type': 'label', 't': 'Harga Reguler (per satuan)'},
      input(_catPrice, 'Contoh: 5000', true, 1),
      {'type': 'label', 't': 'Poin kinerja pegawai (opsional)'},
      input(_catScore, 'Contoh: 80', true, 2),
      {'type': 'button', 't': 'Simpan Kategori', 'primary': true, 'file': '', 'after': false, 'i': 29},
    ];
  }

  void _catEvent(String kind, int index, Object? value) {
    if (kind == 'close') return _close('cat99');
    if (kind == 'input') {
      final v = '${value ?? ''}';
      if (index == 0) _catName = v;
      if (index == 1) _catPrice = v;
      if (index == 2) _catScore = v;
      return;
    }
    if (kind != 'button') return;
    if (index < 22) {
      _catIcon = index;
    } else if (index < 25) {
      _catUnit = index - 22;
    } else if (index < 29) {
      _catProc.contains(index - 25) ? _catProc.remove(index - 25) : _catProc.add(index - 25);
    } else {
      final name = _catName.trim();
      if (name.isEmpty) return toast('Isi nama kategori dulu');
      final price = parseRupiah(_catPrice);
      // Harga Express = 1,4× dibulatkan ke Rp500, Kilat = 2× (sama dengan saveCat99).
      final prices = {'Reguler': price, 'Express': (price * 1.4 / 500).round() * 500, 'Kilat': price * 2};
      _b!.services.insert(0, Service({
        'key': name.toLowerCase(), 'name': name, 'unit': _svUnits[_catUnit], 'prices': prices,
        'enabled': {for (final d in _svDurs) d: prices[d]! > 0},
        'proc': [for (var k = 0; k < 4; k++) if (_catProc.contains(k)) _svSteps[k]],
        'icon': serviceIcons.keys.elementAt(_catIcon),
        if (_catScore.trim().isNotEmpty) 'score': _catScore.trim(),
      }));
      _b!.saveServices();
      _catName = _catPrice = _catScore = '';
      _close('cat99');
      return toast('Kategori "$name" tersimpan · harga Express & Kilat bisa diubah');
    }
    _open(_Sheet('cat99', _catItems()));
  }

  // ---------------- Deposit Pelanggan (deposits178) ----------------
  int _depCust = 0, _depMethod = 0;
  String _depAmount = '';
  void _openDeposits() {
    _depCust = 0;
    _depMethod = 0;
    _depAmount = '';
    _showDeposits();
  }

  void _showDeposits() {
    final b = _b!, list = b.customers;
    final c = list.isEmpty ? null : list[_depCust.clamp(0, list.length - 1)];
    final hist = c == null ? const <dynamic>[] : ((((b.raw['deposits178'] as Map?)?[b.depositKey(c.name)] as Map?)?['history'] as List?) ?? const []);
    _open(_Sheet('deposits178', [
      {'type': 'title', 't': 'Deposit Pelanggan', 's': ''},
      {'type': 'hint', 't': 'Saldo titipan pelanggan untuk pembayaran laundry.'},
      {'type': 'select', 'options': [for (final x in list) '${x.name} · ${x.phone}'], 'index': list.isEmpty ? -1 : _depCust.clamp(0, list.length - 1), 'i': 0},
      {'type': 'hint', 't': c == null ? 'Tambahkan pelanggan terlebih dahulu' : 'Saldo ${rp(b.depositOf(c.name))}'},
      {'type': 'label', 't': 'Nominal tambah saldo'},
      {'type': 'input', 'v': _depAmount, 'ph': '', 'multiline': false, 'numeric': true, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': 1},
      {'type': 'label', 't': 'Metode penerimaan'},
      {'type': 'select', 'options': const ['Tunai', 'QRIS', 'Transfer'], 'index': _depMethod, 'i': 2},
      {'type': 'button', 't': 'Simpan Tambah Saldo', 'primary': true, 'file': '', 'after': false, 'i': 0},
      for (final h in hist.reversed.take(20).whereType<Map>())
        {'type': 'hint', 't': '${h['type'] == 'topup' ? 'Tambah saldo' : (h['type'] == 'refund' ? 'Pengembalian ${h['order'] ?? ''}' : 'Pembayaran ${h['order'] ?? ''}')} · ${rp(parseRupiah(h['amount']))}'},
      {'type': 'button', 't': 'Tutup', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ]));
  }

  void _depositEvent(String kind, int index, Object? value) {
    if (kind == 'close') return _close('deposits178');
    if (kind == 'input') {
      if (index == 1) {
        _depAmount = '${value ?? ''}';
        return;
      }
      if (index == 0) _depCust = value is int ? value : 0;
      if (index == 2) _depMethod = value is int ? value : 0;
      return _showDeposits();
    }
    if (kind != 'button') return;
    if (index == 1) return _close('deposits178');
    final b = _b!, list = b.customers, amount = int.tryParse(_depAmount.trim()) ?? 0;
    if (list.isEmpty || amount <= 0) return toast('Isi nominal saldo yang benar');
    final c = list[_depCust.clamp(0, list.length - 1)];
    final err = b.topUpDeposit(c.name, amount, method: const ['Tunai', 'QRIS', 'Transfer'][_depMethod.clamp(0, 2)], now: now);
    if (err != null) return toast(err);
    _save();
    _depAmount = '';
    toast('Saldo deposit tersimpan');
    _showDeposits();
  }

  /// Popup "terkunci" (lock111) untuk fitur chatbot.
  void _lockSheet(String name) => _open(_Sheet('lock111', [
        {'type': 'title', 't': '🔒'},
        {'type': 'title', 't': '$name terkunci', 's': ''},
        {'type': 'hint', 't': 'Fitur ini butuh minimal 1 nomor chatbot WhatsApp. Pilih paket PRO CHATBOT, atau tambah nomor di paket kamu sekarang.'},
        {'type': 'button', 't': 'Lihat PRO CHATBOT · Rp100.000/bulan', 'primary': true, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Tambah 1 nomor saja · Rp30.000/bulan', 'primary': false, 'file': '', 'after': false, 'i': 1},
      ]));

  // ---------------- popup milik halaman ----------------
  final Set<String> _pageSheets = {};
  @override
  void openPageSheet(String id) => setState(() => _pageSheets.add(id));
  @override
  void closePageSheet(String id) => setState(() => _pageSheets.remove(id));

  // ---------------- popup isian serbaguna (formSheet107) ----------------
  FormSheetDef? _fs;
  List<String> _fsVals = [];

  @override
  void openFormSheet(FormSheetDef def) {
    _fs = def;
    _fsVals = [for (final f in def.fields) f.value];
    _showFormSheet();
  }

  @override
  void closeFormSheet() {
    _fs = null;
    _close('gs107');
  }

  void _showFormSheet() {
    final d = _fs;
    if (d == null) return;
    _open(_Sheet('gs107', [
      {'type': 'title', 't': d.title, 's': ''},
      {'type': 'hint', 't': d.sub},
      for (var k = 0; k < d.fields.length; k++) ...[
        {'type': 'label', 't': d.fields[k].label},
        if (d.fields[k].colors == null)
          {'type': 'input', 'v': _fsVals[k], 'ph': d.fields[k].placeholder, 'multiline': false, 'numeric': d.fields[k].numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': k}
        else
          {'type': 'swatches', 'colors': d.fields[k].colors, 'sel': d.fields[k].colors!.indexWhere((c) => c.toLowerCase() == _fsVals[k].toLowerCase()), 'i': k},
      ],
      {'type': 'button', 't': d.okText, 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ]));
  }

  void _formSheetEvent(String kind, int index, Object? value) {
    final d = _fs;
    if (d == null) return;
    if (kind == 'close') return closeFormSheet();
    if (kind == 'input') {
      if (index < 0 || index >= d.fields.length) return;
      final colors = d.fields[index].colors;
      if (colors != null) {
        _fsVals[index] = colors[(value as int).clamp(0, colors.length - 1)];
        return _showFormSheet();
      }
      _fsVals[index] = '${value ?? ''}'.trim();
      return;
    }
    if (kind != 'button') return;
    if (index == 1) return closeFormSheet();
    for (var k = 0; k < d.fields.length; k++) {
      if (d.fields[k].required && _fsVals[k].trim().isEmpty) return toast('Lengkapi data yang wajib diisi');
    }
    if (d.onOk(List<String>.of(_fsVals)) != false) closeFormSheet();
  }

  // ---------------- navigasi ----------------
  @override
  void nav(String pageId) {
    final gate = pageGates[pageId];
    if (gate != null && !planAccess.has(gate, now)) return toast(planAccess.lockedText(gate));
    setState(() {
      _sheets.clear();
      _pageSheets.clear();
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
    (m['groups'] as List).add({
      'i': 13,
      'svg': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 3h6M10 3v6l-6 10a1 1 0 0 0 1 2h14a1 1 0 0 0 1-2L14 9V3M8 14h8"></path></svg>',
      'icon': '', 't': 'Mode Uji', 's': planAccess.testPlan == null ? 'Coba fitur premium dengan password' : 'Aktif · ${planAccess.testPlan}',
      'accordion': false, 'open': false, 'items': <dynamic>[],
    });
    final tu = planAccess.trialUntil;
    if (m['acct'] is Map && tu != null) {
      (m['acct'] as Map)['s'] = planAccess.rank(now) > 0 ? 'Trial Basic sampai ${tu.day}/${tu.month}/${tu.year}' : 'Trial berakhir · pilih paket';
    }
    for (final g in (m['groups'] as List).cast<Map<String, dynamic>>()) {
      final i = (g['i'] as num).toInt();
      g['open'] = _stOpen.contains(i);
      for (final it in (g['items'] as List? ?? const []).whereType<Map>()) {
        if (it['t'] == 'Antar-Jemput') it['s'] = deliverySub(_settings!.raw).replaceFirst('jemput & antar', 'ongkir, area & kurir');
      }
      if (!_stOpen.contains(i)) g['items'] = <dynamic>[];
    }
    return m;
  }

  /// Item menu HTML → halaman mode murni. null = belum dipindah.
  static const Map<String, String> _stRoutes = {
    '0/0': 'profile', '1/0': 'outlets', '1/1': 'superbilling',
    '2/0': 'services', '2/1': 'duration', '2/2': 'perfume', '2/3': 'discounts', '2/4': 'delivery',
    '3/0': 'employees', '3/1': 'cashier', '3/2': 'audit', '3/3': 'couriers',
    '4/0': 'customers', '4/1': 'crm', '4/2': 'wadevices195', '4/3': 'whatsappbot', '4/4': 'quickreply', '4/5': 'automation',
    '5': 'wadevices195', '6': 'triggers191', '7': 'ai191', '8': 'blast191',
    '9/0': 'qris', '9/1': 'finance', '9/2': 'ralat139', '9/3': 'stock', '9/4': 'reminder', '9/5': 'reports', '9/6': 'sheet:deposits178', '9/7': 'stock',
    '10/0': 'printer', '10/1': 'barcode', '11': 'datacenter', '13': 'testmode192', '12/0': 'helpcenter', '12/1': 'aboutgoyana', '12/2': 'sheet:perm178',
  };
  void _stGo(String key) {
    final r = _stRoutes[key];
    if (r == null) return toast('Halaman ini sedang dipindahkan');
    // Kunci paket khusus menu WhatsApp/Chatbot (sama dengan HTML): grup Chatbot butuh paket AI, lainnya sesuai fiturnya.
    if (const ['4/3', '4/4', '4/5'].contains(key) && !planAccess.has('ai', now)) return _lockSheet(const {'4/3': 'WhatsApp & Chatbot', '4/4': 'Balas Cepat & Trigger', '4/5': 'Otomasi Pelanggan'}[key]!);
    final need = const {'6': 'quick', '7': 'ai', '8': 'blast'}[key];
    if (need != null && !planAccess.has(need, now)) return toast(planAccess.lockedText(need));
    if (r == 'sheet:deposits178') return _openDeposits();
    if (r == 'sheet:perm178') {
      return _open(_Sheet('perm178', [
        {'type': 'title', 't': 'Izin Aplikasi', 's': ''},
        {'type': 'hint', 't': 'Foto dan file dipilih lewat pemilih bawaan HP. Internet tidak memerlukan dialog izin.'},
        {'type': 'button', 't': 'Buka Pengaturan HP', 'primary': true, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Tutup', 'primary': false, 'file': '', 'after': false, 'i': 1},
      ]));
    }
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

  List<List<String>> _editDiscList = const [['Tanpa diskon', '0']];
  void _openEdit(Order o) {
    _editDiscList = _editDiscs(o.discKey);
    final disc = _editDiscList.indexWhere((d) => d[1] == o.discKey);
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
      {'type': 'select', 'options': [for (final d in _editDiscList) d[0]], 'index': _form['disc'], 'i': 2},
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
    if (scope == 'gs107') return _formSheetEvent(kind, index, value);
    if (scope == 'cat99') return _catEvent(kind, index, value);
    if (scope == 'deposits178') return _depositEvent(kind, index, value);
    if (scope == 'perm178') {
      _close('perm178');
      if (kind == 'button' && index == 0) _device.invokeMethod('GoyanaDevice.openSettings').catchError((_) => null);
      return;
    }
    if (scope == 'lock111') {
      _close('lock111');
      if (kind == 'button') nav('plan');
      return;
    }
    if (_pageSheets.contains(scope)) {
      if (kind == 'close') return closePageSheet(scope);
      return _pages[_page]?.sheetEvent(scope, kind, index, value);
    }
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
          addAudit(this, '✕', 'Pesanan dibatalkan', '$_kasir · ${o.id}');
          saveAll();
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
              perfume: _perfumeValue((_form['perfume'] as int?) ?? 0),
              discKey: _editDiscList[((_form['disc'] as int?) ?? 0).clamp(0, _editDiscList.length - 1)][1],
              due: dueDays == null ? null : (o.masuk ?? now).add(Duration(days: dueDays)));
          addAudit(this, '✎', 'Edit transaksi', '$_kasir · ${o.id}');
          saveAll();
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
        if (index == 4) {
          _close('confirm');
          return nav('qris');
        }
        if (index == 1) {
          if (_pendingMethod == 'Saldo Deposit') {
            final bal = _b!.depositOf(_aoCustomer);
            if (bal < _cartTotal) return toast('Saldo deposit $_aoCustomer ${rp(bal)} tidak cukup');
          }
          _finishOrder(_pendingMethod);
        }
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
  Future<void> fmFile(String inputId) async {
    try {
      final uris = await _device.invokeListMethod<String>('Files.pick', {'accept': ['image/png', 'image/jpeg', 'image/webp'], 'multiple': false, 'capture': false});
      if (uris == null || uris.isEmpty) return;
      final f = await _device.invokeMapMethod<String, dynamic>('Files.read', {'uri': uris.first});
      if (f == null) return;
      _pages[_page]?.file(inputId, '${f['name']}', '${f['mime']}', '${f['data']}');
    } catch (_) {
      toast('File tidak dapat dibaca');
    }
  }
  @override
  void fmTap(int index) {}

  // ---------------- Pelanggan ----------------
  @override
  void cuBack() => nav('home');
  @override
  void cuSearch(String text) => setState(() => _custSearch = text);
  @override
  void cuDeposit() => _openDeposits();
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
        _manualDisc = 0;
        _voucher = null;
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

  int _manualDisc = 0;
  List<Map<String, dynamic>> get _activeDiscs => [for (final d in discountsOf(_settings!.raw)) if (discActive(d, now)) d];
  List<List<String>> get _voucherDiscs => [
        for (final v in (_settings!.raw['vouchers'] as List? ?? const []))
          if (v is Map && v['key'] != null) ['Voucher ${v['code']}', '${v['key']}'],
      ];

  /// Pilihan diskon di Atur Pesanan (sama dengan HTML): Tidak, diskon aktif, diskon manual, voucher.
  /// Tiap butir: [label, kunci diskon untuk keranjang saat ini].
  List<List<String>> get _discs {
    final cart = _cartItems;
    return [
      ['Tidak', '0'],
      for (final d in _activeDiscs) [discOption(d), discKey(d, cart)],
      if (discCfgOf(_settings!.raw)['manual'] == true) [_manualDisc > 0 ? 'Diskon manual · ${rp(_manualDisc)}' : 'Diskon manual (Rp)…', 'n$_manualDisc'],
      ..._voucherDiscs,
      // Voucher kode unik dari CRM (vc130): potongan dihitung dari harga layanan, ongkir tidak ikut.
      [
        _voucher == null ? '🎟 Pakai kode voucher…' : '🎟 ${_voucher!.code} · ${_voucher!.type == 'p' ? '${_voucher!.val}%' : rp(_voucher!.val)}',
        _voucher == null ? '0' : (_voucher!.type == 'p' ? 'p${_voucher!.val}' : 'n${_voucher!.val}'),
      ],
    ];
  }

  CrmVoucher? _voucher;
  void _pickVoucher(int option) {
    setState(() => _opt['disc'] = option);
    openFormSheet(FormSheetDef(
      'Kode voucher',
      const [FormSheetField('Kode voucher', placeholder: 'GY-XXXXX', required: true)],
      'Pakai',
      (v) {
        final code = v[0].trim().toUpperCase();
        final total = calcTotals(_cartItems, '0', _optOngkir).total;
        CrmStore(widget.store).load().then((st) {
          final x = st.vouchers.where((z) => z.code == code).firstOrNull;
          if (x == null) return toast('Kode tidak ditemukan');
          if (x.used) return toast('Kode sudah pernah dipakai');
          if (x.expired(now)) return toast('Kode sudah kedaluwarsa');
          if (x.min > 0 && total < x.min) return toast('Minimal transaksi ${rp(x.min)}');
          setState(() => _voucher = x);
          closeFormSheet();
          toast('Voucher ${x.code} dipakai (${x.who})');
        });
        return false;
      },
      sub: 'Ketik kode dari pelanggan, contoh GY-7K2PQ',
    ));
  }

  String get _optDiscKey {
    final d = _discs;
    return d[(_opt['disc'] as int).clamp(0, d.length - 1)][1];
  }

  /// Pilihan diskon di Edit Transaksi: "Tanpa diskon", diskon aktif, voucher, dan diskon pesanan saat ini bila tak ada di daftar.
  List<List<String>> _editDiscs(String current) {
    final out = <List<String>>[
      ['Tanpa diskon', '0'],
      for (final d in _activeDiscs) ['${d['name']} · ${discLabel(d)}', '${d['type']}${d['val']}'],
      ..._voucherDiscs,
    ];
    if (current != '0' && !out.any((e) => e[1] == current)) {
      final m = RegExp(r'^([pn])(\d+)$').firstMatch(current);
      out.add([m == null ? current : (m.group(1) == 'p' ? 'Diskon ${m.group(2)}%' : 'Potongan ${rp(int.parse(m.group(2)!))}'), current]);
    }
    return out;
  }

  void _pickDisc(int option) {
    final act = _activeDiscs;
    final total = calcTotals(_cartItems, '0', 0).total;
    final cfg = discCfgOf(_settings!.raw);
    final maxPct = cfg['maxPct'] as int;
    if (option >= 1 && option <= act.length) {
      final d = act[option - 1];
      final min = (d['min'] as num?)?.round() ?? 0;
      if (min > 0 && total < min) {
        setState(() => _opt['disc'] = 0);
        return toast('"${d['name']}" butuh minimal transaksi ${rp(min)}');
      }
      final a = discAmount(d, _cartItems);
      if (a == 0) {
        setState(() => _opt['disc'] = 0);
        return toast('Tidak ada layanan ${d['scope']} di pesanan ini');
      }
      setState(() => _opt['disc'] = option);
      final v = (d['val'] as num).round();
      return toast(d['type'] == 'p' && v > maxPct ? 'Diskon $v% · perlu persetujuan owner (tercatat di audit)' : 'Hemat ${rp(a)}');
    }
    if (option == _discs.length - 1) return _pickVoucher(option);
    if (cfg['manual'] == true && option == act.length + 1) {
      final limit = total * maxPct / 100;
      setState(() => _opt['disc'] = option);
      return openFormSheet(FormSheetDef(
        'Diskon manual',
        const [FormSheetField('Potongan (Rp)', placeholder: '5000', numeric: true, required: true)],
        'Pakai',
        (v) {
          final n = parseRupiah(v[0]);
          if (n > limit) {
            toast('Melebihi batas diskon kasir $maxPct%');
            return false;
          }
          setState(() => _manualDisc = n);
          toast('Diskon ${rp(n)} dipakai');
          return null;
        },
        sub: 'Maksimal $maxPct% dari total (${rp(limit)})',
      ));
    }
    setState(() => _opt['disc'] = option);
  }

  List<String> get _hands => handoverOptions(_settings!.raw);
  String get _optHand {
    final h = _hands;
    return h[(_opt['hand'] as int).clamp(0, h.length - 1)];
  }

  /// Ongkir pesanan yang sedang dibuat (Tarif Transportasi outlet aktif); tidak ikut didiskon.
  int get _optOngkir {
    final b = _b!;
    final id = b.activeOutlet.isNotEmpty ? b.activeOutlet : (b.outlets.isEmpty ? '' : b.outlets.first.id);
    return transportFee(_optHand, transportCfg(id));
  }


  Map<String, dynamic> _addOrderJson() {
    final b = _b!;
    final m = <String, dynamic>{'title': _aoStage == 'customer' ? 'PILIH PELANGGAN' : 'TAMBAHKAN LAYANAN', 'stage': _aoStage};
    if (_aoStage == 'customer') {
      final q = _aoCustSearch.trim().toLowerCase();
      final list = b.customers;
      m['step'] = 'Langkah 1 dari 5';
      m['search'] = {'v': _aoCustSearch, 'ph': 'Cari nama / no handphone'};
      m['add'] = 'Tambah Pelanggan';
      m['people'] = [
        for (var i = 0; i < list.length; i++)
          if (q.isEmpty || '${list[i].name} ${list[i].phone}'.toLowerCase().contains(q))
            {'i': i, 'name': list[i].name, 'avatar': aoPersonAvatar, 'lines': ['☎ ${list[i].phone}', '⌖ ${list[i].address.isEmpty ? '—' : list[i].address}'], 'btn': 'Pilih'},
      ];
      m['empty'] = (m['people'] as List).isEmpty ? (q.isEmpty ? 'Belum ada pelanggan. Tambahkan pelanggan baru.' : 'Pelanggan tidak ditemukan.') : '';
      return m;
    }
    final t = calcTotals(_cartItems, _optDiscKey, 0);
    m['step'] = 'Langkah 2 dari 5';
    m['customer'] = {'name': _aoCustomer, 'sub': _aoDur, 'avatar': aoBarAvatar};
    m['durations'] = [for (final d in _durations) {'t': d, 's': '${durationHours(d)} Jam', 'on': d == _aoDur}];
    m['cats'] = [for (var i = 0; i < _cats.length; i++) {'t': _cats[i][0], 'on': i == _aoCat, 'svg': aoCatSvg[_cats[i][0]] ?? ''}];
    m['search'] = {'v': _aoSvcSearch, 'ph': 'Cari layanan $_aoDur'};
    final items = <Map<String, dynamic>>[];
    final svcs = _visibleServices;
    for (final cat in _cats.skip(1)) {
      final group = svcs.where((s) => s.unit == cat[1]).toList();
      if (group.isEmpty) continue;
      items.add({'h': 1, 'svg': aoHeadSvg[cat[0]] ?? '', 't': '${cat[0]} · $_aoDur', 's': const {'kg': 'Cuci ››› Kering ››› Setrika', 'pcs': 'Cuci ››› Kering ››› Packing', 'm': 'Cuci ››› Kering'}[cat[1]] ?? ''});
      for (final s in group) {
        final q = _cart[s.name];
        items.add({'i': b.services.indexOf(s), 'svg': aoItemSvg[cat[0]] ?? '', 't': s.name, 's': '${rpSpaced(s.priceFor(_aoDur))} / ${s.unit} · ${durationHours(_aoDur)} Jam', 'btn': q == null ? 'Pilih' : '${qtyText(q)} ${s.unit}', 'on': q != null});
      }
    }
    m['items'] = items;
    double sumOf(String u) => _cart.entries.fold<double>(0, (a, e) => a + (b.services.any((x) => x.name == e.key && x.unit == u) ? e.value : 0));
    String qn(double v) => qtyText(v);
    m['footer'] = {'name': _aoCustomer, 'sum': '${qn(sumOf('kg'))} kg · ${qn(sumOf('pcs'))} pcs · ${qn(sumOf('m'))} m', 'label': 'Total Layanan', 'total': rpSpaced(t.total), 'btn': 'LANJUT ›'};
    if (_aoSheet == 'options') {
      m['sheet'] = {
        'kind': 'options', 'title': 'Atur Pesanan',
        'fields': [
          {'k': 0, 'type': 'select', 'label': 'Parfum', 'options': _perfumes, 'index': _opt['perfume']},
          {'k': 2, 'type': 'select', 'label': 'Penyerahan', 'options': _hands, 'index': _opt['hand']},
          {'k': 3, 'type': 'switch', 'label': 'Jadikan Prioritas', 'sub': 'naik ke atas antrian', 'on': _opt['prio'] == true},
          {'k': 1, 'type': 'select', 'label': 'Diskon', 'options': [for (final d in _discs) d[0]], 'index': _opt['disc']},
        ],
        'note': {'v': '${_opt['note']}', 'ph': 'Catatan: jumlah pakaian, no rak, kondisi (contoh: 12 pcs, rak B2, kemeja luntur)'},
        'main': 'Buat Pesanan',
      };
    } else if (_aoSheet == 'payment') {
      m['sheet'] = {
        'kind': 'payment', 'title': 'Pembayaran', 'label': 'Total Tagihan', 'total': rpSpaced(t.total), 'id': b.nextOrderId(now),
        'methods': [
          for (var i = 0; i < _payMethods.length; i++)
            {
              'i': i, 't': _payMethods[i][3], 'svg': aoPaySvg[_payMethods[i][3]]![0], 'icon': aoPaySvg[_payMethods[i][3]]![3],
              'ic': aoPaySvg[_payMethods[i][3]]![1], 'bg': aoPaySvg[_payMethods[i][3]]![2],
              's': _payMethods[i][0] == 'Saldo Deposit' && b.depositOf(_aoCustomer) > 0 ? 'Saldo ${rp(b.depositOf(_aoCustomer))}' : '',
            },
        ],
        'cancel': 'Batalkan Pesanan',
      };
    }
    return m;
  }

  /// Nilai yang disimpan di pesanan (HTML menyimpan 'Tanpa Parfum' untuk pilihan 'Tidak').
  String _perfumeValue(int i) {
    final v = _perfumes[i.clamp(0, _perfumes.length - 1)];
    return v == 'Tidak' ? 'Tanpa Parfum' : v;
  }

  List<String> get _perfumes => ['Tidak', for (final p in _settings!.perfumes) p.first];

  static const _payMethods = [
    ['Tunai', '', '', 'Tunai'], ['QRIS', '', '', 'QRIS'], ['Transfer', '', '', 'Transfer'],
    ['Bayar Nanti', '', '', 'Bayar Nanti'], ['DP / Uang Muka', '', '', 'DP / Uang Muka'], ['Saldo Deposit', '', '', 'Saldo Deposit'],
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
    final sv = _qtyService!;
    return [
      {'type': 'ao', 'kind': 'qty', 'v': '${_form['amount']}', 'unit': sv.unit, 'hasRemove': _cart.containsKey(sv.name)},
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
  void aoSheetSelect(int field, int option) => field == 1 ? _pickDisc(option) : setState(() => _opt[const ['perfume', 'disc', 'hand'][field]] = option);
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

  int get _cartTotal => calcTotals(_cartItems, _optDiscKey, _optOngkir).total;

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
        _confirm('Saldo Deposit');
      case 'QRIS':
        _confirm('QRIS');
      default:
        _finishOrder(m);
    }
  }

  void _confirm(String method) {
    _pendingMethod = method;
    if (method == 'Saldo Deposit') {
      return _open(_Sheet('confirm', [
        {'type': 'ao', 'kind': 'deposit', 'title': 'Saldo Deposit', 'sub': '$_aoCustomer · saldo ${rp(_b!.depositOf(_aoCustomer))} · tagihan ${rp(_cartTotal)}', 'ok': 'Bayar dengan Deposit'},
      ]));
    }
    final qris = _settings!.qrisText;
    _open(_Sheet('confirm', [
      {'type': 'ao', 'kind': 'qris', 'qr': qrisValid(qris) ? (_settings!.raw['qrisDynamic'] != false ? qrisDynamic(qris, _cartTotal) : qris) : '', 'total': rpSpaced(_cartTotal)},
    ]));
  }

  List<Map<String, dynamic>> _cashItems() {
    final total = _cartTotal, got = parseRupiah(_form['amount']);
    return [
      {
        'type': 'ao', 'kind': 'cash', 'v': '${_form['amount']}', 'total': rpSpaced(total),
        'chips': [{'t': 'Uang pas', 'i': 10}, {'t': '20rb', 'i': 13}, {'t': '50rb', 'i': 11}, {'t': '100rb', 'i': 12}],
        'change': got >= total && got > 0 ? rpSpaced(got - total) : '—', 'changeOk': got >= total && got > 0,
        'ok': got == 0 || got == total ? 'SUDAH DIBAYAR (UANG PAS)' : 'SUDAH DIBAYAR',
      },
    ];
  }

  void _cashButton(int index) {
    if (index >= 10) {
      _form['amount'] = '${index == 10 ? _cartTotal : (index == 11 ? 50000 : (index == 13 ? 20000 : 100000))}';
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
        {'type': 'ao', 'kind': 'dp', 'v': '${_form['amount']}', 'method': '${_form['dpMethod']}', 'sub': '$_aoCustomer · sisa tagihan ${rp(_cartTotal)}'},
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
    final hand = _optHand;
    final usedVoucher = (_opt['disc'] as int) == _discs.length - 1 ? _voucher : null;
    if (usedVoucher != null) {
      // Kode sekali pakai: tandai terpakai di data CRM.
      final db = CrmStore(widget.store);
      db.load().then((st) {
        for (final z in st.vouchers) {
          if (z.code == usedVoucher.code) z.used = true;
        }
        return db.save(st);
      });
    }
    final o = b.createOrder(
      customer: _aoCustomer, phone: cust?.phone ?? '', dur: _aoDur, items: _cartItems,
      discKey: _optDiscKey, ongkir: _optOngkir, perfume: _perfumeValue((_opt['perfume'] as int)),
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
      case 'reports':
        page = NativeReports(model: reportsHubA8(_rpCtx(), periodKey: _rpKey, from: _rpFrom, to: _rpTo, cat: _rpCat, query: _rpQuery, outlet: _activeOutletName()), actions: this);
      case 'rp':
        page = _rpDetail();
      case 'services':
        page = NativeServices(model: ServicesModel.fromJson(servicesJson()), actions: this);
      case 'settings':
        page = NativeSettings(model: SettingsModel.fromJson(_settingsJson()), actions: this);
      default:
        final pp = _pages[_page];
        page = pp != null
            ? (pp.custom(context, this) ?? NativeForm(key: ValueKey(_page), model: FormModel(page: _page, title: pp.title, items: pp.items()), actions: this, navActive: pp.navActive))
            : NativeHome(model: HomeModel.fromJson(homeJson(b, n)), actions: this);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheets.isNotEmpty) return fmScoped(_sheets.last.id, 'close', 0);
        if (_pageSheets.isNotEmpty) return closePageSheet(_pageSheets.last);
        if (_aoSheet != null) return aoSheetClose();
        if (_page == 'addorder' && _aoStage == 'services') return aoBack();
        if (_page != 'home') return nav('home');
        SystemNavigator.pop();
      },
      child: Stack(children: [
        Positioned.fill(child: page),
        for (final s in _sheets)
          Positioned.fill(
            child: isAoPopup(s.items)
                ? AoPopup(key: ValueKey('pure-ao-${s.id}'), id: s.id, data: s.items.first, actions: this)
                : NativeSheet(key: ValueKey('pure-${s.id}-${s.items.length}'), id: s.id, items: s.items, actions: this, full: s.full),
          ),
        for (final id in _pageSheets)
          if (_pages[_page]?.sheetWidget(id, context) case final w?)
            Positioned.fill(child: w)
          else if (_pages[_page]?.sheetItems(id) case final items?)
            Positioned.fill(child: NativeSheet(key: ValueKey('pure-ps-$id'), id: id, items: items, actions: this)),
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
