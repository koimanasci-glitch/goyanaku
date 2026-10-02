import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../native/addorder_page.dart';
import '../native/cash_page.dart';
import '../native/cashclose_page.dart';
import '../native/common.dart';
import '../native/customers_page.dart';
import '../native/home_page.dart';
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

class _GoyanaShellState extends State<GoyanaShell> implements ShellHost, HomeActions, OrdersActions, AddOrderActions, CustomersActions, ReportsActions, SettingsActions, CashActions, CashCloseActions, ServicesActions {
  late final WebViewController _web;
  late final NativeBridge _bridge;
  final _device = const MethodChannel('id.goyana/device');
  bool _loading = true;
  String? _nativePage; // 'home' | 'orders' while a native page covers the WebView
  HomeModel _home = const HomeModel();
  OrdersModel _orders = const OrdersModel();
  AddOrderModel _addOrder = const AddOrderModel();
  CustomersModel _customers = const CustomersModel();
  ReportsModel _reports = const ReportsModel();
  SettingsModel _settings = const SettingsModel();
  CashModel _cash = const CashModel();
  ServicesModel _services = const ServicesModel();
  Map<String, dynamic> _cashClose = {};
  String _toast = ''; // HTML toast shown natively while a native page covers the WebView
  Timer? _toastTimer;
  bool _loginBar = false;
  String? _loadError;
  DateTime? _lastBack;

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
      final page = data['page'] as String?;
      final model = data['model'] is Map ? Map<String, dynamic>.from(data['model'] as Map) : null;
      if (!mounted) return;
      setState(() {
        _nativePage = page;
        if (page == 'cashclose' && model != null) _cashClose = model;
        if (page == 'services' && model != null) _services = ServicesModel.fromJson(model);
        if (page == 'home' && model != null) _home = HomeModel.fromJson(model);
        if (page == 'orders' && model != null) _orders = OrdersModel.fromJson(model);
        if (page == 'addorder' && model != null) _addOrder = AddOrderModel.fromJson(model);
        if (page == 'customers' && model != null) _customers = CustomersModel.fromJson(model);
        if (page == 'reports' && model != null) _reports = ReportsModel.fromJson(model);
        if (page == 'settings' && model != null) _settings = SettingsModel.fromJson(model);
        if ((page == 'cashin' || page == 'cashout') && model != null) _cash = CashModel.fromJson(model);
        final toast = page == null ? '' : (data['toast'] as String? ?? '');
        if (toast.isNotEmpty && toast != _toast) {
          _toastTimer?.cancel();
          _toastTimer = Timer(const Duration(milliseconds: 2600), () { if (mounted) setState(() => _toast = ''); });
        }
        if (toast.isNotEmpty || page == null) _toast = toast;
      });
    } catch (_) {/* ignore malformed events */}
  }

  /// Runs the same HTML element's action, then shows the HTML app while it opens.
  void _tap(String selector, [int index = 0, String? child, bool reveal = true]) {
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
    _tap('#nav-$pageId');
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
  @override
  void stTutorial() => _tap('#tutorial189-open');

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
            if (_nativePage != null && _toast.isNotEmpty && !_loading)
              Positioned(
                left: 24, right: 24, bottom: 130,
                child: IgnorePointer(child: Center(child: NativeToast(text: _toast))),
              ),
            if (_loading && _loadError == null)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: CircularProgressIndicator(color: _brand)),
                ),
              ),
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
    );
  }
}
