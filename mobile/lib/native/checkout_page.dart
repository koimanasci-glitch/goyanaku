import 'package:flutter/material.dart';

import 'common.dart';

Map<String, dynamic> _map(Object? value) => value is Map
    ? {for (final e in value.entries) if (e.key is String) e.key as String: e.value}
    : {};
List<Map<String, dynamic>> _children(Map<String, dynamic> node) =>
    node['ch'] is List ? (node['ch'] as List).whereType<Map>().map(_map).toList() : [];
Map<String, dynamic> _child(Map<String, dynamic> node, int i) {
  final children = _children(node);
  return i >= 0 && i < children.length ? children[i] : {};
}
double _number(Object? value, [double fallback = 0]) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
String _string(Object? value, [String fallback = '']) => value is String ? value : fallback;
int? _index(Object? value) => value is num && value.isFinite && value >= 0 ? value.toInt() : null;
List<double> _sides(Object? value) => value is List && value.length == 4
    ? value.map((v) => _number(v).clamp(0.0, double.infinity).toDouble()).toList() : [0, 0, 0, 0];
EdgeInsets _insets(Object? value) {
  final q = _sides(value);
  return EdgeInsets.fromLTRB(q[3], q[0], q[1], q[2]);
}
String _label(Map<String, dynamic> node) {
  final spans = node['spans'];
  return spans is List ? spans.whereType<Map>().map((sp) => _string(sp['t'])).join() : '';
}
FontWeight _weight(Object? value) {
  final weight = _number(value, 400);
  return weight >= 600 ? FontWeight.w600 : weight >= 500 ? FontWeight.w500 : FontWeight.w400;
}

/// B8: explicit native checkout sections. HTML still owns selection, totals,
/// inputs and actions. This widget never enables the production purchase guard.
class NativeCheckoutPage extends StatelessWidget {
  const NativeCheckoutPage({super.key, required this.model, required this.onButton,
    required this.onInput, required this.onNav, required this.onHeaderScan, this.topInset});
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final void Function(int, Object) onInput;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;

  Widget _text(Map<String, dynamic> node, [String fallback = '']) {
    final s = _map(node['s']);
    final fs = _number(s['fs'], 14);
    final lh = _number(s['lh']);
    final color = cssColor(_string(s['c']), const Color(0xff1e1e1e));
    TextStyle style(Map<String, dynamic> span) => gText(
      _number(span['fs'], fs) > 0 ? _number(span['fs'], fs) : 14,
      w: _weight(span['fw'] ?? s['fw']),
      c: cssColor(_string(span['c']), color), h: lh > 0 ? lh : null,
      ls: _number(s['ls']),
    );
    final spans = node['spans'] is List ? (node['spans'] as List).whereType<Map>().map(_map).toList() : <Map<String, dynamic>>[];
    final text = Text.rich(TextSpan(style: style(s), children: [
      if (spans.isEmpty) TextSpan(text: s['up'] == 1 ? fallback.toUpperCase() : fallback),
      for (final span in spans) TextSpan(
        text: s['up'] == 1 ? _string(span['t']).toUpperCase() : _string(span['t']),
        style: style(span).copyWith(backgroundColor: span['bg'] is String ? cssColor(span['bg'] as String) : null),
      ),
    ]), textAlign: s['ta'] == 'center' ? TextAlign.center : s['ta'] == 'right' ? TextAlign.right : TextAlign.left,
      softWrap: s['nowrap'] != 1);
    final link = spans.where((sp) => _index(sp['b']) != null).firstOrNull;
    return link == null ? text : GestureDetector(key: ValueKey('checkout-button-${_index(link['b'])}'), behavior: HitTestBehavior.opaque,
      onTap: () => onButton(_index(link['b'])!), child: text);
  }

  // Only native box/text styling is shared; section structure is written below.
  Widget _box(Map<String, dynamic> node, Widget child) {
    final s = _map(node['s']);
    final r = _sides(s['br']);
    final bw = _number(s['bw']).clamp(0.0, double.infinity).toDouble();
    final borderColor = cssColor(_string(s['bc']), const Color(0xffe6e9ee));
    BoxBorder? border;
    if (bw > 0) {
      if (s['bs'] is List && r.every((v) => v == 0)) {
        final bs = _sides(s['bs']);
        BorderSide side(double w) => w > 0 ? BorderSide(color: borderColor, width: w) : BorderSide.none;
        border = Border(top: side(bs[0]), right: side(bs[1]), bottom: side(bs[2]), left: side(bs[3]));
      } else {
        border = Border.all(color: borderColor, width: bw);
      }
    }
    final fixed = node['fixed'] == 1;
    Widget result = Container(
      width: fixed ? _number(node['w']) : null,
      height: fixed ? _number(node['h']) : null,
      alignment: fixed ? Alignment.center : null,
      padding: fixed ? null : _insets(s['p']),
      decoration: BoxDecoration(color: s['bg'] is String ? cssColor(s['bg'] as String) : null,
        border: border, borderRadius: r.any((v) => v > 0) ? BorderRadius.only(
          topLeft: Radius.circular(r[0]), topRight: Radius.circular(r[1]),
          bottomRight: Radius.circular(r[2]), bottomLeft: Radius.circular(r[3])) : null),
      child: child,
    );
    final index = _index(node['b']);
    if (index != null) result = GestureDetector(key: ValueKey('checkout-button-$index'),
      behavior: HitTestBehavior.opaque, onTap: () => onButton(index), child: result);
    final minw = _number(s['minw']);
    if (minw > 0) result = ConstrainedBox(constraints: BoxConstraints(minWidth: minw), child: result);
    final m = _sides(s['m']);
    if (m[1] > 0 || m[3] > 0) result = Padding(padding: EdgeInsets.only(left: m[3], right: m[1]), child: result);
    return result;
  }
  Widget _leaf(Map<String, dynamic> node, [String fallback = '']) => _box(node, _text(node, fallback));

  Widget _column(Map<String, dynamic> node, List<Widget> widgets) {
    final nodes = _children(node);
    final children = <Widget>[];
    double previous = 0;
    for (var i = 0; i < widgets.length; i++) {
      final m = _sides(i < nodes.length ? _map(nodes[i]['s'])['m'] : null);
      final gap = i == 0 ? m[0] : m[0] > previous ? m[0] : previous;
      if (gap > 0) children.add(SizedBox(height: gap));
      children.add(widgets[i]);
      previous = m[2];
    }
    if (previous > 0) children.add(SizedBox(height: previous));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _row(Map<String, dynamic> node, List<Widget> widgets) {
    final nodes = _children(node), s = _map(node['s']);
    final padding = _sides(s['p']);
    final inner = _number(node['w']) - padding[1] - padding[3];
    final children = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) children.add(SizedBox(width: _number(node['gap'])));
      final n = i < nodes.length ? nodes[i] : <String, dynamic>{};
      final ns = _map(n['s']), margin = _sides(ns['m']);
      Widget child = widgets[i];
      if (margin[0] > 0 || margin[2] > 0) child = Padding(padding: EdgeInsets.only(top: margin[0], bottom: margin[2]), child: child);
      if (n['grow'] == 1 || (nodes.length == 1 && n['fixed'] != 1 && _number(n['w']) >= inner - 2)) {
        child = Expanded(child: child);
      } else if (n['fixed'] != 1 && ns['nowrap'] != 1) {
        child = Flexible(child: child);
      }
      children.add(child);
    }
    final jc = _string(node['jc']), ai = _string(node['ai']);
    return _box(node, Row(
      mainAxisAlignment: jc.contains('space-between') ? MainAxisAlignment.spaceBetween : jc.contains('center') ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: ai.contains('center') ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: children,
    ));
  }

  Widget _info(Map<String, dynamic> node) => _box(node, _column(node,
    [for (final text in _children(node)) _leaf(text)]));
  Widget _item(Map<String, dynamic> card) {
    final row = _child(card, 0);
    return _box(card, _row(row, [_leaf(_child(row, 0)), _info(_child(row, 1)), _leaf(_child(row, 2))]));
  }
  Widget _outlets(Map<String, dynamic> card) => _box(card, _column(card, [
    for (final node in _children(card))
      if (node['row'] == true)
        _row(node, [_leaf(_child(node, 0)), _info(_child(node, 1)), _leaf(_child(node, 2))])
      else _leaf(node),
  ]));
  Widget _quantity(Map<String, dynamic> card) {
    final row = _child(card, 0), quantity = _child(row, 1);
    return _box(card, _row(row, [_info(_child(row, 0)),
      _row(quantity, [for (final node in _children(quantity)) _leaf(node)]),
    ]));
  }
  Widget _payment(Map<String, dynamic> card) => _box(card, _column(card, [
    for (final node in _children(card))
      if (node['row'] == true)
        _row(node, [_leaf(_child(node, 0)), _info(_child(node, 1)), _leaf(_child(node, 2))])
      else if (_children(node).any((c) => c['input'] is Map))
        _box(node, _column(node, [for (final c in _children(node)) c['input'] is Map ? _field(c) : _leaf(c)]))
      else _leaf(node),
  ]));
  Widget _field(Map<String, dynamic> node) => _CheckoutField(
    key: ValueKey('checkout-input-${_map(node['input'])['i']}'), node: node, onInput: onInput);
  Widget _promo(Map<String, dynamic> card) => _box(card, _column(card, [
    for (final node in _children(card))
      if (node['row'] == true)
        _row(node, [for (final c in _children(node)) c['input'] is Map ? _field(c) : _leaf(c)])
      else _leaf(node),
  ]));
  Widget _summary(Map<String, dynamic> card) => _box(card, _column(card, [
    for (final node in _children(card)) node['row'] == true
      ? _row(node, [for (final c in _children(node)) _leaf(c)]) : _leaf(node),
  ]));
  Widget _card(Map<String, dynamic> card) {
    final first = _child(card, 0), label = _label(first);
    if (label.startsWith('Outlet yang aktif')) return _outlets(card);
    if (label == 'Metode Pembayaran') return _payment(card);
    if (label == 'Kode Promo') return _promo(card);
    if (label == 'Rincian Pembayaran') return _summary(card);
    if (first['row'] == true && _child(first, 1)['row'] == true) return _quantity(card);
    if (first['row'] == true) return _item(card);
    return _box(card, _text(card));
  }

  @override
  Widget build(BuildContext context) {
    final body = _map(model['body']), content = _child(body, 1), subhead = _child(body, 0);
    final nodes = _children(content);
    final bars = nodes.where((node) => node['sticky'] == 1).toList();
    final cards = nodes.where((node) => node['sticky'] != 1).toList();
    final flow = {...content, 'ch': cards};
    final nav = _index(model['nav']);
    final rootPadding = _insets(_map(body['s'])['p']);
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    final title = _child(subhead, 1);
    return Material(color: cssColor(_string(model['bg']), Colors.white), child: Column(children: [
      if (model['head'] == true) GTopBar(top: top, onScan: onHeaderScan) else SizedBox(height: top),
      Expanded(child: SingleChildScrollView(key: const Key('checkout-scroll'),
        padding: rootPadding.copyWith(bottom: rootPadding.bottom + 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          _row(subhead, [_leaf(_child(subhead, 0), '‹'),
            _leaf(title.isEmpty ? {'s': {'fs': 14.5, 'fw': 600, 'lh': 18.85, 'ls': .7, 'up': 1}} : title, 'Konfirmasi Pembelian')]),
          _box(content, _column(flow, cards.isEmpty
            ? [const Text('Belum ada rincian pembelian.', style: TextStyle(fontFamily: 'Poppins', fontSize: 14))]
            : [for (final card in cards) _card(card)])),
        ]))),
      for (final bar in bars) _row(bar, [_info(_child(bar, 0)), _leaf(_child(bar, 1))]),
      if (nav != null) GBottomNav(onTap: onNav, active: nav > 3 ? -1 : nav),
    ]));
  }
}

class _CheckoutField extends StatefulWidget {
  const _CheckoutField({super.key, required this.node, required this.onInput});
  final Map<String, dynamic> node;
  final void Function(int, Object) onInput;
  @override
  State<_CheckoutField> createState() => _CheckoutFieldState();
}
class _CheckoutFieldState extends State<_CheckoutField> {
  late final controller = TextEditingController(text: _string(_map(widget.node['input'])['v']));
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _CheckoutField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _string(_map(widget.node['input'])['v']);
    if (!focus.hasFocus && value != controller.text) controller.text = value;
  }
  @override
  void dispose() { controller.dispose(); focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = _map(widget.node['s']), input = _map(widget.node['input']);
    final fs = _number(s['fs'], 13), lh = _number(s['lh']);
    final style = gText(fs > 0 ? fs : 13, c: cssColor(_string(s['c']), const Color(0xff1e1e1e)), h: lh > 0 ? lh : null);
    final index = _index(input['i']);
    return Container(padding: _insets(s['p']), decoration: BoxDecoration(
      color: cssColor(_string(s['bg']), Colors.white), borderRadius: BorderRadius.circular(_sides(s['br'])[0]),
      border: _number(s['bw']) > 0 ? Border.all(width: _number(s['bw']), color: cssColor(_string(s['bc']), const Color(0xffdfe3e9))) : null),
      child: TextField(controller: controller, focusNode: focus, readOnly: index == null || input['ro'] == true,
        style: style, cursorColor: gBrand,
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _string(input['ph']),
          hintStyle: style.copyWith(color: const Color(0xffb0b4bf))),
        onChanged: index == null ? null : (value) => widget.onInput(index, value),
      ));
  }
}
