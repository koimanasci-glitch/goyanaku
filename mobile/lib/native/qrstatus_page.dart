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

/// QR status presentation follows the existing mirror, including its current
/// checker artwork. This widget does not invent a new QR payload or business rule.
class NativeQrstatusPage extends StatefulWidget {
  const NativeQrstatusPage({super.key, required this.model, required this.onButton,
    required this.onInput, required this.onNav, required this.onHeaderScan, this.topInset});
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final void Function(int index, Object value) onInput;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;
  @override
  State<NativeQrstatusPage> createState() => _NativeQrstatusPageState();
}

class _NativeQrstatusPageState extends State<NativeQrstatusPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Map<String, dynamic> get _field => _child(_child(_child(_map(widget.model['body']), 1), 1), 1);
  Map<String, dynamic> get _input => _map(_field['input']);
  @override
  void initState() {
    super.initState();
    _controller.text = _string(_input['v'], '');
  }
  @override
  void didUpdateWidget(covariant NativeQrstatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _string(_input['v'], '');
    if (!_focus.hasFocus && _controller.text != value) _controller.text = value;
  }
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }
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
          ? () => widget.onButton(action.toInt()) : null,
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
    final model = widget.model;
    final body = _map(model['body']);
    final subhead = _child(body, 0), content = _child(body, 1);
    final back = _child(subhead, 0), intro = _child(content, 0), search = _child(content, 1);
    final card = _child(content, 2), brand = _child(card, 0), qr = _child(card, 4);
    final progress = _child(card, 6), full = _child(content, 3);
    final backAction = back['b'], findAction = _child(search, 2)['b'];
    final inputStyle = _map(_field['s']);
    final fs = _number(inputStyle['fs'], 12), lh = _number(inputStyle['lh'], 16.8);
    final fieldText = gText(fs > 0 ? fs : 12, h: lh > 0 ? lh : 16.8,
      c: cssColor(_string(inputStyle['c'], 'rgb(30, 30, 30)')));
    final nav = _number(model['nav'], 1).toInt();
    return Material(color: cssColor(_string(model['bg'], 'rgb(255, 255, 255)')),
      child: Column(children: [
        if (model['head'] != false)
          GTopBar(top: widget.topInset ?? MediaQuery.paddingOf(context).top, onScan: widget.onHeaderScan)
        else SizedBox(height: widget.topInset ?? MediaQuery.paddingOf(context).top),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GestureDetector(key: const Key('qrstatus-back'), behavior: HitTestBehavior.opaque,
                  onTap: backAction is num && backAction.isFinite && backAction >= 0
                      ? () => widget.onButton(backAction.toInt()) : null,
                  child: _box(back, _text(back, '‹', size: 20, weight: 500, height: 20, center: true),
                    fixed: true, width: 38, height: 32, radius: 9, background: 'rgb(243, 244, 247)')),
                const SizedBox(width: 10),
                Flexible(child: _text(_child(subhead, 1), 'QR Status', size: 14.5,
                  weight: 600, height: 18.85, spacing: .7, upper: true)),
              ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _text(_child(intro, 0), 'QR Status Pesanan', size: 14, weight: 500, height: 18.2),
                const SizedBox(height: 3),
                _text(_child(intro, 1), 'Tampilkan QR agar pelanggan dapat mengecek status laundry tanpa login.',
                  size: 11, height: 15.4, color: 'rgb(139, 148, 163)'),
                _box(search, Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Flexible(child: _text(_child(search, 0), '⌕', size: 18, height: 25.2, color: 'rgb(145, 153, 167)')),
                  const SizedBox(width: 8),
                  Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(color: cssColor(_string(inputStyle['bg'], 'rgb(255, 255, 255)')),
                      borderRadius: BorderRadius.circular(0)),
                    child: TextField(key: const Key('qrstatus-input'), controller: _controller, focusNode: _focus,
                      readOnly: _input['ro'] == true, minLines: 1, maxLines: 1, style: fieldText, cursorColor: gBrand,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(isCollapsed: true, border: InputBorder.none,
                        hintText: _string(_input['ph'], 'Cari nama / Order ID / nomor HP'),
                        hintStyle: fieldText.copyWith(color: const Color(0xffb0b4bf))),
                      onChanged: (value) {
                        final index = _input['i'];
                        if (index is num && index.isFinite && index >= 0) widget.onInput(index.toInt(), value);
                      },
                    ))),
                  const SizedBox(width: 8),
                  GestureDetector(key: const Key('qrstatus-find'), behavior: HitTestBehavior.opaque,
                    onTap: findAction is num && findAction.isFinite && findAction >= 0
                        ? () => widget.onButton(findAction.toInt()) : null,
                    child: _box(_child(search, 2), _text(_child(search, 2), '→', size: 17,
                      weight: 500, height: 23.8, color: 'rgb(235, 63, 76)', center: true),
                      fixed: true, radius: 10, background: 'rgb(255, 240, 242)')),
                ]), radius: 14, border: 1, borderColor: 'rgb(228, 231, 236)', background: 'rgb(248, 249, 251)'),
                const SizedBox(height: 14),
                _box(card, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _box(_child(brand, 0), _text(_child(brand, 0), 'G', color: 'rgb(233, 63, 76)'),
                      fixed: true, radius: 10, background: 'rgb(255, 240, 242)'),
                    const SizedBox(width: 8),
                    Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _text(_child(_child(brand, 1), 0), 'GOYANA LAUNDRY', size: 10, weight: 500, height: 14),
                      _text(_child(_child(brand, 1), 1), '—', size: 7.5, height: 10.5, color: 'rgb(146, 154, 167)'),
                    ])),
                  ]),
                  const SizedBox(height: 15),
                  _text(_child(card, 1), 'STATUS PESANAN', size: 7.5, height: 10.5, color: 'rgb(146, 154, 167)', center: true),
                  const SizedBox(height: 7),
                  _text(_child(card, 2), '—', size: 12, weight: 500, height: 16.8, center: true),
                  const SizedBox(height: 3),
                  _text(_child(card, 3), '—', size: 15, weight: 500, height: 21, center: true),
                  const SizedBox(height: 13),
                  Center(child: _box(qr,
                    ClipRect(child: CustomPaint(painter: _Checker(_map(_map(qr['s'])['checker'])), child: const SizedBox.expand())),
                    fixed: true, width: 145, height: 145, border: 9, borderColor: 'rgb(255, 255, 255)',
                    background: 'rgb(23, 23, 23)')),
                  const SizedBox(height: 13),
                  _text(_child(card, 5), 'Scan QR untuk melihat progres pesanan', size: 8, height: 11.2,
                    color: 'rgb(146, 154, 167)', center: true),
                  const SizedBox(height: 13),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 67),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < 5; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Expanded(child: _box(_child(progress, i), const SizedBox.shrink(), fixed: true,
                          width: 34, height: 5, radius: 99, background: 'rgb(231, 233, 237)')),
                      ],
                    ])),
                  const SizedBox(height: 6),
                  _text(_child(card, 7), '—', size: 9, height: 12.6, color: 'rgb(232, 63, 76)', center: true),
                ]), padding: 16, radius: 18, border: 1, borderColor: 'rgb(228, 231, 236)', background: 'rgb(255, 255, 255)'),
                const SizedBox(height: 14),
                _button(full, 'Tampilkan QR Full Screen', 'qrstatus-full', primary: true),
              ])),
          ]))),
        if (nav >= 0) GBottomNav(onTap: widget.onNav, active: nav > 3 ? -1 : nav),
      ]),
    );
  }
}

class _Checker extends CustomPainter {
  _Checker(this.data);
  final Map<String, dynamic> data;
  @override
  void paint(Canvas canvas, Size size) {
    final raw = data['c'];
    final colors = raw is List ? raw : [];
    final dark = cssColor(colors.isNotEmpty ? _string(colors[0], 'rgb(23, 23, 23)') : 'rgb(23, 23, 23)');
    final light = cssColor(colors.length > 1 ? _string(colors[1], 'rgb(255, 255, 255)') : 'rgb(255, 255, 255)');
    final scale = _number(data['s'], 12);
    final q = scale > 0 ? scale / 2 : 6.0;
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var y = 0.0; y < size.height; y += q) {
      for (var x = 0.0; x < size.width; x += q) {
        if (((x / q).round() + (y / q).round()).isEven) canvas.drawRect(Rect.fromLTWH(x, y, q, q), paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _Checker oldDelegate) => oldDelegate.data != data;
}
