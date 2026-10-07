// Tandai lokasi di peta dalam aplikasi (revisi Koiman): peta OpenStreetMap yang digeser di bawah pin tengah,
// lalu "Tandai Lokasi Ini" menyimpan koordinatnya. Tanpa pustaka tambahan dan tanpa kunci API.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../native/common.dart';

const _tile = 256.0;
const mapMinZoom = 4, mapMaxZoom = 19;

/// Proyeksi Web Mercator: (lat, lng) → piksel dunia pada [zoom].
Offset mapProject(double lat, double lng, int zoom) {
  final n = _tile * (1 << zoom);
  final s = math.sin(lat.clamp(-85.0, 85.0).toDouble() * math.pi / 180);
  return Offset((lng + 180) / 360 * n, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n);
}

/// Kebalikan [mapProject]: piksel dunia → (lat, lng).
(double, double) mapUnproject(Offset p, int zoom) {
  final n = _tile * (1 << zoom);
  final lng = p.dx / n * 360 - 180;
  final y = math.pi * (1 - 2 * p.dy / n);
  final lat = math.atan((math.exp(y) - math.exp(-y)) / 2) * 180 / math.pi;
  return (lat.clamp(-85.0, 85.0).toDouble(), ((lng + 540) % 360) - 180);
}

String mapCoordText(double lat, double lng) => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

class MapPick extends StatefulWidget {
  const MapPick({super.key, required this.lat, required this.lng, required this.onPick, required this.onClose, this.onLocate, this.located = false, this.zoom = 17});

  /// Titik awal di tengah peta.
  final double lat, lng;
  final int zoom;

  /// True bila titik awal berasal dari GPS (titik biru "posisi saya" ditampilkan di sana).
  final bool located;
  final void Function(double lat, double lng) onPick;
  final VoidCallback onClose;

  /// Ambil posisi GPS sekarang; null bila gagal.
  final Future<(double, double)?> Function()? onLocate;

  @override
  State<MapPick> createState() => MapPickState();
}

class MapPickState extends State<MapPick> {
  late double lat = widget.lat, lng = widget.lng;
  late int zoom = widget.zoom.clamp(mapMinZoom, mapMaxZoom).toInt();
  (double, double)? me;
  double _scale = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.located) me = (widget.lat, widget.lng);
  }

  void _pan(Offset d) {
    final c = mapProject(lat, lng, zoom) - d;
    final r = mapUnproject(c, zoom);
    setState(() {
      lat = r.$1;
      lng = r.$2;
    });
  }

  void zoomBy(int d) => setState(() => zoom = (zoom + d).clamp(mapMinZoom, mapMaxZoom).toInt());

  Future<void> _locate() async {
    final f = widget.onLocate;
    if (f == null || _busy) return;
    setState(() => _busy = true);
    final r = await f();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        me = r;
        lat = r.$1;
        lng = r.$2;
        if (zoom < 16) zoom = 17;
      }
    });
  }

  Widget _tiles(Size size) {
    final c = mapProject(lat, lng, zoom);
    final tl = c - Offset(size.width / 2, size.height / 2);
    final n = 1 << zoom;
    final x0 = (tl.dx / _tile).floor(), x1 = ((tl.dx + size.width) / _tile).floor();
    final y0 = (tl.dy / _tile).floor(), y1 = ((tl.dy + size.height) / _tile).floor();
    final m = me == null ? null : mapProject(me!.$1, me!.$2, zoom) - tl;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xffe9edf2))),
      for (var x = x0; x <= x1; x++)
        for (var y = y0; y <= y1; y++)
          if (y >= 0 && y < n)
            Positioned(
              left: x * _tile - tl.dx, top: y * _tile - tl.dy, width: _tile, height: _tile,
              child: Image.network(
                'https://tile.openstreetmap.org/$zoom/${((x % n) + n) % n}/$y.png',
                key: ValueKey('t$zoom/$x/$y'), headers: const {'User-Agent': 'GOYANA-Laundry/1.0 (id.goyana.app)'},
                fit: BoxFit.cover, gaplessPlayback: true,
                errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(color: Color(0xffe9edf2), border: Border.fromBorderSide(BorderSide(color: Color(0xffdfe4ea), width: .5)))),
              ),
            ),
      if (m != null)
        Positioned(
          left: m.dx - 11, top: m.dy - 11,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: const Color(0xff2f80ed), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x552f80ed), blurRadius: 10)]),
          ),
        ),
    ]);
  }

  Widget _round(IconData icon, VoidCallback onTap, {bool busy = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x26172235), blurRadius: 10, offset: Offset(0, 3))]),
          child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: gBrand)) : Icon(icon, size: 22, color: const Color(0xff17191d)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: Colors.white,
      child: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(12, pad.top + 10, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xffeef0f3)))),
          child: Row(children: [
            GestureDetector(
              onTap: widget.onClose,
              child: Container(width: 42, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xfff3f5f8), borderRadius: BorderRadius.circular(10)), child: Text('‹', style: gText(24, w: FontWeight.w600, h: 26))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TANDAI LOKASI', style: gText(15, w: FontWeight.w600, ls: .6)),
                Text('Geser peta sampai pin tepat di rumah pelanggan', style: gText(11.5, c: const Color(0xff8b93a1))),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _scale = 1,
                  onScaleUpdate: (d) {
                    if (d.pointerCount > 1) {
                      final r = d.scale / _scale;
                      if (r > 1.5) {
                        _scale = d.scale;
                        zoomBy(1);
                      } else if (r < .67) {
                        _scale = d.scale;
                        zoomBy(-1);
                      }
                    }
                    if (d.focalPointDelta != Offset.zero) _pan(d.focalPointDelta);
                  },
                  onDoubleTap: () => zoomBy(1),
                  child: _tiles(size),
                ),
              ),
              // Pin tengah: ujung bawahnya tepat di titik yang ditandai.
              Positioned(
                left: size.width / 2 - 22, top: size.height / 2 - 44,
                child: const IgnorePointer(child: Icon(Icons.location_on, size: 44, color: gBrand, shadows: [Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))])),
              ),
              Positioned(
                right: 12, top: 12,
                child: Column(children: [
                  _round(Icons.add, () => zoomBy(1)),
                  const SizedBox(height: 8),
                  _round(Icons.remove, () => zoomBy(-1)),
                  if (widget.onLocate != null) ...[const SizedBox(height: 8), _round(Icons.my_location, _locate, busy: _busy)],
                ]),
              ),
              Positioned(
                left: 6, bottom: 4,
                child: IgnorePointer(child: Text('© OpenStreetMap', style: gText(9.5, c: const Color(0xff5c6470)))),
              ),
            ]);
          }),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + pad.bottom),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x14172235), blurRadius: 16, offset: Offset(0, -6))]),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.location_on, size: 18, color: gBrand),
              const SizedBox(width: 6),
              Expanded(child: Text(mapCoordText(lat, lng), style: gText(13.5, w: FontWeight.w500))),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => widget.onPick(lat, lng),
              child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(12)), child: Text('Tandai Lokasi Ini', style: gText(14, w: FontWeight.w600, c: Colors.white, ls: .3))),
            ),
          ]),
        ),
      ]),
    );
  }
}
