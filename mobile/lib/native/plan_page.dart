import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'common.dart';

// Jalur B7: #plan111 tidak lagi digambar oleh renderer cermin generik.
// Teks/detail yang sedang terbuka tetap dibaca dari model mirror plan111.
// Harga, urutan paket, paket aktif, tombol Detail & Riwayat memakai item model
// Harga Paket (upgrade) yang sudah berada di shell, jadi tidak ada harga/teks yang
// ditulis ulang di Dart.

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v'.trim());
Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

String _norm(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

Iterable<Map<String, dynamic>> _walk(Map<String, dynamic> node) sync* {
  yield node;
  for (final child in _l(node['ch'])) {
    yield* _walk(child);
  }
}

List<String> _ownTexts(Map<String, dynamic> node) {
  final spans = node['spans'];
  if (spans is! List) return const [];
  final upper = _m(node['s'])['up'] == 1;
  return spans
      .whereType<Map>()
      .map((sp) => _norm(_s(sp['t'])))
      .where((t) => t.isNotEmpty)
      .map((t) => upper ? t.toUpperCase() : t)
      .toList();
}

String _deepText(Map<String, dynamic> node) =>
    _norm(_walk(node).expand(_ownTexts).join(' '));

List<String> _allTexts(Map<String, dynamic> root) {
  final out = <String>[];
  for (final node in _walk(root)) {
    for (final text in _ownTexts(node)) {
      if (text.isNotEmpty) out.add(text);
    }
  }
  return out;
}

class _ButtonRef {
  const _ButtonRef(this.label, this.index, this.node);
  final String label;
  final int index;
  final Map<String, dynamic> node;
}

class _PlanFeature {
  const _PlanFeature(this.text, this.included);
  final String text;
  final bool included;
}

class _PlanAccent {
  const _PlanAccent(this.main, this.soft);
  final Color main, soft;
}

const _accents = <String, _PlanAccent>{
  'FREE': _PlanAccent(Color(0xff667085), Color(0xfff2f4f7)),
  'BASIC': _PlanAccent(gBrand, Color(0xfffff0ee)),
  'SILVER': _PlanAccent(Color(0xff718096), Color(0xffedf1f5)),
  'GOLD': _PlanAccent(Color(0xffb7791f), Color(0xfffff4d8)),
  'PLATINUM': _PlanAccent(Color(0xff53658d), Color(0xffeef1f8)),
};

_PlanAccent _accent(String id) => _accents[id] ?? _accents['BASIC']!;

const _planSvgs = <String, String>{
  'FREE': '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7.5h16v12H4z"/><path d="M12 7.5v12M3 7.5h18V4.8H3z"/><path d="M12 4.8c-2.5 0-4-.8-4-2 0-1 .8-1.6 1.8-1.6 1.5 0 2.2 1.5 2.2 3.6zM12 4.8c2.5 0 4-.8 4-2 0-1-.8-1.6-1.8-1.6-1.5 0-2.2 1.5-2.2 3.6z"/></svg>''',
  'BASIC': '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 5.5h14v14H5z"/><path d="M8 5.5V4a1.8 1.8 0 0 1 1.8-1.8h4.4A1.8 1.8 0 0 1 16 4v1.5M8.5 10h7M8.5 14h5"/></svg>''',
  'SILVER': '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 8 4.2-8 4.2L4 7.2 12 3Z"/><path d="m5.5 11 6.5 3.4 6.5-3.4M5.5 15l6.5 3.4 6.5-3.4"/></svg>''',
  'GOLD': '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m4 7 4.3 4 3.7-6 3.7 6L20 7l-1.5 10H5.5L4 7Z"/><path d="M6 20h12"/></svg>''',
  'PLATINUM': '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m7 4-4 5 9 11 9-11-4-5H7Z"/><path d="m3 9 9 3 9-3M7 4l5 8 5-8"/></svg>''',
};

const _checkSvg = '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16.5 8.5"/></svg>''';
const _yesSvg = '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-10"/></svg>''';
const _noSvg = '''<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round"><path d="m6 6 12 12M18 6 6 18"/></svg>''';

Widget _svg(String svg, double size, Color color) => SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

Widget _planIcon(String id, double size, Color color) =>
    _svg(_planSvgs[id] ?? _planSvgs['BASIC']!, size, color);

class _PlanData {
  _PlanData({
    required this.title,
    required this.planId,
    required this.heroTitle,
    required this.description,
    required this.price,
    required this.per,
    required this.currentLabel,
    required this.currentValue,
    required this.currentStatus,
    required this.activePlanId,
    required this.features,
    required this.note,
    required this.buttons,
    required this.tabs,
    required this.selectedTab,
    required this.sectionTexts,
    required this.comparisonRows,
    required this.planItems,
    required this.historyItem,
  });

  final String title, planId, heroTitle, description, price, per;
  final String currentLabel, currentValue, currentStatus, activePlanId;
  final List<_PlanFeature> features;
  final String note;
  final List<_ButtonRef> buttons, tabs;
  final String selectedTab;
  final List<String> sectionTexts;
  final List<List<String>> comparisonRows;
  final List<Map<String, dynamic>> planItems;
  final Map<String, dynamic>? historyItem;

  bool get selectedIsActive => planId.isNotEmpty && planId == activePlanId;

  _ButtonRef? button(String label) {
    for (final b in buttons) {
      if (_norm(b.label).toLowerCase() == _norm(label).toLowerCase()) return b;
    }
    return null;
  }

  _ButtonRef? get cta {
    for (final b in buttons.reversed) {
      final low = b.label.toLowerCase();
      if (b.label == '‹' || const {'fitur', 'promo', 'ulasan'}.contains(low) || low.contains('perbandingan')) continue;
      return b;
    }
    return null;
  }

  static _PlanData from(Map<String, dynamic> mirror, List<Map<String, dynamic>> pricingItems) {
    final body = _m(mirror['body']);
    final texts = _allTexts(body);
    final buttons = <_ButtonRef>[];
    for (final node in _walk(body)) {
      final bi = node['b'];
      if (bi is! num) continue;
      final label = _deepText(node);
      if (label.isNotEmpty) buttons.add(_ButtonRef(label, bi.toInt(), node));
    }

    const ids = ['FREE', 'BASIC', 'SILVER', 'GOLD', 'PLATINUM'];
    var planId = '';
    String? heroTitle;
    for (final t in texts) {
      final u = t.toUpperCase();
      final match = RegExp(r'\bPAKET\s+(FREE|BASIC|SILVER|GOLD|PLATINUM)\b').firstMatch(u);
      if (match != null) {
        planId = match.group(1)!;
        if (t == u) heroTitle ??= t;
        break;
      }
    }
    if (planId.isEmpty) {
      for (final id in ids) {
        if (texts.any((t) => t.toUpperCase() == id)) {
          planId = id;
          break;
        }
      }
    }
    heroTitle ??= planId.isEmpty ? '' : 'PAKET $planId';

    var title = texts.firstWhere(
      (t) => RegExp(r'^PAKET\s+(FREE|BASIC|SILVER|GOLD|PLATINUM)$', caseSensitive: false).hasMatch(t),
      orElse: () => heroTitle!,
    );

    final planItems = pricingItems.where((it) => _s(it['type']) == 'plan').map((e) => Map<String, dynamic>.from(e)).toList();
    Map<String, dynamic>? selectedPlan;
    for (final it in planItems) {
      if (_s(it['t']).toUpperCase() == planId) {
        selectedPlan = it;
        break;
      }
    }

    Map<String, dynamic>? current;
    for (final it in pricingItems) {
      if (_s(it['type']) == 'hero' && _s(it['t']).toUpperCase().contains('PAKET SAAT INI')) {
        current = it;
        break;
      }
    }
    final currentValue = _s(current?['v']);
    var activePlanId = '';
    final upperCurrent = currentValue.toUpperCase();
    if (upperCurrent.contains('TRIAL BASIC')) {
      activePlanId = 'BASIC';
    } else {
      for (final id in ids.reversed) {
        if (upperCurrent.contains(id)) {
          activePlanId = id;
          break;
        }
      }
    }

    var description = _s(selectedPlan?['s']);
    if (description.isEmpty && heroTitle!.isNotEmpty) {
      final hi = texts.indexOf(heroTitle);
      if (hi >= 0 && hi + 1 < texts.length) description = texts[hi + 1];
    }

    final features = <_PlanFeature>[];
    final featureSeen = <String>{};
    for (final node in _walk(body)) {
      if (node['row'] != true) continue;
      final svgs = _walk(node).map((n) => _s(n['svg'])).where((s) => s.isNotEmpty).toList();
      if (svgs.isEmpty) continue;
      final included = svgs.any((s) => s.contains('m4 12 5 5L20 6') || s.contains('#82b956'));
      final excluded = svgs.any((s) => s.contains('m5 5 14 14') || s.contains('M19 5 5 19') || s.contains('14 14'));
      if (!included && !excluded) continue;
      final rowTexts = _walk(node).expand(_ownTexts).where((t) => t.length > 1).toList();
      if (rowTexts.isEmpty) continue;
      final label = rowTexts.last;
      if (featureSeen.add(label)) features.add(_PlanFeature(label, included));
    }

    String note = '';
    for (final t in texts) {
      if (t.startsWith('Centang menunjukkan') || t.startsWith('Chatbot AI memakai')) {
        note = t;
        break;
      }
    }

    final tabs = buttons.where((b) => const {'fitur', 'promo', 'ulasan'}.contains(b.label.toLowerCase())).toList();
    final comparison = texts.contains('Perbandingan Fitur');
    var selectedTab = '';
    if (comparison) {
      selectedTab = 'compare';
    } else if (features.isNotEmpty) {
      selectedTab = 'fitur';
    } else if (texts.any((t) => t.toLowerCase().contains('belum ada promo'))) {
      selectedTab = 'promo';
    } else if (texts.any((t) => t.toLowerCase().contains('ulasan pelanggan'))) {
      selectedTab = 'ulasan';
    } else {
      for (final tab in tabs) {
        final c = _s(_m(tab.node['s'])['c']);
        if (c.contains('218, 117, 104') || c.contains('232, 73, 63')) {
          selectedTab = tab.label.toLowerCase();
          break;
        }
      }
    }

    final skip = <String>{
      '‹', title, heroTitle, description, note,
      ...tabs.map((e) => e.label),
      ...features.map((e) => e.text),
    }..removeWhere((e) => e.isEmpty);
    final buttonLabels = buttons.map((e) => e.label).toSet();
    final sectionTexts = <String>[];
    for (final text in texts) {
      if (skip.contains(text) || buttonLabels.contains(text)) continue;
      if (text.length == 1 && ids.any((id) => id.startsWith(text.toUpperCase()))) continue;
      if (text == 'Perbandingan Fitur') continue;
      if (!sectionTexts.contains(text)) sectionTexts.add(text);
    }

    final comparisonRows = <List<String>>[];
    if (comparison) {
      final h = texts.indexOf('Perbandingan Fitur');
      if (h >= 0) {
        var cells = texts.sublist(h + 1);
        final ctaLabels = buttons.map((e) => e.label).toSet();
        final stop = cells.indexWhere((t) => ctaLabels.contains(t) && t != 'Fitur' && t != 'Promo' && t != 'Ulasan');
        if (stop >= 0) cells = cells.sublist(0, stop);
        final start = cells.indexWhere((t) => t == 'Fitur');
        if (start >= 0) cells = cells.sublist(start);
        for (var i = 0; i + 5 < cells.length; i += 6) {
          comparisonRows.add(cells.sublist(i, i + 6));
        }
      }
    }

    Map<String, dynamic>? historyItem;
    for (final it in pricingItems) {
      if (_s(it['type']) == 'button' && _s(it['t']).toLowerCase().contains('riwayat transaksi')) {
        historyItem = it;
        break;
      }
    }

    return _PlanData(
      title: title,
      planId: planId,
      heroTitle: heroTitle,
      description: description,
      price: _s(selectedPlan?['price']),
      per: _s(selectedPlan?['per']),
      currentLabel: _s(current?['t']),
      currentValue: currentValue,
      currentStatus: _s(current?['s']),
      activePlanId: activePlanId,
      features: features,
      note: note,
      buttons: buttons,
      tabs: tabs,
      selectedTab: selectedTab,
      sectionTexts: sectionTexts,
      comparisonRows: comparisonRows,
      planItems: planItems,
      historyItem: historyItem,
    );
  }
}

class NativePlanPage extends StatelessWidget {
  const NativePlanPage({
    super.key,
    required this.model,
    required this.pricingItems,
    required this.onButton,
    required this.onPricingButton,
    required this.onNav,
    required this.onHeaderScan,
    this.topInset,
  });

  /// Model mirror yang sekarang dikirim khusus untuk #plan111.
  final Map<String, dynamic> model;

  /// Item model Harga Paket (`upgrade`) yang sudah tersimpan di shell. Model ini
  /// adalah sumber harga, urutan paket dan status paket aktif; tidak ada angka
  /// paket yang di-hardcode di widget.
  final List<Map<String, dynamic>> pricingItems;
  final ValueChanged<int> onButton;
  final ValueChanged<int> onPricingButton;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final data = _PlanData.from(model, pricingItems);
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    final nav = (model['nav'] as num?)?.toInt() ?? -1;
    final cta = data.cta;
    return Material(
      color: Colors.white,
      child: Column(children: [
        if (model['head'] == true) GTopBar(top: top, onScan: onHeaderScan) else SizedBox(height: top),
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 10, 16, cta == null ? 24 : 104),
                children: [
                  _Subhead(data: data, onButton: onButton),
                  if (data.currentValue.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CurrentPlan(data: data, onPricingButton: onPricingButton),
                  ],
                  if (data.planItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PlanRail(data: data, onPricingButton: onPricingButton),
                  ],
                  const SizedBox(height: 14),
                  _Hero(data: data),
                  if (data.tabs.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Tabs(data: data, onButton: onButton),
                  ],
                  const SizedBox(height: 14),
                  _Body(data: data, onButton: onButton),
                ],
              ),
            ),
            if (cta != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(top: BorderSide(color: Color(0xffeceff3))),
                    boxShadow: [gShadow(const Color(0x16000000), -2, 18)],
                  ),
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => onButton(cta.index),
                      style: FilledButton.styleFrom(
                        backgroundColor: gBrand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: gText(13.5, w: FontWeight.w600, c: Colors.white),
                      ),
                      child: Text(cta.label),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        if (nav >= 0) GBottomNav(onTap: onNav, active: nav > 3 ? -1 : nav),
      ]),
    );
  }
}

class _Subhead extends StatelessWidget {
  const _Subhead({required this.data, required this.onButton});
  final _PlanData data;
  final ValueChanged<int> onButton;

  @override
  Widget build(BuildContext context) {
    final back = data.button('‹');
    return SizedBox(
      height: 42,
      child: Row(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: back == null ? null : () => onButton(back.index),
          child: Container(
            width: 38,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(10)),
            child: Text('‹', style: gText(22, w: FontWeight.w500, c: const Color(0xff27323e), h: 22)),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14.5, w: FontWeight.w600, c: const Color(0xff1e1e1e), ls: .6))),
      ]),
    );
  }
}

class _CurrentPlan extends StatelessWidget {
  const _CurrentPlan({required this.data, required this.onPricingButton});
  final _PlanData data;
  final ValueChanged<int> onPricingButton;

  @override
  Widget build(BuildContext context) {
    final id = data.activePlanId.isEmpty ? data.currentValue : data.activePlanId;
    final accent = _accent(id);
    final history = data.historyItem;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.main.withAlpha(50)),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: _planIcon(id, 25, accent.main),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (data.currentLabel.isNotEmpty) Text(data.currentLabel, style: gText(9.5, w: FontWeight.w600, c: accent.main, ls: .7)),
            const SizedBox(height: 2),
            Text(data.currentValue, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(15.5, w: FontWeight.w600, c: const Color(0xff20242b))),
            if (data.currentStatus.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(data.currentStatus, maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(10.5, c: const Color(0xff6f7785), h: 15)),
            ],
          ]),
        ),
        if (history != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: history['i'] is num ? () => onPricingButton((history['i'] as num).toInt()) : null,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 102),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.main.withAlpha(55))),
              child: Text(_s(history['t']), textAlign: TextAlign.center, style: gText(10, w: FontWeight.w500, c: accent.main, h: 13)),
            ),
          ),
      ]),
    );
  }
}

class _PlanRail extends StatelessWidget {
  const _PlanRail({required this.data, required this.onPricingButton});
  final _PlanData data;
  final ValueChanged<int> onPricingButton;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: data.planItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final item = data.planItems[i];
            final id = _s(item['t']).toUpperCase();
            final accent = _accent(id);
            final active = id == data.activePlanId;
            final selected = id == data.planId;
            final bi = (item['i'] as num?)?.toInt();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: bi == null ? null : () => onPricingButton(bi),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 68,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? accent.soft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? accent.main : (selected ? accent.main.withAlpha(90) : const Color(0xffeceff3)), width: active ? 1.8 : 1),
                  boxShadow: selected ? [gShadow(accent.main.withAlpha(22), 3, 12)] : null,
                ),
                child: Stack(children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Center(child: _planIcon(id, 24, accent.main)),
                    const SizedBox(height: 7),
                    Text(id, maxLines: 1, overflow: TextOverflow.fade, style: gText(9.2, w: selected || active ? FontWeight.w600 : FontWeight.w500, c: accent.main)),
                  ]),
                  if (active)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: accent.main)),
                        child: _svg(_yesSvg, 10, accent.main),
                      ),
                    ),
                ]),
              ),
            );
          },
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final _PlanData data;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(data.planId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.main.withAlpha(42)),
        boxShadow: [gShadow(const Color(0x120f172a), 5, 20)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(17)),
          child: _planIcon(data.planId, 30, accent.main),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(data.heroTitle, style: gText(16.5, w: FontWeight.w600, c: const Color(0xff252a31), h: 22))),
              if (data.selectedIsActive)
                Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: accent.soft, shape: BoxShape.circle),
                  child: _svg(_checkSvg, 18, accent.main),
                ),
            ]),
            if (data.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(data.description, style: gText(11.5, c: const Color(0xff7b8492), h: 17)),
            ],
            if (data.price.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 5, children: [
                Text(data.price, style: gText(20, w: FontWeight.w600, c: accent.main, h: 23)),
                if (data.per.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(data.per, style: gText(10.5, c: const Color(0xff9299a5)))),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.data, required this.onButton});
  final _PlanData data;
  final ValueChanged<int> onButton;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xfff4f5f7), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final tab in data.tabs)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onButton(tab.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: data.selectedTab == tab.label.toLowerCase() ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: data.selectedTab == tab.label.toLowerCase() ? [gShadow(const Color(0x12000000), 2, 8)] : null,
                  ),
                  child: Text(tab.label, style: gText(11.5, w: FontWeight.w600, c: data.selectedTab == tab.label.toLowerCase() ? gBrand : const Color(0xff747d8b))),
                ),
              ),
            ),
        ]),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.onButton});
  final _PlanData data;
  final ValueChanged<int> onButton;

  @override
  Widget build(BuildContext context) {
    if (data.selectedTab == 'compare' && data.comparisonRows.isNotEmpty) {
      return _Comparison(rows: data.comparisonRows);
    }
    if (data.features.isNotEmpty) {
      final compare = data.buttons.where((b) => b.label.toLowerCase().contains('perbandingan')).toList();
      return Column(children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffeceff3))),
          child: Column(children: [
            for (var i = 0; i < data.features.length; i++) ...[
              _FeatureRow(feature: data.features[i]),
              if (i + 1 < data.features.length) const Divider(height: 1, indent: 48, endIndent: 12, color: Color(0xfff0f2f5)),
            ],
          ]),
        ),
        if (data.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xfff8f9fb), borderRadius: BorderRadius.circular(14)),
            child: Text(data.note, style: gText(10.5, c: const Color(0xff7c8592), h: 16)),
          ),
        ],
        if (compare.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => onButton(compare.first.index),
              style: OutlinedButton.styleFrom(
                foregroundColor: gBrand,
                side: const BorderSide(color: gBrand),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: gText(11.5, w: FontWeight.w600, c: gBrand),
              ),
              child: Text(compare.first.label),
            ),
          ),
        ],
      ]);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffeceff3))),
      child: data.sectionTexts.isEmpty
          ? const SizedBox(height: 36)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < data.sectionTexts.length; i++) ...[
                Text(data.sectionTexts[i], style: gText(12.5, c: const Color(0xff707986), h: 19)),
                if (i + 1 < data.sectionTexts.length) const SizedBox(height: 10),
              ],
            ]),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final _PlanFeature feature;

  @override
  Widget build(BuildContext context) {
    final color = feature.included ? const Color(0xff6aa33f) : const Color(0xffb04e59);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(9)),
          child: _svg(feature.included ? _yesSvg : _noSvg, 18, color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(feature.text, style: gText(12.2, c: const Color(0xff30343b), h: 18)))),
      ]),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.rows});
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffeceff3))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var r = 0; r < rows.length; r++)
              Container(
                decoration: BoxDecoration(color: r == 0 ? const Color(0xfff8f9fb) : Colors.transparent, borderRadius: r == 0 ? BorderRadius.circular(10) : null),
                child: Row(children: [
                  for (var c = 0; c < rows[r].length; c++)
                    SizedBox(
                      width: c == 0 ? 220 : 84,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        child: Text(
                          rows[r][c],
                          textAlign: c == 0 ? TextAlign.left : TextAlign.center,
                          style: gText(
                            r == 0 ? 10.5 : 10,
                            w: r == 0 || c == 0 ? FontWeight.w600 : FontWeight.w400,
                            c: rows[r][c] == '✓' ? const Color(0xff6aa33f) : (rows[r][c] == '×' ? const Color(0xffb04e59) : const Color(0xff4f5865)),
                            h: 15,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      );
}
