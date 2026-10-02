import 'dart:async';

import 'package:flutter/material.dart';

import 'common.dart';

/// A colored label from the web app (status, payment, chips). Colors come from
/// the HTML's computed CSS so every status keeps its own color.
class Chip62 {
  const Chip62(this.text, this.bg, this.fg);
  final String text;
  final Color bg, fg;

  static Chip62? from(Object? j) {
    if (j is! Map) return null;
    final t = '${j['t'] ?? ''}'.trim();
    if (t.isEmpty) return null;
    return Chip62(t, cssColor(j['bg'] as String?), cssColor(j['c'] as String?, gInk));
  }
}

class OrderCardModel {
  const OrderCardModel({
    required this.index, required this.id, required this.name, required this.amount,
    this.dur, this.status, this.pay, this.auto, this.action,
    this.lines = const [], this.chips = const [], this.female = false,
  });
  final int index;
  final String id, name, amount;
  final Chip62? dur, status, pay, auto, action;
  final List<String> lines;
  final List<Chip62> chips;
  final bool female;

  factory OrderCardModel.fromJson(Map<String, dynamic> j) => OrderCardModel(
        index: (j['i'] as num?)?.toInt() ?? 0,
        id: '${j['id'] ?? ''}'.trim(), name: '${j['name'] ?? ''}'.trim(), amount: '${j['amount'] ?? ''}'.trim(),
        dur: Chip62.from(j['dur']), status: Chip62.from(j['status']), pay: Chip62.from(j['pay']),
        auto: Chip62.from(j['auto']), action: Chip62.from(j['action']),
        lines: (j['lines'] is List) ? (j['lines'] as List).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() : const [],
        chips: (j['chips'] is List) ? (j['chips'] as List).map(Chip62.from).whereType<Chip62>().toList() : const [],
        female: j['gender'] == 'female',
      );
}

class OrderTab {
  const OrderTab(this.label, this.count, this.on);
  final String label, count;
  final bool on;
}

class OrdersModel {
  const OrdersModel({
    this.title = 'Pesanan', this.autoLabel, this.autoOn = false, this.search = '',
    this.placeholder = 'Cari nama / ID / no HP', this.tabs = const [], this.cards = const [], this.empty = '',
  });
  final String title, search, placeholder, empty;
  final String? autoLabel;
  final bool autoOn;
  final List<OrderTab> tabs;
  final List<OrderCardModel> cards;

  factory OrdersModel.fromJson(Map<String, dynamic> j) {
    final auto = j['auto'] is Map ? j['auto'] as Map : null;
    return OrdersModel(
      title: '${j['title'] ?? 'Pesanan'}'.trim(),
      autoLabel: auto == null ? null : '${auto['t'] ?? ''}'.trim(), autoOn: auto?['on'] == true,
      search: '${j['search'] ?? ''}', placeholder: '${j['placeholder'] ?? 'Cari nama / ID / no HP'}',
      tabs: (j['tabs'] is List)
          ? (j['tabs'] as List).whereType<Map>().map((t) => OrderTab('${t['t'] ?? ''}', '${t['n'] ?? ''}', t['on'] == true)).toList()
          : const [],
      cards: (j['cards'] is List)
          ? (j['cards'] as List).whereType<Map>().map((c) => OrderCardModel.fromJson(Map<String, dynamic>.from(c))).toList()
          : const [],
      empty: '${j['empty'] ?? ''}'.trim(),
    );
  }
}

abstract class OrdersActions {
  void scan();
  void nav(String pageId);
  void autoSettings();
  void addOrder();
  void search(String text);
  void tab(int index);
  void openCard(int index);
  void cardAction(int index);
}

const _muted = Color(0xff8a8fa3);
const _line = Color(0xffeceef2);

const _svgAuto =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#2B6AA6" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="13" r="7.5"/><path d="M12 9v4l2.5 2"/><path d="M9 2.5h6"/></svg>';
const _svgSearch =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#929BA7" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/></svg>';
const _svgMale =
    '<svg viewBox="0 0 64 64"><path d="M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54" fill="#5C97F8"/><circle cx="32" cy="26" r="11" fill="#FFD6B3"/><path d="M21 24.5c0-8.5 4.5-13.5 11-13.5 6.6 0 11 5 11 13.5v2.1H21v-2.1z" fill="#26384D"/><circle cx="28" cy="26" r="1.3" fill="#26384D"/><circle cx="36" cy="26" r="1.3" fill="#26384D"/><path d="M29 31c1.6 1.6 4.4 1.6 6 0" stroke="#D58A78" stroke-width="1.7" fill="none" stroke-linecap="round"/></svg>';
const _svgFemale =
    '<svg viewBox="0 0 64 64"><path d="M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54" fill="#E56A8C"/><circle cx="32" cy="26" r="11" fill="#FFD8C7"/><path d="M18.5 26.2c0-9.6 5.1-15 13.5-15s13.5 5.4 13.5 15c0 4.5-1.7 8.4-4.4 11-1.1-6.9-4.3-10.6-9.1-10.6s-8 3.7-9.1 10.6c-2.7-2.6-4.4-6.5-4.4-11z" fill="#6D4A3C"/><circle cx="28" cy="26" r="1.3" fill="#453126"/><circle cx="36" cy="26" r="1.3" fill="#453126"/><path d="M29 31c1.6 1.6 4.4 1.6 6 0" stroke="#D88A86" stroke-width="1.7" fill="none" stroke-linecap="round"/></svg>';

/// Native Pesanan page. Lists, filters and actions run the HTML app's logic.
class NativeOrders extends StatefulWidget {
  const NativeOrders({super.key, required this.model, required this.actions, this.topInset});
  final OrdersModel model;
  final OrdersActions actions;
  final double? topInset;

  @override
  State<NativeOrders> createState() => _NativeOrdersState();
}

class _NativeOrdersState extends State<NativeOrders> {
  late final TextEditingController _search = TextEditingController(text: widget.model.search);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(NativeOrders old) {
    super.didUpdateWidget(old);
    // Keep the field in step with the app, except while the user is typing.
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
    _debounce = Timer(const Duration(milliseconds: 180), () => widget.actions.search(v));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: const Color(0xfff4f5f7),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          _Header(title: m.title, autoLabel: m.autoLabel, autoOn: m.autoOn, onAuto: a.autoSettings),
          _SearchRow(controller: _search, focus: _focus, placeholder: m.placeholder, onChanged: _onSearch, onAdd: a.addOrder),
          _Tabs(tabs: m.tabs, onTap: a.tab),
          Expanded(
            child: m.cards.isEmpty
                ? _Empty(text: m.empty.isNotEmpty ? m.empty : 'Belum ada pesanan di tab ini')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                    itemCount: m.cards.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OrderCard(
                        card: m.cards[i],
                        onTap: () => a.openCard(m.cards[i].index),
                        onAction: () => a.cardAction(m.cards[i].index),
                      ),
                    ),
                  ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 1, onTap: a.nav)),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.autoLabel, required this.autoOn, required this.onAuto});
  final String title;
  final String? autoLabel;
  final bool autoOn;
  final VoidCallback onAuto;
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text(title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: const Color(0xff1e1e1e), ls: .7))),
          if (autoLabel != null)
            GestureDetector(
              onTap: onAuto,
              child: Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: autoOn ? const Color(0xfff3f8ff) : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: autoOn ? const Color(0xffbcd6f5) : const Color(0xffe3e6ea)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  gSvg(_svgAuto, 17),
                  const SizedBox(width: 5),
                  Text(autoLabel!, style: gText(12, c: const Color(0xff5b5f6e), h: 16.8)),
                ]),
              ),
            ),
        ]),
      );
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.focus, required this.placeholder, required this.onChanged, required this.onAdd});
  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xfff8f9fa), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe3e6ea))),
              child: Row(children: [
                gSvg(_svgSearch, 18),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: controller, focusNode: focus, onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: gText(14, c: const Color(0xff1e1e1e)),
                    cursorColor: gBrand,
                    decoration: InputDecoration(
                      isCollapsed: true, border: InputBorder.none, hintText: placeholder,
                      hintStyle: gText(14, c: const Color(0xffb4b8c4)),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () { controller.clear(); onChanged(''); },
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xff929ba7)),
                        ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(12),
                  boxShadow: [gShadow(const Color(0x40e8493f), 4, 10)]),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ]),
      );
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.tabs, required this.onTap});
  final List<OrderTab> tabs;
  final ValueChanged<int> onTap;
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final _keys = <int, GlobalKey>{};
  int _lastOn = -1;

  @override
  void didUpdateWidget(_Tabs old) {
    super.didUpdateWidget(old);
    final on = widget.tabs.indexWhere((t) => t.on);
    if (on != _lastOn && on >= 0) {
      _lastOn = on;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[on]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 250));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0xffeceef1), offset: Offset(0, 1))]),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: widget.tabs.length,
          itemBuilder: (context, i) {
            final t = widget.tabs[i];
            final hasCount = t.count.isNotEmpty;
            return GestureDetector(
              key: _keys.putIfAbsent(i, GlobalKey.new),
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.on ? gBrand : Colors.transparent, width: 3))),
                child: Row(children: [
                  Text(t.label, style: gText(13.5, w: FontWeight.w500, c: t.on ? const Color(0xff1e1e1e) : _muted)),
                  if (hasCount) ...[
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18), height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.on ? gBrand : const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                      child: Text(t.count, style: gText(10, c: t.on ? Colors.white : _muted, h: 18)),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      );
}

Widget _chip(Chip62 c, {EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 7, vertical: 2), double size = 10.5, FontWeight w = FontWeight.w400}) =>
    Container(
      padding: pad,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(6)),
      child: Text(c.text, maxLines: 1, style: gText(size, w: w, c: c.fg, h: size * 1.4)),
    );

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = (c.maxWidth / 6).floor();
        return Row(children: List.generate(n, (_) => Container(width: 3, height: 1, margin: const EdgeInsets.only(right: 3), color: _line)));
      });
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.card, required this.onTap, required this.onAction});
  final OrderCardModel card;
  final VoidCallback onTap, onAction;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final footer = c.auto != null || c.chips.isNotEmpty || c.action != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line),
          boxShadow: [gShadow(const Color(0x0d141e32), 2, 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(c.id, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: gText(11.5, w: FontWeight.w500, c: _muted, h: 16.1, ls: .3))),
            if (c.dur != null) _chip(c.dur!),
            if (c.status != null) ...[const SizedBox(width: 6), _chip(c.status!, pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 2))],
          ]),
          const SizedBox(height: 9),
          const _DashedLine(),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 54, alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: c.female ? const [Color(0xfffff1f5), Color(0xfffde3eb)] : const [Color(0xffeef7ff), Color(0xffdfeefe)]),
                border: Border.all(color: c.female ? const Color(0xfff6dbe6) : const Color(0xffdde5ee)),
                boxShadow: [gShadow(const Color(0x141f3145), 6, 16)],
              ),
              child: gSvg(c.female ? _svgFemale : _svgMale, 40),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: gText(15.5, w: FontWeight.w500, c: const Color(0xff1e1e1e), h: 20.15)),
                for (final l in c.lines) Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11.5, c: _muted, h: 16)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.amount, style: gText(15.5, w: FontWeight.w600, c: const Color(0xff1e1e1e), h: 20.9)),
              if (c.pay != null) ...[const SizedBox(height: 4), _chip(c.pay!, w: FontWeight.w500)],
            ]),
          ]),
          if (footer) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xfff1f2f5)),
            const SizedBox(height: 10),
            // Footer chips and the action button share one 34 px row so they line up.
            SizedBox(
              height: 34,
              child: Row(children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(children: [
                      for (final (k, ch) in [if (c.auto != null) c.auto!, ...c.chips].indexed) ...[
                        if (k > 0) const SizedBox(width: 6),
                        _footChip(ch),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                if (c.action != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      height: 34, alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: c.action!.bg, borderRadius: BorderRadius.circular(10),
                          boxShadow: [gShadow(const Color(0x38e8493f), 3, 8)]),
                      child: Text(c.action!.text, style: gText(13, w: FontWeight.w600, c: c.action!.fg)),
                    ),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _footChip(Chip62 c) => Container(
        height: 26, alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8)),
        child: Text(c.text, style: gText(11.5, c: c.fg)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 120),
        child: Column(children: [
          Container(
            width: 64, height: 64, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xffc3c8d2), size: 30),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: gText(13, c: _muted, h: 19)),
        ]),
      );
}
