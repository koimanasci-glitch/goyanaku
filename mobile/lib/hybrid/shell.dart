import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/business.dart';
import '../core/store.dart';
import '../logic/addorder.dart';
import '../logic/addorder_save.dart';
import '../logic/home.dart';
import '../logic/cash.dart';
import '../logic/order_detail.dart';
import '../logic/orders.dart';
import '../logic/payments.dart';
import '../logic/status_auto.dart';
import '../native/addorder_page.dart';
import '../native/cash_page.dart';
import '../native/cashclose_page.dart';
import '../native/cat99_sheet.dart';
import '../native/common.dart';
import '../native/brand_intro.dart';
import '../native/guide_intro.dart';
import '../native/customers_page.dart';
import '../native/form_page.dart';
import '../native/gs107_sheet.dart';
import '../native/home_page.dart';
import '../native/mirror_sheet.dart';
import '../native/popup_components.dart';
import '../native/f61_print_sheet.dart';
import '../native/hist115_sheet.dart';
import '../native/photo115_sheet.dart';
import '../native/wa131_sheet.dart';
import '../native/wa138_sheet.dart';
import '../native/rm138s_sheet.dart';
import '../native/rs139_sheet.dart';
import '../native/contacts178_sheet.dart';
import '../native/guide135_sheet.dart';
import '../native/api135_sheet.dart';
import '../native/pay111_sheet.dart';
import '../native/upgrade_pay_modal_sheet.dart';
import '../native/g181_modal_sheet.dart';
import '../native/td175_sheet.dart';
import '../native/order_detail_page.dart';
import '../native/order_status_qr.dart';
import '../native/duration_page.dart';
import '../native/pickservice_page.dart';
import '../native/pickup_page.dart';
import '../native/orderscan_page.dart';
import '../native/qrstatus_page.dart';
import '../native/perfume_page.dart';
import '../native/plan_page.dart';
import '../native/checkout_page.dart';
import '../native/billing_page.dart';
import '../native/invoice_page.dart';
import '../native/orders_page.dart';
import '../native/reports_page.dart';
import '../native/services_page.dart';
import '../native/settings_page.dart';
import 'bridge.dart';

const _brand = Color(0xffe8493f);
const _startPage = 'assets/web/index.html';

class GoyanaHybridApp extends StatelessWidget {
  const GoyanaHybridApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Goyana',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _brand),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const GoyanaShell(),
      );
}

/// Full-screen WebView that runs the final GOYANA HTML exactly as designed,
/// with Android features provided natively through [NativeBridge].
class GoyanaShell extends StatefulWidget {
  const GoyanaShell({super.key});

  @override
  State<GoyanaShell> createState() => _GoyanaShellState();
}

class _GoyanaShellState extends State<GoyanaShell> implements OrderDetailActions, ShellHost, HomeActions, OrdersActions, AddOrderActions, CustomersActions, ReportsActions, SettingsActions, CashActions, CashCloseActions, ServicesActions, FormActions {
  late final WebViewController _web;
  late final NativeBridge _bridge;
  final _device = const MethodChannel('id.goyana/device');
  bool _loading = true;
  bool _brandIntroDone = false;
  bool _guideOpen = false, _guideChecked = false;
  String? _nativePage; // 'home' | 'orders' while a native page covers the WebView
  HomeModel _home = const HomeModel();
  OrdersModel _orders = const OrdersModel();
  AddOrderModel _addOrder = const AddOrderModel();
  CustomersModel _customers = const CustomersModel();
  ReportsModel _reports = const ReportsModel();
  SettingsModel _settings = const SettingsModel();
  CashModel _cash = const CashModel();
  ServicesModel _services = const ServicesModel();
  FormModel _form = const FormModel();
  /// HTML pages drawn by the generic native form (formModel in capacitor.js).
  static const _formPages = {'printer', 'profile', 'customeradd', 'helpcenter', 'outlets', 'outletedit', 'delivery', 'qris',
    'cashier', 'reminder', 'expense', 'printerconnect', 'aboutgoyana', 'auditlog', 'automation', 'datacenter', 'wadevices195', 'whatsappbot', 'branchmonitor58',
    'employees', 'inventory', 'crm', 'ai191', 'blast191', 'quickreply', 'triggers191', 'audit', 'integrations', 'perfume', 'finance', 'duration', 'discount', 'upgrade', 'addbot', 'paymentfinal', 'rp170d', 'barcode', 'notif', 'today187', 'superbilling', 'courier181', 'jemput202', 'jemputnew202', 'ralat139', 'txhist111', 'finreport', 'printlabel'};
  Map<String, dynamic> _cashClose = {};
  String _toast = ''; // HTML toast shown natively while a native page covers the WebView
  String _sheetId = ''; // simple HTML sheet drawn natively over the native page
  bool _sheetFull = false, _sheetScreen = false;
  List<Map<String, dynamic>> _sheetItems = const [];
  Map<String, dynamic>? _sheetOd; // Rincian Pesanan: model khusus (tampilan sama dengan HTML)
  Map<String, dynamic>? _pageMirror; // Halaman yang digambar dari cermin HTML
  bool _scanned = false;
  Map<String, dynamic>? _sheetMirror; // Popup yang digambar dari cermin HTML (ukuran & warna dari CSS)
  Timer? _toastTimer;
  bool _loginBar = false;
  String? _loadError;
  DateTime? _lastBack;
  String? _orderDetailA4BeforeRaw;
  String _orderDetailA4Id = '';
  int _orderDetailA4Seq = 0;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bridge = NativeBridge(this);
    _applyBars();
    _web = WebViewController(onPermissionRequest: _onWebPermission);
    unawaited(_setup());
  }

  Future<void> _setup() async {
    final web = _web;
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setBackgroundColor(Colors.white);
    await web.addJavaScriptChannel('GoyanaNative', onMessageReceived: (m) => _onMessage(m.message));
    await web.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: _onNavigation,
      onPageFinished: (_) {
        if (mounted) setState(() => _loading = false);
      },
      onWebResourceError: (error) {
        if (error.isForMainFrame == true && mounted) {
          setState(() => _loadError = error.description);
        }
      },
    ));
    await web.setOnJavaScriptAlertDialog((request) => _alert(request.message));
    await web.setOnJavaScriptConfirmDialog((request) => _confirm(request.message));
    await web.setOnJavaScriptTextInputDialog(
        (request) => _prompt(request.message, request.defaultText ?? ''));

    final platform = web.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setTextZoom(100); // keep layout identical when the phone font size is large
      await platform.setOnShowFileSelector(_pickFiles);
      await platform.setGeolocationEnabled(true);
      await platform.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final granted = await _requestAccess('location');
          return GeolocationPermissionsResponse(allow: granted, retain: granted);
        },
      );
      // Flutter already keeps the page clear of the navigation bar and keyboard.
      await platform.setInsetsForWebContentToIgnore(const [
        AndroidWebViewInsets.systemBars,
        AndroidWebViewInsets.displayCutout,
        AndroidWebViewInsets.ime,
      ]);
    }
    if (platform is AndroidWebViewController) {
      // Local data lives in SQLite on the phone (window.GoyanaStore), not the small WebView storage.
      try {
        await _device.invokeMethod('Store.attach', {'id': platform.webViewIdentifier});
      } catch (_) {/* falls back to WebView storage */}
    }
    await web.loadFlutterAsset(_startPage);
  }

  // ---------- ShellHost ----------
  @override
  double get statusBarHeight =>
      mounted ? MediaQuery.viewPaddingOf(context).top : 24;

  @override
  void setLoginStatusBar(bool login) {
    _loginBar = login;
    _applyBars();
  }

  @override
  Future<void> exitApp() => SystemNavigator.pop();

  void _applyBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _loginBar ? Brightness.dark : Brightness.light,
      statusBarBrightness: _loginBar ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }

  // ---------- page <-> native ----------
  Future<void> _onMessage(String message) async {
    if (message.startsWith('{"event"')) {
      _onEvent(message);
      return;
    }
    final request = BridgeRequest.parse(message);
    if (request == null) return;
    final result = await _bridge.handle(request);
    if (!mounted) return;
    try {
      await _web.runJavaScript(result.script(request.id));
    } catch (_) {/* page reloaded meanwhile */}
  }

  // ---------- native pages (Flutter) over the HTML app ----------
  void _onEvent(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['event'] != 'native') return;
      _paymentA5Check();
      final page = data['page'] as String?;
      final model = data['model'] is Map ? Map<String, dynamic>.from(data['model'] as Map) : null;
      if (!mounted) return;
      setState(() {
        _nativePage = page;
        if (page == 'cashclose' && model != null) {
          _cashClose = model;
          unawaited(_cashCloseFromDart());
        }
        if (page == 'services' && model != null) _services = ServicesModel.fromJson(model);
        if (_formPages.contains(page) && model != null) _form = FormModel.fromJson(page!, model);
        if (page == 'home' && model != null) {
          _home = HomeModel.fromJson(model);
          _homeFromDart(model);
        }
        if (page == 'orders' && model != null) {
          _orders = OrdersModel.fromJson(model);
          _ordersFromDart(model);
        }
        if (page == 'addorder' && model != null) {
          _addOrder = AddOrderModel.fromJson(model);
          _addorderFromDart(model);
        }
        if (page == 'customers' && model != null) _customers = CustomersModel.fromJson(model);
        if (page == 'reports' && model != null) _reports = ReportsModel.fromJson(model);
        if (page == 'settings' && model != null) _settings = SettingsModel.fromJson(model);
        if ((page == 'cashin' || page == 'cashout') && model != null) _cash = CashModel.fromJson(model);
        _pageMirror = model != null && model['mirror'] is Map ? Map<String, dynamic>.from(model['mirror'] as Map) : null;
        if (page != 'orderscan') _scanned = false;
        final sheet = data['sheet'] is Map ? Map<String, dynamic>.from(data['sheet'] as Map) : null;
        _sheetId = sheet == null ? '' : (sheet['id'] as String? ?? '');
        _sheetFull = sheet?['full'] == true;
        _sheetScreen = sheet?['screen'] == true;
        _sheetOd = sheet?['od'] is Map ? Map<String, dynamic>.from(sheet!['od'] as Map) : null;
        _sheetMirror = sheet?['mirror'] is Map ? Map<String, dynamic>.from(sheet!['mirror'] as Map) : null;
        _sheetItems = sheet == null || sheet['items'] is! List
            ? const []
            : (sheet['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final toast = page == null ? '' : (data['toast'] as String? ?? '');
        if (toast.isNotEmpty && toast != _toast) {
          _toastTimer?.cancel();
          _toastTimer = Timer(const Duration(milliseconds: 2600), () { if (mounted) setState(() => _toast = ''); });
        }
        if (toast.isNotEmpty || page == null) _toast = toast;
      });
      if (page == 'home') unawaited(_maybeShowGuide());
      if (page == 'orders' && _addorderSavePending != null) {
        unawaited(_addorderSaveFromDart());
      }
      final rawSheet = data['sheet'];
      if (page == 'orders' && model != null && rawSheet is Map &&
          rawSheet['id'] == 'g62-order-detail' && rawSheet['od'] is Map) {
        unawaited(_orderDetailA4FromDart(
          Map<String, dynamic>.from(rawSheet),
          model,
        ));
      } else if (page != 'orders') {
        _orderDetailA4BeforeRaw = null;
        _orderDetailA4Id = '';
      }
    } catch (_) {/* ignore malformed events */}
  }

  /// Runs the same HTML element's action. The native view stays until the page reports back (~80 ms):
  /// a new native page, an HTML sheet (then the WebView shows) or updated values — no HTML flash in between.
  void _tap(String selector, [int index = 0, String? child, bool reveal = false]) {
    if (reveal) setState(() => _nativePage = null);
    _web.runJavaScript('window.__goyanaTap&&__goyanaTap(${jsonEncode(selector)},$index,${jsonEncode(child)})');
  }

  @override
  void scan() => _tap('#${_nativePage ?? 'home'} .gy167-scan');
  @override
  void slide(int index) => _tap('#home .gy155-slide', index);
  @override
  void tile(int index) => _tap('#home .gy155-grid button', index);
  @override
  void manageOutlet() => _tap('#home .gy155-manage');
  @override
  void qr() => _tap('#home .gy155-receipt-wrap button');
  @override
  void monthly() => _tap('#home .gy155-omset button');
  @override
  void helpChat() => _tap('#home .help100 button');
  @override
  void nav(String pageId) {
    if (pageId == _nativePage) return;
    // Tabs are native pages: keep the current native page until the next one reports, so the HTML never flashes in between.
    _tap('#nav-$pageId', 0, null, !const {'home', 'orders', 'reports', 'settings'}.contains(pageId));
  }

  // Pesanan
  @override
  void autoSettings() => _tap('#au133btn');
  @override
  void addOrder() => _tap('#orders .g62-searchrow > button');
  @override
  void search(String text) =>
      _web.runJavaScript('window.__goyanaSearch&&__goyanaSearch("#g62-order-search",${jsonEncode(text)})');
  @override
  void tab(int index) => _tap('#orders .g62-tabs button', index, null, false);
  @override
  void openCard(int index) => _tap('#orders .g62-ordercard', index);
  @override
  void cardAction(int index) => _tap('#orders .g62-ordercard', index, '.next91', false);
  @override
  void openMaps(String url) {
    if (url.startsWith('http')) _device.invokeMethod('App.openUrl', {'url': url});
  }

  // Tambah Transaksi
  void _type(String selector, String text) =>
      _web.runJavaScript('window.__goyanaSearch&&__goyanaSearch(${jsonEncode(selector)},${jsonEncode(text)})');
  @override
  void aoBack() => _tap('#addorder .flow61-head .back', 0, null, false);
  @override
  void aoSearchCustomer(String text) => _type('#f61-customer .f61-search input', text);
  @override
  void aoAddCustomer() => _tap('#f61-customer .f61-addcustomer');
  @override
  void aoPickCustomer(int index) => _tap('#f61-customer .f61-person', index, 'button');
  @override
  void aoDuration(int index) => _tap('#dur116 button', index, null, false);
  @override
  void aoSearchService(String text) => _type('#q116', text);
  @override
  void aoCategory(int index) => _tap('#catnav120 button', index, null, false);
  @override
  void aoService(int index) => _tap('#list116 .sv116', index);
  @override
  void aoNext() => _tap('#f61-service-footer > button');

  // Tambah Transaksi: sheet Atur Pesanan & Pembayaran (native)
  String _optLabel(int k) => '#f61-options .f61-sheet > label:nth-of-type(${k + 1})';
  @override
  void aoSheetSelect(int field, int option) =>
      _web.runJavaScript('window.__goyanaSelect&&__goyanaSelect(${jsonEncode('${_optLabel(field)} select')},$option)');
  @override
  void aoSheetSwitch(int field) => _tap('${_optLabel(field)} input', 0, null, false);
  @override
  void aoSheetNote(String text) => _type('#f61-options textarea', text);
  @override
  void aoSheetMain() => _tap('#f61-options .f61-main', 0, null, false);
  @override
  void aoSheetClose() => _tap('#f61-options', 0, null, false);
  @override
  void aoPay(int index) => _tap('#f61-payment .f61-paygrid button', index, null, false);
  @override
  void aoPayCancel() => _tap('#f61-payment .pay-cancel152', 0, null, false);

  // Formulir generik
  void _formAct(String kind, int index, [Object? value]) => _web.runJavaScript(
      'window.__goyanaForm&&__goyanaForm(${jsonEncode(_form.page)},${jsonEncode(kind)},$index,${jsonEncode(value)})');
  @override
  void fmBack() => _tap('#${_form.page} .subhead .back', 0, null, false);
  @override
  void fmInput(int index, Object value) => _formAct('input', index, value);
  @override
  void fmToggle(int index) => _formAct('toggle', index);
  @override
  void fmRadio(int index) => _formAct('radio', index);
  @override
  // The page reports back right after the click (new page, sheet, or updated values), so the native view stays
  // until then instead of flashing the HTML underneath (steppers, tabs and switches tap many times).
  void fmButton(int index) => _formAct('button', index);
  @override
  void fmTap(int index) => _formAct('tap', index);
  void _mirror(String kind, int index, [Object? value]) => _web.runJavaScript(
      'window.__goyanaMirror&&__goyanaMirror(${jsonEncode(_nativePage ?? '')},${jsonEncode(kind)},$index,${jsonEncode(value)})');

  // ---------- Logika Dart (tahap peralihan) ----------
  // Beranda dihitung Dart dari database HP yang sama. Selama HTML masih ada, hasil Dart dipakai bila sama dengan HTML;
  // bila berbeda, tampilan tetap memakai angka HTML dan perbedaannya dicatat (kunci goyana-parity-log) untuk diperbaiki.
  int _homeSeq = 0;
  int _cashCloseSeq = 0;
  Future<void> _cashCloseFromDart() async {
    final seq = ++_cashCloseSeq;
    try {
      final raw = await _web.runJavaScriptReturningResult(
          'JSON.stringify(window.__goyanaCashA7 ? __goyanaCashA7() : null)');
      var text = raw.toString();
      final outer = jsonDecode(text);
      if (outer is String) text = outer;
      final decoded = jsonDecode(text);
      if (decoded is! Map || !mounted || seq != _cashCloseSeq || _nativePage != 'cashclose') return;
      final state = Map<String, dynamic>.from(decoded);
      final summary = cashSummaryA7(state['kas'] as Map);
      const store = DeviceKvStore();
      if (jsonEncode(_canonical(summary)) != jsonEncode(_canonical(state['expected']))) {
        await _parityLog(store, 'cash-a7', state['expected'], summary);
        return;
      }
      final candidate = cashCloseModelA7(state);
      if (jsonEncode(_canonical(candidate)) != jsonEncode(_canonical(state['model']))) {
        await _parityLog(store, 'cashclose-a7', state['model'], candidate);
        return;
      }
      if (!mounted || seq != _cashCloseSeq || _nativePage != 'cashclose') return;
      setState(() => _cashClose = candidate);
    } catch (_) {/* tetap memakai HTML */}
  }

  Future<void> _homeFromDart(Map<String, dynamic> htmlModel) async {
    final seq = ++_homeSeq;
    try {
      const store = DeviceKvStore();
      final b = await Business.load(store);
      final dart = homeModel(b, DateTime.now());
      if (!mounted || seq != _homeSeq) return;
      final html = jsonDecode(jsonEncode(htmlModel));
      final same = jsonEncode(_numbers(jsonDecode(jsonEncode(dart)))) == jsonEncode(_numbers(html));
      if (same) {
        setState(() => _home = HomeModel.fromJson({...htmlModel, ..._numbers(dart)}));
      } else {
        final log = <dynamic>[];
        try {
          final old = jsonDecode(await store.get('goyana-parity-log') ?? '[]');
          if (old is List) log.addAll(old.take(19));
        } catch (_) {}
        log.insert(0, {'at': DateTime.now().toIso8601String(), 'page': 'home', 'html': _numbers(html), 'dart': _numbers(dart)});
        await store.set('goyana-parity-log', jsonEncode(log));
      }
    } catch (_) {/* tetap memakai HTML */}
  }

  // Pesanan dihitung Dart (tab & kata pencarian dari layar yang sama). Bila hasilnya beda dengan HTML, layar tetap memakai HTML
  // dan perbedaannya dicatat; bila sama, layar memakai hasil Dart.
  int _ordersSeq = 0;
  Future<void> _ordersFromDart(Map<String, dynamic> htmlModel) async {
    final seq = ++_ordersSeq;
    try {
      const store = DeviceKvStore();
      final observation = await _web.runJavaScriptReturningResult('JSON.stringify(window.__goyanaStatusA6 ? __goyanaStatusA6() : null)');
      var observationText = observation.toString();
      final outer = jsonDecode(observationText);
      if (outer is String) observationText = outer;
      final state = jsonDecode(observationText);
      if (state is! Map || !mounted || seq != _ordersSeq) return;
      final a6 = Map<String, dynamic>.from(state);
      final plan = statusAutoPlan(a6);
      if (jsonEncode(_canonical(plan)) != jsonEncode(_canonical(a6['expected']))) {
        await _parityLog(store, 'status-a6', a6['expected'], plan);
        return;
      }
      final current = Map<String, dynamic>.from(a6['model'] as Map);
      final b = await Business.load(store);
      final tabs = (current['tabs'] as List? ?? const []);
      final tab = tabs.indexWhere((t) => t is Map && t['on'] == true);
      final dart = ordersModel(b, tab: tab < 0 ? 1 : tab, search: '${current['search'] ?? ''}', now: DateTime.fromMillisecondsSinceEpoch((a6['now'] as num).toInt()), lateDays: (a6['reminderDays'] as num).toInt(), queueEnabled: (a6['rules'] as Map)['q'] == true, queueMinutes: ((a6['rules'] as Map)['qMin'] as num).toDouble(), reminderLog: Map<String, dynamic>.from(a6['log'] as Map));
      if (!mounted || seq != _ordersSeq) return;
      final html = jsonDecode(jsonEncode(current));
      final d = jsonDecode(jsonEncode(dart));
      if (jsonEncode(_stable(d)) == jsonEncode(_stable(html))) {
        setState(() => _orders = OrdersModel.fromJson(Map<String, dynamic>.from(d as Map)));
      } else {
        await _parityLog(store, 'orders', _stable(html), _stable(d));
      }
    } catch (_) {/* tetap memakai HTML */}
  }

  int _addorderSeq = 0;
  Map<String, dynamic>? _addorderSavePending;
  Future<void> _addorderFromDart(Map<String, dynamic> htmlModel) async {
    final seq = ++_addorderSeq;
    if (htmlModel['stage'] != 'services') return;
    try {
      const store = DeviceKvStore();
      final b = await Business.load(store);
      final raw = await _web.runJavaScriptReturningResult(
          'JSON.stringify((function(){'
          'var ds=document.querySelectorAll("#f61-options select")[2];'
          'var perfume=document.querySelector("#f61-options select");'
          'var priority=document.getElementById("f61-priority");'
          'var durationLabel=document.getElementById("f61-duration-label");'
          'var customer=document.querySelector("#f61-services .f61-customerbar div b");'
          'var handover=document.getElementById("f61-handover");'
          'var cart=(typeof f61!=="undefined"&&Array.isArray(f61.cart)?f61.cart:[]);'
          'var duration=(typeof f61!=="undefined"&&f61.dur)||"Reguler";'
          'return {cart:cart,catalog:(typeof catalog158!=="undefined"?catalog158:[]),duration:duration,handover:String(handover?.value||""),discount:{value:String(ds?.value||""),manual:String(ds?.dataset.manual||""),definitions:(Array.isArray(window.DISC127)?window.DISC127:[])},htmlPricing:{discount:(window.disc127?{amt:Number(window.disc127.amt)||0,pct:Number(window.disc127.pct)||0,name:String(window.disc127.name||"")}:null),transport:{fee:(typeof f61!=="undefined"?Number(f61._transport183)||0:0),type:(typeof f61!=="undefined"?String(f61._transportType183||"none"):"none")}},saveDraft:{name:String((typeof pickedName136!=="undefined"&&pickedName136)||customer?.textContent||"Pelanggan"),cart:cart,dur:duration,durationLabel:String(durationLabel?.textContent||duration),total:(typeof f61!=="undefined"?Number(f61.total)||0:0),payamount:String(document.getElementById("f61-payamount")?.textContent||""),priority:Boolean(priority?.checked),handover:String(handover?.value||"Datang Langsung"),perfume:String(perfume?.value||"Tanpa Parfum")}};'
          '})())');
      if (!mounted || seq != _addorderSeq) return;
      var text = raw.toString();
      try {
        final outer = jsonDecode(text);
        if (outer is String) text = outer;
      } catch (_) {}
      final value = jsonDecode(text);
      if (value is! Map) return;
      final draft = Map<String, dynamic>.from(value);
      final presentation = jsonDecode(jsonEncode(htmlModel)) as Map<String, dynamic>;
      final sheet = presentation['sheet'];
      if (sheet is Map && sheet['kind'] == 'payment') {
        final dartPricing = await transactionPricingModel(b, draft);
        if (!mounted || seq != _addorderSeq) return;
        final htmlState = draft['htmlPricing'] is Map
            ? Map<String, dynamic>.from(draft['htmlPricing'] as Map)
            : <String, dynamic>{};
        final htmlPricing = <String, dynamic>{
          'total': '${sheet['total'] ?? ''}',
          'discount': htmlState['discount'],
          'transport': htmlState['transport'],
        };
        final hp = jsonDecode(jsonEncode(htmlPricing));
        final dp = jsonDecode(jsonEncode(dartPricing));
        if (jsonEncode(_stable(dp)) != jsonEncode(_stable(hp))) {
          await _parityLog(store, 'addorder-3b', _stable(hp), _stable(dp));
          return;
        }
        // Hanya setelah paritas 3b sama: angka pembayaran pada model native berasal dari Dart.
        sheet['total'] = dartPricing['total'];

        // A3c: simpan keadaan sebelum HTML finish. HTML tetap menulis sekali lebih dulu;
        // hasil Dart baru boleh mengganti blob yang sama bila snapshot penuh identik.
        final saveDraft = draft['saveDraft'];
        final beforeRaw = await store.get('goyana-business177');
        if (!mounted || seq != _addorderSeq) return;
        if (saveDraft is Map && beforeRaw != null) {
          final beforeValue = jsonDecode(beforeRaw);
          if (beforeValue is Map) {
            final saveStore = <String, dynamic>{};
            for (final key in const [
              'goyana-durations199',
              'goyana-active-outlet180',
              'goyana-outlets180',
            ]) {
              final saved = await store.get(key);
              if (saved != null) saveStore[key] = saved;
            }
            if (!mounted || seq != _addorderSeq) return;
            _addorderSavePending = <String, dynamic>{
              'before': Map<String, dynamic>.from(beforeValue),
              'draft': Map<String, dynamic>.from(saveDraft),
              'store': saveStore,
            };
            // Menutup celah bila pengguna sangat cepat menekan metode bayar.
            if (_nativePage == 'orders') unawaited(_addorderSaveFromDart());
          }
        }
      }
      final dart = addorderModel(b, draft, presentation);
      final html = jsonDecode(jsonEncode(htmlModel));
      final d = jsonDecode(jsonEncode(dart));
      if (jsonEncode(_stable(d)) == jsonEncode(_stable(html))) {
        setState(() => _addOrder = AddOrderModel.fromJson(Map<String, dynamic>.from(d as Map)));
      } else {
        await _parityLog(store, 'addorder', _stable(html), _stable(d));
      }
    } catch (_) {/* tetap memakai HTML */}
  }

  Future<void> _addorderSaveFromDart() async {
    final pending = _addorderSavePending;
    if (pending == null) return;
    // Event native dapat muncul lebih dari sekali; hanya satu guard yang boleh memproses transaksi ini.
    _addorderSavePending = null;
    try {
      const store = DeviceKvStore();
      final before = Map<String, dynamic>.from(pending['before'] as Map);
      final saveDraft = Map<String, dynamic>.from(pending['draft'] as Map);
      final saveStore = Map<String, dynamic>.from(pending['store'] as Map);
      final beforeOrders = before['orders'] is List
          ? List<dynamic>.from(before['orders'] as List)
          : const <dynamic>[];

      Map<String, dynamic>? html;
      // GoyanaStore menulis ke SQLite; beri waktu singkat sampai hasil HTML benar-benar terlihat.
      for (var attempt = 0; attempt < 12; attempt++) {
        final raw = await store.get('goyana-business177');
        if (raw != null) {
          final value = jsonDecode(raw);
          if (value is Map) {
            final candidate = Map<String, dynamic>.from(value);
            final orders = candidate['orders'] as List? ?? const [];
            if (orders.length == beforeOrders.length + 1) {
              html = candidate;
              break;
            }
          }
        }
        if (attempt < 11) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      if (html == null) return; // batal/kembali tanpa menyimpan: HTML dibiarkan apa adanya.

      String orderId(Object? raw) {
        if (raw is! Map) return '';
        final fields = raw['fields'];
        if (fields is! List || fields.length < 2) return '';
        final code = fields[1];
        return code is List && code.isNotEmpty ? '${code.first}' : '';
      }

      final htmlOrders = html['orders'] as List? ?? const [];
      if (htmlOrders.isEmpty) return;
      final newCardRaw = htmlOrders.first;
      if (newCardRaw is! Map) return;
      final id = orderId(newCardRaw);
      if (id.isEmpty || beforeOrders.any((o) => orderId(o) == id)) return;
      final dataset = newCardRaw['dataset'];
      if (dataset is! Map) return;
      final now = DateTime.tryParse('${dataset['created177'] ?? ''}');
      if (now == null) return;
      final paid = '${dataset['paid177'] ?? '0'}';
      saveDraft['method'] = paid == '0'
          ? 'Bayar Nanti'
          : '${dataset['method177'] ?? ''}';

      final dart = prepareAddOrderSave(
        before: before,
        draft: saveDraft,
        store: saveStore,
        now: now,
        localOffset: now.toLocal().timeZoneOffset,
      );
      final h = jsonDecode(jsonEncode(html));
      final d = jsonDecode(jsonEncode(dart));
      // Sama: tidak menulis apa pun (isinya identik; menulis ulang bisa menimpa perubahan HTML sesaat sesudahnya,
      // contoh penanda hitung mundur w133/ts133). Beda: catat ke goyana-parity-log, HTML tetap dipakai.
      if (jsonEncode(_canonical(d)) != jsonEncode(_canonical(h))) {
        await _parityLog(store, 'addorder-3c', _canonical(h), _canonical(d));
      }
    } on UnsupportedError {
      // Jalur di luar fixture 3c tetap sepenuhnya memakai hasil HTML.
    } catch (_) {/* tetap memakai HTML */}
  }

  Future<void> _orderDetailA4FromDart(
      Map<String, dynamic> htmlDetail, Map<String, dynamic> htmlOrders) async {
    final seq = ++_orderDetailA4Seq;
    try {
      final od = htmlDetail['od'];
      if (od is! Map) return;
      final sub = '${od['sub'] ?? ''}';
      final split = sub.indexOf(' · ');
      final id = (split < 0 ? sub : sub.substring(0, split)).trim();
      if (id.isEmpty) return;

      const store = DeviceKvStore();
      final current = await store.get(Keys.business);
      if (current == null || !mounted || seq != _orderDetailA4Seq) return;

      var candidateRaw = current;
      var paymentChange = false;
      final beforeRaw = _orderDetailA4BeforeRaw;
      final sameOrder = _orderDetailA4Id == id;
      if (beforeRaw != null && sameOrder && beforeRaw != current) {
        final before = <String, dynamic>{Keys.business: beforeRaw};
        final after = <String, dynamic>{Keys.business: current};
        final action = inferOrderDetailA4Action(
          before: before,
          after: after,
          orderId: id,
        );
        final payment = action == null
            ? inferPaymentA5Action(before: before, after: after, orderId: id)
            : null;
        if (action == null && payment == null) {
          _orderDetailA4BeforeRaw = current;
          _orderDetailA4Id = id;
          return;
        }
        final candidate = action != null
            ? applyOrderDetailA4(before: before, action: action)
            : applyPaymentA5(before: before, action: payment!);
        paymentChange = payment != null;
        candidateRaw = candidate[Keys.business] as String;
        final hStore = jsonDecode(current);
        final dStore = jsonDecode(candidateRaw);
        if (jsonEncode(_canonical(hStore)) != jsonEncode(_canonical(dStore))) {
          await _parityLog(store, action == null ? 'payment-a5' : 'order-detail-a4',
              {'store': _canonical(hStore)}, {'store': _canonical(dStore)});
          _orderDetailA4BeforeRaw = current;
          _orderDetailA4Id = id;
          return;
        }
      }

      final dartDetail = orderDetailA4Model(
        store: <String, dynamic>{Keys.business: candidateRaw},
        orderId: id,
        presentation: htmlDetail,
        preserveSavedBanner: paymentChange,
      );
      final business = await Business.load(store);
      final tabs = htmlOrders['tabs'] as List? ?? const [];
      final selected = tabs.indexWhere((t) => t is Map && t['on'] == true);
      final dartOrders = ordersModel(
        business,
        tab: selected < 0 ? 1 : selected,
        search: '${htmlOrders['search'] ?? ''}',
        now: DateTime.now(),
      );
      if (!mounted || seq != _orderDetailA4Seq) return;

      final hDetail = jsonDecode(jsonEncode(htmlDetail));
      final dDetail = jsonDecode(jsonEncode(dartDetail));
      final hOrders = jsonDecode(jsonEncode(htmlOrders));
      final dOrders = jsonDecode(jsonEncode(dartOrders));
      final sameDetail = jsonEncode(_canonical(dDetail)) == jsonEncode(_canonical(hDetail));
      final sameOrders = jsonEncode(_stable(dOrders)) == jsonEncode(_stable(hOrders));
      if (sameDetail && sameOrders) {
        setState(() {
          _sheetOd = Map<String, dynamic>.from(dartDetail['od'] as Map);
          _orders = OrdersModel.fromJson(Map<String, dynamic>.from(dartOrders));
        });
      } else {
        await _parityLog(store, 'order-detail-a4',
            {'detail': _canonical(hDetail), 'orders': _stable(hOrders)},
            {'detail': _canonical(dDetail), 'orders': _stable(dOrders)});
      }
      _orderDetailA4BeforeRaw = current;
      _orderDetailA4Id = id;
    } on UnsupportedError catch (_) {
      // Status di luar patokan A4 tetap memakai HTML.
    } catch (_) {/* tetap memakai HTML */}
  }

  int _paymentA5Seq = 0;
  String? _paymentA5Before;
  Future<void> _paymentA5Check() async {
    final seq = ++_paymentA5Seq;
    try {
      const store = DeviceKvStore();
      final raw = await store.get(Keys.business);
      if (raw == null || !mounted || seq != _paymentA5Seq) return;
      final previous = _paymentA5Before;
      _paymentA5Before = raw;
      if (previous == null || previous == raw) return;
      final before = <String, dynamic>{Keys.business: previous};
      final after = <String, dynamic>{Keys.business: raw};
      final action = inferPaymentA5Action(before: before, after: after);
      if (action == null) {
        return; // Hanya satu aksi yang dapat diturunkan dari patokan.
      }
      final candidate = applyPaymentA5(before: before, action: action);
      final expected = _canonical(
        jsonDecode(candidate[Keys.business] as String),
      );
      final actual = _canonical(jsonDecode(raw));
      if (jsonEncode(expected) != jsonEncode(actual)) {
        await _parityLog(store, 'payment-a5', actual, expected);
      }
    } catch (_) {
      /* transaksi di luar patokan tetap memakai HTML */
    }
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
      return {for (final e in entries) '${e.key}': _canonical(e.value)};
    }
    if (value is List) return [for (final x in value) _canonical(x)];
    return value;
  }

  /// Bagian yang dibandingkan: semuanya kecuali hitung mundur otomatis (berubah tiap menit).
  static Object? _stable(Object? m) {
    if (m is Map) return {for (final e in m.entries) '${e.key}': (e.key == 'auto' && m.containsKey('id')) ? null : _stable(e.value)};
    if (m is List) return [for (final x in m) _stable(x)];
    return m;
  }

  Future<void> _parityLog(KvStore store, String page, Object? html, Object? dart) async {
    final log = <dynamic>[];
    try {
      final old = jsonDecode(await store.get('goyana-parity-log') ?? '[]');
      if (old is List) log.addAll(old.take(19));
    } catch (_) {}
    log.insert(0, {'at': DateTime.now().toIso8601String(), 'page': page, 'html': html, 'dart': dart});
    await store.set('goyana-parity-log', jsonEncode(log));
  }

  static Map<String, dynamic> _numbers(Object? m) {
    final x = m is Map ? m : const {};
    return {for (final k in const ['statIn', 'statReady', 'statLate', 'today', 'badge']) k: '${x[k] ?? ''}'};
  }

  @override
  void odButton(int index) => fmScoped('g62-order-detail', 'button', index);
  @override
  void odTap(int index) => fmScoped('g62-order-detail', 'tap', index);
  @override
  void odClose() {
    _orderDetailA4BeforeRaw = null;
    _orderDetailA4Id = '';
    fmScoped('g62-order-detail', 'close', 0);
  }

  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) => _web.runJavaScript(
      'window.__goyanaForm&&__goyanaForm(${jsonEncode(scope)},${jsonEncode(kind)},$index,${jsonEncode(value)})');

  @override
  Future<void> fmFile(String inputId) async {
    try {
      final uris = await _device.invokeListMethod<String>('Files.pick', {'accept': ['image/png', 'image/jpeg', 'image/webp'], 'multiple': false, 'capture': false});
      if (uris == null || uris.isEmpty) return;
      final f = await _device.invokeMapMethod<String, dynamic>('Files.read', {'uri': uris.first});
      if (f == null) return;
      await _web.runJavaScript('window.__goyanaFile&&__goyanaFile(${jsonEncode(inputId)},${jsonEncode(f['name'])},${jsonEncode(f['mime'])},${jsonEncode(f['data'])})');
    } catch (_) {
      setState(() => _toast = 'File tidak dapat dibaca');
    }
  }

  // Layanan
  @override
  void svBack() => _tap('#services .subhead .back', 0, null, false);
  @override
  void svSearch(String text) => _type('#services .bar99 input', text);
  @override
  void svAdd() => _tap('#services .bar99 button');
  @override
  void svEdit(int index) => _tap('#cat99-list .cat99', index, '.cat99-h button');
  @override
  void svToggle(int index, int variant) =>
      _web.runJavaScript('window.__goyanaTapIn&&__goyanaTapIn("#cat99-list .cat99",$index,".v99 input",$variant)');

  // Pelanggan
  @override
  void cuBack() => _tap('#customers .cust59-head .back', 0, null, false);
  @override
  void cuSearch(String text) => _type('#cust59-search', text);
  @override
  void cuDeposit() => _tap('#customers .depositshortcut180');
  @override
  void cuAdd() => _tap('#customers .cust59-add');
  @override
  void cuToggleDb() => _tap('#customers .cust59-dbbtn', 0, null, false);
  @override
  void cuFilter() => _tap('#customers .cust59-dbhead button');
  @override
  void cuTopUp(int index) => _tap('#cust59-db .cust59-row', index, '.balance180 button');
  @override
  void cuEdit(int index) => _tap('#cust59-db .cust59-row', index, '.gy154-edit');
  @override
  void cuPage(int delta) => _tap(delta < 0 ? '#pg138-p' : '#pg138-n', 0, null, false);
  @override
  void cuRank() => _tap('#rk138btn');
  @override
  void cuCrm() => _tap('#customers .crm130-entry');

  // Laporan
  @override
  void rpOutlet() => _tap('#reports .g62-outlet');
  @override
  void rpPeriod(int index) => _tap('#reports .rp170-per button', index, null, false);
  @override
  void rpKpi(int index) => _tap('#reports .rp170-kp button', index);
  @override
  void rpQuick(int index) => _tap('#reports .rp170-qa button', index);
  @override
  void rpSearch(String text) => _type('#rp170-q', text);
  @override
  void rpCategory(int index) => _tap('#reports .rp170-cat button', index, null, false);
  @override
  void rpOpen(int index) => _tap('#reports .rp170-it', index);

  // Pengaturan
  @override
  void stGroup(int index, bool accordion) => _tap('#st178 > .setting178', index, ':scope > button', !accordion);
  @override
  void stItem(int group, int item) => _tap('#st178 > .setting178', group, '.st171-b > button:nth-child(${item + 1})');
  @override
  void stSyncUrl(String url) => _type('#sync197 .s197-url', url);
  @override
  void stSyncSave() => _tap('#sync197 .s197-save', 0, null, false);
  @override
  void stSyncNow() => _tap('#sync197 .s197-now', 0, null, false);
  @override
  void stAcctGo() => _tap('#settings .acct117-go');
  @override
  void stAcctAction(int index) => _tap('#settings .acct92-act button', index);
  @override
  void stAcctLink() => _tap('#settings .acct92-link');
  @override
  void stLogout() => _tap('#settings .lo167');
  /// Five-slide guide: once, as soon as the owner's Beranda appears for the first time
  /// (right after the first outlet is created), after the opening animation has finished.
  Future<void> _maybeShowGuide() async {
    if (_guideChecked || !_brandIntroDone) return;
    _guideChecked = true;
    try {
      final seen = await const DeviceKvStore().get(guideSeenKey);
      if (seen == null && mounted) setState(() => _guideOpen = true);
    } catch (_) {/* storage problem: skip the guide rather than block the app */}
  }

  @override
  void stTutorial() => setState(() => _guideOpen = true);

  @override
  void ccTap(String selector, int index, String? child) => _tap(selector, index, child, false);
  @override
  void ccType(String selector, String value) => _type(selector, value);

  // Kas Masuk / Pengeluaran
  String get _cashPage => _nativePage == 'cashout' ? '#cashout' : '#cashin';
  @override
  void caBack() => _tap('$_cashPage .subhead .back', 0, null, false);
  @override
  void caType(String option) => _type('$_cashPage select.cash-input', option);
  @override
  void caAmount(String text) => _type('$_cashPage .cash-input-group input', text);
  @override
  void caNote(String text) => _type('$_cashPage .cash-form-wrap > label:nth-child(3) input', text);
  @override
  void caSubmit() => _tap('$_cashPage .cash-submit', 0, null, false);

  Future<NavigationDecision> _onNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'file' || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }
    // WhatsApp, Maps, phone, payment and other links open outside the app,
    // so the cashier screen and its data stay where they were.
    try {
      await _device.invokeMethod('App.openUrl', {'url': request.url});
    } catch (_) {}
    return NavigationDecision.prevent;
  }

  Future<bool> _requestAccess(String alias) async {
    try {
      final r = await _device.invokeMapMethod<String, dynamic>(
          'GoyanaDevice.requestAccess', {'alias': alias});
      return r?['granted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onWebPermission(WebViewPermissionRequest request) async {
    final wantsCamera = request.types.contains(WebViewPermissionResourceType.camera);
    final wantsMic = request.types.contains(WebViewPermissionResourceType.microphone);
    if (wantsMic && !wantsCamera) {
      await request.deny();
      return;
    }
    if (await _requestAccess('camera')) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final list = await _device.invokeListMethod<String>('Files.pick', {
        'accept': params.acceptTypes,
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'capture': params.isCaptureEnabled,
      });
      return list ?? const [];
    } catch (_) {
      return const [];
    }
  }

  // ---------- native dialogs for alert/confirm/prompt ----------
  Future<void> _alert(String message) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(message),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String> _prompt(String message, String initial) async {
    final field = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message),
          TextField(controller: field, autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, field.text), child: const Text('OK')),
        ],
      ),
    );
    field.dispose();
    return value ?? '';
  }

  // ---------- hardware back ----------
  Future<void> _onBack() async {
    if (_guideOpen) {
      // Back on the guide = skip it (same as "Lewati").
      try { await const DeviceKvStore().set(guideSeenKey, '1'); } catch (_) {/* storage problem: the guide just shows once more */}
      if (mounted) setState(() => _guideOpen = false);
      return;
    }
    String action = 'exit';
    try {
      final r = await _web.runJavaScriptReturningResult(
          'window.__goyanaBack?window.__goyanaBack():"exit"');
      action = r.toString().replaceAll('"', '');
    } catch (_) {}
    if (action == 'handled') {
      _lastBack = null;
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Tekan kembali sekali lagi untuk keluar'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Keyboard open: lift the page above it. Otherwise keep clear of the
    // gesture/navigation bar, like the Capacitor build did.
    final bottom = media.viewInsets.bottom > 0 ? media.viewInsets.bottom : media.viewPadding.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: EdgeInsets.only(
            bottom: bottom,
            left: media.viewPadding.left,
            right: media.viewPadding.right,
          ),
          // Ruang keyboard sudah diberikan oleh padding di atas: layar & popup di dalamnya tidak menambahkannya lagi
          // (dulu terhitung dua kali sehingga popup terpotong di atas).
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Stack(children: [
            // While the native Beranda covers the screen, the WebView is taken out of the
            // frame (kept alive, scripts keep running). Drawing Flutter on top of a visible
            // Android WebView forces two layers per frame and makes scrolling heavy.
            Positioned.fill(
              child: Offstage(
                offstage: _nativePage != null && !_loading,
                child: WebViewWidget.fromPlatformCreationParams(
                params: AndroidWebViewWidgetCreationParams(
                  controller: _web.platform,
                  displayWithHybridComposition: true,
                ),
              ),
              ),
            ),
            // Native Flutter Beranda over the HTML app (kept alive underneath).
            if (_nativePage == 'home' && !_loading)
              Positioned.fill(child: NativeHome(model: _home, actions: this)),
            if (_nativePage == 'orders' && !_loading)
              Positioned.fill(child: NativeOrders(model: _orders, actions: this)),
            if ((_nativePage == 'cashin' || _nativePage == 'cashout') && !_loading)
              Positioned.fill(child: NativeCash(key: ValueKey(_nativePage), model: _cash, actions: this)),
            if (_nativePage == 'plan111' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativePlanPage(
                  key: const ValueKey('native-plan111'),
                  model: _pageMirror!,
                  pricingItems: _form.page == 'upgrade' ? _form.items : const [],
                  onButton: (i) => _mirror('button', i),
                  onPricingButton: (i) {
                    if (_form.page == 'upgrade') _formAct('button', i);
                  },
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage == 'checkout111' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeCheckoutPage(
                  key: const ValueKey('native-checkout111'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onInput: (i, value) => _mirror('input', i, value),
                  onNav: nav,
                  onHeaderScan: () {
                    final scan = _pageMirror?['scan'];
                    if (scan is num && scan.isFinite && scan >= 0) _mirror('button', scan.toInt());
                  },
                ),
              ),
            if (_nativePage == 'billing' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeBillingPage(
                  key: const ValueKey('native-billing'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final scan = _pageMirror?['scan'];
                    if (scan is num && scan.isFinite && scan >= 0) _mirror('button', scan.toInt());
                  },
                ),
              ),
            if (_nativePage == 'invoice111' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeInvoicePage(
                  key: const ValueKey('native-invoice111'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final scan = _pageMirror?['scan'];
                    if (scan is num && scan.isFinite && scan >= 0) _mirror('button', scan.toInt());
                  },
                ),
              ),
            if (_nativePage == 'perfume' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativePerfumePage(
                  key: const ValueKey('native-perfume'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage == 'duration' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeDurationPage(
                  key: const ValueKey('native-duration'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage == 'pickservice' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativePickservicePage(
                  key: const ValueKey('native-pickservice'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage == 'pickup' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativePickupPage(
                  key: const ValueKey('native-pickup'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage == 'orderscan' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeOrderscanPage(
                  key: const ValueKey('native-orderscan'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onInput: (i, v) => _mirror('input', i, v),
                  cameraBuilder: (_) => MobileScanner(onDetect: (capture) {
                      final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                      if (code == null || _scanned) return;
                      _scanned = true;
                      _mirror('scan', 0, code);
                    }),
                ),
              ),
            if (_nativePage == 'qrstatus' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeQrstatusPage(
                  key: const ValueKey('native-qrstatus'),
                  model: _pageMirror!,
                  onButton: (i) => _mirror('button', i),
                  onInput: (i, v) => _mirror('input', i, v),
                  onNav: nav,
                  onHeaderScan: () {
                    final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1;
                    if (i >= 0) _mirror('button', i);
                  },
                ),
              ),
            if (_nativePage != null && _nativePage != 'plan111' && _nativePage != 'checkout111' && _nativePage != 'billing' && _nativePage != 'invoice111' && _nativePage != 'perfume' && _nativePage != 'duration' && _nativePage != 'pickservice' && _nativePage != 'pickup' && _nativePage != 'orderscan' && _nativePage != 'qrstatus' && _pageMirror != null && !_loading)
              Positioned.fill(
                child: NativeMirrorPage(
                  key: ValueKey('mirror-page-$_nativePage'), model: _pageMirror!,
                  env: MirrorEnv(
                    onButton: (i) => _mirror('button', i),
                    onTap: (i) => _mirror('tap', i),
                    onInput: (i, v) => _mirror('input', i, v),
                    video: (_) => MobileScanner(onDetect: (capture) {
                      final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                      if (code == null || _scanned) return;
                      _scanned = true;
                      _mirror('scan', 0, code);
                    }),
                  ),
                  onNav: nav,
                  onHeaderScan: () { final i = (_pageMirror?['scan'] as num?)?.toInt() ?? -1; if (i >= 0) _mirror('button', i); },
                ),
              ),
            if (_formPages.contains(_nativePage) && _pageMirror == null && !_loading)
              Positioned.fill(child: NativeForm(key: ValueKey(_nativePage), model: _form, actions: this, navActive: const {'rp170d': 2, 'ralat139': 2, 'finreport': 2, 'customeradd': 0, 'crm': 0, 'today187': 1, 'notif': 0, 'printlabel': 1}[_nativePage] ?? 3)),
            if (_nativePage == 'services' && !_loading)
              Positioned.fill(child: NativeServices(model: _services, actions: this)),
            if (_nativePage == 'cashclose' && !_loading)
              Positioned.fill(child: NativeCashClose(model: _cashClose, actions: this)),
            if (_nativePage == 'settings' && !_loading)
              Positioned.fill(child: NativeSettings(model: _settings, actions: this)),
            if (_nativePage == 'reports' && !_loading)
              Positioned.fill(child: NativeReports(model: _reports, actions: this)),
            if (_nativePage == 'customers' && !_loading)
              Positioned.fill(child: NativeCustomers(model: _customers, actions: this)),
            if (_nativePage == 'addorder' && !_loading)
              Positioned.fill(child: NativeAddOrder(model: _addOrder, actions: this)),
            if (_nativePage != null && _sheetId == 'g62-order-detail' && _sheetOd != null && !_loading)
              Positioned.fill(child: NativeOrderDetail(
                model: _sheetOd!, actions: this,
                onQrStatus: orderStatusId(_sheetOd!) == null ? null : () {
                  final detail = _sheetOd;
                  if (detail == null) return;
                  final id = orderStatusId(detail);
                  if (id == null) return;
                  final customer = detail['customer'];
                  showModalBottomSheet<void>(
                    context: context, isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (context) => NativeOrderStatusQr(
                      orderId: id,
                      customerName: customer is Map && customer['name'] is String ? customer['name'] as String : '',
                      onClose: () => Navigator.pop(context),
                    ),
                  );
                },
              ))
            else if (_nativePage != null && _sheetId == 'f61-print' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeF61PrintSheet(
                key: const ValueKey('native-f61-print'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'hist115' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeHist115Sheet(
                key: const ValueKey('native-hist115'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'photo115' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativePhoto115Sheet(
                key: const ValueKey('native-photo115'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'wa131' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeWa131Sheet(
                key: const ValueKey('native-wa131'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'wa138' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeWa138Sheet(
                key: const ValueKey('native-wa138'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'rm138s' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeRm138sSheet(
                key: const ValueKey('native-rm138s'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'rs139' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeRs139Sheet(
                key: const ValueKey('native-rs139'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'contacts178' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeContacts178Sheet(
                key: const ValueKey('native-contacts178'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'guide135' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeGuide135Sheet(
                key: const ValueKey('native-guide135'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'api135' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeApi135Sheet(
                key: const ValueKey('native-api135'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'pay111' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativePay111Sheet(
                key: const ValueKey('native-pay111'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'upgrade-pay-modal' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeUpgradePaySheet(
                key: const ValueKey('native-upgrade-pay-modal'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'g181-modal' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeG181ModalSheet(
                key: const ValueKey('native-g181-modal'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'td175' && _sheetMirror != null && !_loading)
              Positioned.fill(child: NativeTd175Sheet(
                key: const ValueKey('native-td175'), model: _sheetMirror!,
                actions: PopupActions(id: _sheetId,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i,v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0)),
              ))
            else if (_nativePage != null && _sheetId == 'cat99' && _sheetMirror != null && !_loading)
              Positioned.fill(
                child: NativeCat99Sheet(
                  key: const ValueKey('native-cat99'), model: _sheetMirror!,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onInput: (i, v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0),
                ),
              )
            else if (_nativePage != null && _sheetId == 'gs107' && _sheetMirror != null && !_loading)
              Positioned.fill(
                child: NativeGs107Sheet(
                  key: const ValueKey('native-gs107'), model: _sheetMirror!,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onInput: (i, v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0),
                ),
              )
            else if (_nativePage != null && _sheetMirror != null && !_loading)
              Positioned.fill(
                child: NativeMirrorSheet(
                  key: ValueKey('mirror-$_sheetId'), model: _sheetMirror!,
                  onButton: (i) => fmScoped(_sheetId, 'button', i),
                  onTap: (i) => fmScoped(_sheetId, 'tap', i),
                  onInput: (i, v) => fmScoped(_sheetId, 'input', i, v),
                  onClose: () => fmScoped(_sheetId, 'close', 0),
                ),
              )
            else if (_nativePage != null && _sheetItems.isNotEmpty && !_loading)
              Positioned.fill(child: NativeSheet(key: ValueKey('sheet-$_sheetId'), id: _sheetId, items: _sheetItems, actions: this, full: _sheetFull, screen: _sheetScreen)),
            if (_nativePage != null && _toast.isNotEmpty && !_loading)
              Positioned(
                left: 24, right: 24, bottom: 130,
                child: IgnorePointer(child: Center(child: NativeToast(text: _toast))),
              ),
            if (_guideOpen && _brandIntroDone && _loadError == null)
              Positioned.fill(key: const ValueKey('guide-intro-overlay'), child: GuideIntro(onDone: () {
                if (mounted) setState(() => _guideOpen = false);
              })),
            if (!_brandIntroDone && _loadError == null)
              Positioned.fill(key: const ValueKey('brand-intro-overlay'), child: BrandIntro(ready: !_loading, onDone: () {
                if (mounted) { setState(() => _brandIntroDone = true); }
                if (_nativePage == 'home') unawaited(_maybeShowGuide());
              })),
            if (_loadError != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Aplikasi gagal dimuat',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _loadError = null;
                              _loading = true;
                            });
                            _web.loadFlutterAsset(_startPage);
                          },
                          child: const Text('Muat ulang'),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          ),
        ),
      ),
    );
  }
}
