import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'home_icons.dart';

// Shared look of native GOYANA pages (same values as the HTML CSS).
const gInk = Color(0xff27323e);
const gBrand = Color(0xffe8493f);
const gFont = 'Poppins';

TextStyle gText(double size, {FontWeight w = FontWeight.w400, Color c = const Color(0xff17191d), double? h, double ls = 0}) =>
    TextStyle(fontFamily: gFont, fontSize: size, fontWeight: w, color: c, height: h == null ? null : h / size, letterSpacing: ls);

BoxShadow gShadow(Color c, double y, double blur) => BoxShadow(color: c, offset: Offset(0, y), blurRadius: blur);

Widget gSvg(String s, double size, {double? h}) => SvgPicture.string(s, width: size, height: h ?? size);

/// Parses CSS colors from the web app ("rgb(1, 2, 3)", "rgba(1, 2, 3, .5)", "#rrggbb").
Color cssColor(String? css, [Color fallback = Colors.transparent]) {
  if (css == null) return fallback;
  final s = css.trim();
  final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s);
  if (m != null) {
    final p = m.group(1)!.split(RegExp(r'[,\s/]+')).where((x) => x.isNotEmpty).toList();
    if (p.length < 3) return fallback;
    final a = p.length > 3 ? (double.tryParse(p[3]) ?? 1) : 1.0;
    return Color.fromARGB((a * 255).round().clamp(0, 255), int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
  if (s.startsWith('#') && s.length == 7) return Color(int.parse('ff${s.substring(1)}', radix: 16));
  return fallback;
}

class GWhiteSquare extends StatelessWidget {
  const GWhiteSquare({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              boxShadow: [gShadow(const Color(0x1f781823), 2, 6)]),
          child: child,
        ),
      );
}

class GTopBar extends StatelessWidget {
  const GTopBar({super.key, required this.top, required this.onScan});
  final double top;
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64 + top,
        child: Stack(children: [
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment(-.98, -.17), end: Alignment(.98, .17), colors: [Color(0xffff6b48), Color(0xfff0472f)])))),
          const Positioned.fill(child: RepaintBoundary(child: _TopbarPattern())),
          Positioned(
            left: 16, right: 16, top: top, height: 64,
            child: Row(children: [
              Image.asset('assets/branding/mark.png', width: 34, height: 34),
              const SizedBox(width: 9),
              Text('Goyana', style: gText(31, w: FontWeight.w500, c: Colors.white, h: 34, ls: .2)),
              const Spacer(),
              GWhiteSquare(onTap: onScan, child: gSvg(svgScan, 22)),
            ]),
          ),
        ]),
      );
}

/// Topbar flower pattern: the 30x30 SVG tile is drawn once into an image and
/// repeated by the GPU, instead of placing dozens of SVG widgets.
class _TopbarPattern extends StatefulWidget {
  const _TopbarPattern();
  @override
  State<_TopbarPattern> createState() => _TopbarPatternState();
}

class _TopbarPatternState extends State<_TopbarPattern> {
  static ui.Image? _tile;
  @override
  void initState() {
    super.initState();
    if (_tile == null) _load();
  }

  Future<void> _load() async {
    final info = await vg.loadPicture(const SvgStringLoader(svgTopbarPattern), null);
    const scale = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawPicture(info.picture);
    info.picture.dispose();
    final image = await recorder.endRecording().toImage((30 * scale).toInt(), (30 * scale).toInt());
    _tile = image;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    if (tile == null) return const SizedBox.expand();
    return CustomPaint(painter: _PatternPainter(tile), size: Size.infinite);
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.tile);
  final ui.Image tile;
  @override
  void paint(Canvas canvas, Size size) {
    final s = 30 / tile.width;
    final matrix = Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated, matrix)..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.tile != tile;
}

class GBottomNav extends StatelessWidget {
  const GBottomNav({super.key, required this.onTap, this.active = 0});
  final ValueChanged<String> onTap;
  final int active;
  static const _items = [['home', 'Beranda'], ['orders', 'Pesanan'], ['reports', 'Laporan'], ['settings', 'Pengaturan']];
  @override
  Widget build(BuildContext context) {
    // Saat mengetik (keyboard terbuka) menu bawah disembunyikan supaya kolom isian punya ruang penuh.
    if (View.of(context).viewInsets.bottom > 0) return const SizedBox.shrink();
    return _bar();
  }

  Widget _bar() => Container(
        height: 76,
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xffeef0f3)))),
        child: Row(children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(_items[i][0]),
                child: Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 7),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 34, height: 34, child: Center(child: gSvg(navIcon(i, i == active), 28))),
                    const SizedBox(height: 5),
                    Text(_items[i][1], style: gText(12,
                        w: i == active ? FontWeight.w600 : FontWeight.w400,
                        c: i == active ? gBrand : const Color(0xff9aa0ac), h: 13.2)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

/// Dark pill like the HTML #toast90, shown while a native page covers the WebView.
class NativeToast extends StatelessWidget {
  const NativeToast({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xeb1e1e1e), borderRadius: BorderRadius.circular(14),
              boxShadow: [gShadow(const Color(0x33000000), 6, 18)]),
          child: Text(text, textAlign: TextAlign.center, style: gText(13, c: Colors.white, h: 18.2)),
        ),
      );
}
