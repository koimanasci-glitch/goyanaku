import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/store.dart';
import 'common.dart';

const brandIntroKey = '__goyana_brand_intro_seen_v1';

/// Opening animation: the white dove perched on the "G" looks left, then
/// right, while the name and tagline fade in. 1.2 s on the first opening and
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

const brandIntroFirstMs = 1200;
const brandIntroLaterMs = 900;
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
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _leave]),
      builder: (context, _) {
        final u = _animation.value;
        final logo = (u / .25).clamp(0.0, 1.0);
        final name = _easeOut(((u - .45) / .35).clamp(0.0, 1.0));
        final tag = _easeOut(((u - .6) / .32).clamp(0.0, 1.0));
        final dove = doveAt(u);
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
                              Positioned(
                                left: _doveLeft,
                                top: _doveTop + dove.lift,
                                width: _doveSize,
                                height: _doveSize,
                                child: Opacity(
                                  opacity: dove.opacity,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.diagonal3Values(
                                      dove.scaleX,
                                      1,
                                      1,
                                    ),
                                    child: Image.asset(
                                      'assets/branding/dove.png',
                                      cacheWidth: 360,
                                      filterQuality: FilterQuality.medium,
                                      errorBuilder: (context, e, s) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
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

// Dove position in the 175px logo box: feet rest on the upper-left of the "G"
// ring (ring top is at y~10), image is nearly square and faces right.
const _doveSize = 112.0, _doveLeft = 6.0, _doveTop = -96.0;

class DovePose {
  const DovePose(this.scaleX, this.lift, this.opacity);
  final double scaleX, lift, opacity;
}

double _smooth(double p) => p * p * (3 - 2 * p);

/// Dove pose for animation progress [u] (0..1): settles in, looks left (flips),
/// holds, looks right again and ends facing right (the artwork's own direction).
DovePose doveAt(double u) {
  final fadeIn = ((u - .08) / .17).clamp(0.0, 1.0);
  final settle = (1 - _easeOut(fadeIn)) * -10; // drops 10px into place
  // 0 = facing right, 1 = facing left.
  final toLeft = _smooth(((u - .25) / .2).clamp(0.0, 1.0));
  final toRight = _smooth(((u - .55) / .2).clamp(0.0, 1.0));
  final turn = toLeft - toRight;
  var sx = math.cos(math.pi * turn);
  if (sx.abs() < .12) {
    sx = sx < 0 ? -.12 : .12; // never fully edge-on
  }
  final hop = -4 * math.sin(math.pi * turn.clamp(0.0, 1.0));
  return DovePose(sx, settle + hop, fadeIn);
}
