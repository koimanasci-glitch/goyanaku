import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/store.dart';
import 'common.dart';

const brandIntroKey = '__goyana_brand_intro_seen_v1';

/// Opening animation: the white dove perched on the "G" breathes gently, while the name and tagline fade in. 1.2 s on the first opening and
/// 0.9 s afterwards. Startup work continues behind this overlay, so it never
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

const brandIntroFirstMs = 2200;
const brandIntroLaterMs = 2200;
const _leaveMs = 160;
const _markSize = 200.0;

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
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _leave]),
      builder: (context, _) {
        final u = _animation.value;
        final draw = _easeOut((u / .5).clamp(0.0, 1.0));
        final shine = ((u - .62) / .25).clamp(0.0, 1.0);
        final bird = birdAt(u);
        final tag = _easeOut(((u - .75) / .25).clamp(0.0, 1.0));
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
                              Positioned.fill(child: _Mark(draw, shine)),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _BirdPainter(bird),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < _word.length; i++)
                              _Letter(_word[i], letterProgress(u, i)),
                          ],
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

const _word = 'Goyana';

/// Progress (0..1) of letter [i] of the name for animation progress [u].
double letterProgress(double u, int i) =>
    _easeOut(((u - .5 - i * .045) / .25).clamp(0.0, 1.0));

class _Letter extends StatelessWidget {
  const _Letter(this.ch, this.p);
  final String ch;
  final double p;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: p,
    child: Transform.translate(
      offset: Offset(0, (1 - p) * 22),
      child: Text(ch, style: gText(48, w: FontWeight.w600, c: Colors.white)),
    ),
  );
}

/// The G: revealed by a counter-clockwise sweep starting at the upper right,
/// then crossed once by a diagonal shine.
class _Mark extends StatelessWidget {
  const _Mark(this.draw, this.shine);
  final double draw, shine;
  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset('assets/branding/mark.png');
    if (shine > 0 && shine < 1) {
      final c = -.3 + 1.6 * shine;
      image = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0x00ffffff), Color(0xb3ffffff), Color(0x00ffffff)],
          stops: [
            (c - .14).clamp(0.0, 1.0),
            c.clamp(0.0, 1.0),
            (c + .14).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
        child: image,
      );
    }
    if (draw >= 1) {
      return image;
    }
    return ClipPath(clipper: _SweepClip(draw), child: image);
  }
}

class _SweepClip extends CustomClipper<Path> {
  const _SweepClip(this.t);
  final double t;
  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        -35 * math.pi / 180,
        -2 * math.pi * t,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_SweepClip old) => old.t != t;
}

double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();

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

/// Bird state for one frame, in the 200px logo box (feet position).
class BirdPose {
  const BirdPose(this.x, this.y, this.flap, this.scale, this.tilt, this.alpha);

  /// Feet position, flap angle in degrees (positive = wings up), wing scale,
  /// body tilt in radians and opacity.
  final double x, y, flap, scale, tilt, alpha;
}

const _perch = Offset(92, 14); // feet rest on the upper-left of the G ring
const _birdStart = Offset(30, -200); // above the screen, upper left

/// Bird for animation progress [u] (0..1): flies in flapping (u .08-.55),
/// lands on the G, flaps slowly and folds its wings (u .55-.75), then rests.
BirdPose birdAt(double u) {
  final fl = _easeOut(((u - .08) / .47).clamp(0.0, 1.0));
  final x = _birdStart.dx + (_perch.dx - _birdStart.dx) * fl;
  final y = _birdStart.dy + (_perch.dy - _birdStart.dy) * fl;
  final alpha = ((u - .08) / .1).clamp(0.0, 1.0);
  if (u < .55) {
    final psi = 18 + 48 * math.sin(2 * math.pi * 3 * (u - .08) / .47);
    return BirdPose(x, y, psi, 1, -.35 * (1 - fl), alpha);
  }
  final k = ((u - .55) / .2).clamp(0.0, 1.0);
  final psi =
      (18 + 48 * math.sin(2 * math.pi * 1.2 * k)) * (1 - k) + -12 * k;
  return BirdPose(x, y, psi, 1 - .2 * k, 0, alpha);
}

class _BirdPainter extends CustomPainter {
  const _BirdPainter(this.b);
  final BirdPose b;

  static const _wing = [
    Offset(0, -5),
    Offset(25, -13),
    Offset(60, -15),
    Offset(98, -7),
    Offset(82, 2),
    Offset(56, 7),
    Offset(26, 11),
    Offset(0, 8),
  ];

  Path _poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Offset _t(double px, double py) {
    final c = math.cos(b.tilt), s = math.sin(b.tilt);
    return Offset(b.x + px * c - py * s, b.y + px * s + py * c);
  }

  void _drawWing(Canvas canvas, Offset shoulder, double psi, double sc, Paint p) {
    final a = math.pi - psi * math.pi / 180;
    final c = math.cos(a), s = math.sin(a);
    final pts = [
      for (final w in _wing)
        Offset(
          shoulder.dx + (w.dx * c - w.dy * s) * sc,
          shoulder.dy + (w.dx * s + w.dy * c) * sc,
        ),
    ];
    canvas.drawPath(_poly(pts), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (b.alpha <= 0) {
      return;
    }
    int a(int v) => (v * b.alpha).round();
    final near = Paint()..color = Color.fromARGB(a(255), 255, 255, 255);
    final far = Paint()..color = Color.fromARGB(a(255), 225, 228, 236);
    final beak = Paint()..color = Color.fromARGB(a(255), 255, 236, 200);
    final eye = Paint()..color = Color.fromARGB(a(255), 237, 0, 38);
    final shoulder = _t(-2, -34);
    _drawWing(canvas, shoulder, b.flap * .9 - 8, b.scale * .92, far);
    canvas.drawPath(
      _poly([
        for (final p in const [
          [-34.0, -24.0], [-20.0, -42.0], [6.0, -48.0], [28.0, -46.0],
          [38.0, -38.0], [36.0, -30.0], [20.0, -18.0], [-6.0, -12.0],
          [-26.0, -14.0],
        ])
          _t(p[0], p[1]),
      ]),
      near,
    );
    canvas.drawPath(
      _poly([
        for (final p in const [
          [-30.0, -22.0], [-66.0, -14.0], [-62.0, -26.0], [-60.0, -34.0],
          [-28.0, -36.0],
        ])
          _t(p[0], p[1]),
      ]),
      near,
    );
    canvas.drawCircle(_t(34, -48), 11, near);
    canvas.drawPath(_poly([_t(42, -52), _t(58, -47), _t(42, -44)]), beak);
    canvas.drawCircle(_t(38, -52), 1.8, eye);
    final leg = Paint()
      ..color = beak.color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final fx in const [-4.0, 8.0]) {
      canvas.drawLine(_t(fx, -12), _t(fx - 3, 0), leg);
    }
    _drawWing(canvas, shoulder, b.flap, b.scale, near);
  }

  @override
  bool shouldRepaint(_BirdPainter old) => old.b != b;
}
