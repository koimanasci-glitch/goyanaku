import 'dart:async';

import 'package:flutter/material.dart';

import 'common.dart';
import 'home_icons.dart';

/// Values shown on Beranda. They come from the same app logic as the HTML
/// version (web_bridge/capacitor.js → homeModel), so numbers always match.
class HomeModel {
  const HomeModel({
    this.statIn = '0', this.statReady = '0', this.statLate = '0',
    this.labelIn = 'Masuk', this.labelReady = 'Siap diambil', this.labelLate = 'Terlambat',
    this.today = 'Rp 0', this.todayLabel = 'Omset hari ini', this.badge = '0', this.showBadge = true,
    this.slides = defaultSlides,
    this.helpTitle = 'Butuh bantuan?',
    this.helpText = 'Tim GOYANA siap bantu setup, printer & kendala aplikasi.',
  });

  final String statIn, statReady, statLate, labelIn, labelReady, labelLate;
  final String today, todayLabel, badge, helpTitle, helpText;
  final bool showBadge;
  final List<HomeSlide> slides;

  static const defaultSlides = [
    HomeSlide('GOYANA SMART SERVICE', 'Chatbot Pintar\nLayani Pelanggan 24 Jam', 'Balasan cepat & otomatis'),
    HomeSlide('KONTROL BISNIS', 'Pantau Semua Cabang\nDari Satu Dashboard', 'Omzet • transaksi • performa'),
    HomeSlide('CRM & PELANGGAN', 'Kelola Pelanggan\nFollow-up Jadi Lebih Rapi', 'Lead • pelanggan • histori'),
  ];

  factory HomeModel.fromJson(Map<String, dynamic> j) {
    String s(String k, String d) => (j[k] is String && (j[k] as String).trim().isNotEmpty) ? (j[k] as String).trim() : d;
    final slides = (j['slides'] is List)
        ? (j['slides'] as List).whereType<Map>().map((m) => HomeSlide(
              '${m['brand'] ?? ''}'.trim(), '${m['title'] ?? ''}'.trim(), '${m['sub'] ?? ''}'.trim())).toList()
        : <HomeSlide>[];
    return HomeModel(
      statIn: s('statIn', '0'), statReady: s('statReady', '0'), statLate: s('statLate', '0'),
      labelIn: s('labelIn', 'Masuk'), labelReady: s('labelReady', 'Siap diambil'), labelLate: s('labelLate', 'Terlambat'),
      today: s('today', 'Rp 0'), todayLabel: s('todayLabel', 'Omset hari ini'),
      badge: s('badge', '0'), showBadge: j['showBadge'] != false,
      slides: slides.length == 3 ? slides : defaultSlides,
      helpTitle: s('helpTitle', 'Butuh bantuan?'), helpText: s('helpText', 'Tim GOYANA siap bantu setup, printer & kendala aplikasi.'),
    );
  }
}

class HomeSlide {
  const HomeSlide(this.brand, this.title, this.sub);
  final String brand, title, sub;
}

/// Taps on Beranda. Each one runs the same action as the HTML element it replaces.
abstract class HomeActions {
  void scan();
  void slide(int index);
  void tile(int index);
  void manageOutlet();
  void qr();
  void monthly();
  void helpChat();
  void nav(String pageId);
}

/// Native Flutter Beranda, drawn to match the HTML design (#home) exactly.
class NativeHome extends StatelessWidget {
  const NativeHome({super.key, required this.model, required this.actions, this.topInset});

  final HomeModel model;
  final HomeActions actions;
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
      color: const Color(0xfff4f6f8),
      child: Stack(children: [
        const Positioned.fill(child: RepaintBoundary(child: _PageBackground())),
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            addRepaintBoundaries: true,
            children: [
              RepaintBoundary(child: GTopBar(top: top, onScan: actions.scan)),
              RepaintBoundary(child: _Slider(slides: model.slides, onTap: actions.slide)),
              _Grid(model: model, onTap: actions.tile),
              _Manage(onTap: actions.manageOutlet),
              _Qr(onTap: actions.qr),
              _Stats(model: model),
              _Omset(model: model, onMonthly: actions.monthly),
              _Help(model: model, onChat: actions.helpChat),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(onTap: actions.nav)),
      ]),
      ),
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xfffbfcfd), Color(0xfff5f7f9), Color(0xfff1f4f7), Color(0xfff4f6f8)],
            stops: [0, .20, .42, 1],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment(.72, -.92), radius: .75,
            colors: [Color(0xb8e8eef4), Color(0xb8e8eef4), Color(0x00e8eef4)], stops: [0, .36, 1])))),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment(-.84, -.68), radius: .7,
            colors: [Color(0xc7f4f7fa), Color(0xc7f4f7fa), Color(0x00f4f7fa)], stops: [0, .35, 1])))),
        ]),
      );
}

class _Slider extends StatefulWidget {
  const _Slider({required this.slides, required this.onTap});
  final List<HomeSlide> slides;
  final ValueChanged<int> onTap;
  @override
  State<_Slider> createState() => _SliderState();
}

class _SliderState extends State<_Slider> {
  static const _gradients = [
    [Color(0xff71bfe1), Color(0xff89cce7), Color(0xff6eaecb), .38],
    [Color(0xfff0b782), Color(0xffecad70), Color(0xffe39a5e), .45],
    [Color(0xff8ea2d6), Color(0xff7f94cb), Color(0xff7186be), .44],
  ];
  final _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _go((_index + 1) % 3));
  }

  void _go(int i) {
    if (!_page.hasClients) return;
    _page.animateToPage(i, duration: const Duration(milliseconds: 450), curve: Curves.ease);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  Widget _slide(int i) {
    final g = _gradients[i], s = widget.slides[i];
    return GestureDetector(
      onTap: () => widget.onTap(i),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [g[0] as Color, g[1] as Color, g[2] as Color], stops: [0, g[3] as double, 1]),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          SizedBox(
            width: 179,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.brand, style: gText(10, c: Colors.white, h: 14)),
              const SizedBox(height: 7),
              Text(s.title, style: gText(15, w: FontWeight.w500, c: Colors.white, h: 17.1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x24ffffff), borderRadius: BorderRadius.circular(999)),
                child: Text(s.sub, style: gText(10, c: Colors.white, h: 14)),
              ),
            ]),
          ),
          const SizedBox(width: 4),
          Expanded(child: Center(child: gSvg(svgSlides[i], 118, h: 98))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
          child: Container(
            height: 126,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                boxShadow: [gShadow(const Color(0x1a374d60), 10, 20)]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PageView(
                controller: _page,
                onPageChanged: (i) { setState(() => _index = i); _restart(); },
                children: [for (var i = 0; i < 3; i++) _slide(i)],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 3; i++)
              GestureDetector(
                onTap: () => _go(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 6, bottom: 2),
                  width: i == _index ? 18 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: i == _index ? const Color(0xff7aa8cf) : const Color(0xffc8ced5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ]),
        ),
      ]);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.model, required this.onTap});
  final HomeModel model;
  final ValueChanged<int> onTap;

  Widget _tile(int i, Widget icon, String label, {Widget? badge}) => Expanded(
        child: GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xf7ffffff),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0x0f505e6c)),
              boxShadow: [gShadow(const Color(0x0a3c4c5a), 8, 18)],
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(height: 42, child: Center(child: icon)),
                    const SizedBox(height: 3),
                    Text(label, textAlign: TextAlign.center, style: gText(12, c: const Color(0xff20262c), h: 13.44)),
                  ]),
                ),
              ),
              if (badge != null) Positioned(left: 87, top: 7, child: badge),
            ]),
          ),
        ),
      );

  Widget _emoji(String e) => Text(e, style: const TextStyle(fontSize: 30, height: 1.12));

  @override
  Widget build(BuildContext context) {
    final badge = model.showBadge
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(20)),
            child: Text(model.badge, style: gText(10, c: Colors.white, h: 11.2)),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
      child: Column(children: [
        Row(children: [
          _tile(0, gSvg(svgTileAdd, 43), 'Tambah\nTransaksi'),
          const SizedBox(width: 8),
          _tile(1, _emoji('🛵'), 'Antar\nJemput'),
          const SizedBox(width: 8),
          _tile(2, _emoji('🚚'), 'Kurir'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _tile(3, _emoji('👥'), 'Pelanggan'),
          const SizedBox(width: 8),
          _tile(4, _emoji('📅'), 'Hari Ini', badge: badge),
          const SizedBox(width: 8),
          _tile(5, _emoji('🤖'), 'Chatbot'),
        ]),
      ]),
    );
  }
}

class _Manage extends StatelessWidget {
  const _Manage({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(color: const Color(0xffef4b42), borderRadius: BorderRadius.circular(14),
                boxShadow: [gShadow(const Color(0x1fef4b42), 6, 14)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 20, height: 20,
                child: GridView.count(
                  crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(9, (_) => DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Colors.white)))),
                ),
              ),
              const SizedBox(width: 12),
              Text.rich(TextSpan(style: gText(16, c: Colors.white, h: 22.4), children: const [
                TextSpan(text: 'MANAGE', style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: ' OUTLET'),
              ])),
            ]),
          ),
        ),
      );
}

class _Qr extends StatelessWidget {
  const _Qr({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xe0ffffff), borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x1a6c5a58)),
              boxShadow: [gShadow(const Color(0x0b403531), 6, 16)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              gSvg(svgQr, 18),
              const SizedBox(width: 9),
              Text('QR', style: gText(13, w: FontWeight.w500, c: const Color(0xff28313a), h: 18.2)),
            ]),
          ),
        ),
      );
}

BoxDecoration _card(double radius, {Color border = const Color(0xffe6eaf0)}) => BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border),
      boxShadow: [gShadow(const Color(0x06202d41), 2, 5)],
    );

class _Stats extends StatelessWidget {
  const _Stats({required this.model});
  final HomeModel model;

  Widget _stat(String svg, Color bg, String value, String label) => Expanded(
        child: Container(
          height: 82,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: _card(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 27, height: 27, alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: gSvg(svg, 16)),
              const Spacer(),
              Text(value, style: gText(22, w: FontWeight.w600, c: gInk, h: 22)),
            ]),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11, c: const Color(0xff828995), h: 14.3)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
        child: Row(children: [
          _stat(svgStatIn, const Color(0xffeef4fb), model.statIn, model.labelIn),
          const SizedBox(width: 9),
          _stat(svgStatReady, const Color(0xffecf7f1), model.statReady, model.labelReady),
          const SizedBox(width: 9),
          _stat(svgStatLate, const Color(0xfffff5e9), model.statLate, model.labelLate),
        ]),
      );
}

class _Omset extends StatelessWidget {
  const _Omset({required this.model, required this.onMonthly});
  final HomeModel model;
  final VoidCallback onMonthly;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: _card(15),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(model.todayLabel, style: gText(11, c: const Color(0xff858b95), h: 15.4)),
                const SizedBox(height: 5),
                Text(model.today, style: gText(22, w: FontWeight.w600, c: gInk, h: 26.4, ls: -.3)),
              ]),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onMonthly,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xfffff7f4), borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xfff5dcd7))),
                child: Text('Bulanan ›', style: gText(11, w: FontWeight.w500, c: const Color(0xffdb6555), h: 15.4)),
              ),
            ),
          ]),
        ),
      );
}

class _Help extends StatelessWidget {
  const _Help({required this.model, required this.onChat});
  final HomeModel model;
  final VoidCallback onChat;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _card(18, border: const Color(0xffd7f0e2)),
          child: Row(children: [
            gSvg(svgHelp, 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(model.helpTitle, style: gText(14, w: FontWeight.w500, c: const Color(0xff1e1e1e), h: 19.6)),
                const SizedBox(height: 2),
                Text(model.helpText, style: gText(11.5, c: const Color(0xff6b7486), h: 16.1)),
              ]),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xff22b35e), borderRadius: BorderRadius.circular(11)),
                child: Text('Chat WA', style: gText(12.5, w: FontWeight.w500, c: Colors.white, h: 17.5)),
              ),
            ),
          ]),
        ),
      );
}
