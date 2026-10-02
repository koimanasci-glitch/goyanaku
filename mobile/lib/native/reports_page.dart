import 'dart:async';

import 'package:flutter/material.dart';

import 'common.dart';

// Laporan (HTML #reports, rp170). Ringkasan, KPI, aksi cepat, cari & daftar laporan native.
// Angka diambil apa adanya dari HTML (tidak dihitung ulang). Detail laporan & tanggal kustom tetap HTML.

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class RpChip {
  const RpChip(this.t, {this.on = false, this.bg = '', this.c = ''});
  final String t, bg, c;
  final bool on;
}

class RpTile {
  const RpTile({this.index = 0, this.icon = '', this.bg = '', this.title = '', this.sub = '', this.value = ''});
  final int index;
  final String icon, bg, title, sub, value;
}

class RpSection {
  const RpSection(this.title, this.items);
  final String title;
  final List<RpTile> items;
}

class ReportsModel {
  const ReportsModel({
    this.title = 'Laporan', this.outlet = '', this.periods = const [], this.heroLabel = '', this.heroBig = '', this.heroSub = '',
    this.methods = const [], this.kpis = const [], this.quick = const [], this.search = '', this.placeholder = '', this.cats = const [],
    this.sections = const [], this.empty = '',
  });

  factory ReportsModel.fromJson(Map<String, dynamic> j) {
    final hero = j['hero'] is Map ? Map<String, dynamic>.from(j['hero'] as Map) : const <String, dynamic>{};
    final search = j['search'] is Map ? Map<String, dynamic>.from(j['search'] as Map) : const <String, dynamic>{};
    RpTile tile(Map<String, dynamic> m) => RpTile(index: (m['i'] as num?)?.toInt() ?? 0, icon: _s(m['icon']), bg: _s(m['bg']),
        title: _s(m['t']), sub: _s(m['s']), value: _s(m['v']));
    return ReportsModel(
      title: _s(j['title']), outlet: _s(j['outlet']),
      periods: _list(j['periods']).map((p) => RpChip(_s(p['t']), on: p['on'] == true)).toList(),
      heroLabel: _s(hero['label']), heroBig: _s(hero['big']), heroSub: _s(hero['sub']),
      methods: _list(hero['pm']).map((p) => RpTile(title: _s(p['t']), value: _s(p['v']))).toList(),
      kpis: _list(j['kpis']).map(tile).toList(), quick: _list(j['quick']).map(tile).toList(),
      search: _s(search['v']), placeholder: _s(search['ph']),
      cats: _list(j['cats']).map((c) => RpChip(_s(c['t']), on: c['on'] == true, bg: _s(c['bg']), c: _s(c['c']))).toList(),
      sections: _list(j['sections']).map((sec) => RpSection(_s(sec['t']), _list(sec['items']).map(tile).toList())).toList(),
      empty: _s(j['empty']),
    );
  }

  final String title, outlet, heroLabel, heroBig, heroSub, search, placeholder, empty;
  final List<RpChip> periods, cats;
  final List<RpTile> methods, kpis, quick;
  final List<RpSection> sections;
}

abstract class ReportsActions {
  void scan();
  void nav(String pageId);
  void rpOutlet();
  void rpPeriod(int index);
  void rpKpi(int index);
  void rpQuick(int index);
  void rpSearch(String text);
  void rpCategory(int index);
  void rpOpen(int index);
}

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);
final _cardShadow = [gShadow(const Color(0xffeef0f3), 1, 0)];

class NativeReports extends StatefulWidget {
  const NativeReports({super.key, required this.model, required this.actions, this.topInset});
  final ReportsModel model;
  final ReportsActions actions;
  final double? topInset;
  @override
  State<NativeReports> createState() => _NativeReportsState();
}

class _NativeReportsState extends State<NativeReports> {
  late final TextEditingController _search = TextEditingController(text: widget.model.search);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(NativeReports old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _search.text != widget.model.search) _search.text = widget.model.search;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => widget.actions.rpSearch(v));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final rows = <Widget>[
      _Chips(chips: m.periods, onTap: a.rpPeriod, height: 32, radius: 16, onBg: gBrand, offBorder: const Color(0xffe6e8ec)),
      const SizedBox(height: 10),
      if (m.heroBig.isNotEmpty) _Hero(model: m),
      if (m.kpis.isNotEmpty) ...[const SizedBox(height: 10), _KpiGrid(kpis: m.kpis, onTap: a.rpKpi)],
      if (m.quick.isNotEmpty) ...[const SizedBox(height: 12), _Quick(items: m.quick, onTap: a.rpQuick)],
      const SizedBox(height: 12),
      _SearchBox(controller: _search, focus: _focus, placeholder: m.placeholder, onChanged: _onSearch),
      const SizedBox(height: 10),
      _CatChips(chips: m.cats, onTap: a.rpCategory),
      for (final sec in m.sections) ...[
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 7), child: Text(sec.title, style: gText(12, w: FontWeight.w500, c: _muted, h: 16.8))),
        _List(items: sec.items, onTap: a.rpOpen),
      ],
      if (m.empty.isNotEmpty) Padding(padding: const EdgeInsets.all(28), child: Text(m.empty, textAlign: TextAlign.center, style: gText(13, c: _muted))),
    ];
    return Material(
      color: const Color(0xfff6f7f9),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          Container(
            height: 50, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(m.title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7))),
              if (m.outlet.isNotEmpty)
                GestureDetector(
                  onTap: a.rpOutlet,
                  child: Container(
                    height: 36, padding: const EdgeInsets.symmetric(horizontal: 13), alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
                    child: Text(m.outlet, style: gText(11.5, w: FontWeight.w500, c: const Color(0xff646d7a))),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 2, onTap: a.nav)),
      ]),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.chips, required this.onTap, required this.height, required this.radius, required this.onBg, required this.offBorder});
  final List<RpChip> chips;
  final ValueChanged<int> onTap;
  final double height, radius;
  final Color onBg, offBorder;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (context, i) => const SizedBox(width: 6),
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13), alignment: Alignment.center,
              decoration: BoxDecoration(color: chips[i].on ? onBg : Colors.white, borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: chips[i].on ? onBg : offBorder)),
              child: Text(chips[i].t, style: gText(12.5, w: FontWeight.w500, c: chips[i].on ? Colors.white : const Color(0xff5b5f6e))),
            ),
          ),
        ),
      );
}

class _CatChips extends StatelessWidget {
  const _CatChips({required this.chips, required this.onTap});
  final List<RpChip> chips;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (context, i) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final c = chips[i];
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                decoration: BoxDecoration(color: cssColor(c.bg, c.on ? _ink : Colors.white), borderRadius: BorderRadius.circular(8), boxShadow: _cardShadow),
                child: Text(c.t, style: gText(12, w: FontWeight.w500, c: cssColor(c.c, c.on ? Colors.white : const Color(0xff5b5f6e)))),
              ),
            );
          },
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.model});
  final ReportsModel model;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xffff6b48), Color(0xfff0472f)]),
          borderRadius: BorderRadius.circular(18), boxShadow: [gShadow(const Color(0x38e8493f), 8, 20)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(model.heroLabel, style: gText(12, c: Colors.white, h: 16.8)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(model.heroBig, style: gText(28, c: Colors.white, h: 39.2))),
          const SizedBox(height: 2),
          Text(model.heroSub, style: gText(12, c: Colors.white, h: 16.8)),
          if (model.methods.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 16) / 3;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final pm in model.methods)
                  Container(
                    width: w, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0x29ffffff), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pm.title, style: gText(10.5, c: Colors.white, h: 14.7)),
                      const SizedBox(height: 1),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                          child: Text(pm.value, style: gText(13.5, w: FontWeight.w500, c: Colors.white, h: 18.9))),
                    ]),
                  ),
              ]);
            }),
          ],
        ]),
      );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.onTap});
  final List<RpTile> kpis;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kpis.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                width: w, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _cardShadow),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 22, height: 22, alignment: Alignment.center,
                        decoration: BoxDecoration(color: cssColor(kpis[i].bg, const Color(0xfff2f4f7)), borderRadius: BorderRadius.circular(7)),
                        child: Text(kpis[i].icon, style: gText(12, c: _muted))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(kpis[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11.5, c: _muted, h: 16.1))),
                  ]),
                  const SizedBox(height: 4),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                      child: Text(kpis[i].value, style: gText(16, w: FontWeight.w500, c: _ink, h: 22.4))),
                  const SizedBox(height: 1),
                  Text(kpis[i].sub.isEmpty ? ' ' : kpis[i].sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(10.5, c: _muted, h: 14.7)),
                ]),
              ),
            ),
        ]);
      });
}

class _Quick extends StatelessWidget {
  const _Quick({required this.items, required this.onTap});
  final List<RpTile> items;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _cardShadow),
                child: Column(children: [
                  Container(width: 36, height: 36, alignment: Alignment.center,
                      decoration: BoxDecoration(color: cssColor(items[i].bg, const Color(0xfff2f4f7)), borderRadius: BorderRadius.circular(11)),
                      child: Text(items[i].icon, style: gText(18, c: _ink))),
                  const SizedBox(height: 6),
                  Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: gText(11, w: FontWeight.w500, c: _ink, h: 13.2)),
                ]),
              ),
            ),
          ),
        ],
      ]);
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.focus, required this.placeholder, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe6e8ec))),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xff8f98a4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller, focusNode: focus, onChanged: onChanged, cursorColor: gBrand,
              textInputAction: TextInputAction.search, style: gText(13, c: _ink),
              decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: placeholder, hintStyle: gText(13, c: const Color(0xffb4b8c4))),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(onTap: () { controller.clear(); onChanged(''); },
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: Color(0xff929ba7)))),
          ),
        ]),
      );
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.onTap});
  final List<RpTile> items;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _cardShadow),
        child: Column(children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(items[i].index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Color(0xfff2f3f5)))),
                child: Row(children: [
                  Container(width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(color: cssColor(items[i].bg, const Color(0xfff2f4f7)), borderRadius: BorderRadius.circular(12)),
                      child: Text(items[i].icon, style: const TextStyle(fontSize: 19))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(13.5, w: FontWeight.w500, c: _ink, h: 18.9)),
                      const SizedBox(height: 1),
                      Text(items[i].sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11, c: _muted, h: 15.4)),
                    ]),
                  ),
                  if (items[i].value.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(items[i].value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: gText(12, c: _ink))),
                  ],
                  const SizedBox(width: 8),
                  Text('›', style: gText(18, c: const Color(0xffc3c7d0))),
                ]),
              ),
            ),
        ]),
      );
}
