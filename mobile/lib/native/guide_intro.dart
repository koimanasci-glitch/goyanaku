import 'dart:async';

import 'package:flutter/material.dart';

import '../core/store.dart';
import 'common.dart';

/// Marker: the five-slide guide was shown (or skipped) once on this phone.
const guideSeenKey = '__goyana_guide_seen_v1';

class GuideSlide {
  const GuideSlide(this.title, this.body, this.asset, this.icon);
  final String title, body, asset;
  final IconData icon; // shown until the illustration PNG is added
}

const guideSlides = [
  GuideSlide(
    'Kelola Pesanan\nLebih Mudah',
    'Catat pesanan, cetak struk & label barcode dengan cepat dan rapi.',
    'assets/guide/guide1.png',
    Icons.local_laundry_service_rounded,
  ),
  GuideSlide(
    'Pembayaran Lengkap\ndan Praktis',
    'Terima pembayaran tunai, transfer dan QRIS dinamis untuk setiap pesanan.',
    'assets/guide/guide2.png',
    Icons.qr_code_2_rounded,
  ),
  GuideSlide(
    'Laporan Usaha\nReal-time',
    'Pantau omset harian, bulanan dan perkembangan usaha Anda.',
    'assets/guide/guide3.png',
    Icons.bar_chart_rounded,
  ),
  GuideSlide(
    'Kelola Banyak Cabang',
    'Atur hingga beberapa cabang dalam satu aplikasi. Mudah dipantau dari mana saja.',
    'assets/guide/guide4.png',
    Icons.storefront_rounded,
  ),
  GuideSlide(
    'Otomasi & Chatbot\nWhatsApp',
    'Kirim reminder selesai ke pelanggan dan gunakan chatbot (untuk paket Gold ke atas) agar komunikasi lebih efisien.',
    'assets/guide/guide5.png',
    Icons.chat_rounded,
  ),
];

/// Five introduction slides shown once after the owner's first outlet exists,
/// and again from Pengaturan -> Panduan awal Goyana. Replaces the old
/// "Mulai bersama Goyana" five-step HTML tutorial.
class GuideIntro extends StatefulWidget {
  const GuideIntro({
    super.key,
    required this.onDone,
    this.store = const DeviceKvStore(),
  });
  final VoidCallback onDone;
  final KvStore store;
  @override
  State<GuideIntro> createState() => _GuideIntroState();
}

class _GuideIntroState extends State<GuideIntro> {
  int _i = 0;
  bool _closed = false;

  Future<void> _close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      await widget.store.set(guideSeenKey, '1');
    } catch (_) {
      /* It will simply show once more if storage fails. */
    }
    if (mounted) {
      widget.onDone();
    }
  }

  void _next() {
    if (_i >= guideSlides.length - 1) {
      unawaited(_close());
    } else {
      setState(() => _i++);
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() => _i--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = guideSlides[_i];
    final last = _i == guideSlides.length - 1;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffff3a3f), Color(0xffed0026)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, top + 16, 24, bottom + 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('guide-skip'),
                  onPressed: () => unawaited(_close()),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text('Lewati', style: gText(14, c: Colors.white)),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(_i),
                    children: [
                      Expanded(
                        child: Center(
                          child: _Illustration(slide: slide),
                        ),
                      ),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: gText(
                          26,
                          w: FontWeight.w600,
                          c: Colors.white,
                          h: 34,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: gText(
                            15,
                            c: const Color(0xe6ffffff),
                            h: 23,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: _i == 0
                          ? null
                          : OutlinedButton(
                              key: const Key('guide-prev'),
                              onPressed: _prev,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                'KEMBALI',
                                style: gText(
                                  13,
                                  w: FontWeight.w600,
                                  c: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var d = 0; d < guideSlides.length; d++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: d == _i ? 11 : 9,
                              height: d == _i ? 11 : 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d == _i
                                    ? Colors.white
                                    : const Color(0x73ffffff),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: ElevatedButton(
                        key: const Key('guide-next'),
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xffed0026),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          last ? 'MULAI' : 'LANJUT',
                          style: gText(
                            13,
                            w: FontWeight.w600,
                            c: const Color(0xffed0026),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide});
  final GuideSlide slide;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
    child: Image.asset(
      slide.asset,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Center(
        child: Container(
          width: 170,
          height: 170,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x33ffffff),
          ),
          child: Icon(slide.icon, size: 84, color: Colors.white),
        ),
      ),
    ),
  );
}
