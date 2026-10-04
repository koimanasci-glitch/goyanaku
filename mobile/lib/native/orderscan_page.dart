import 'package:flutter/material.dart';

import 'common.dart';

Map<String, dynamic> _map(Object? v) => v is Map
    ? {for (final e in v.entries) if (e.key is String) e.key as String: e.value}
    : <String, dynamic>{};
Map<String, dynamic> _child(Map<String, dynamic> node, int index) {
  final list = node['ch'];
  if (list is! List) return {};
  final children = list.whereType<Map>().toList();
  return index < children.length ? _map(children[index]) : {};
}
double _num(Object? v, double fallback) => v is num && v.isFinite ? v.toDouble() : fallback;
String _str(Object? v, String fallback) => v is String && v.isNotEmpty ? v : fallback;

/// Only the scanner's presentation lives here. The shell supplies its existing
/// MobileScanner unchanged; inputs and buttons keep their HTML action indices.
class NativeOrderscanPage extends StatefulWidget {
  const NativeOrderscanPage({super.key, required this.model,
    required this.onButton, required this.onInput, required this.cameraBuilder, this.topInset});
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final void Function(int index, Object value) onInput;
  final WidgetBuilder cameraBuilder;
  final double? topInset;
  @override
  State<NativeOrderscanPage> createState() => _NativeOrderscanPageState();
}

class _NativeOrderscanPageState extends State<NativeOrderscanPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Map<String, dynamic> get _overlay => _child(_map(widget.model['body']), 1);
  Map<String, dynamic> get _search => _child(_overlay, 4);
  Map<String, dynamic> get _field => _child(_search, 0);
  Map<String, dynamic> get _input => _map(_field['input']);

  @override
  void initState() {
    super.initState();
    _controller.text = _str(_input['v'], '');
  }
  @override
  void didUpdateWidget(covariant NativeOrderscanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _str(_input['v'], '');
    if (!_focus.hasFocus && _controller.text != value) _controller.text = value;
  }
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Color _color(Map<String, dynamic> node, String name, String fallback) =>
      cssColor(_str(_map(node['s'])[name], fallback));
  double _size(Map<String, dynamic> node, String name, double fallback) =>
      _num(node[name], fallback).clamp(0, 1000).toDouble();
  Widget _text(Map<String, dynamic> node, String fallback, double size, double height,
      int weight, String color, {bool center = false}) {
    final s = _map(node['s']);
    final fs = _num(s['fs'], size), lh = _num(s['lh'], height);
    final style = gText(fs > 0 ? fs : size, h: lh > 0 ? lh : height,
      w: FontWeight.values[(_num(s['fw'], weight.toDouble()).toInt() ~/ 100 - 1).clamp(0, 8)],
      c: _color(node, 'c', color), ls: _num(s['ls'], 0));
    final raw = node['spans'];
    final spans = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    return Text.rich(TextSpan(style: style, children: [
      for (final span in spans.isNotEmpty ? spans : [{'t': fallback}])
        TextSpan(text: '${span['t'] ?? ''}', style: style),
    ]), textAlign: center ? TextAlign.center : TextAlign.left);
  }
  VoidCallback? _action(Map<String, dynamic> node) {
    final index = node['b'];
    return index is num && index.isFinite && index >= 0
        ? () => widget.onButton(index.toInt()) : null;
  }

  @override
  Widget build(BuildContext context) {
    final body = _map(widget.model['body']);
    final overlay = _overlay, close = _child(overlay, 0), frame = _child(overlay, 1);
    final line = _child(frame, 0), title = _child(overlay, 2), hint = _child(overlay, 3);
    final find = _child(_search, 1);
    final fieldStyle = _map(_field['s']);
    final textStyle = gText(_num(fieldStyle['fs'], 12) > 0 ? _num(fieldStyle['fs'], 12) : 12,
      c: _color(_field, 'c', 'rgb(30, 30, 30)'), h: _num(fieldStyle['lh'], 16.8) > 0 ? _num(fieldStyle['lh'], 16.8) : 16.8);
    return Material(
      color: _color(body, 'bg', 'rgb(5, 6, 8)'),
      child: Padding(
        padding: EdgeInsets.only(top: widget.topInset ?? MediaQuery.paddingOf(context).top),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: widget.cameraBuilder(context)),
          Positioned.fill(child: Container(
            color: _color(overlay, 'bg', 'rgba(0, 0, 0, 0.35)'),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: _size(frame, 'w', 225), height: _size(frame, 'h', 225),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: _color(frame, 'bc', 'rgba(255, 255, 255, 0.9)')),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(top: _num(_map(line['abs'])['t'], 110.5),
                      left: _num(_map(line['abs'])['l'], 13),
                      child: Container(width: _size(line, 'w', 195), height: _size(line, 'h', 2),
                        color: _color(line, 'bg', 'rgb(232, 73, 63)'))),
                  ]),
                ),
                const SizedBox(height: 25),
                Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: _size(title, 'w', 183.69) + 1),
                  child: _text(title, 'Scan Barcode / QR Pesanan', 13, 18.2, 500, 'rgb(255, 255, 255)'))),
                const SizedBox(height: 7),
                Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: _size(hint, 'w', 250) + 1),
                  child: _text(hint, 'Arahkan kamera ke barcode atau QR code pada struk / label',
                    9, 12.6, 400, 'rgb(216, 220, 226)', center: true))),
                const SizedBox(height: 16),
                Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: _size(_search, 'w', 320) + 1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Flexible(child: Container(padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _color(_field, 'bg', 'rgba(255, 255, 255, 0.95)'),
                        borderRadius: BorderRadius.circular(12)),
                      child: TextField(key: const Key('orderscan-input'), controller: _controller,
                        focusNode: _focus, readOnly: _input['ro'] == true,
                        minLines: 1, maxLines: 1, style: textStyle, cursorColor: gBrand,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none,
                          hintText: _str(_input['ph'], 'Nama / no HP / Order ID'),
                          hintStyle: textStyle.copyWith(color: const Color(0xffb0b4bf))),
                        onChanged: (value) {
                          final index = _input['i'];
                          if (index is num && index.isFinite && index >= 0) widget.onInput(index.toInt(), value);
                        },
                      ),
                    )),
                    const SizedBox(width: 6),
                    GestureDetector(key: const Key('orderscan-find'), behavior: HitTestBehavior.opaque,
                      onTap: _action(find), child: Container(width: _size(find, 'w', 57.39),
                        height: _size(find, 'h', 40.8), alignment: Alignment.center,
                        decoration: BoxDecoration(color: _color(find, 'bg', 'rgb(232, 73, 63)'),
                          borderRadius: BorderRadius.circular(12)),
                        child: _text(find, 'Cari', 14, 19.6, 500, 'rgb(255, 255, 255)', center: true))),
                  ]))),
              ])),
              Positioned(top: _num(_map(close['abs'])['t'], 22), left: _num(_map(close['abs'])['l'], 18),
                child: GestureDetector(key: const Key('orderscan-close'), behavior: HitTestBehavior.opaque,
                  onTap: _action(close), child: Container(width: _size(close, 'w', 40),
                    height: _size(close, 'h', 40), alignment: Alignment.center,
                    decoration: BoxDecoration(color: _color(close, 'bg', 'rgba(0, 0, 0, 0.42)'),
                      borderRadius: BorderRadius.circular(20)),
                    child: _text(close, '×', 25, 35, 500, 'rgb(255, 255, 255)', center: true)))),
            ]),
          )),
        ]),
      ),
    );
  }
}
