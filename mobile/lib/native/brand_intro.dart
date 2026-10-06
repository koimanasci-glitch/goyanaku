import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import 'common.dart';

const brandIntroKey = '__goyana_brand_intro_seen_v1';

/// Startup work continues behind this overlay. Only the first install gets the
/// full cloth -> water -> logo sequence; later openings fade concurrently.
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

class _BrandIntroState extends State<BrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  bool _first = false, _resolved = false, _done = false;
  ui.Image? _story;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_first) {
          unawaited(_remember());
        }
        _finish();
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
    _animation.duration = Duration(milliseconds: first ? 3000 : 350);
    _animation.forward();
    if (first) {
      final data = await rootBundle.load('assets/branding/storyboard.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() => _story = frame.image);
      } else {
        frame.image.dispose();
      }
    }
  }

  void _finish() {
    if (!_done && widget.ready && _resolved && _animation.isCompleted) {
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onDone();
        }
      });
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
    _story?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) {
      final t = _animation.value;
      final finalLogo = !_first ? 1.0 : ((t - .55) / .25).clamp(0.0, 1.0);
      return IgnorePointer(
        ignoring: widget.ready && !_first,
        child: Opacity(
          opacity: !_first && _resolved && widget.ready ? 1 - t : 1,
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
                Positioned.fill(
                  child: CustomPaint(
                    painter: _IntroArt(t, _first ? _story : null),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: finalLogo,
                    child: Transform.scale(
                      scale: .88 + .12 * finalLogo,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/branding/mark.png',
                            width: 175,
                            height: 175,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Goyana',
                            style: gText(
                              48,
                              w: FontWeight.w600,
                              c: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'KASIR LAUNDRY',
                            style: gText(11, c: Colors.white, ls: 4),
                          ),
                        ],
                      ),
                    ),
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

class _IntroArt extends CustomPainter {
  _IntroArt(this.t, this.story);
  final double t;
  final ui.Image? story;
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
    final image = story;
    if (image == null || t >= .8) {
      return;
    }
    final width = size.width * .98;
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .45),
      width: width,
      height: width * 1.12,
    );
    void panel(int index, double opacity, double scale) {
      if (opacity <= 0) {
        return;
      }
      canvas.save();
      canvas.translate(dst.center.dx, dst.center.dy);
      canvas.scale(scale);
      canvas.translate(-dst.center.dx, -dst.center.dy);
      canvas.saveLayer(
        dst,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(index * 512 + 28, 165, 456, 555),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.drawRect(
        dst,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const RadialGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, .6, 1],
          ).createShader(dst),
      );
      canvas.restore();
      canvas.restore();
    }

    final water = ((t - .25) / .2).clamp(0.0, 1.0),
        fade = 1 - ((t - .55) / .25).clamp(0.0, 1.0);
    panel(0, (1 - water) * fade, .9 + .12 * t);
    panel(1, water * fade, .88 + .15 * t);
  }

  @override
  bool shouldRepaint(_IntroArt oldDelegate) =>
      t != oldDelegate.t || story != oldDelegate.story;
}
