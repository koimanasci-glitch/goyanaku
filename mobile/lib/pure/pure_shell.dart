// GOYANA mode murni Flutter: tanpa WebView. Semua hitungan & penyimpanan oleh logika Dart (lib/core),
// halaman memakai widget native yang sama dengan mode hybrid.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/business.dart';
import '../core/hpp.dart';
import '../core/stock.dart';
import '../core/models.dart';
import '../core/qris.dart';
import '../core/receipt.dart';
import '../core/settings.dart';
import '../core/money.dart';
import '../core/store.dart';
import '../native/addorder_page.dart';
import '../native/addorder_sheet.dart';
import '../native/order_detail_page.dart';
import '../native/outlet_setup.dart';
import '../native/order_status_qr.dart';
import '../native/hist115_sheet.dart';
import '../native/photo115_sheet.dart';
import '../native/popup_components.dart';
import '../native/wa131_sheet.dart';
import 'label_page.dart';
import 'g181_mirror.dart';
import 'order_history.dart';
import 'order_view.dart';
import 'receipt_image.dart';
import 'addorder_assets.dart';
import 'access.dart';
import 'addorder_popups.dart';
import 'cash_pages.dart';
import 'customer_add_page.dart';
import 'defaults.dart';
import 'delivery.dart';
import 'discounts.dart';
import '../native/common.dart';
import '../native/customers_page.dart';
import '../native/form_page.dart';
import '../native/login_screen.dart';
import '../native/home_page.dart';
import '../logic/crm.dart';
import '../logic/reports_a8.dart';
import '../native/orders_page.dart';
import '../native/report_detail.dart';
import '../native/reports_page.dart';
import '../native/services_page.dart';
import '../native/settings_page.dart';
import '../logic/reports_catalog.dart';
import 'courier_home.dart';
import 'courier_settings_page.dart';
import 'google_login.dart';
import 'pages.dart';
import 'pickup_pages.dart';
import 'ralat.dart';
import 'rank_page.dart';
import 'reminders.dart';
import 'reports_dart.dart';
import 'scan_page.dart';
import 'server_sync.dart';
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
  _Sheet(this.id, this.items, {this.mirror});
  final String id;
  final List<Map<String, dynamic>> items;
  /// Popup dengan widget khusus Hibrida (hist115, wa131, photo115): pohon tampilan.
  final Map<String, dynamic>? mirror;
}

/// Penghubung layar masuk (NativeLogin) ke mesin sinkronisasi: isian 0 = email/nomor HP, 1 = password/PIN;
/// tombol 0 = Masuk, tombol 1 = Lupa Password (dibuka di web server).
class _GateActions implements FormActions {
  _GateActions(this.shell);
  final PureShellState shell;
  @override
  void fmInput(int index, Object value) {
    if (index == 0) shell._srvUser = '$value';
    if (index == 1) shell._srvPass = '$value';
  }

  @override
  void fmButton(int index) {
    if (index == 0) {
      shell._srvRoster = [];
      shell._srvLogin();
    } else {
      shell._gateOpen('/forgot-password');
    }
  }

  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void fmBack() {}
  @override
  void fmToggle(int index) {}
  @override
  void fmRadio(int index) {}
  @override
  void fmFile(String inputId) {}
  @override
  void fmTap(int index) {}
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {}
}

class PureShellState extends State<PureShell> implements OrderDetailActions, HomeActions, OrdersActions, AddOrderActions, CustomersActions, FormActions, SettingsActions, ReportsActions, ReportDetailActions, ServicesActions, PureHost {
  static const _device = MethodChannel('id.goyana/device');
  Business? _b;
  AppSettings? _settings;
  late final Map<String, PurePage> _pages = {
    ...templatePages(this),
    ...whatsappPages(this),
    'printer': PrinterNotaPage(this), 'printerconnect': PrinterPage(this), 'qris': QrisPage(this),
    'perfume': PerfumePage(this), 'duration': DurationPage(this), 
    'today': TodayPage(this), 
    'stock': StockPage(this), 'couriers': CourierPage(this), 'kurirsetting': CourierSettingsPage(this), 'finance': FinancePage(this), 'delivery': DeliveryPage(this), 'discounts': DiscountPage(this), 'employees': EmployeesPage(this), 'pinlock': PinLockPage(this), 'cashin': CashEntryPage(this, income: true), 'cashout': CashEntryPage(this, income: false), 'cashclose': CashClosePage(this), 'jemput202': PickupPage(this), 'jemputnew202': PickupNewPage(this), 'ralat139': RalatPage(this), 'printlabel': LabelPage(this), 'customeradd': CustomerAddPage(this), 'rank138': RankPage(this), 'audit': AuditPage(this), 'koreksi': CorrectionsPage(this), 
    'crm': CrmNativePage(this), 'outlets': OutletsPage(this), 'outletedit': OutletEditPage(this), 'superbilling': ManageBranchesPage(this), 'branchmonitor58': BranchMonitorPage(this), 'kurirhome': CourierHomePage(this), 'testmode192': TestModePage(this), 
  };

  @override
  KvStore get kv => widget.store;

  /// Kasir yang sedang login (PIN); dicatat di riwayat pesanan.
  String _kasir = 'Kasir';
  /// True bila aplikasi dibuka dengan PIN pegawai (bukan PIN Admin): izin di Pengaturan → Kasir berlaku.
  bool _kasirSession = false;
  static const _kasirDefault = [true, true, false, true, true, true, false, false, true];

  /// Izin kasir ke-[k] (urutan sakelar Pengaturan Kasir): 0 statistik harian, 1 statistik layanan, 2 hapus pelanggan,
  /// 3 batalkan pesanan, 4 lihat saldo tunai, 5 lihat saldo non-tunai, 6 kurangi kas tunai, 7 kurangi kas non-tunai, 8 mutasi kas.
  @override
  bool kasirCan(int k) {
    if (!_kasirSession || k < 0 || k >= _kasirDefault.length) return true;
    final v = (((_settings?.raw['tpl'] as Map?)?['cashier'] as Map?)?['tg'] as Map?)?['$k'];
    return v is bool ? v : _kasirDefault[k];
  }

  bool _deny(int k, String what) {
    if (kasirCan(k)) return false;
    toast('Kasir tidak diizinkan $what · hubungi pemilik');
    return true;
  }

  @visibleForTesting
  set debugKasirSession(bool v) => _kasirSession = v;
  bool _locked = false;
  String _pin = '';

  @override
  void openOrder(String id) {
    if (!_courierMode) nav('orders');
    _showDetail(id);
  }

  // PureHost
  @override
  ServerSync get server => _srv;
  @override
  Business get business => _b!;
  @override
  AppSettings get settings => _settings!;
  @override
  MethodChannel get device => _device;
  // ---- Laporan (A8): dihitung Dart dari database yang sama ----
  String _rpKey = '30', _rpCat = 'all', _rpQuery = '', _rpId = 'omzet';
  DateTime? _rpFrom, _rpTo;

  /// Laporan per cabang (10 Okt 2026): '' = outlet aktif HP ini, '*' = semua cabang, selain itu id outlet.
  /// Akun staf selalu melihat cabangnya sendiri.
  String _rpOutletSel = '';
  String get _rpHome {
    final b = _b!;
    return b.activeOutlet.isNotEmpty ? b.activeOutlet : (b.outlets.isEmpty ? '' : b.outlets.first.id);
  }

  String get _rpOutlet {
    final b = _b!, home = _rpHome;
    if ((_srv.loggedIn && !_srv.isOwner) || _rpOutletSel.isEmpty) return home;
    if (_rpOutletSel == '*') return '*';
    return b.outlets.any((o) => o.id == _rpOutletSel) ? _rpOutletSel : home;
  }

  String _rpOutletLabel() {
    final sel = _rpOutlet;
    if (sel == '*') return 'Semua Cabang';
    return _b!.outlets.where((o) => o.id == sel).firstOrNull?.name ?? _activeOutletName();
  }

  RepCtx _rpCtx() {
    final sel = _rpOutlet, home = _rpHome;
    // Laci kas di HP ini milik outlet aktifnya, jadi hanya ikut di laporan outlet itu atau gabungan.
    return RepCtx.fromJson(reportStateFromBusiness(_b!.raw, now: now, outlet: sel == '*' || sel.isEmpty ? null : sel, blankOutlet: home, withKas: sel == '*' || sel == home));
  }

  void _rpOutletEvent(String kind, int index) {
    _close('rpoutlet');
    if (kind != 'button') return;
    final outs = _b!.outlets;
    if (index == 0) {
      setState(() => _rpOutletSel = '*');
    } else if (index - 1 < outs.length) {
      setState(() => _rpOutletSel = outs[index - 1].id);
    }
  }

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
        periodLabel: periodLabelA8(_rpKey, range), data: reportAny(ent.$1, ctx, range) ?? const {}, isExport: ent.$1.startsWith('x-'),
      ),
    );
  }

  Object? _rpData() {
    final ctx = _rpCtx();
    return reportAny(_rpId, ctx, ctx.range(_rpKey, from: _rpFrom, to: _rpTo));
  }

  @override
  void rpOutlet() {
    final outs = _b!.outlets;
    if (_srv.loggedIn && !_srv.isOwner) return toast('Laporan menampilkan cabang Anda saja');
    if (outs.length < 2) return toast('Laporan ${_rpOutletLabel()} · usaha ini baru punya 1 outlet');
    final sel = _rpOutlet;
    _open(_Sheet('rpoutlet', [
      {'type': 'title', 't': 'Laporan Cabang', 's': ''},
      {'type': 'hint', 't': 'Pilih cabang yang laporannya ingin dilihat.'},
      {'type': 'button', 't': '${sel == '*' ? '✓ ' : ''}Semua Cabang', 'primary': sel == '*', 'file': '', 'after': false, 'i': 0},
      for (var k = 0; k < outs.length; k++)
        {'type': 'button', 't': '${sel == outs[k].id ? '✓ ' : ''}${outs[k].name}', 'primary': sel == outs[k].id, 'file': '', 'after': false, 'i': k + 1},
      {'type': 'hint', 't': 'Uang laci kas yang belum ditutup hanya terlihat di laporan cabang HP ini atau Semua Cabang.'},
    ]));
  }
  @override
  void rpPeriod(int index) => rdPeriod(reportPeriodsA8[index].$1);
  @override
  void rpKpi(int index) {
    final id = const ['keluar', 'laba', 'piutang', 'tumbuh'][index];
    if (_denyReport(id)) return;
    setState(() => _rpId = id);
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
    if (_denyReport(id)) return;
    setState(() => _rpId = id);
    nav('rp');
  }

  /// Izin kasir untuk laporan: mutasi kas (Arus Kas), statistik harian (keuangan) dan statistik layanan.
  bool _denyReport(String id) {
    // Keputusan paket 10 Okt 2026: laba-rugi gabungan semua cabang hanya Platinum.
    if (_rpOutlet == '*' && const {'laba', 'labaop182'}.contains(id) && planAccess.rank(now) < 4) {
      toast('Laba-rugi gabungan semua cabang membutuhkan paket Platinum');
      return true;
    }
    if (id == 'arus') return _deny(8, 'melihat mutasi kas');
    if (const {'layanan', 'durasi'}.contains(id)) return _deny(1, 'melihat statistik layanan');
    final cat = reportCatalogA8.where((r) => r.$1 == id).firstOrNull?.$2;
    return cat == 'keu' && _deny(0, 'melihat statistik keuangan');
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
  bool _odBanner = false;
  Timer? _odTimer, _autoTimer;
  String? _payOrderId;
  bool _custOpen = false;
  int _custPage = 0;
  String _custSort = '';
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
  final Map<String, Object> _opt = {'perfume': 0, 'disc': 0, 'hand': 0, 'kurir': 0, 'prio': false, 'note': ''};

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
        final seeded = seedDefaults(_b!.services, _settings!.raw);
        if (seeded.$1) _b!.saveServices();
        if (seeded.$2) _settings!.save();
        _applyAuto();
        _hppSync();
        syncReminders();
        _srvStart();
      }
    });
    gBrandWord = 'GOYANA';
    gPhotoAvatars = true;
    _loadCrmRule();
    reportExtra = _reportExtra;
    // HTML v133: mesin status otomatis memeriksa tiap 20 detik.
    _autoTimer = Timer.periodic(const Duration(seconds: 20), (_) => _applyAuto());
  }

  /// Aturan status otomatis tersimpan ({q, qv, qu, p, step}); bawaan sama dengan HTML (Antrian → Proses 1 jam).
  Map<String, dynamic> get _auto => Map<String, dynamic>.from(_settings?.raw['auto133'] as Map? ?? const {});

  void _applyAuto() {
    final b = _b;
    if (!mounted || b == null || _settings == null || _srvBusy) return;
    final a = _auto;
    final steps = a['p'] == true
        ? {for (final e in const {'cuci': 60, 'kering': 90, 'setrika': 60, 'packing': 20}.entries) e.key: (num.tryParse('${(a['step'] as Map?)?[e.key] ?? e.value}') ?? e.value).toDouble()}
        : null;
    if (b.autoStatus(now, queueEnabled: a['q'] != false, queueMinutes: autoQueueMinutes(a), procMinutes: steps)) {
      _save();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _odTimer?.cancel();
    _autoTimer?.cancel();
    _pointTimer?.cancel();
    _remTimer?.cancel();
    _srvTimer?.cancel();
    _srvSoon?.cancel();
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
    // Saat data dari server sedang diterapkan, isi memori segera diganti; jangan menimpanya ke penyimpanan.
    if (_srvBusy) return;
    final ok = await _b!.save();
    if (!ok) toast('Penyimpanan perangkat penuh. Data belum tersimpan permanen.');
    await _hppSync();
    syncReminders();
    _srvKick();
  }

  // ---------------- Server GOYANA: masuk dan sinkronisasi (server_sync.dart) ----------------
  late final ServerSync _srv = ServerSync(widget.store, onChanged: _srvChanged);
  Timer? _srvTimer, _srvSoon;
  bool _srvBusy = false, _srvLogging = false;
  String _srvUrlDraft = '', _srvUser = '', _srvPass = '';

  void _srvChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _srvStart() async {
    serverNoteCode = _srv.noteCode;
    await _srv.load();
    if (!mounted) return;
    setState(() => _srvLoaded = true);
    // HP outlet yang dipakai bergantian langsung menampilkan pilihan nama.
    if (_gate && _srv.sharedBound) unawaited(_srvOpenRoster());
    // Peran tersimpan langsung berlaku; lalu diperbarui dari server (paket, peran, outlet bisa berubah sejak terakhir dibuka).
    _srvAdopt();
    if (_srv.loggedIn) {
      try {
        if (await _srv.refreshProfile() && mounted) await reloadAll();
      } on ServerFailure catch (_) {}
      if (!mounted) return;
      _srvAdopt();
    }
    await _srvApply();
    if (!mounted) return;
    _srvTimer = Timer.periodic(const Duration(seconds: 60), (_) => _srvCycle());
    await _srvCycle();
  }

  /// Peran dan paket dari server berlaku di aplikasi: selain pemilik dibatasi seperti sesi kasir.
  void _srvAdopt() {
    if (!_srv.loggedIn) {
      planAccess.serverPlan = null;
      return;
    }
    final access = _srv.access;
    planAccess.serverPlan = access['read_only'] == true ? '' : '${access['package'] ?? ''}'.toUpperCase();
    final name = '${_srv.user['name'] ?? ''}';
    setState(() {
      if (name.isNotEmpty) _kasir = name;
      _kasirSession = _srv.role != 'owner';
    });
    if (_courierMode && _b != null && const {'home', 'orders', 'customers', 'reports'}.contains(_page)) nav('kurirhome');
  }

  /// Menu yang dibatasi peran saat akun pegawai masuk ke server (server juga menolak tindakannya).
  /// Mengembalikan pesan penolakan, atau null bila boleh dibuka.
  String? _srvDenied(String pageId) {
    if (!_srv.loggedIn || _srv.role == 'owner') return null;
    if (_srv.role == 'kurir' &&
        !const {'kurirhome', 'addorder', 'settings', 'jemput202', 'customeradd', 'ralat139', 'printer', 'printerconnect', 'printlabel', 'helpcenter'}.contains(pageId)) {
      return 'Menu ini tidak tersedia untuk akun kurir';
    }
    if (const {'outlets', 'outletedit', 'superbilling', 'employees', 'kurirsetting', 'cashier', 'pinlock', 'upgrade', 'datacenter', 'testmode192'}.contains(pageId)) {
      return 'Hanya pemilik yang bisa membuka menu ini';
    }
    if (const {'reports', 'rp', 'branchmonitor58'}.contains(pageId) && !_srv.can('reports.view')) return 'Laporan hanya untuk pemilik';
    if (const {'services', 'duration', 'perfume', 'discounts', 'delivery', 'qris', 'finance'}.contains(pageId) && !_srv.can('prices.edit')) {
      return 'Harga dan setelan usaha diatur pemilik';
    }
    if (pageId == 'stock' && !_srv.can('stock.manage') && !_srv.can('stock.use')) return 'Stok diatur pemilik';
    if (pageId == 'addorder' && !_srv.can('orders.create') && !_srv.can('courier.tasks')) return 'Akun ini tidak membuat transaksi';
    return null;
  }

  /// Perubahan lokal dikirim tidak lama setelah disimpan (beberapa perubahan beruntun cukup sekali).
  void _srvKick() {
    if (!_srv.loggedIn) return;
    _srvSoon?.cancel();
    _srvSoon = Timer(const Duration(milliseconds: 2500), _srvCycle);
  }

  Future<void> _srvCycle() async {
    if (!mounted || !_srv.loggedIn) return;
    // Cabang yang ditambah owner di HP ini didaftarkan ke server lebih dulu, supaya pesanannya masuk cabang yang benar.
    if (_srv.isOwner && !_srvBusy && (_srvIdle || (_sheets.isEmpty && _pageSheets.isEmpty && const {'outlets', 'superbilling'}.contains(_page)))) {
      _srvBusy = true;
      try {
        if (await _srv.uploadLocalOutlets() && mounted) await reloadAll();
      } finally {
        _srvBusy = false;
      }
    }
    if (!mounted) return;
    await _srv.claimSlot(_b?.activeOutlet ?? '');
    await _srv.cycle();
    await _srvApply();
  }

  /// Data dari server diterapkan saat pengguna tidak sedang mengisi sesuatu (sama dengan aplikasi HTML).
  bool get _srvIdle =>
      _sheets.isEmpty && _pageSheets.isEmpty && _detailId == null && _payOrderId == null && _aoSheet == null &&
      const {'home', 'orders', 'customers', 'reports', 'settings', 'datacenter'}.contains(_page);

  Future<void> _srvApply() async {
    if (_srvBusy || !mounted || !_srvIdle) return;
    _srvBusy = true;
    try {
      if (await _srv.inboxCount() > 0 && mounted && _srvIdle) {
        await _srv.applyInbox();
        if (mounted) await reloadAll();
      }
    } finally {
      _srvBusy = false;
    }
  }

  Future<void> _srvSaveUrl() async {
    final problem = await _srv.setUrl(_srvUrlDraft.trim().isEmpty ? _srv.url : _srvUrlDraft);
    if (!mounted) return;
    if (problem != null) return toast(problem);
    if (_srv.loggedIn) return toast('Alamat server tersimpan');
    _srvOpenLogin();
  }

  /// HP outlet yang dipakai bergantian: daftar nama pegawai outlet dan nama yang sedang dipilih.
  List<Map<String, dynamic>> _srvRoster = [];
  int _srvPick = 0;

  // ---------- layar masuk (wajib selama aplikasi tersambung ke server dan belum ada akun yang masuk) ----------
  bool _srvLoaded = false;

  /// Butir pilihan nama + PIN untuk HP outlet saat layar masuk tampil; null = formulir masuk biasa.
  List<Map<String, dynamic>>? _gateRoster;
  late final _GateActions _gateActions = _GateActions(this);

  /// Masuk wajib, cukup sekali (keputusan pengguna 8 Oktober 2026): selama alamat server ada dan belum ada akun yang masuk,
  /// yang tampil hanya layar masuk. APK tanpa alamat server tetap bisa dipakai tanpa akun.
  bool get _gate => _srvLoaded && _srv.url.isNotEmpty && !_srv.loggedIn;

  /// Butir lembar/layar masuk yang sedang tampil.
  List<Map<String, dynamic>> get _loginItems =>
      _gateRoster ?? _sheets.where((e) => e.id == 'srvlogin').firstOrNull?.items ?? const <Map<String, dynamic>>[];

  void _gateOpen(String path) {
    _device.invokeMethod('App.openUrl', {'url': '${_srv.url}$path'}).catchError((_) => null);
  }

  Future<void> _gateGoogle() async {
    if (_srvLogging) return;
    _srvLogging = true;
    try {
      final ids = await _srv.googleClientIds();
      if (!mounted) return;
      if (ids.isEmpty) return toast('Masuk dengan Google belum diaktifkan di server.');
      final token = await googleIdToken(ids.first);
      if (token == null || !mounted) return;
      toast('Masuk ke server…');
      await _srv.loginGoogle(token);
      await _srvEntered();
    } on ServerFailure catch (e) {
      if (mounted) toast(e.offline ? 'Butuh internet untuk masuk' : e.message);
    } on GoogleLoginFailure catch (e) {
      if (mounted) toast(e.message);
    } finally {
      _srvLogging = false;
    }
  }

  /// Sesudah berhasil masuk dengan cara apa pun: terapkan peran dan paket, muat data, lalu sinkronkan.
  Future<void> _srvEntered() async {
    if (!mounted) return;
    _srvPass = '';
    _gateRoster = null;
    _close('srvlogin');
    _srvAdopt();
    await reloadAll();
    if (mounted) toast('Berhasil masuk · data disinkronkan');
    await _srvCycle();
  }

  Widget _gateScreen() {
    final roster = _gateRoster;
    if (roster != null) return NativeSheet(id: 'srvlogin', screen: true, actions: this, items: roster);
    final shared = _srv.sharedBound;
    return NativeLogin(
      key: const ValueKey('gate-login'),
      items: const [],
      bindings: const LoginBindings(0, 1, 0, 1),
      actions: _gateActions,
      onGoogle: _gateGoogle,
      onRegister: () => _gateOpen('/register'),
      note: _toast,
      footer: shared ? 'HP outlet · pilih nama lalu PIN' : (serverDefaultUrl.isEmpty ? 'Pakai tanpa server (APK uji)' : ''),
      onFooter: shared ? _srvOpenRoster : _srv.clearUrl,
    );
  }

  /// HP outlet: pegawai memilih nama lalu mengetik PIN. Daftar nama diambil dari server.
  Future<void> _srvOpenRoster() async {
    toast('Memuat daftar pegawai…');
    try {
      _srvRoster = await _srv.roster();
    } on ServerFailure catch (e) {
      if (!mounted) return;
      toast(e.offline ? 'Butuh internet untuk masuk' : e.message);
      _srvRoster = [];
    }
    if (!mounted) return;
    if (_srvRoster.isEmpty) return _srvOpenLogin(form: true);
    _srvPick = 0;
    _srvPass = '';
    final items = <Map<String, dynamic>>[
      {'type': 'title', 't': 'Masuk · ${_srv.sharedOutletName}', 's': ''},
      {'type': 'hint', 't': 'Pilih nama Anda, lalu ketik PIN dari pemilik.'},
      {'type': 'select', 'options': [for (final m in _srvRoster) '${m['name']} · ${m['role_label'] ?? ''}'], 'index': 0, 'i': 0},
      {'type': 'input', 'v': '', 'ph': 'PIN', 'numeric': true, 'secret': true, 'i': 1},
      {'type': 'button', 't': 'Masuk', 'primary': true, 'i': 0},
      {'type': 'button', 't': 'Masuk dengan akun lain', 'primary': false, 'i': 2},
      if (!_gate) {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1},
    ];
    if (_gate) return setState(() => _gateRoster = items);
    _open(_Sheet('srvlogin', items));
  }

  void _srvOpenLogin({bool form = false}) {
    if (!form && _srv.sharedBound) {
      _srvOpenRoster();
      return;
    }
    _srvRoster = [];
    _srvUser = '';
    _srvPass = '';
    // Layar masuk sudah memuat formulirnya sendiri.
    if (_gate) return setState(() => _gateRoster = null);
    _open(_Sheet('srvlogin', [
      {'type': 'title', 't': 'Masuk ke server', 's': ''},
      {'type': 'hint', 't': 'Pemilik: email dan password akun GOYANA. Kasir, pegawai, dan kurir: nomor HP dan PIN dari pemilik.'},
      {'type': 'input', 'v': '', 'ph': 'Email atau nomor HP', 'i': 0},
      {'type': 'input', 'v': '', 'ph': 'Password atau PIN', 'secret': true, 'i': 1},
      {'type': 'button', 't': 'Masuk', 'primary': true, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1},
    ]));
  }

  void _srvLoginEvent(String kind, int index, Object? value) {
    if (kind == 'input' && index == 0 && _srvRoster.isNotEmpty) {
      // Pilihan nama di HP outlet.
      _srvPick = value is int ? value : int.tryParse('$value') ?? 0;
      for (final it in _loginItems) {
        if (it['type'] == 'select') it['index'] = _srvPick;
      }
      return;
    }
    if (kind == 'input') {
      final text = '${value ?? ''}';
      if (index == 0) _srvUser = text;
      if (index == 1) _srvPass = text;
      // Isian disimpan di butir lembar supaya tidak kosong lagi saat layar digambar ulang.
      for (final it in _loginItems) {
        if (it['type'] == 'input' && it['i'] == index) it['v'] = text;
      }
      return;
    }
    if (kind == 'button' && index == 0) {
      _srvLogin();
      return;
    }
    _close('srvlogin');
    if (kind == 'button' && index == 2) _srvOpenLogin(form: true);
  }

  Future<void> _srvLogin() async {
    if (_srvLogging) return;
    _srvLogging = true;
    toast('Masuk ke server…');
    try {
      if (_srvRoster.isNotEmpty) {
        final who = _srvRoster[_srvPick < 0 || _srvPick >= _srvRoster.length ? 0 : _srvPick];
        await _srv.loginShared(who['id'], _srvPass, '${who['name'] ?? ''}');
      } else {
        await _srv.login(_srvUser, _srvPass);
      }
      await _srvEntered();
    } on ServerFailure catch (e) {
      if (mounted) toast(e.message);
    } finally {
      _srvLogging = false;
    }
  }

  Future<void> _srvLogout() async {
    if (!_srv.loggedIn) return toast('Akun server belum masuk di HP ini');
    await _srv.logout();
    planAccess.serverPlan = null;
    if (!mounted) return;
    setState(() {
      _kasir = 'Kasir';
      _kasirSession = false;
    });
    if (_page == 'kurirhome') nav('home');
    toast('Keluar dari akun server · data di HP ini tetap ada');
  }

  // ---------- Reminder Pekerjaan: notifikasi HP dijadwalkan dari data pesanan & stok ----------
  static const remindersKey = 'goyana-reminders203';
  Timer? _remTimer;

  /// Jadwalkan ulang pengingat (ditunda sebentar supaya beberapa perubahan beruntun cukup sekali).
  @override
  void syncReminders() {
    _remTimer?.cancel();
    _remTimer = Timer(const Duration(seconds: 2), _doSyncReminders);
  }

  Future<void> _doSyncReminders() async {
    final b = _b, st = _settings;
    if (!mounted || b == null || st == null) return;
    try {
      final stock = _stock ?? await StockBook.load(widget.store);
      final list = buildReminders(b: b, stock: stock, on: (i) => tplToggle(st, 'reminder', i), now: now);
      Map prev = const {};
      try {
        final v = jsonDecode(await widget.store.get(remindersKey) ?? '{}');
        if (v is Map) prev = v;
      } catch (_) {}
      final (cancel, add, next) = diffReminders(prev, list);
      if (cancel.isEmpty && add.isEmpty) return;
      if (add.isNotEmpty && st.raw['notifAsked203'] != true) {
        // Android 13+: izin notifikasi diminta sekali, saat pertama kali ada pengingat.
        st.raw['notifAsked203'] = true;
        await st.save();
        await _device.invokeMethod<dynamic>('LocalNotifications.requestPermissions');
      }
      if (cancel.isNotEmpty) await _device.invokeMethod<dynamic>('LocalNotifications.cancel', {'notifications': [for (final id in cancel) {'id': id}]});
      if (add.isNotEmpty) {
        await _device.invokeMethod<dynamic>('LocalNotifications.schedule', {
          'notifications': [for (final r in add) {'id': r.id, 'title': r.title, 'body': r.body, 'schedule': {'at': r.at.millisecondsSinceEpoch}}],
        });
      }
      await widget.store.set(remindersKey, jsonEncode(next));
    } catch (_) {
      // Tanpa perangkat (tes) atau izin ditolak: pengingat tetap tampil di halaman Reminder.
    }
  }

  // ---------- HPP bahan v182: pemakaian otomatis saat produksi, pembelian lunas → kas, laporan ----------
  StockBook? _stock;
  bool _hppBusy = false;

  Future<void> _hppSync() async {
    final b = _b;
    if (b == null || _hppBusy) return;
    _hppBusy = true;
    try {
      final s = await StockBook.load(widget.store);
      final r = reconcileHpp(b, s, now);
      final cash = syncPurchaseCash(b, s, now);
      if (r.stock || cash) await s.save();
      if (r.orders || cash) await b.save();
      _stock = s;
      if (!mounted) return;
      if (r.consumed > 0) toast('HPP bahan tercatat saat produksi dimulai · ${r.consumed} mutasi');
    } catch (_) {
    } finally {
      _hppBusy = false;
    }
  }

  Object? _reportExtra(String id, RepCtx ctx, RepRange r) {
    final s = _stock;
    if (s == null) return const <String, dynamic>{'k': <dynamic>[], 'cols': <dynamic>[], 'rows': <dynamic>[], 'raw': 1, 'empty': 'Belum ada pemakaian otomatis.'};
    String money(num n) => rp(n.round());
    if (id == 'hpp182') {
      final a = hppRows(s, r.s, r.e, _rpOutlet == '*' || _rpOutlet.isEmpty ? null : _rpOutlet);
      final v = a.fold<double>(0, (q, x) => q + (x[3] as double));
      return {
        'k': [['Total HPP', money(v), '${a.length} bahan', 'w']],
        'cols': ['Bahan', 'Terpakai Bersih', 'Biaya'],
        'rows': [for (final x in a) [x[0], '${qtyText(x[2] as double)} ${x[1]}', money(x[3] as double)]],
        'raw': 1, 'pv': v.round(), 'empty': 'Belum ada pemakaian otomatis.',
      };
    }
    final rev = ctx.ords(r).fold<num>(0, (a, o) => a + o.total), cost = hppTotal(s, r.s, r.e, _rpOutlet == '*' || _rpOutlet.isEmpty ? null : _rpOutlet);
    final ops = ctx.exps(r).where((x) => !RegExp('Bahan Baku', caseSensitive: false).hasMatch(x.cat)).fold<num>(0, (a, x) => a + x.a);
    final profit = rev - cost - ops;
    return {
      'k': [
        ['Laba operasional', money(profit), rev != 0 ? 'Margin ${(profit / rev * 100).round()}%' : '', 'w'],
        ['Omzet', money(rev), '', 'g'], ['HPP', money(cost), '', 'r'], ['Biaya operasional', money(ops), '', 'r'],
      ],
      'cols': ['Pos', '', 'Nominal'],
      'rows': [['Omzet', '', money(rev)], ['HPP bahan', '', money(-cost)], ['Biaya operasional', '', money(-ops)], ['<b>Laba operasional</b>', '', '<b>${money(profit)}</b>']],
      'raw': 1, 'pv': profit.round(),
    };
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
  Map<String, dynamic>? debugMirror(String id) => _sheets.where((e) => e.id == id).firstOrNull?.mirror;
  @visibleForTesting
  List<String> debugDiscOptions() => [for (final d in _discs) d[0]];
  @visibleForTesting
  String get debugToast => _toast;
  @visibleForTesting
  Map<String, dynamic> debugAddOrder() => _addOrderJson();

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
      {'type': 'buttons', 'cols': 5, 'options': [for (var k = 0; k < icons.length; k++) opt(icons[k], serviceIconSvg(icons[k], 30), k == _catIcon, k)]},
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
    // Akun kurir hanya punya Jemput, Antar, Setoran (plus Tambah Transaksi di lokasi dan Pengaturan untuk keluar akun).
    if (_courierMode && const {'home', 'orders', 'customers', 'reports', 'rp'}.contains(pageId)) pageId = 'kurirhome';
    final gate = pageGates[pageId];
    if (gate != null && !planAccess.has(gate, now)) return toast(planAccess.lockedText(gate));
    final denied = _srvDenied(pageId);
    if (denied != null) return toast(denied);
    if (_kasirSession && const {'cashier', 'employees', 'pinlock'}.contains(pageId)) return toast('Hanya pemilik · buka aplikasi dengan PIN Admin');
    if (_page == 'crm') _loadCrmRule();
    if (_page == 'stock') _hppSync();
    setState(() {
      _sheets.clear();
      _pageSheets.clear();
      _detailId = null;
      _payOrderId = null;
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
    // Nomor nota lama (GY-YYMMDD-NNNN) dan baru (KODE-YYMMDD-HP-NNNN).
    final m = RegExp(r'[A-Z]{2,4}-\d{6}-(?:[A-Z0-9]{1,6}-)?\d+').firstMatch(code);
    final id = m?.group(0) ?? code.trim();
    if (_b!.orderById(id) == null) return toast('Pesanan $id tidak ditemukan');
    nav('orders');
    _showDetail(id);
  }

  // ---------------- Beranda ----------------
  @override
  void slide(int index) => nav(const ['whatsappbot', 'superbilling', 'crm'][index.clamp(0, 2)]);
  @override
  void tile(int index) {
    // Ikon Beranda (sama dengan HTML): 0 Tambah Transaksi, 1 Antar Jemput, 2 Kurir, 3 Pelanggan, 4 Hari Ini, 5 Chatbot.
    switch (index) {
      case 0:
        _startOrder();
      case 1:
        nav('jemput202');
      case 3:
        nav('customers');
      case 2:
        nav('couriers');
      case 4:
        nav('today');
      case 5:
        nav('whatsappbot');
      default:
        toast('Menu ini sedang dipindahkan ke mode murni');
    }
  }

  @override
  void manageOutlet() => nav('superbilling');
  @override
  void qr() => _open(_Sheet('qr160-menu', [
        {'type': 'title', 't': 'QR', 's': ''},
        {'type': 'button', 't': 'Scan Struk', 'primary': false, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Cari Pesanan', 'primary': false, 'file': '', 'after': false, 'i': 1},
        {'type': 'button', 't': 'Buat Label Barcode', 'primary': false, 'file': '', 'after': false, 'i': 2},
        {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 3},
      ]));
  @override
  void monthly() => nav('reports');

  // ---------------- Pengaturan (menu sama persis dengan HTML) ----------------
  final Set<int> _stOpen = {};
  Map<String, dynamic> _settingsJson() {
    final m = jsonDecode(settingsMenuJson) as Map<String, dynamic>;
    // Kartu sinkronisasi: tanpa alamat server tampil seperti semula ("Belum terhubung").
    final card = _srv.card();
    if (card != null) m['sync'] = card;
    // Permintaan Koiman (7 Okt): 4 menu WhatsApp yang berdiri sendiri digabung jadi satu kategori "WhatsApp Chatbot"
    // dengan ikon berwarna; salinannya di grup Pelanggan dibuang supaya Pengaturan tidak kepanjangan.
    final groups = m['groups'] as List;
    final at = groups.indexWhere((g) => g is Map && g['i'] == 5);
    groups.removeWhere((g) => g is Map && const [5, 6, 7, 8].contains(g['i']));
    groups.insert(at < 0 ? groups.length : at, {
      'i': 5,
      'svg': '<svg viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><path d="M8 10h32a4 4 0 0 1 4 4v18a4 4 0 0 1-4 4H22l-9 8v-8H8a4 4 0 0 1-4-4V14a4 4 0 0 1 4-4Z" fill="#2fbf71"></path>'
          '<rect x="14" y="16" width="20" height="14" rx="4" fill="#ffffff"></rect><circle cx="20" cy="22" r="2.2" fill="#1f6f4a"></circle><circle cx="28" cy="22" r="2.2" fill="#1f6f4a"></circle>'
          '<path d="M20 26.5h8" stroke="#1f6f4a" stroke-width="2" stroke-linecap="round"></path><path d="M24 16v-5" stroke="#ffcf70" stroke-width="2.5" stroke-linecap="round"></path>'
          '<circle cx="24" cy="9" r="2.5" fill="#ffcf70"></circle></svg>',
      'icon': '', 't': 'WhatsApp Chatbot', 's': 'Perangkat, balasan otomatis, AI dan promo', 'accordion': true, 'open': false,
      'items': [
        {'j': 0, 'icon': '📱', 't': 'Hubungkan WhatsApp', 'badge': '', 's': 'Tambah perangkat dan pilih cabang WhatsApp'},
        {'j': 1, 'icon': '⚡', 't': 'Balasan Cepat & Trigger', 'badge': '', 's': 'Atur kata pemicu, teks dan gambar balasan'},
        {'j': 2, 'icon': '🤖', 't': 'Chatbot AI', 'badge': '', 's': 'Atur asisten dan pengetahuan laundry'},
        {'j': 3, 'icon': '📣', 't': 'WhatsApp Blast', 'badge': '', 's': 'Buat promo dan pilih penerima'},
        {'j': 4, 'icon': '💬', 't': 'Otomasi Pelanggan', 'badge': planAccess.has('ai', now) ? '' : '🔒 Chatbot', 's': 'Pesan selesai dan reminder otomatis'},
      ],
    });
    for (final g in groups.whereType<Map>()) {
      if (g['i'] == 4) (g['items'] as List).removeWhere((it) => it is Map && (it['j'] as num) >= 2);
      // Satu menu Kurir saja (10 Okt): "Pengaturan Kurir" terpisah dobel dengan tab di halaman Kurir.
      if (g['i'] == 3) {
        for (final it in (g['items'] as List).whereType<Map>()) {
          if (it['j'] == 3) {
            it['t'] = 'Kurir';
            it['s'] = 'Tugas antar-jemput, akun & PIN kurir';
          }
        }
      }
      // "Stock Opname & Supplier" membuka halaman yang sama dengan "Stok & Bahan" → cukup satu menu.
      if (g['i'] == 9) (g['items'] as List).removeWhere((it) => it is Map && it['j'] == 7);
    }
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
    '3/0': 'employees', '3/1': 'cashier', '3/2': 'audit', '3/3': 'couriers', '3/4': 'kurirsetting',
    '4/0': 'customers', '4/1': 'crm',
    '5/0': 'wadevices195', '5/1': 'triggers191', '5/2': 'ai191', '5/3': 'blast191', '5/4': 'automation',
    '9/0': 'qris', '9/1': 'finance', '9/2': 'ralat139', '9/3': 'stock', '9/4': 'reminder', '9/5': 'reports', '9/6': 'sheet:deposits178', '9/7': 'stock',
    '10/0': 'printer', '10/1': 'barcode', '11': 'datacenter', '13': 'testmode192', '12/0': 'helpcenter', '12/1': 'aboutgoyana', '12/2': 'sheet:perm178',
  };
  void _stGo(String key) {
    final r = _stRoutes[key];
    if (r == null) return toast('Halaman ini sedang dipindahkan');
    // Kunci paket khusus menu WhatsApp/Chatbot (sama dengan HTML): grup Chatbot butuh paket AI, lainnya sesuai fiturnya.
    if (key == '5/4' && !planAccess.has('ai', now)) return _lockSheet('Otomasi Pelanggan');
    final need = const {'5/0': 'wa', '5/1': 'quick', '5/2': 'ai', '5/3': 'blast'}[key];
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
  void stSyncUrl(String url) => _srvUrlDraft = url;
  @override
  void stSyncSave() {
    _srvSaveUrl();
  }

  @override
  void stSyncNow() {
    if (!_srv.loggedIn) return toast('Masuk ke server dulu');
    toast('Menyinkronkan…');
    _srvCycle();
  }

  @override
  void stAcctGo() => nav('upgrade');
  @override
  void stAcctAction(int index) => nav('upgrade');
  @override
  void stAcctLink() => nav('upgrade');
  @override
  void stLogout() {
    _srvLogout();
  }

  @override
  void stTutorial() => nav('helpcenter');

  // ---------------- Cetak struk ----------------
  Future<void> _print(Order o) => _printRaw(receiptText(o, _settings!.receipt, printedAt: now), o.id, 'Struk dicetak');

  @override
  Future<void> printText(String text, String title, String done) => _printRaw(text, title, done);
  @override
  void scanCode() => scan();
  @override
  Future<void> reloadAll() async {
    final r = await Future.wait([Business.load(widget.store), AppSettings.load(widget.store)]);
    await planAccess.load(widget.store, now);
    await loadTransport(widget.store);
    if (!mounted) return;
    setState(() {
      _b = r[0] as Business;
      _settings = r[1] as AppSettings;
      _detailId = null;
      _sheets.clear();
    });
    _loadCrmRule();
    _hppSync();
  }
  /// Penjemputan → Buat Pesanan (keputusan Paduka 9 Oktober 2026): Tambah Transaksi yang sama persis (durasi, layanan,
  /// Atur Pesanan, Pembayaran) untuk pesanan Penjemputan ini, tanpa pilihan Penyerahan (selalu Jemput & Antar).
  /// Hasilnya mengisi pesanan yang sama (nomor nota tetap) lalu masuk Antrian.
  String _fillId = '', _fillFrom = '';
  /// Penjemputan belum punya penjemput (kurir atau "Saya sendiri"): proses tidak bisa dilanjutkan (keputusan Paduka 10 Okt).
  /// HP kurir dikecualikan: kurirnya sendiri yang menjemput.
  bool _noPicker(Order o) => !_courierMode && '${o.dataset['courier181'] ?? ''}'.isEmpty && '${o.dataset['jemputSelf'] ?? ''}'.isEmpty;

  @override
  void weighOrder(String id) {
    final o = _b!.orderById(id);
    // Juga cucian yang sudah dijemput kurir tanpa ditimbang (hak timbang dimatikan pemilik): kasir menimbangnya di outlet.
    final unweighed = !_courierMode && o != null && o.status == 'antrian' && o.items.isEmpty;
    if (o == null || (o.status != 'jemput' && !unweighed)) return;
    if (!unweighed && _noPicker(o)) return toast('Pilih kurir dulu');
    final from = _page;
    _startOrder();
    _fillId = id;
    _fillFrom = from;
    _opt['note'] = o.note == '-' ? '' : o.note;
    if (_courierMode) {
      // Kurir memakai durasi pesanan (harga dicek server menurut durasi itu), langsung ke daftar layanan.
      _aoCustomer = o.name;
      setState(() {
        _aoDur = o.dur.isEmpty ? 'Reguler' : o.dur;
        _aoStage = 'services';
      });
      return;
    }
    _aoPickName(o.name);
  }

  @override
  void payOrder(String id) {
    openOrder(id);
    final o = _b!.orderById(id);
    if (o != null && !o.isCancelled && o.remaining > 0) {
      setState(() {
        _handoverId = null;
        _payOrderId = id;
      });
    }
  }

  @override
  Future<void> printDoc({required String html, required String text, required String title, required String done}) => _printRaw(text, title, done, html: html);

  Future<void> _printRaw(String text, String title, String done, {String? html}) async {
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
      await _device.invokeMethod('Print.html', {'html': html ?? '<pre style="font:12px monospace">$esc</pre>', 'title': title});
      if (html != null) toast(done);
    } catch (_) {
      toast('Atur printer di Pengaturan → Printer Bluetooth');
    }
  }
  @override
  void helpChat() {
    final o = _b!.outlets;
    final name = (o.where((x) => x.id == _b!.activeOutlet).firstOrNull ?? o.firstOrNull)?.name ?? 'Outlet';
    _device.invokeMethod('App.openUrl', {'url': 'https://wa.me/${HelpCenterPage.supportWa}?text=${Uri.encodeComponent('Halo tim GOYANA, saya butuh bantuan. Outlet: $name. Kendala: ')}'}).catchError((_) => null);
    toast('Membuka WhatsApp CS GOYANA…');
  }

  // ---------------- Pesanan ----------------
  @override
  void autoSettings() => _open(_Sheet('au133s', _autoItems()));

  List<Map<String, dynamic>> _autoItems() {
    final a = _auto;
    final step = a['step'] as Map? ?? const {};
    return [
      {'type': 'title', 't': 'Aturan Status Otomatis'},
      {'type': 'hint', 't': 'Pesanan berpindah status sendiri sesuai waktu. Kasir tetap bisa ubah manual kapan saja.'},
      {'type': 'steps', 'steps': [{'n': '1', 't': 'Antrian', 'on': true}, {'n': '2', 't': 'Proses', 'on': true}, {'n': '3', 't': 'Siap Ambil (manual)', 'on': false}]},
      {'type': 'toggle', 't': 'Antrian → Proses otomatis', 's': 'Setelah pesanan masuk antrian selama', 'on': a['q'] != false, 'i': 0},
      if (a['q'] != false) ...[
        {'type': 'input', 'v': '${a['qv'] ?? 1}', 'ph': '1', 'numeric': true, 'i': 0},
        {'type': 'select', 'options': const ['jam', 'menit'], 'index': '${a['qu'] ?? 60}' == '1' ? 1 : 0, 'i': 1},
      ],
      {'type': 'toggle', 't': 'Tahap proses berjalan otomatis', 's': 'Cuci → Kering → Setrika → Packing (menit per tahap)', 'on': a['p'] == true, 'i': 1},
      if (a['p'] == true)
        for (final (k, e) in const [['cuci', 'Cuci', 60], ['kering', 'Kering', 90], ['setrika', 'Setrika', 60], ['packing', 'Packing', 20]].indexed)
          {'type': 'input', 'label': '${e[1]}', 'suf': 'menit', 'v': '${step[e[0]] ?? e[2]}', 'numeric': true, 'i': 2 + k},
      {'type': 'hint', 't': '🔒 Siap Ambil selalu manual oleh kasir atau owner, supaya notifikasi "cucian siap" ke pelanggan hanya terkirim kalau cucian benar-benar sudah beres.'},
      {'type': 'button', 't': 'Selesai', 'primary': true, 'i': 0},
    ];
  }

  void _autoEvent(String kind, int index, Object? value) {
    if (kind == 'close' || kind == 'button') return _close('au133s');
    final a = _auto;
    if (kind == 'toggle') a[index == 0 ? 'q' : 'p'] = index == 0 ? a['q'] == false : a['p'] != true;
    if (kind == 'input') {
      if (index == 0) a['qv'] = (int.tryParse('${value ?? ''}'.replaceAll(RegExp(r'\D'), '')) ?? 1).clamp(1, 9999);
      if (index == 1) a['qu'] = (value is num ? value.toInt() : int.tryParse('$value') ?? 0) == 1 ? 1 : 60;
      if (index >= 2 && index <= 5) {
        final st = Map<String, dynamic>.from(a['step'] as Map? ?? const {});
        st[const ['cuci', 'kering', 'setrika', 'packing'][index - 2]] = (int.tryParse('${value ?? ''}'.replaceAll(RegExp(r'\D'), '')) ?? 1).clamp(1, 9999);
        a['step'] = st;
      }
    }
    _settings!.raw['auto133'] = a;
    _settings!.save();
    if (kind != 'input' || index == 1) {
      _open(_Sheet('au133s', _autoItems()));
      if (kind == 'toggle') toast('Aturan status otomatis tersimpan');
    }
    _applyAuto();
  }
  @override
  void addOrder() => _startOrder();
  @override
  void search(String text) => setState(() => _search = text);
  @override
  void tab(int index) => setState(() {
        final shown = _shownTabs;
        _tab = index >= 0 && index < shown.length ? shown[index] : index;
        _search = '';
      });

  /// Tab Pesanan yang tampil (HTML v109: Penjemputan/Diantar disembunyikan bila layanan jemput/antar dimatikan).
  List<int> get _shownTabs => [
        for (var k = 0; k < orderTabs.length; k++)
          if (!(k == 0 && !deliveryJemput(_settings!.raw)) && !(k == 4 && !deliveryAntar(_settings!.raw))) k,
      ];

  Map<String, dynamic> _ordersModel(Business b, DateTime n) {
    final shown = _shownTabs;
    if (!shown.contains(_tab)) _tab = 1;
    final m = ordersJson(b, tab: _tab, search: _search, now: n, auto: _auto);
    final tabs = m['tabs'] as List;
    m['tabs'] = [for (final k in shown) tabs[k]];
    if (_srv.loggedIn) _stageCards(b, m);
    return m;
  }
  /// Akun kurir di server: tampilannya hanya Jemput, Antar, Setoran.
  bool get _courierMode => _srv.loggedIn && _srv.role == 'kurir';

  /// Cucian yang ditimbang kurir di lokasi: kasir memastikan timbangannya di outlet sebelum memproses.
  /// Mengembalikan true bila popup "Cek Timbangan" ditampilkan (tombol tahap menunggu jawabannya).
  bool _weighCheck(Order o) {
    if ('${o.dataset['timbang'] ?? ''}' != 'cek' || o.status == 'jemput' || _courierMode || _stageMode) return false;
    final by = '${o.dataset['timbangBy'] ?? ''}';
    final lines = [for (final it in o.items) '${it.name} ${qtyText(it.qty)} ${it.unit}'].join(', ');
    openFormSheet(FormSheetDef(
      'Cek Timbangan',
      const [],
      'Timbangan Sesuai',
      (_) {
        o.dataset['timbang'] = 'ok';
        addAudit(this, '⚖', 'Timbangan dicek', '$_kasir · ${o.id} · kurir ${by.isEmpty ? '-' : by}');
        _next(o);
        return true;
      },
      sub: 'Ditimbang kurir${by.isEmpty ? '' : ' $by'} di lokasi: $lines. Timbang ulang di outlet. Bila berbeda, tutup popup ini lalu perbaiki lewat Edit di rincian pesanan.',
    ));
    return true;
  }

  /// Akun pegawai (peran Pegawai di server): hanya memajukan tahap cucian, satu per satu, sampai Selesai Proses.
  bool get _stageMode => _srv.loggedIn && _srv.role == 'produksi';

  /// Akun yang masuk ke server: kartu Pesanan menyebut tahapnya; untuk pegawai tombolnya memajukan satu tahap.
  void _stageCards(Business b, Map<String, dynamic> m) {
    final staff = _stageMode;
    for (final c in (m['cards'] as List? ?? const []).whereType<Map>()) {
      final st = '${c['st']}';
      final name = stageName[st];
      if (name != null && c['status'] is Map) c['status'] = Map<String, String>.from(c['status'] as Map)..['t'] = name;
      if (!staff || c['action'] is! Map) continue;
      final o = b.orderById('${c['id']}');
      final next = o == null ? null : b.nextStage(o);
      final String text;
      if (next != null) {
        text = next == doneStage ? 'Selesai Proses ›' : '${stageName[next]} ›';
      } else {
        text = st == doneStage ? 'Menunggu kasir' : const {'jemput': 'Dijemput kurir', 'diambil': 'Selesai ✓', 'batal': 'Dibatalkan'}[st] ?? 'Tugas kasir';
      }
      final action = Map<String, String>.from(c['action'] as Map)..['t'] = text;
      if (next == null) {
        action['bg'] = 'rgb(241, 242, 245)';
        action['c'] = 'rgb(154, 160, 172)';
      }
      c['action'] = action;
    }
  }

  /// Pegawai memajukan satu tahap. Mengembalikan true bila tombol sudah ditangani di sini.
  bool _stageNext(Order o) {
    if (!_stageMode) return false;
    final before = o.status;
    final n = _b!.advanceStage(o, now: now, by: _kasir);
    if (n == null) {
      toast(before == doneStage ? 'Sudah Selesai Proses · menunggu kasir menandai Siap Ambil' : 'Tahap ini dikerjakan kasir');
      return true;
    }
    _save();
    toast(n == doneStage ? 'Selesai Proses ✓ · kasir akan menandai Siap Ambil' : 'Masuk tahap ${stageName[n]}');
    _refreshDetail();
    return true;
  }

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

  /// Pesanan yang sedang diserahkan (Diantar/Diambil) dan menunggu keputusan bayar di lembar Pembayaran.
  String? _handoverId;
  String _handoverBy = '';
  bool get _handing => _handoverId != null && _handoverId == _payOrderId;

  /// Serah terima pesanan yang belum lunas (revisi Koiman): tampilkan Pembayaran dulu, dengan pilihan "Hutang Dulu".
  /// Mengembalikan true bila lembar Pembayaran dibuka (status belum diubah).
  bool _askHandoverPay(Order o, String by) {
    final st = o.status;
    if (o.isCancelled || o.remaining <= 0 || !(st == 'siap' || st == 'telat' || st == 'diantar')) return false;
    setState(() {
      _handoverId = o.id;
      _handoverBy = by;
      _payOrderId = o.id;
    });
    return true;
  }

  /// Selesaikan serah terima tanpa pelunasan: status maju, sisa tagihan tetap tercatat di Belum Bayar.
  void _handoverDebt(Order o) {
    final by = _handoverBy.isEmpty ? _kasir : _handoverBy;
    setState(() {
      _payOrderId = null;
      _handoverId = null;
      _sheets.removeWhere((s) => const {'cash', 'dp', 'confirm'}.contains(s.id));
    });
    o.dataset['hutang203'] = '1';
    _b!.advance(o, now: now, by: by);
    addAudit(this, '⏳', 'Hutang dulu', '$by · ${o.id} · sisa ${rp(o.remaining)}');
    saveAll();
    toast('Hutang dulu · sisa ${rp(o.remaining)} masuk Belum Bayar');
    _refreshDetail();
  }

  @override
  void advanceOrder(String id, {String? by}) {
    final o = _b!.orderById(id);
    if (o == null) return;
    if (_pickupNeedsOrder(o)) return;
    if (_stageNext(o)) return refresh();
    if (_weighCheck(o)) return;
    if (_askHandoverPay(o, by ?? _kasir)) return;
    _b!.advance(o, now: now, by: by ?? _kasir);
    saveAll();
    refresh();
  }

  /// Penjemputan tanpa layanan/berat tidak boleh langsung masuk Antrian (Rp0): buka Buat Pesanan (Tambah Transaksi) dulu.
  bool _pickupNeedsOrder(Order o) {
    if (!_courierMode && o.status == 'antrian' && o.items.isEmpty) {
      setState(() => _detailId = null);
      weighOrder(o.id);
      toast('Timbang dulu cucian dari kurir');
      return true;
    }
    if (o.status != 'jemput') return false;
    if (_noPicker(o)) {
      toast('Pilih kurir dulu · lewat Antar Jemput (menu titik tiga) atau Tugas Kurir');
      return true;
    }
    if (o.items.isNotEmpty) return false;
    setState(() => _detailId = null);
    weighOrder(o.id);
    return true;
  }

  void _next(Order o) {
    if (_pickupNeedsOrder(o)) return;
    if (_stageNext(o)) return;
    if (_weighCheck(o)) return;
    if (_askHandoverPay(o, _kasir)) return;
    final n = _b!.advance(o, now: now, by: _kasir);
    if (n == null) return;
    _save();
    toast(const {
          'antrian': 'Cucian sudah dijemput · masuk antrian', 'cuci': 'Pesanan masuk Proses', 'siap': 'Siap Ambil ✓ · kabari pelanggan lewat WA (opsional)',
          'diantar': 'Kurir mengantar pesanan', 'diambil': 'Pesanan selesai · sudah diambil pelanggan',
        }[n] ??
        'Status diperbarui');
    _refreshDetail();
  }

  /// Rincian Pesanan (NativeOrderDetail, sama dengan hybrid). [banner] = baru saja disimpan:
  /// kotak "Pesanan tersimpan" tampil 6 detik seperti HTML v142.
  void _showDetail(String id, {bool banner = false}) {
    if (_b!.orderById(id) == null) return;
    _odTimer?.cancel();
    setState(() {
      _detailId = id;
      _odBanner = banner;
    });
    if (banner) {
      _odTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _odBanner = false);
      });
    }
  }

  void _refreshDetail() => setState(() {});

  @visibleForTesting
  bool get debugHanding => _handing;
  /// Ringkasan keadaan layar (untuk tes audit tombol): halaman, toast, popup yang terbuka.
  @visibleForTesting
  String debugState() => '$_page|$_toast|${_sheets.map((e) => e.id).join(',')}|${_pageSheets.join(',')}|$_detailId|$_payOrderId|$_aoSheet|$_aoStage|${_stOpen.join(',')}';
  @visibleForTesting
  List<String> debugSheetIds() => [..._sheets.map((e) => e.id), ..._pageSheets];
  @visibleForTesting
  Iterable<String> debugPageIds() => _pages.keys;
  @visibleForTesting
  Map<String, dynamic> debugSettingsMenu() {
    final keep = {..._stOpen};
    _stOpen.addAll([for (var i = 0; i < 20; i++) i]);
    final m = _settingsJson();
    _stOpen
      ..clear()
      ..addAll(keep);
    return m;
  }
  @visibleForTesting
  PurePage? debugPage(String id) => _pages[id];
  @visibleForTesting
  Map<String, dynamic> debugOrders() => _ordersModel(_b!, now);
  @visibleForTesting
  Map<String, dynamic>? debugDetail() {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    return o == null ? null : orderDetailOd(_b!, o, banner: _odBanner, detailed: _srv.loggedIn, staff: _stageMode);
  }

  @override
  void odClose() {
    _odTimer?.cancel();
    setState(() {
      _detailId = null;
      _odBanner = false;
      _payOrderId = null;
    });
  }

  @override
  void odTap(int index) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o != null) _openPhotos(o);
  }

  /// Tombol rincian memakai indeks HTML (tanpa banner, indeks ≥ 3 turun satu).
  @override
  void odButton(int index) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null) return;
    final k = _odBanner || index < 3 ? index : index + 1;
    switch (k) {
      case 1:
        _open(_Sheet('act115', orderMenuItems()));
      case 2:
        odClose();
      case 3:
        _openLabel(o);
      case 4:
      case 5:
        _openStruk(o);
      case 7:
        _openEdit(o);
      case 8:
        if (o.isCancelled || o.status == 'diambil') return;
        _next(o);
      case 9:
        _openNotaKind(o);
      case 12:
        if (o.isCancelled) return toast('Pesanan sudah dibatalkan');
        if (o.remaining <= 0) return toast('Pesanan sudah lunas');
        setState(() {
          _handoverId = null;
          _payOrderId = o.id;
        });
    }
  }

  void _menuEvent(String kind, int index) {
    _close('act115');
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null || kind != 'button') return;
    switch (index) {
      case 0:
        _openPhotos(o);
      case 1:
        if (o.isCancelled) return toast('Pesanan sudah dibatalkan');
        _openEdit(o);
      case 2:
        _openHistory(o);
      case 3:
        _openLabel(o);
      case 4:
        if (o.paid <= 0) return toast('Pesanan ini belum ada pembayaran untuk diralat');
        odClose();
        nav('ralat139');
      case 5:
        if (o.isCancelled || o.status == 'diambil') return toast(o.isCancelled ? 'Pesanan sudah dibatalkan' : 'Pesanan sudah diambil');
        _openCancel(o);
    }
  }

  /// Label kantong: halaman Cetak Label Cucian (HTML printlabel) dengan pesanan ini terpilih.
  void _openLabel(Order o) {
    (_pages['printlabel'] as LabelPage).select(o);
    nav('printlabel');
  }

  void _openPhotos(Order o) => _open(_Sheet('photo115', const [], mirror: orderPhotoMirror(o)));

  Future<void> _addPhoto(Order o, String slot) async {
    try {
      final uris = await _device.invokeListMethod<String>('Files.pick', {'accept': ['image/png', 'image/jpeg', 'image/webp'], 'multiple': false, 'capture': true});
      if (uris == null || uris.isEmpty) return;
      final f = await _device.invokeMapMethod<String, dynamic>('Files.read', {'uri': uris.first});
      final data = '${f?['data'] ?? ''}';
      if (data.isEmpty) return;
      final ph = o.detail.putIfAbsent('photos', () => <String, dynamic>{'in': <dynamic>[], 'out': <dynamic>[]}) as Map;
      (ph.putIfAbsent(slot, () => <dynamic>[]) as List).add(data.startsWith('data:') ? data : 'data:${f?['mime'] ?? 'image/jpeg'};base64,$data');
      await _save();
      if (mounted) _openPhotos(o);
      toast('Foto tersimpan');
    } catch (_) {
      toast('Kamera tidak tersedia');
    }
  }

  // ---------- Struk Pesanan (HTML rc106): gambar struk + Kirim WA / Cetak / Simpan / Bagikan ----------
  Uint8List? _strukPng;
  /// Aturan cucian tidak diambil (CRM) yang ikut dicetak di nota; kosong bila dimatikan.
  String _crmRule = '';
  CrmState? _crm;
  Timer? _pointTimer;
  void _loadCrmRule() => CrmStore(widget.store).load().then((st) {
        _crm = st;
        return _crmRule = st.printRule ? st.ruleText : '';
      }).catchError((_) => '');

  /// Poin member pelanggan (dari pesanan yang sudah dibayar), sama dengan hitungan halaman CRM.
  int _points(String name) => _crm == null ? 0 : (crmFromBusiness(_b!.raw, _crm!, now).members[name] ?? 0);

  /// HTML v130: sesudah pembayaran, tampilkan tambahan poin member (muncul 1,4 detik kemudian).
  void _pointsToast(String name, int before) {
    final total = _points(name), add = total - before;
    if (add <= 0) return;
    _pointTimer?.cancel();
    _pointTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) toast('+$add poin untuk $name · total ⭐ $total');
    });
  }

  /// Outlet aktif; bila tidak ketemu, outlet pertama.
  Outlet? get _outletNow => _b!.outlets.where((x) => x.id == _b!.activeOutlet).firstOrNull ?? _b!.outlets.firstOrNull;

  /// Gambar struk pesanan (kepala outlet aktif).
  Future<Uint8List> _receiptPngOf(Order o) {
    final out = _outletNow;
    return receiptPng(ReceiptData.of(o, outlet: out?.name ?? 'GOYANA', address: out?.address ?? '', wa: out?.phone ?? '', phone: _phoneOf(o), kasir: _kasir, barcode: tplToggle(_settings!, 'barcode', 2)));
  }

  Future<void> _openStruk(Order o) async {
    try {
      final png = await _receiptPngOf(o);
      if (!mounted) return;
      _strukPng = png;
      _open(_Sheet('rc106', [
        {'type': 'title', 't': 'Struk Pesanan', 's': ''},
        {'type': 'hint', 't': '${o.id} · ${o.name} · ${rpSpaced(o.total)}'},
        {'type': 'image', 'src': 'data:image/png;base64,${base64Encode(png)}', 'svg': '', 'mark': '', 't': '', 's': '', 'w': 300},
        {'type': 'button', 't': 'Kirim WA', 'primary': true, 'i': 1},
        {'type': 'buttons', 'cols': 3, 'options': [
          {'t': 'Cetak', 'on': false, 'i': 2}, {'t': 'Simpan Gambar', 'on': false, 'i': 3}, {'t': 'Bagikan', 'on': false, 'i': 4},
        ]},
      ]));
    } catch (_) {
      toast('Struk tidak dapat dibuat');
    }
  }

  Future<void> _strukEvent(String kind, int index) async {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    final png = _strukPng;
    if (kind != 'button' || o == null || png == null) return _close('rc106');
    final name = 'struk-${o.id}.png';
    switch (index) {
      case 1:
        _close('rc106');
        _openNotaKind(o);
      case 2:
        _print(o);
      case 3:
        try {
          await _device.invokeMethod<dynamic>('Files.save', {'name': name, 'mime': 'image/png', 'data': base64Encode(png)});
          toast('Struk tersimpan sebagai gambar');
        } catch (_) {
          toast('Gagal menyimpan gambar');
        }
      case 4:
        try {
          await _device.invokeMethod('Files.share', {'title': 'Struk ${o.id}', 'files': [{'name': name, 'mime': 'image/png', 'data': base64Encode(png)}]});
        } catch (_) {
          toast('Gagal membagikan gambar');
        }
    }
  }

  /// Teks nota WhatsApp (format HTML waNota131). Footer dari Profil Nota; bila kosong, 5 baris bawaan HTML.
  String _notaWa(Order o) {
    final out = _outletNow;
    final foot = _settings!.receipt.footer.split('\n').where((l) => l.trim().isNotEmpty && !RegExp('^-?\\s*terima kasih', caseSensitive: false).hasMatch(l.trim())).join('\n');
    return orderNotaWa(o, outlet: out?.name ?? 'GOYANA', address: out?.address ?? '', phone: out?.phone ?? '', kasir: _kasir,
        footer: [
          foot.isNotEmpty
              ? foot
              : '- Harap membawa nota ini saat mengambil pakaian\n- Pisahkan pakaian luntur dan tidak luntur\n- Kelunturan di mesin cuci bukan tanggung jawab kami\n- Sprei, selimut, sepatu & bed cover dihitung satuan\n- Kiloan minimal 2 kg',
          if (_crmRule.isNotEmpty) '- $_crmRule',
        ].join('\n'));
  }

  void _openNota(Order o) => _open(_Sheet('wa131', const [], mirror: orderNotaMirror(o, _notaWa(o))));

  /// Kirim WA: pilih jenis nota dulu (revisi Koiman) — gambar struk atau teks.
  void _openNotaKind(Order o) => _open(_Sheet('wakind', const [
        {'type': 'title', 't': 'Kirim Nota lewat WhatsApp', 's': ''},
        {'type': 'hint', 't': 'Pilih bentuk nota yang dikirim ke pelanggan.'},
        {'type': 'card', 't': 'Nota Gambar', 's': 'Gambar struk lengkap dengan barcode & QR', 'svg': '', 'ic': '🖼', 'badge': '', 'meta': '', 'on': false, 'i': 0},
        {'type': 'card', 't': 'Nota Teks', 's': 'Pesan teks · bisa dibaca tanpa membuka gambar', 'svg': '', 'ic': '💬', 'badge': '', 'meta': '', 'on': false, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 9},
      ]));

  Future<void> _notaKindEvent(String kind, int index) async {
    _close('wakind');
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null || (kind != 'button' && kind != 'card' && kind != 'tap')) return;
    if (index == 1) return _openNota(o);
    if (index != 0) return;
    final phone = waNumber(_phoneOf(o));
    try {
      final png = await _receiptPngOf(o);
      await _device.invokeMethod('Files.share', {
        'title': 'Nota ${o.id}', 'whatsapp': phone,
        'files': [{'name': 'nota-${o.id}.png', 'mime': 'image/png', 'data': base64Encode(png)}],
      });
      toast(phone.isEmpty ? 'Pilih WhatsApp lalu kontak pelanggan' : 'Membuka WhatsApp pelanggan dengan gambar nota…');
    } catch (_) {
      toast('Gagal membagikan gambar nota');
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
    if (_deny(3, 'membatalkan pesanan')) return;
    _form
      ..clear()
      ..['reason'] = 0
      ..['note'] = '';
    _open(_Sheet('cancel', [
      {'type': 'title', 't': 'Batalkan Pesanan?', 's': o.id},
      {'type': 'hint', 't': 'Pembatalan tidak bisa diurungkan dan tercatat di Audit Aktivitas.'},
      {'type': 'label', 't': 'Alasan pembatalan'},
      {'type': 'select', 'options': cancelReasons, 'index': 0, 'i': 0},
      {'type': 'input', 'v': '', 'ph': 'Keterangan tambahan (opsional)', 'multiline': true, 'i': 1},
      {'type': 'button', 't': 'Ya, Batalkan Pesanan', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Kembali', 'primary': false, 'i': 2},
    ]));
  }

  // ---------- Edit Transaksi (HTML edit115): layanan ±/hapus/tambah, estimasi, keterangan, parfum, diskon ----------
  List<List<String>> _editDiscList = const [['Tanpa diskon', '0']];
  List<OrderItem> _edItems = [];
  bool _edPick = false;
  List<String> get _edPerfumes => [for (final p in _settings!.perfumes) p.first, 'Tanpa Parfum'];
  List<Service> _edServices(Order o) => [for (final sv in _b!.services) if (sv.enabledFor(o.dur)) sv];

  /// Edit Transaksi (HTML v139): pesanan yang sudah diproses/lunas, bila login Kasir, wajib PIN Admin Utama dulu.
  void _openEdit(Order o) {
    if (o.isCancelled) return toast('Pesanan batal tidak bisa diedit');
    final free = o.status == 'antrian' && !o.isPaid;
    final ralat = _pages['ralat139'] as RalatPage;
    if (!free && !ralat.owner) {
      if (!ralat.hasPin) return toast('PIN Admin belum dibuat pemilik');
      _pin = '';
      return _open(_Sheet('pin139e', pinPadItems('Edit transaksi ${o.id} · minta Admin Utama memasukkan PIN', 0)));
    }
    _openEditForm(o);
  }

  int _pinFail = 0;
  void _editPinEvent(String kind, int index, Object? value) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (kind != 'button' || o == null) return _close('pin139e');
    final next = pinPadKey(_pin, index);
    if (next == null) return _close('pin139e');
    _pin = next;
    final ralat = _pages['ralat139'] as RalatPage;
    if (_pin.length < ralat.pinLen) return _open(_Sheet('pin139e', pinPadItems('Edit transaksi ${o.id} · minta Admin Utama memasukkan PIN', _pin.length)));
    if (ralat.pinOk(_pin)) {
      _pinFail = 0;
      _pin = '';
      _close('pin139e');
      return _openEditForm(o);
    }
    _pin = '';
    if (++_pinFail >= 3) {
      _pinFail = 0;
      _close('pin139e');
      addAudit(this, '⚠', 'PIN Admin salah 3×', 'Kasir mencoba edit transaksi ${o.id}');
      saveAll();
      return toast('PIN salah 3× · percobaan dicatat di Audit');
    }
    toast('PIN salah');
    _open(_Sheet('pin139e', pinPadItems('Edit transaksi ${o.id} · minta Admin Utama memasukkan PIN', 0)));
  }

  void _openEditForm(Order o) {
    _editDiscList = _editDiscs(o.discKey);
    final disc = _editDiscList.indexWhere((d) => d[1] == o.discKey);
    final per = _edPerfumes.indexOf(o.perfume);
    final d = o.due;
    String two(int n) => n.toString().padLeft(2, '0');
    _edItems = [for (final it in o.items) OrderItem.fromJson(it.toJson())];
    _edPick = false;
    _form
      ..clear()
      ..['note'] = o.note == '-' ? '' : o.note
      ..['perfume'] = per < 0 ? _edPerfumes.length - 1 : per
      ..['disc'] = disc < 0 ? 0 : disc
      ..['due'] = d == null ? '' : '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}';
    _open(_Sheet('edit115', _editItems(o)));
  }

  String get _edDiscKey => _editDiscList[((_form['disc'] as int?) ?? 0).clamp(0, _editDiscList.length - 1)][1];

  List<Map<String, dynamic>> _editItems(Order o) {
    final n = _edItems.length;
    final sv = _edServices(o);
    return [
      {'type': 'title', 't': 'Edit Transaksi', 's': ''},
      {'type': 'hint', 't': '${o.id} · ${o.name}'},
      {'type': 'entry', 't': 'Detail Order', 'lines': const <String>[], 'compact': true, 'btns': [{'t': '＋ Tambah Layanan', 'on': false, 'i': 0}]},
      if (_edPick)
        for (var k = 0; k < sv.length; k++)
          {'type': 'card', 't': sv[k].name, 's': '${rpSpaced(sv[k].priceFor(o.dur))}/${sv[k].unit}', 'svg': serviceIconSvg(_svIcon(sv[k]), 24), 'ic': '', 'badge': '', 'meta': '', 'on': false, 'i': 1000 + k},
      for (var k = 0; k < n; k++) ...[
        {'type': 'title', 't': _edItems[k].name},
        {'type': 'hint', 't': '${rpSpaced(_edItems[k].price)}/${_edItems[k].unit} · ${rpSpaced(_edItems[k].subtotal)}'},
        {'type': 'button', 't': '−', 'primary': false, 'i': 1 + 3 * k},
        {'type': 'input', 'v': qtyText(_edItems[k].qty), 'ph': '', 'numeric': true, 'decimal': true, 'i': k},
        {'type': 'button', 't': '＋', 'primary': false, 'i': 2 + 3 * k},
        {'type': 'button', 't': '×', 'primary': false, 'i': 3 + 3 * k},
      ],
      if (n == 0) {'type': 'hint', 't': 'Belum ada layanan. Tekan ＋ Tambah Layanan.'},
      {'type': 'label', 't': 'Estimasi Selesai'},
      {'type': 'input', 'v': '${_form['due']}', 'ph': '', 'i': n},
      {'type': 'label', 't': 'Keterangan'},
      {'type': 'input', 'v': '${_form['note']}', 'ph': 'Contoh: 12 pcs · rak B2', 'i': n + 1},
      {'type': 'label', 't': 'Parfum'},
      {'type': 'select', 'options': _edPerfumes, 'index': _form['perfume'], 'i': n + 2},
      {'type': 'label', 't': 'Diskon'},
      {'type': 'select', 'options': [for (final d in _editDiscList) d[0]], 'index': _form['disc'], 'i': n + 3},
      {'type': 'pair', 't': 'Total baru', 'v': rpSpaced(calcTotals(_edItems, _edDiscKey, o.ongkir).total), 'tone': '', 'tap': -1},
      {'type': 'button', 't': 'Simpan Perubahan', 'primary': true, 'i': 1 + 3 * n},
    ];
  }

  static const _edReasons = ['Salah timbang / berat', 'Salah pilih layanan', 'Salah jumlah item', 'Permintaan pelanggan'];
  int _edReason = -1;
  String _itemsTxt(List<OrderItem> items) => items.isEmpty ? '-' : items.map((i) => '${i.name} ${qtyText(i.qty)} ${i.unit}').join(', ');

  List<Map<String, dynamic>> _edReasonItems(Order o) => [
        {'type': 'title', 't': 'Alasan ralat pesanan', 's': ''},
        {'type': 'hint', 't': '${o.id} · ${o.name}'},
        {'type': 'pair', 't': 'Sebelumnya', 'v': '${_itemsTxt(o.items)} · ${rpSpaced(o.total)}', 'tone': '', 'tap': -1},
        {'type': 'buttons', 'options': [for (var k = 0; k < _edReasons.length; k++) {'t': _edReasons[k], 'on': _edReason == k, 'i': 10 + k}]},
        {'type': 'hint', 't': 'Setelah disimpan, perubahan & selisih tagihan tercatat di Log Ralat.'},
        {'type': 'button', 't': 'Simpan Ralat', 'primary': true, 'i': 1},
      ];

  void _edReasonEvent(String kind, int index) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null || kind != 'button') return _close('rs139e');
    if (index >= 10) {
      _edReason = index - 10;
      return _open(_Sheet('rs139e', _edReasonItems(o), mirror: const {}));
    }
    if (_edReason < 0) return toast('Pilih alasan ralat dulu');
    _close('rs139e');
    _applyEdit(o, _edReasons[_edReason]);
  }

  /// Simpan Edit Transaksi. [reason] kosong = koreksi bebas (Antrian, belum lunas).
  void _applyEdit(Order o, String reason) {
    final b = _b!;
    final before = o.total, beforeTxt = _itemsTxt(o.items), paid = o.paid;
    final due = DateTime.tryParse('${_form['due'] ?? ''}');
    final per = _edPerfumes;
    b.setItems(o, _edItems);
    b.edit(o, note: '${_form['note'] ?? ''}'.trim().isEmpty ? '-' : '${_form['note']}'.trim(), perfume: per[((_form['perfume'] as int?) ?? per.length - 1).clamp(0, per.length - 1)], discKey: _edDiscKey, due: due);
    final after = o.total, afterTxt = _itemsTxt(o.items);
    var ex = '';
    if (reason.isNotEmpty && paid > 0 && after != before) {
      if (after < paid) {
        // Lebih bayar: kas dikurangi (penjualan minus, sama dengan HTML) dan pembayaran pesanan disesuaikan.
        final back = paid - after;
        (b.kas.putIfAbsent('sales', () => <dynamic>[]) as List).add({'m': o.method, 'a': -back, 'id': o.id, 'adj': 1, 'at': isoString(now)});
        o.detail['paid'] = after;
        o.dataset['paid177'] = '$after';
        ex = ' · kembalikan ${rpSpaced(back)} ke pelanggan';
      } else {
        ex = ' · pelanggan kurang bayar ${rpSpaced(after - paid)}';
      }
    }
    if (beforeTxt != afterTxt || before != after) {
      (b.kas.putIfAbsent('ralatLog', () => <dynamic>[]) as List).insert(0, {
        'type': 'order', 'title': '${reason.isEmpty ? 'Edit' : 'Ralat'} pesanan ${o.id}', 'before': '$beforeTxt · ${rpSpaced(before)}', 'after': '$afterTxt · ${rpSpaced(after)}',
        'reason': reason.isEmpty ? 'Koreksi sebelum diproses' : '$reason$ex', 'by': _kasir, 't': now.toIso8601String(),
      });
    }
    addAudit(this, '✎', 'Edit transaksi ${o.id}', '$_kasir · total ${rpSpaced(before)} → ${rpSpaced(after)}');
    saveAll();
    _close('edit115');
    toast(reason.isNotEmpty
        ? (ex.isNotEmpty ? 'Ralat tersimpan$ex' : 'Ralat tersimpan · tercatat di Log Ralat')
        : (before != after ? 'Tersimpan · total ${rpSpaced(before)} → ${rpSpaced(after)} · tercatat di Audit' : 'Perubahan tersimpan · tercatat di Audit'));
    _refreshDetail();
  }

  String _svIcon(Service sv) => sv.unit == 'kg' ? 'Kiloan' : (sv.unit == 'm' ? 'Meteran' : 'Satuan');

  void _editEvent(String kind, int index, Object? value) {
    final o = _detailId == null ? null : _b!.orderById(_detailId!);
    if (o == null || kind == 'close') return _close('edit115');
    final n = _edItems.length;
    void redraw() => _open(_Sheet('edit115', _editItems(o)));
    if (kind == 'input') {
      if (index < n) {
        final q = parseQty(value);
        if (q <= 0) {
          toast('Isi jumlah yang benar, contoh 1,3');
        } else {
          _edItems[index].qty = (q * 100).round() / 100;
        }
        return redraw();
      }
      if (index == n) _form['due'] = '${value ?? ''}';
      if (index == n + 1) _form['note'] = '${value ?? ''}';
      if (index == n + 2) _form['perfume'] = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      if (index == n + 3) {
        _form['disc'] = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
        redraw();
      }
      return;
    }
    if (kind != 'button') return;
    if (index == 0) {
      _edPick = !_edPick;
      return redraw();
    }
    if (index >= 1000) {
      final sv = _edServices(o);
      if (index - 1000 >= sv.length) return;
      final pick = sv[index - 1000];
      final ex = _edItems.where((it) => it.name == pick.name).firstOrNull;
      if (ex != null) {
        ex.qty += 1;
      } else {
        _edItems.add(OrderItem(name: pick.name, icon: _svIcon(pick), unit: pick.unit, price: pick.priceFor(o.dur), qty: 1));
      }
      _edPick = false;
      return redraw();
    }
    if (index == 1 + 3 * n) {
      if (_edItems.isEmpty) return toast('Minimal 1 layanan');
      // HTML v139: pesanan Antrian yang belum lunas boleh dikoreksi langsung; selain itu wajib alasan ralat.
      if (o.status == 'antrian' && !o.isPaid) return _applyEdit(o, '');
      _edReason = -1;
      return _open(_Sheet('rs139e', _edReasonItems(o), mirror: const {}));
    }
    final k = (index - 1) ~/ 3, act = (index - 1) % 3;
    if (k < 0 || k >= n) return;
    final it = _edItems[k];
    if (act == 2) {
      _edItems.removeAt(k);
    } else {
      final step = it.unit == 'pcs' ? 1.0 : .5;
      final q = ((it.qty + (act == 0 ? -step : step)) * 100).round() / 100;
      final min = it.unit == 'pcs' ? 1.0 : .1;
      it.qty = q < min ? min : q;
    }
    redraw();
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

  /// Riwayat Transaksi (10 Okt 2026): akun yang masuk ke server (kasir, kepala cabang, owner) melihat catatan server —
  /// siapa mengubah apa, sebelum → sesudah. Tanpa server: riwayat status di HP seperti sebelumnya.
  void _openHistory(Order o) {
    if (!_srv.loggedIn || !(_srv.isOwner || _srv.can('orders.update'))) return _open(_Sheet('hist115', const [], mirror: orderHistoryMirror(o)));
    _open(_Sheet('histsrv', historySheetItems(o.id, const [], showOutlet: _srv.isOwner, note: 'Memuat riwayat…')));
    _srv.api('GET', '/orders/${Uri.encodeComponent(o.id)}/history').then((j) {
      if (!mounted || !_sheets.any((s) => s.id == 'histsrv')) return;
      _open(_Sheet('histsrv', historySheetItems(o.id, j['events'] as List? ?? const [], showOutlet: _srv.isOwner)));
    }).catchError((Object e) {
      if (!mounted || !_sheets.any((s) => s.id == 'histsrv')) return;
      _close('histsrv');
      toast(e is ServerFailure && !e.offline ? e.message : 'Riwayat server belum bisa dimuat · menampilkan riwayat di HP ini');
      _open(_Sheet('hist115', const [], mirror: orderHistoryMirror(o)));
    });
  }

  String _phoneOf(Order o) => o.phone.isNotEmpty ? o.phone : (_b!.customerByName(o.name)?.phone ?? '');

  void _sendWa(Order o) {
    final phone = waNumber(_phoneOf(o));
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

  Widget _mirrorSheet(_Sheet s) {
    final a = PopupActions(
      id: s.id,
      onButton: (i) => fmScoped(s.id, 'button', i),
      onTap: (i) => fmScoped(s.id, 'tap', i),
      onInput: (i, v) => fmScoped(s.id, 'input', i, v),
      onClose: () => fmScoped(s.id, 'close', 0),
    );
    final key = ValueKey('pure-${s.id}-${identityHashCode(s)}');
    if (s.id == 'rs139e') return rs139Widget(s.id, s.items, (kind, i, v) => fmScoped(s.id, kind, i, v), () => fmScoped(s.id, 'close', 0));
    return switch (s.id) {
      'wa131' => NativeWa131Sheet(key: key, model: s.mirror!, actions: a),
      'photo115' => NativePhoto115Sheet(key: key, model: s.mirror!, actions: a),
      _ => NativeHist115Sheet(key: key, model: s.mirror!, actions: a),
    };
  }

  // ---------------- lembar (sheet) ----------------
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {
    final b = _b;
    if (b == null) return;
    if (scope == 'srvlogin') return _srvLoginEvent(kind, index, value);
    if (scope == 'gs107') return _formSheetEvent(kind, index, value);
    if (scope == 'rpoutlet') return _rpOutletEvent(kind, index);
    if (scope == 'cat99') return _catEvent(kind, index, value);
    if (scope == 'qr160-menu') {
      _close('qr160-menu');
      if (kind != 'button') return;
      if (index == 0) scan();
      if (index == 1) nav('orders');
      if (index == 2) {
        nav('orders');
        toast('Pilih pesanan dulu');
      }
      return;
    }
    if (scope == 'deposits178') return _depositEvent(kind, index, value);
    if (scope == 'au133s') return _autoEvent(kind, index, value);
    if (scope == 'act115') return _menuEvent(kind, index);
    if (scope == 'gy158-sort') {
      _close(scope);
      if (kind == 'button' && index < 2) {
        setState(() {
          _custSort = index == 0 ? 'name' : 'order';
          _custPage = 0;
        });
        toast('Urutan pelanggan diperbarui');
      }
      return;
    }
    if (scope == 'photo115') {
      final po = _detailId == null ? null : b.orderById(_detailId!);
      if (kind == 'button' && index < 2 && po != null) {
        _addPhoto(po, index == 0 ? 'in' : 'out');
        return;
      }
      return _close(scope);
    }
    if (scope == 'hist115' || scope == 'histsrv') return _close(scope);
    if (scope == 'gy154-transfer') return _transferEvent(kind, index);
    if (scope == 'rc106') {
      _strukEvent(kind, index);
      return;
    }
    if (scope == 'wakind') {
      _notaKindEvent(kind, index);
      return;
    }
    if (scope == 'edit115') return _editEvent(kind, index, value);
    if (scope == 'rs139e') return _edReasonEvent(kind, index);
    if (scope == 'pin139e') return _editPinEvent(kind, index, value);
    if (scope == 'wa131') {
      final wo = _detailId == null ? null : b.orderById(_detailId!);
      if (kind == 'button' && wo != null && index == 1) {
        final phone = waNumber(_phoneOf(wo));
        if (phone.isEmpty) return toast('Nomor WA pelanggan belum ada');
        _close(scope);
        openMaps('https://wa.me/$phone?text=${Uri.encodeComponent(_notaWa(wo))}');
        return toast('Membuka WhatsApp pelanggan dengan teks nota…');
      }
      if (kind == 'button' && wo != null && index == 2) {
        Clipboard.setData(ClipboardData(text: _notaWa(wo)));
        return toast('Teks nota disalin');
      }
      return _close(scope);
    }
    if (scope == 'perm178') {
      _close('perm178');
      if (kind == 'button' && index == 0) _device.invokeMethod('GoyanaDevice.openSettings').catchError((_) => null);
      return;
    }
    if (scope == 'lock111') {
      _close('lock111');
      if (kind == 'button') nav('upgrade');
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
        // PIN Admin (Ralat → Ganti PIN Admin) = pemilik: akses penuh, izin kasir tidak membatasi.
        final owner = emp == null && (_pages['ralat139'] as RalatPage).pinOk(_pin);
        if (emp == null && !owner) return toast('PIN salah');
        setState(() {
          _kasir = owner ? 'Pemilik' : '${emp!['name']}';
          _kasirSession = !owner;
          _locked = false;
          _pin = '';
        });
        toast('Halo, $_kasir');
      }
      return;
    }
    if (kind == 'close') {
      if (scope == 'detail') return odClose();
      _close(scope);
      return;
    }
    if (kind == 'input') {
      final key = switch (scope) {
        'cancel' => index == 0 ? 'reason' : 'note',
        'items' => 'item$index',
        'setup' => const ['oname', 'oaddr', 'ophone'][index.clamp(0, 2)],
        _ => 'amount',
      };
      if (scope == 'dp' && index == 1) {
        _form['dpMethod'] = const ['Tunai', 'QRIS', 'Transfer'][(value is num ? value.toInt() : int.tryParse('$value') ?? 0).clamp(0, 2)];
        return;
      }
      _form[key] = value ?? '';
      if (scope == 'items') _itemQty[index] = '${value ?? ''}';
      // Lembar yang menampilkan hitungan (kembalian, subtotal, sisa) ikut diperbarui.
      if (scope == 'cash') _open(_Sheet('cash', _cashItems()));
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
            _openLabel(o);
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
          final err = b.cancel(o, reason: note.isEmpty ? reason : (reason.isEmpty ? '' : '$reason · $note'), now: now, by: _kasir);
          if (err != null) return toast(err);
          final refund = int.tryParse('${o.detail['refunded'] ?? ''}') ?? 0;
          addAudit(this, '✕', 'Pesanan dibatalkan', '$_kasir · ${o.id}${refund > 0 ? ' · dana kembali ${rp(refund)}' : ''}');
          saveAll();
          _close('cancel');
          toast(refund > 0 ? 'Pesanan dibatalkan · pengembalian ${rp(refund)} dicatat' : 'Pesanan dibatalkan');
          _refreshDetail();
        } else {
          _close('cancel');
        }
      case 'history':
        _close('history');
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
      case 'nota':
        _close('nota');
        if (index == 1 && o != null) _sendWa(o);
      case 'pickup':
        _close('pickup');
        if (index == 1) {
          // Pesanan jemput tanpa layanan = Buat Penjemputan: langsung popup Jadwal lalu Pilih Kurir untuk pelanggan ini.
          final p = _pages['jemputnew202'];
          if (p is PickupNewPage) {
            p
              ..pick(_aoCustomer)
              ..keep = true;
          }
          nav('jemputnew202');
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
            final bal = _b!.depositOf(_payName);
            if (bal < _cartTotal) return toast('Saldo deposit $_payName ${rp(bal)} tidak cukup');
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
  void cuSearch(String text) => setState(() {
        _custSearch = text;
        _custPage = 0;
      });
  @override
  void cuDeposit() => _openDeposits();
  @override
  void cuAdd() => _openCustomerForm(null);
  @override
  void cuToggleDb() => setState(() => _custOpen = !_custOpen);
  @override
  void cuFilter() => _open(_Sheet('gy158-sort', [
        {'type': 'title', 't': 'Urutkan Pelanggan'},
        {'type': 'button', 't': 'Nama A–Z', 'primary': false, 'i': 0},
        {'type': 'button', 't': 'Order Terbanyak', 'primary': false, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
      ]));
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
  void cuPage(int delta) => setState(() => _custPage = (_custPage + delta).clamp(0, 9999));
  @override
  void cuRank() => nav('rank138');
  @override
  void cuCrm() => nav('crm');


  /// Tambah / Edit Pelanggan = halaman `customeradd` (sama dengan Hibrida): jenis kelamin dulu, lalu data & lokasi Maps.
  void _openCustomerForm(Customer? c, {bool forOrder = false}) {
    (_pages['customeradd'] as CustomerAddPage).start(c, forOrder: forOrder);
    nav('customeradd');
  }

  @override
  void addCustomerFor(String page) {
    final p = _pages[page];
    if (p is PickupNewPage) p.keep = true; // isian yang sudah ada jangan hilang
    (_pages['customeradd'] as CustomerAddPage).start(null, returnTo: page);
    nav('customeradd');
  }

  @override
  void customerSaved(String name, {bool forOrder = false, String? returnTo}) {
    final p = returnTo == null ? null : _pages[returnTo];
    if (p is PickupNewPage) {
      p
        ..pick(name)
        ..keep = true;
      return nav(returnTo!);
    }
    if (!forOrder) return nav('customers');
    setState(() {
      _pageSheets.clear();
      _page = 'addorder';
    });
    _aoPickName(name);
  }

  // ---------------- Tambah Transaksi ----------------
  String _pickupId = '';
  @override
  void startOrderFor(String customerName) {
    _startOrder();
    widget.store.get(pickupActiveKey).then((v) {
      try {
        _pickupId = '${jsonDecode(v ?? '""')}';
      } catch (_) {
        _pickupId = '';
      }
    });
    if (_b!.customerByName(customerName) != null) {
      _aoPickName(customerName);
      toast('Timbang barang, lalu pilih ongkos kirim di opsi pesanan');
    } else {
      toast('Pilih atau tambahkan pelanggan "$customerName", lalu timbang barang');
    }
  }

  /// Transaksi dari Sampai Lokasi selesai dibuat: penjemputan ditandai selesai, pesanan masuk Antrian (barang sudah dibawa).
  Future<void> _pickupFinished(Order o) async {
    final id = _pickupId;
    if (id.isEmpty) return;
    _pickupId = '';
    final list = await loadPickups(this);
    final r = list.where((x) => x['id'] == id).firstOrNull;
    if (r == null) return;
    r
      ..['status'] = 'selesai'
      ..['selesaiAt'] = now.millisecondsSinceEpoch
      ..['orderId'] = o.id;
    await widget.store.set(pickupKey, jsonEncode(list));
    await widget.store.remove(pickupActiveKey);
  }

  /// Kurir aktif outlet ini untuk pilihan Kurir di Atur Pesanan.
  List<Map<String, dynamic>> _aoCouriers = [];
  bool get _needsCourier => !_courierMode && _fillId.isEmpty && transportType(_optHand) != 'none';
  List<String> get _courierOptions => ['Pilih kurir', 'Saya sendiri (${pickupSelfName(this)})', for (final k in _aoCouriers) '${k['name']}'];

  void _startOrder() => setState(() {
        Couriers.load(widget.store).then((v) {
          final out = _b?.activeOutlet ?? '';
          _aoCouriers = [
            for (final k in v.list)
              if (k['deleted'] != true && k['active'] != false &&
                  ((k['outlets'] as List? ?? const []).isEmpty || out.isEmpty || (k['outlets'] as List).map((e) => '$e').contains(out)))
                k,
          ];
        });
        _fillId = _fillFrom = '';
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
          ..['kurir'] = 0
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
    if (_fillId.isNotEmpty) return 'Jemput & Antar';
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
            {'i': i, 'name': list[i].name, 'avatar': aoPersonAvatar, 'lines': ['☎ ${list[i].phone}', '⌖ ${list[i].address.isEmpty ? '-' : list[i].address}'], 'btn': 'Pilih'},
      ];
      m['empty'] = (m['people'] as List).isEmpty ? (q.isEmpty ? 'Belum ada pelanggan. Tambahkan pelanggan baru.' : 'Pelanggan tidak ditemukan.') : '';
      m['sheet'] = null;
      return m;
    }
    final t = calcTotals(_cartItems, _optDiscKey, 0);
    m['step'] = _aoSheet == 'options' ? 'Langkah 3 dari 5' : (_aoSheet == 'payment' ? 'Langkah 4 dari 5' : 'Langkah 2 dari 5');
    if (_aoSheet == 'options') m['title'] = 'ATUR PESANAN';
    if (_aoSheet == 'payment') m['title'] = 'PEMBAYARAN';
    m['customer'] = {'name': _aoCustomer, 'sub': '$_aoDur · ${durationHours(_aoDur)} Jam', 'avatar': aoBarAvatar};
    m['durations'] = [for (final d in _durations) {'t': d, 's': '${durationHours(d)} Jam', 'on': d == _aoDur}];
    m['cats'] = [for (var i = 0; i < _cats.length; i++) {'t': _cats[i][0], 'on': i == _aoCat, 'svg': aoCatSvg[_cats[i][0]] ?? ''}];
    m['search'] = {'v': _aoSvcSearch, 'ph': 'Cari layanan $_aoDur'};
    final items = <Map<String, dynamic>>[];
    _aoShown.clear();
    final svcs = _visibleServices;
    for (final cat in _cats.skip(1)) {
      final group = svcs.where((s) => s.unit == cat[1]).toList();
      if (group.isEmpty) continue;
      items.add({'h': 1, 'svg': aoHeadSvg[cat[0]] ?? '', 't': '${cat[0]} · $_aoDur', 's': const {'kg': 'Cuci ››› Kering ››› Setrika', 'pcs': 'Cuci ››› Kering ››› Packing', 'm': 'Cuci ››› Kering'}[cat[1]] ?? ''});
      for (final s in group) {
        final q = _cart[s.name];
        _aoShown.add(b.services.indexOf(s));
        items.add({'i': _aoShown.length - 1, 'svg': aoItemSvg[cat[0]] ?? '', 't': s.name, 's': '${rpSpaced(s.priceFor(_aoDur))} / ${s.unit} · ${durationHours(_aoDur)} Jam', 'btn': q == null ? 'Pilih' : '${qtyText(q)} ${s.unit}', 'on': q != null});
      }
    }
    m['items'] = items;
    m['empty'] = '';
    m['sheet'] = null;
    double sumOf(String u) => _cart.entries.fold<double>(0, (a, e) => a + (b.services.any((x) => x.name == e.key && x.unit == u) ? e.value : 0));
    String qn(double v) => qtyText(v);
    m['footer'] = {'name': _aoCustomer, 'sum': '${qn(sumOf('kg'))} kg · ${qn(sumOf('pcs'))} pcs · ${qn(sumOf('m'))} m', 'label': 'Total Layanan', 'total': rpSpaced(t.total), 'btn': 'LANJUT ›'};
    if (_aoSheet == 'options') {
      m['sheet'] = {
        'kind': 'options', 'title': 'Atur Pesanan',
        'fields': [
          {'k': 0, 'type': 'select', 'label': 'Parfum', 'options': _perfumes, 'index': _opt['perfume']},
          if (_fillId.isEmpty) {'k': 1, 'type': 'select', 'label': 'Penyerahan', 'options': _hands, 'index': _opt['hand']},
          // Antar / jemput: wajib pilih kurir (Datang Langsung tidak). Keputusan Paduka 10 Okt 2026.
          if (_needsCourier) {'k': 4, 'type': 'select', 'label': 'Kurir', 'options': _courierOptions, 'index': _opt['kurir'] ?? 0},
          {'k': 2, 'type': 'switch', 'label': 'Jadikan Prioritas', 'sub': 'naik ke atas antrian', 'on': _opt['prio'] == true},
          {'k': 3, 'type': 'select', 'label': 'Diskon', 'options': [for (final d in _discs) d[0]], 'index': _opt['disc']},
        ],
        'note': {'v': '${_opt['note']}', 'ph': 'Catatan: jumlah pakaian, no rak, kondisi (contoh: 12 pcs, rak B2, kemeja luntur)'},
        'main': 'Buat Pesanan',
      };
    } else if (_aoSheet == 'payment') {
      m['sheet'] = _paySheetJson(rpSpaced(t.total), _fillId.isNotEmpty ? _fillId : b.nextOrderId(now), _aoCustomer, 'BATALKAN PESANAN');
    }
    return m;
  }

  Map<String, dynamic> _paySheetJson(String total, String id, String name, String cancel, {String close = ''}) {
    final b = _b!;
    return {
        'kind': 'payment', 'title': 'Pembayaran', 'label': 'Total Tagihan', 'total': total, 'id': id,
        'methods': [
          for (var i = 0; i < _payMethods.length; i++)
            {
              'i': i < 4 ? i : i + 6, 't': _payMethods[i][3], 'svg': aoPaySvg[_payMethods[i][3]]![0], 'icon': aoPaySvg[_payMethods[i][3]]![3],
              'ic': aoPaySvg[_payMethods[i][3]]![1], 'bg': aoPaySvg[_payMethods[i][3]]![2].isEmpty ? 'rgba(0, 0, 0, 0)' : aoPaySvg[_payMethods[i][3]]![2],
              's': _payMethods[i][0] == 'Saldo Deposit' && b.depositOf(name) > 0 ? 'Saldo ${rp(b.depositOf(name))}' : '',
            },
        ],
        'cancel': cancel,
        if (close.isNotEmpty) 'close': close,
      };
  }

  /// Nilai yang disimpan di pesanan (HTML menyimpan 'Tanpa Parfum' untuk pilihan 'Tidak').
  String _perfumeValue(int i) {
    final v = _perfumes[i.clamp(0, _perfumes.length - 1)];
    return v;
  }

  List<String> get _perfumes => ['Tanpa Parfum', for (final p in _settings!.perfumes) p.first];
  /// Indeks layanan (di daftar layanan) untuk tiap baris yang tampil di Tambah Transaksi.
  final List<int> _aoShown = [];

  static const _payMethods = [
    ['Tunai', '', '', 'Tunai'], ['QRIS', '', '', 'QRIS'], ['Transfer', '', '', 'Transfer'],
    ['Bayar Nanti', '', '', 'Bayar Nanti'], ['DP / Uang Muka', '', '', 'DP / Uang Muka'], ['Saldo Deposit', '', '', 'Saldo Deposit'],
  ];

  @override
  void aoBack() {
    if (_fillId.isNotEmpty) {
      // Buat Pesanan dari Penjemputan dibatalkan: pesanan Penjemputan tetap seperti semula.
      final to = _fillFrom.isEmpty ? 'jemput202' : _fillFrom;
      _fillId = _fillFrom = '';
      setState(() {
        _sheets.clear();
        _aoSheet = null;
      });
      return nav(to);
    }
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
    if (_aoShown.isEmpty) _addOrderJson();
    if (index < 0 || index >= _aoShown.length) return;
    _qtyService = list[_aoShown[index]];
    final q = _cart[_qtyService!.name];
    _form
      ..clear()
      ..['amount'] = q == null ? '' : qtyText(q);
    _open(_Sheet('qty', _qtyItems()));
  }

  /// Butir sama dengan HTML qty116 (isian jumlah + satuan, SIMPAN, BATAL).
  List<Map<String, dynamic>> _qtyItems() {
    final sv = _qtyService!;
    return [
      {'type': 'input', 'v': '${_form['amount']}', 'ph': '0,0', 'numeric': true, 'decimal': true, 'i': 0},
      {'type': 'title', 't': sv.unit},
      {'type': 'button', 't': 'SIMPAN', 'primary': true, 'i': 1},
      if (_cart.containsKey(sv.name)) {'type': 'button', 't': 'HAPUS DARI PESANAN', 'primary': false, 'i': 2},
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
      toast('${s.name} · ${qtyText(q)} ${s.unit} ditambahkan');
    } else if (index == 2) {
      setState(() => _cart.remove(s.name));
      _close('qty');
    } else {
      _close('qty');
    }
  }

  @override
  void aoNext() {
    if (_cart.isEmpty && _fillId.isNotEmpty) return toast('Pilih layanan dan isi berat atau jumlahnya');
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
  void aoSheetSelect(int field, int option) => field == 3
      ? _pickDisc(option)
      : setState(() => _opt[field == 1 ? 'hand' : (field == 4 ? 'kurir' : 'perfume')] = option);
  @override
  void aoSheetSwitch(int field) => setState(() => _opt['prio'] = _opt['prio'] != true);
  @override
  void aoSheetNote(String text) => _opt['note'] = text;
  @override
  void aoSheetMain() {
    if (_needsCourier && ((_opt['kurir'] as int?) ?? 0) <= 0) return toast('Pilih kurir dulu');
    setState(() => _aoSheet = 'payment');
  }
  @override
  void aoSheetClose() => setState(() {
        if (_payOrderId != null) {
          // Serah terima dibatalkan: lembar ditutup, status pesanan tetap (belum diambil / belum diterima).
          _payOrderId = null;
          _handoverId = null;
        } else {
          _aoSheet = null;
        }
      });
  @override
  void aoPayCancel() {
    final o = _payOrder;
    if (_handing && o != null) return _handoverDebt(o);
    setState(() => _payOrderId != null ? _payOrderId = null : _aoSheet = 'options');
  }

  String _pendingMethod = '';

  int get _cartTotal => _payOrder?.remaining ?? calcTotals(_cartItems, _optDiscKey, _optOngkir).total;

  @override
  void aoPay(int index) {
    final k = index >= 10 ? index - 6 : index;
    if (k < 0 || k >= _payMethods.length) return;
    final m = _payMethods[k][0];
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
      case 'Transfer':
        _openTransfer();
      default:
        _finishOrder(m);
    }
  }

  // ---------- Transfer Bank (HTML gy154-transfer): rekening dari Pengaturan → Pembayaran ----------
  List<String> _bank = const ['', '', ''];
  Future<void> _openTransfer() async {
    final v = await Future.wait([widget.store.get('gy154-bank'), widget.store.get('gy154-account'), widget.store.get('gy154-holder')]);
    if (!mounted) return;
    _bank = [for (final x in v) (x ?? '').trim()];
    final ok = _bank.every((x) => x.isNotEmpty);
    _open(_Sheet('gy154-transfer', [
      {'type': 'title', 't': 'Transfer Bank'},
      {'type': 'title', 't': _bank[0].isEmpty ? 'Rekening belum diatur' : _bank[0]},
      {'type': 'title', 't': _bank[1].isEmpty ? '—' : _bank[1].replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ')},
      if (_bank[2].isNotEmpty) {'type': 'hint', 't': 'a.n. ${_bank[2]}'},
      if (!ok) {'type': 'button', 't': 'Pengaturan Pembayaran', 'primary': false, 'i': 0},
      {'type': 'pair', 't': 'Total Tagihan', 'v': rpSpaced(_cartTotal), 'tone': '', 'tap': -1},
      {'type': 'hint', 't': 'Cek mutasi / notifikasi bank dulu, baru tekan Sudah Ditransfer.'},
      {'type': 'button', 't': 'SUDAH DITRANSFER', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'BATAL', 'primary': false, 'i': 2},
    ]));
  }

  void _transferEvent(String kind, int index) {
    _close('gy154-transfer');
    if (kind != 'button') return;
    if (index == 0) return nav('qris');
    if (index == 1) {
      if (_bank.any((x) => x.isEmpty)) return toast('Rekening belum diatur · buka Pengaturan Pembayaran');
      _finishOrder('Transfer');
    }
  }

  void _confirm(String method) {
    _pendingMethod = method;
    if (method == 'Saldo Deposit') {
      // Butir sama dengan HTML depositpay178.
      return _open(_Sheet('confirm', [
        {'type': 'title', 't': 'Saldo Deposit'},
        {'type': 'hint', 't': '$_payName · saldo ${rp(_b!.depositOf(_payName))} · tagihan ${rp(_cartTotal)}'},
        {'type': 'button', 't': 'Bayar dengan Deposit', 'primary': true, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
      ]));
    }
    final qris = _settings!.qrisText;
    if (!qrisValid(qris)) {
      // Butir sama dengan HTML qris193-setup.
      return _open(_Sheet('confirm', [
        {'type': 'title', 't': 'Upload QRIS Outlet'},
        {'type': 'hint', 't': 'QRIS dinamis membutuhkan QRIS usaha Anda terlebih dahulu. Upload gambar QRIS untuk mengisi nominal transaksi otomatis.'},
        {'type': 'button', 't': 'Upload QRIS', 'primary': true, 'i': 4},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
      ]));
    }
    // HTML f61-qris: kartu QR + nominal, SUDAH LUNAS, Batal.
    final dyn = _settings!.raw['qrisDynamic'] != false;
    _open(_Sheet('confirm', [
      {'type': 'qr', 'data': dyn ? qrisDynamic(qris, _cartTotal) : qris, 'size': 220},
      {'type': 'title', 't': rpSpaced(_cartTotal)},
      {'type': 'hint', 't': dyn
          ? 'Nominal otomatis. Periksa pembayaran masuk sebelum menekan Sudah Lunas.'
          : 'QRIS statis. Pelanggan mengisi nominal di atas. Periksa pembayaran masuk sebelum menekan Sudah Lunas.'},
      {'type': 'button', 't': 'SUDAH LUNAS', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
    ]));
  }

  /// Pecahan cepat (HTML gy154-cash): puluhan ribu di atas total, 50rb, 100rb — hanya yang lebih besar dari total.
  List<int> get _cashChips {
    final total = _cartTotal;
    return {((total + 9999) ~/ 10000) * 10000, 50000, 100000}.where((v) => v > total).toList();
  }

  /// Butir sama dengan HTML gy154-cash.
  List<Map<String, dynamic>> _cashItems() {
    final total = _cartTotal, got = parseRupiah(_form['amount']);
    final chips = _cashChips;
    return [
      {'type': 'title', 't': 'Pembayaran Tunai'},
      {'type': 'pair', 't': 'Total Tagihan', 'v': rpSpaced(total), 'tone': '', 'tap': -1},
      {'type': 'input', 'label': 'Uang diterima', 'v': got > 0 ? thousands(got) : '', 'ph': '0', 'numeric': true, 'i': 0},
      {'type': 'buttons', 'options': [
        {'t': 'Uang pas', 'on': false, 'i': 10},
        for (var k = 0; k < chips.length; k++) {'t': '${chips[k] ~/ 1000}rb', 'on': false, 'i': 11 + k},
      ]},
      {'type': 'pair', 't': 'Kembalian', 'v': got >= total && got > 0 ? rpSpaced(got - total) : '—', 'tone': got >= total && got > 0 ? 'g' : '', 'tap': -1},
      {'type': 'button', 't': got == 0 || got == total ? 'SUDAH DIBAYAR (UANG PAS)' : 'SUDAH DIBAYAR', 'primary': true, 'i': 1},
      {'type': 'button', 't': 'BATAL', 'primary': false, 'i': 2},
    ];
  }

  void _cashButton(int index) {
    if (index >= 10) {
      final chips = _cashChips;
      _form['amount'] = '${index == 10 || index - 11 >= chips.length ? _cartTotal : chips[index - 11]}';
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

  /// Butir sama dengan HTML dp178.
  List<Map<String, dynamic>> _dpItems() => [
        {'type': 'title', 't': 'DP / Uang Muka'},
        {'type': 'hint', 't': '$_payName · sisa tagihan ${rp(_cartTotal)}'},
        {'type': 'label', 't': 'Nominal DP'},
        {'type': 'input', 'v': '${_form['amount']}', 'ph': '', 'numeric': true, 'i': 0},
        {'type': 'label', 't': 'Metode pembayaran'},
        {'type': 'select', 'options': const ['Tunai', 'QRIS', 'Transfer'], 'index': const ['Tunai', 'QRIS', 'Transfer'].indexOf('${_form['dpMethod']}').clamp(0, 2), 'i': 1},
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
    if (_payOrderId != null) return _finishDetailPay(method, change: change, dp: dp, dpMethod: dpMethod);
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
    final pointsBefore = _points(_aoCustomer);
    final fill = _fillId.isEmpty ? null : b.orderById(_fillId);
    if (fill != null && (fill.status == 'jemput' || fill.items.isEmpty)) return _finishFill(fill, method, change: change, dp: dp, dpMethod: dpMethod, pointsBefore: pointsBefore);
    _fillId = _fillFrom = '';
    final o = b.createOrder(
      customer: _aoCustomer, phone: cust?.phone ?? '', dur: _aoDur, items: _cartItems,
      discKey: _courierMode ? '0' : _optDiscKey, ongkir: _optOngkir, perfume: _perfumeValue((_opt['perfume'] as int)),
      note: '${_opt['note']}'.trim(), handover: hand, priority: _opt['prio'] == true,
      payMethod: method == 'DP' ? 'DP' : (method == 'Saldo Deposit' ? 'Bayar Nanti' : method), dpMethod: dpMethod, payAmount: dp, kasir: _kasir, now: now,
    );
    if (_needsCourier) {
      final pick = (_opt['kurir'] as int?) ?? 0;
      if (pick == 1) o.dataset['jemputSelf'] = pickupSelfName(this);
      if (pick >= 2 && pick - 2 < _aoCouriers.length) o.dataset['courier181'] = '${_aoCouriers[pick - 2]['id']}';
    }
    if (method == 'Saldo Deposit') {
      // Saldo deposit dipotong lewat satu pembayaran saja (sebelumnya tercatat dua kali di kas & riwayat bayar).
      b.pay(o, method: 'Deposit', amount: o.total, now: now);
    }
    if (_pickupId.isNotEmpty) {
      if (o.status == 'jemput') {
        b.advance(o, now: now, by: _kasir);
      }
      _pickupFinished(o);
    }
    _save();
    setState(() {
      _aoSheet = null;
      _sheets.clear();
      _page = 'orders';
      _tab = o.status == 'jemput' ? 0 : 1;
      _search = '';
    });
    toast(change > 0 ? 'Lunas · kembalian ${rp(change)}' : 'Pesanan tersimpan · kirim nota lewat tombol WA hijau');
    _pointsToast(o.name, pointsBefore);
    _showDetail(o.id, banner: true);
    // Pengaturan → Barcode & Label: "Otomatis cetak struk setelah order".
    if (tplToggle(_settings!, 'barcode', 0)) _print(o);
  }

  /// Penjemputan → Buat Pesanan selesai: isi pesanan yang sama, catat pembayaran, lalu majukan ke Antrian.
  void _finishFill(Order o, String method, {int change = 0, int? dp, String dpMethod = 'Tunai', int pointsBefore = 0}) {
    final b = _b!;
    _fillId = _fillFrom = '';
    b.fillPickup(o, dur: _aoDur, items: _cartItems, discKey: _courierMode ? '0' : _optDiscKey, ongkir: _optOngkir,
        perfume: _perfumeValue(_opt['perfume'] as int), note: '${_opt['note']}', priority: _opt['prio'] == true, now: now);
    if (method == 'Saldo Deposit') {
      b.pay(o, method: 'Deposit', amount: o.remaining, now: now);
    } else if (method == 'DP') {
      if ((dp ?? 0) > 0) b.pay(o, method: dpMethod, amount: dp!, now: now);
    } else if (!RegExp('Bayar Nanti', caseSensitive: false).hasMatch(method)) {
      b.pay(o, method: method, amount: o.remaining, now: now);
    }
    if (o.status == 'jemput') b.advance(o, now: now, by: _kasir);
    _save();
    setState(() {
      _aoSheet = null;
      _sheets.clear();
      _page = 'orders';
      _tab = 1;
      _search = '';
    });
    toast(change > 0 ? 'Masuk Antrian · lunas · kembalian ${rp(change)}' : 'Pesanan masuk Antrian · kirim nota lewat tombol WA hijau');
    _pointsToast(o.name, pointsBefore);
    _showDetail(o.id, banner: true);
    if (tplToggle(_settings!, 'barcode', 0)) _print(o);
  }

  /// Bayar dari Rincian Pesanan: lembar Pembayaran yang sama dengan Tambah Transaksi (HTML v160 openPay115).
  void _finishDetailPay(String method, {int change = 0, int? dp, String dpMethod = 'Tunai'}) {
    final b = _b!, o = _payOrder;
    final hand = _handing, handBy = _handoverBy.isEmpty ? _kasir : _handoverBy;
    if (hand && o != null && method == 'Bayar Nanti') return _handoverDebt(o);
    setState(() {
      _payOrderId = null;
      _handoverId = null;
      _sheets.removeWhere((s) => const {'cash', 'dp', 'confirm'}.contains(s.id));
    });
    if (o == null || method == 'Bayar Nanti') return;
    final m = method == 'DP' ? dpMethod : (method == 'Saldo Deposit' ? 'Deposit' : method);
    final pointsBefore = _points(o.name);
    final err = b.pay(o, method: m, amount: dp ?? o.remaining, now: now);
    if (err != null) return toast(err);
    _pointsToast(o.name, pointsBefore);
    addAudit(this, '💵', 'Pembayaran pesanan', '$_kasir · ${o.id} · $m');
    if (hand) {
      // Serah terima: setelah dibayar (lunas atau sebagian) status langsung maju; sisa tetap di Belum Bayar.
      if (o.remaining > 0) o.dataset['hutang203'] = '1';
      b.advance(o, now: now, by: handBy);
    }
    saveAll();
    toast(change > 0 ? 'Lunas · kembalian ${rp(change)}' : 'Pembayaran diperbarui: ${o.isPaid ? 'Lunas · $method' : 'DP ${rp(o.paid)} · sisa ${rp(o.remaining)}'}');
    _refreshDetail();
  }

  Order? get _payOrder => _payOrderId == null ? null : _b!.orderById(_payOrderId!);
  String get _payName => _payOrder?.name ?? _aoCustomer;

  // ---------------- Pengaturan & Laporan (sementara) ----------------
  // ---------------- tampilan ----------------
  /// Jarak aman bawah: menu bawah & tombol bawah halaman dinaikkan setinggi bilah gestur/lengkung layar HP,
  /// supaya tidak tertimpa. Popup tetap selebar layar penuh (mereka menambah jarak aman sendiri).
  Widget _lift(BuildContext context, Widget child) {
    // Susunan widget harus selalu sama: saat keyboard muncul jarak aman jadi 0, dan bila pembungkusnya
    // berubah halaman dibuat ulang → kolom isian kehilangan fokus → keyboard menutup lagi.
    final inset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: Colors.white,
      child: Padding(padding: EdgeInsets.only(bottom: inset), child: MediaQuery.removePadding(context: context, removeBottom: true, child: child)),
    );
  }

  Widget _liftDetail(BuildContext context, Widget child) => _lift(context, child);

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null || _settings == null) return const Material(color: Colors.white, child: Center(child: CircularProgressIndicator(color: gBrand)));
    if (_gate) return _gateScreen();
    final n = now;
    if (b.outlets.isEmpty) {
      return Stack(children: [
        Positioned.fill(child: NativeOutletSetup(actions: this, name: '${_form['oname'] ?? ''}', address: '${_form['oaddr'] ?? ''}', phone: '${_form['ophone'] ?? ''}')),
        // Pesan "Isi nama outlet" dulu tidak terlihat di layar ini.
        if (_toast.isNotEmpty) Positioned(left: 24, right: 24, bottom: 60, child: IgnorePointer(child: Center(child: NativeToast(text: _toast)))),
      ]);
    }
    if (_locked) {
      return NativeSheet(id: 'pin', screen: true, actions: this, items: [
        {'type': 'title', 't': 'GOYANA'},
        {'type': 'title', 't': 'Masukkan PIN', 's': ''},
        {'type': 'hint', 't': 'PIN pegawai untuk membuka aplikasi. Pemilik: masukkan PIN Admin untuk akses penuh.'},
        {'type': 'input', 'v': _pin, 'ph': 'PIN', 'numeric': true, 'secret': true, 'i': 0},
        {'type': 'button', 't': 'Masuk', 'primary': true, 'i': 1},
      ]);
    }
    Widget page;
    switch (_page) {
      case 'orders':
        page = NativeOrders(model: OrdersModel.fromJson(_ordersModel(b, n)), actions: this);
      case 'customers':
        page = NativeCustomers(model: CustomersModel.fromJson(customersJson(b, _custSearch, open: _custOpen, page: _custPage, sort: _custSort)), actions: this);
      case 'addorder':
        page = NativeAddOrder(model: AddOrderModel.fromJson(_addOrderJson()), actions: this);
      case 'reports':
        page = NativeReports(model: reportsHubA8(_rpCtx(), periodKey: _rpKey, from: _rpFrom, to: _rpTo, cat: _rpCat, query: _rpQuery, outlet: _rpOutletLabel(), lockProfit: _rpOutlet == '*' && planAccess.rank(now) < 4), actions: this);
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
            : NativeHome(model: HomeModel.fromJson(homeJson(b, n)..addAll(kasirCan(0) ? const {} : const {'today': 'Rp •••'})), actions: this);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheets.isNotEmpty) return fmScoped(_sheets.last.id, 'close', 0);
        if (_payOrderId != null) return aoSheetClose();
        if (_detailId != null) return odClose();
        if (_pageSheets.isNotEmpty) return closePageSheet(_pageSheets.last);
        if (_aoSheet != null) return aoSheetClose();
        if (_page == 'addorder' && _aoStage == 'services') return aoBack();
        if (_page != 'home' && !(_courierMode && _page == 'kurirhome')) return nav('home');
        SystemNavigator.pop();
      },
      child: Stack(children: [
        Positioned.fill(child: _lift(context, page)),
        if (_detailId != null && b.orderById(_detailId!) != null)
          Positioned.fill(
            child: _liftDetail(context, NativeOrderDetail(
              model: orderDetailOd(b, b.orderById(_detailId!)!, banner: _odBanner, detailed: _srv.loggedIn, staff: _stageMode), actions: this,
              onQrStatus: () => showModalBottomSheet<void>(
                context: context, isScrollControlled: true, backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (context) => NativeOrderStatusQr(orderId: _detailId ?? '', customerName: b.orderById(_detailId ?? '')?.name ?? '', onClose: () => Navigator.pop(context)),
              ),
            )),
          ),
        if (_payOrder case final po?)
          Positioned.fill(child: AoSheet(sheet: _paySheetJson(rpSpaced(po.remaining), po.id, po.name, _handing ? 'HUTANG DULU' : 'BATAL', close: _handing ? 'Tutup' : ''), actions: this)),
        for (final s in _sheets)
          Positioned.fill(
            child: s.mirror != null
                ? _mirrorSheet(s)
                : isAoPopup(s.items)
                ? AoPopup(key: ValueKey('pure-ao-${s.id}'), id: s.id, data: s.items.first, actions: this)
                : NativeSheet(key: ValueKey('pure-${s.id}-${s.items.length}'), id: s.id, items: s.items, actions: this),
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
