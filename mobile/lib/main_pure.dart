import 'package:flutter/material.dart';

import 'core/store.dart';
import 'native/brand_intro.dart';
import 'native/guide_intro.dart';
import 'pure/pure_shell.dart';

/// Pintu masuk "Mode Murni": seluruh aplikasi dari Dart, tanpa WebView/HTML.
/// Membaca kunci penyimpanan yang sama dengan versi hybrid.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GOYANA',
    home: PureApp(store: DeviceKvStore()),
  ));
}

/// Mode Murni dengan pembuka yang sama dengan Hibrida: animasi merpati GOYANA setiap aplikasi dibuka,
/// lalu panduan lima slide sekali saja di HP ini. Aplikasi dimuat di belakang animasi, jadi tidak menambah waktu tunggu.
class PureApp extends StatefulWidget {
  const PureApp({super.key, required this.store});
  final KvStore store;
  @override
  State<PureApp> createState() => _PureAppState();
}

class _PureAppState extends State<PureApp> {
  bool _introDone = false, _guideOpen = false;

  Future<void> _afterIntro() async {
    if (!mounted) return;
    setState(() => _introDone = true);
    String? seen;
    try {
      seen = await widget.store.get(guideSeenKey);
    } catch (_) {
      return; // penyimpanan bermasalah: panduan dilewati, aplikasi tetap terbuka
    }
    if (seen == null && mounted) setState(() => _guideOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PureShell(store: widget.store),
        if (_guideOpen && _introDone)
          Positioned.fill(
            key: const ValueKey('guide-intro-overlay'),
            child: Material(
              type: MaterialType.transparency,
              child: GuideIntro(
                store: widget.store,
                onDone: () {
                  if (mounted) setState(() => _guideOpen = false);
                },
              ),
            ),
          ),
        if (!_introDone)
          Positioned.fill(
            key: const ValueKey('brand-intro-overlay'),
            child: Material(
              type: MaterialType.transparency,
              child: BrandIntro(ready: true, store: widget.store, onDone: _afterIntro),
            ),
          ),
      ],
    );
  }
}
