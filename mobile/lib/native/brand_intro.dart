import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/store.dart';
import 'common.dart';

const brandIntroKey = '__goyana_brand_intro_seen_v1';

/// Opening animation: a butterfly flies in from the top and lands on the "G",
/// then the name and tagline fade in. About 1.1 s on the first opening and
/// 0.8 s afterwards. Startup work continues behind this overlay, so it never
/// adds waiting time of its own beyond the animation.
class BrandIntro extends StatefulWidget {
  const BrandIntro({
    super.key,
    required this.ready,
    required this.onDone,
    this.store = const DeviceKvStore(),
  });
  final bool ready;
  final VoidCallback onDone;
  final KvStore store;
  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

const brandIntroFirstMs = 1100;
const brandIntroLaterMs = 800;
const _leaveMs = 160;
const _markSize = 175.0;

class _BrandIntroState extends State<BrandIntro> with TickerProviderStateMixin {
  late final AnimationController _animation;
  late final AnimationController _leave;
  bool _first = false, _resolved = false, _done = false;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: brandIntroLaterMs),
    );
    _leave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _leaveMs),
    );
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_first) {
          unawaited(_remember());
        }
        _finish();
      }
    });
    _leave.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onDone();
          }
        });
      }
    });
    unawaited(_start());
  }

  Future<void> _remember() async {
    try {
      await widget.store.set(brandIntroKey, '1');
    } catch (_) {
      /* Retry on next launch if storage fails. */
    }
  }

  Future<void> _start() async {
    var first = false;
    try {
      first =
          await widget.store
              .get(brandIntroKey)
              .timeout(const Duration(seconds: 1)) ==
          null;
    } catch (_) {
      /* A storage problem must not hold startup. */
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _first = first;
      _resolved = true;
    });
    _animation.duration = Duration(
      milliseconds: first ? brandIntroFirstMs : brandIntroLaterMs,
    );
    _animation.forward();
  }

  void _finish() {
    if (!_done && widget.ready && _resolved && _animation.isCompleted) {
      _done = true;
      _leave.forward();
    }
  }

  @override
  void didUpdateWidget(BrandIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready) {
      _finish();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _leave]),
      builder: (context, _) {
        final u = _animation.value;
        final logo = (u / .3).clamp(0.0, 1.0);
        final name = _easeOut(((u - .45) / .35).clamp(0.0, 1.0));
        final tag = _easeOut(((u - .6) / .32).clamp(0.0, 1.0));
        return IgnorePointer(
          ignoring: _done,
          child: Opacity(
            opacity: 1 - _leave.value,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffff7956),
                    Color(0xffff2636),
                    Color(0xffed0026),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _Floral())),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _markSize,
                          height: _markSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: logo,
                                  child: Transform.scale(
                                    scale: .92 + .08 * _easeOut(logo),
                                    child: Image.asset(
                                      'assets/branding/mark.png',
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: ButterflyPainter(u, screenH),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: name,
                          child: Transform.translate(
                            offset: Offset(0, (1 - name) * 16),
                            child: Text(
                              'Goyana',
                              style: gText(
                                48,
                                w: FontWeight.w600,
                                c: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: tag,
                          child: Text(
                            'KASIR LAUNDRY',
                            style: gText(
                              11,
                              c: Colors.white,
                              ls: 9 - 5 * tag,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();
double _easeFly(double p) => 1 - math.pow(1 - p, 2).toDouble();

class _Floral extends CustomPainter {
  const _Floral();
  @override
  void paint(Canvas canvas, Size size) {
    final floral = Paint()..color = const Color(0x40ffcc90);
    for (final corner in [Offset.zero, Offset(size.width, size.height)]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      if (corner != Offset.zero) {
        canvas.rotate(math.pi);
      }
      for (var i = 0; i < 5; i++) {
        canvas.save();
        canvas.rotate(i * .29);
        canvas.drawOval(const Rect.fromLTWH(-25, -15, 170, 55), floral);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Floral oldDelegate) => false;
}

// Butterfly in unit space: body on the y axis (head up), wings span +-1.
// Each wing: start point, then two cubic segments (6 numbers each).
const _fore = [
  0.0, -0.05, //
  0.10, -0.80, 0.70, -1.05, 0.98, -0.78, //
  1.08, -0.52, 0.85, -0.12, 0.04, 0.06,
];
const _hind = [
  0.02, 0.04, //
  0.55, -0.10, 0.98, 0.12, 0.88, 0.50, //
  0.78, 0.84, 0.32, 0.82, 0.04, 0.30,
];

// Landing spot and pose, in the 175px mark box (upper-left of the "G" ring).
const _endX = 36.0, _endY = 12.0, _endAng = .45, _endOpen = .8, _size = 58.0;
// Flight lasts for the first 72% of the animation, the rest is a small settle.
const _flightEnd = .72;

/// Paints the butterfly for animation progress [u] (0..1). Coordinates are
/// relative to the top-left of the 175px logo box; it may draw outside it.
class ButterflyPainter extends CustomPainter {
  ButterflyPainter(this.u, this.screenH);
  final double u, screenH;

  static Path _wing(List<double> c, double m, double sx, double sy) {
    double x(int i) => m * c[i] * sx;
    double y(int i) => c[i] * sy;
    return Path()
      ..moveTo(x(0), y(1))
      ..cubicTo(x(2), y(3), x(4), y(5), x(6), y(7))
      ..cubicTo(x(8), y(9), x(10), y(11), x(12), y(13))
      ..close();
  }

  /// Wing opening: flapping while flying, easing to the perched pose, then a
  /// short decaying flutter.
  static double openAt(double u) {
    final p = (u / _flightEnd).clamp(0.0, 1.0);
    if (u < _flightEnd) {
      final flap = .38 + .62 * (.5 + .5 * math.cos(u * math.pi * 2 * 5.5));
      return flap * (1 - p * p) + _endOpen * p * p;
    }
    final q = (u - _flightEnd) / (1 - _flightEnd);
    return _endOpen + .3 * math.sin(q * math.pi * 3) * (1 - q);
  }

  /// Position (x, y) and angle of the butterfly in the logo box.
  static (double, double, double) poseAt(double u, double screenH) {
    final p = (u / _flightEnd).clamp(0.0, 1.0);
    final y0 = -(screenH / 2 - 140) - 70, x0 = _endX + 80;
    (double, double) at(double q) {
      final e = _easeFly(q);
      return (
        _endX + (x0 - _endX) * (1 - e) + 46 * (1 - e) * math.sin(e * math.pi * 2.4),
        _endY + (y0 - _endY) * (1 - e),
      );
    }

    final a = at(p), b = at(math.min(1.0, p + .01));
    final heading = math
        .atan2(b.$1 - a.$1, -(b.$2 - a.$2))
        .clamp(-.7, .7)
        .toDouble();
    final k = p * p;
    return (a.$1, a.$2, heading * (1 - k) + _endAng * k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (x, y, ang) = poseAt(u, screenH);
    final open = openAt(u);
    const s = _size;
    final fill = Paint()..color = const Color(0xf7ffffff);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .02
      ..color = const Color(0x8cffaab0);
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .016
      ..color = const Color(0x47ff8c96);
    final solid = Paint()..color = Colors.white;
    final feeler = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .03
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(ang);
    for (final m in const [-1.0, 1.0]) {
      for (final w in const [_hind, _fore]) {
        final path = _wing(w, m, s * open, s);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, edge);
      }
      for (final v in const [
        [.5, -.55],
        [.62, -.25],
        [.5, .3],
      ]) {
        canvas.drawLine(
          Offset(m * .03 * s * open, 0),
          Offset(m * v[0] * s * open, v[1] * s),
          vein,
        );
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, .02 * s), width: .12 * s, height: .88 * s),
      solid,
    );
    canvas.drawCircle(Offset(0, -.46 * s), .075 * s, solid);
    for (final m in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -.5 * s)
          ..quadraticBezierTo(m * .1 * s, -.82 * s, m * .3 * s, -.95 * s),
        feeler,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ButterflyPainter oldDelegate) =>
      u != oldDelegate.u || screenH != oldDelegate.screenH;
}
