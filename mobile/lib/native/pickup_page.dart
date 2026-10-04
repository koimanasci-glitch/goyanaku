import 'package:flutter/material.dart';

import 'common.dart';

Map<String, dynamic> _map(Object? value) => value is Map
    ? {for (final entry in value.entries) if (entry.key is String) entry.key as String: entry.value}
    : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? value) =>
    value is List ? value.whereType<Map>().map(_map).toList() : [];
Map<String, dynamic> _child(Map<String, dynamic> node, int index) {
  final children = _list(node['ch']);
  return index < children.length ? children[index] : <String, dynamic>{};
}
double _number(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
String _string(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;
FontWeight _weight(Object? value, int fallback) =>
    FontWeight.values[(_number(value, fallback.toDouble()).toInt() ~/ 100 - 1).clamp(0, 8)];

/// Pickup layout is native; presentation values and HTML action indices remain
/// data from the current mirror model. Missing model parts have safe defaults.
class NativePickupPage extends StatelessWidget {
  const NativePickupPage({super.key, required this.model, required this.onButton,
    required this.onNav, required this.onHeaderScan, this.topInset});
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;

  Widget _text(Map<String, dynamic> node, String fallback, {
    double size = 14, int weight = 400, double height = 19.6,
    String color = 'rgb(30, 30, 30)', double spacing = 0,
    bool upper = false, bool center = false,
  }) {
    final s = _map(node['s']);
    final fs = _number(s['fs'], size);
    final lh = _number(s['lh'], height);
    final ink = cssColor(_string(s['c'], color));
    final ls = _number(s['ls'], spacing);
    TextStyle style(Map<String, dynamic> x, Color c) => gText(
      _number(x['fs'], fs) > 0 ? _number(x['fs'], fs) : size,
      w: _weight(x['fw'], _number(s['fw'], weight.toDouble()).toInt()),
      c: c, h: lh > 0 ? lh : height, ls: ls,
    );
    final spans = _list(node['spans']);
    final useUpper = s['up'] == 1 || (s['up'] == null && upper);
    final useCenter = s['ta'] == 'center' || (s['ta'] == null && center);
    return Text.rich(
      TextSpan(style: style(s, ink), children: [
        for (final span in spans.isNotEmpty ? spans : [{'t': fallback}])
          TextSpan(
            text: useUpper ? '${span['t'] ?? ''}'.toUpperCase() : '${span['t'] ?? ''}',
            style: style(span, cssColor(_string(span['c'], _string(s['c'], color)))),
          ),
      ]),
      textAlign: useCenter ? TextAlign.center : TextAlign.left,
      softWrap: s['nowrap'] != 1,
    );
  }

  Widget _box(Map<String, dynamic> node, Widget child, {
    double padding = 0, double radius = 0, String? background,
    double border = 0, String borderColor = 'rgb(231, 233, 237)',
    bool fixed = false, double width = 34, double height = 34,
  }) {
    final s = _map(node['s']);
    final p = s['p'];
    double side(int i) => p is List && p.length > i
        ? _number(p[i], padding).clamp(0, 1000).toDouble() : padding;
    final radii = s['br'];
    final r = radii is List && radii.isNotEmpty
        ? _number(radii[0], radius).clamp(0, 1000).toDouble() : radius;
    final bw = _number(s['bw'], border).clamp(0, 100).toDouble();
    final bg = s['bg'] is String ? s['bg'] as String : background;
    return Container(
      width: fixed ? _number(node['w'], width).clamp(1, 1000).toDouble() : null,
      height: fixed ? _number(node['h'], height).clamp(1, 1000).toDouble() : null,
      alignment: fixed ? Alignment.center : null,
      padding: fixed ? null : EdgeInsets.fromLTRB(side(3), side(0), side(1), side(2)),
      decoration: BoxDecoration(
        color: bg == null ? null : cssColor(bg),
        border: bw > 0 ? Border.all(width: bw, color: cssColor(_string(s['bc'], borderColor))) : null,
        borderRadius: r > 0 ? BorderRadius.circular(r) : null,
      ),
      child: child,
    );
  }

  Widget _button(Map<String, dynamic> node, String label, String key, {
    required bool primary,
  }) {
    final action = node['b'];
    return GestureDetector(
      key: Key(key), behavior: HitTestBehavior.opaque,
      onTap: action is num && action.isFinite && action >= 0
          ? () => onButton(action.toInt()) : null,
      child: _box(node,
        _text(node, label, size: primary ? 12 : 9.5, weight: 500,
          height: primary ? 16.8 : 13.3,
          color: primary ? 'rgb(255, 255, 255)' : 'rgb(0, 0, 0)',
          spacing: primary ? .3 : 0, upper: primary, center: true),
        padding: primary ? 14 : 11, radius: primary ? 10 : 11,
        background: primary ? 'rgb(232, 73, 63)' : 'rgb(255, 255, 255)',
        border: primary ? 0 : 1, borderColor: 'rgb(225, 228, 233)',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _map(model['body']);
    final subhead = _child(body, 0), content = _child(body, 1);
    final back = _child(subhead, 0), title = _child(subhead, 1);
    final success = _child(content, 0), order = _child(content, 1);
    final successInfo = _child(success, 1), orderHead = _child(order, 0);
    final person = _child(orderHead, 1), grid = _child(order, 1);
    final action = back['b'];
    final nav = _number(model['nav'], 1).toInt();
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: cssColor(_string(model['bg'], 'rgb(255, 255, 255)')),
      child: Column(children: [
        if (model['head'] != false) GTopBar(top: top, onScan: onHeaderScan)
        else SizedBox(height: top),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GestureDetector(key: const Key('pickup-back'), behavior: HitTestBehavior.opaque,
                  onTap: action is num && action.isFinite && action >= 0
                      ? () => onButton(action.toInt()) : null,
                  child: _box(back, _text(back, '‹', size: 20, weight: 500,
                    height: 20, center: true), fixed: true, width: 38, height: 32,
                    radius: 9, background: 'rgb(243, 244, 247)'),
                ),
                const SizedBox(width: 10),
                Flexible(child: _text(title, 'Pengambilan Pesanan', size: 14.5,
                  weight: 600, height: 18.85, spacing: .7, upper: true)),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 105),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _box(success, Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _box(_child(success, 0), _text(_child(success, 0), '✓', color: 'rgb(255, 255, 255)'),
                    fixed: true, radius: 17, background: 'rgb(53, 166, 99)'),
                  const SizedBox(width: 9),
                  Flexible(child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _text(_child(successInfo, 0), 'Pesanan ditemukan', size: 11, weight: 500, height: 15.4),
                      _text(_child(successInfo, 1), 'Barcode cocok dengan Order ID GOYANA', size: 8, height: 11.2,
                        color: 'rgb(115, 144, 128)'),
                    ])),
                ]), padding: 12, radius: 14, border: 1,
                  borderColor: 'rgb(220, 239, 227)', background: 'rgb(239, 249, 243)'),
                // Mirror combines adjacent vertical margins (12 and 11).
                const SizedBox(height: 12),
                _box(order, Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      _box(_child(orderHead, 0), _text(_child(orderHead, 0), '—'),
                        fixed: true, radius: 10, background: 'rgb(241, 243, 246)'),
                      const SizedBox(width: 9),
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _text(_child(person, 0), '—', size: 11, weight: 500, height: 15.4),
                          const SizedBox(height: 3),
                          _text(_child(person, 1), '—', size: 8, height: 11.2, color: 'rgb(149, 157, 170)'),
                        ])),
                      const SizedBox(width: 9),
                      _box(_child(orderHead, 2), _text(_child(orderHead, 2), '—', size: 7,
                        weight: 500, height: 9.8, color: 'rgb(75, 108, 165)'),
                        fixed: true, width: 49.36, height: 19.8, radius: 99, background: 'rgb(237, 243, 255)'),
                    ]),
                    const SizedBox(height: 11),
                    for (var row = 0; row < 2; row++) ...[
                      if (row > 0) const SizedBox(height: 7),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (var col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 7),
                          Expanded(child: _box(_child(grid, row * 2 + col),
                            _text(_child(grid, row * 2 + col), '—', size: 7.5,
                              height: 10.5, color: 'rgb(146, 154, 167)'),
                            padding: 7, radius: 8, background: 'rgb(247, 248, 250)')),
                        ],
                      ]),
                    ],
                  ]), padding: 12, radius: 14, border: 1),
                // Mirror combines the card's 15px bottom and button's 12px top.
                const SizedBox(height: 15),
                _button(_child(content, 2), 'Bayar', 'pickup-pay', primary: true),
                const SizedBox(height: 10),
                _button(_child(content, 3), 'Konfirmasi Sudah Diambil', 'pickup-done', primary: false),
              ]),
            ),
          ]),
        )),
        if (nav >= 0) GBottomNav(onTap: onNav, active: nav > 3 ? -1 : nav),
      ]),
    );
  }
}
