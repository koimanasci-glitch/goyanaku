import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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

class _GoyanaShellState extends State<GoyanaShell> implements ShellHost {
  late final WebViewController _web;
  late final NativeBridge _bridge;
  final _device = const MethodChannel('id.goyana/device');
  bool _loading = true;
  bool _loginBar = false;
  String? _loadError;
  DateTime? _lastBack;

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
    final request = BridgeRequest.parse(message);
    if (request == null) return;
    final result = await _bridge.handle(request);
    if (!mounted) return;
    try {
      await _web.runJavaScript(result.script(request.id));
    } catch (_) {/* page reloaded meanwhile */}
  }

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
            Positioned.fill(
              child: WebViewWidget.fromPlatformCreationParams(
                params: AndroidWebViewWidgetCreationParams(
                  controller: _web.platform,
                  displayWithHybridComposition: true,
                ),
              ),
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
