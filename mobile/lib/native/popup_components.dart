import 'dart:convert';

import 'package:flutter/material.dart';

import 'common.dart';

// Shared style/layout primitives. Dedicated popup widgets provide every child;
// this file does not interpret or recursively render an HTML node tree.
Map<String, dynamic> _map(Object? value) => value is Map
    ? {
        for (final e in value.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : {};
List<Map<String, dynamic>> _children(Map<String, dynamic> node) =>
    node['ch'] is List
    ? (node['ch'] as List).whereType<Map>().map(_map).toList()
    : [];
Map<String, dynamic> _child(Map<String, dynamic> node, int i) {
  final children = _children(node);
  return i >= 0 && i < children.length ? children[i] : {};
}

double _number(Object? value, [double fallback = 0]) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
int? _index(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toInt() : null;
// Unscoped legacy fields carry -1; keep their identity/callback unchanged.
int? _fieldIndex(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;
List<double> _sides(Object? value) => value is List && value.length == 4
    ? value
          .map((v) => _number(v).clamp(0.0, double.infinity).toDouble())
          .toList()
    : [0, 0, 0, 0];
EdgeInsets _insets(Object? value) {
  final q = _sides(value);
  return EdgeInsets.fromLTRB(q[3], q[0], q[1], q[2]);
}

Color _color(Object? value, [Color fallback = Colors.transparent]) {
  try {
    return cssColor(value is String ? value : null, fallback);
  } on FormatException {
    return fallback;
  }
}

FontWeight _weight(Object? value) {
  final weight = _number(value, 400);
  return weight >= 600
      ? FontWeight.w600
      : weight >= 500
      ? FontWeight.w500
      : FontWeight.w400;
}

Map<String, dynamic> popupMap(Object? value) => _map(value);
List<Map<String, dynamic>> popupChildren(Map<String, dynamic> node) =>
    _children(node);
Map<String, dynamic> popupChild(Map<String, dynamic> node, int i) =>
    _child(node, i);

class PopupActions {
  const PopupActions({
    required this.id,
    required this.onButton,
    required this.onTap,
    required this.onInput,
    required this.onClose,
  });
  final String id;
  final ValueChanged<int> onButton, onTap;
  final void Function(int, Object) onInput;
  final VoidCallback onClose;
}

class PopupStyle {
  const PopupStyle(this.actions);
  final PopupActions actions;
  BoxBorder? _border(Map<String, dynamic> s, double bw, List<double> r) {
    final c = _color(s['bc'], const Color(0xffe6e9ee)), bs = _sides(s['bs']);
    if (s['bs'] is! List) return Border.all(color: c, width: bw);
    if (r.any((v) => v > 0)) {
      return bs[0] > 0 ? Border.all(color: c, width: bw) : null;
    }
    BorderSide side(double w) =>
        w > 0 ? BorderSide(color: c, width: w) : BorderSide.none;
    return Border(
      top: side(bs[0]),
      right: side(bs[1]),
      bottom: side(bs[2]),
      left: side(bs[3]),
    );
  }

  Widget text(Map<String, dynamic> node, [String fallback = '']) {
    final s = _map(node['s']);
    final spans = node['spans'] is List
        ? (node['spans'] as List).whereType<Map>().map(_map).toList()
        : <Map<String, dynamic>>[];
    if (spans.isEmpty && fallback.isEmpty) return const SizedBox.shrink();
    final fs = _number(s['fs'], 14), lh = _number(s['lh']);
    TextStyle style(Map<String, dynamic> x) => gText(
      _number(x['fs'], fs) > 0 ? _number(x['fs'], fs) : 14,
      w: _weight(x['fw'] ?? s['fw']),
      c: _color(x['c'] ?? s['c'], const Color(0xff1e1e1e)),
      h: lh > 0 ? lh : null,
      ls: _number(s['ls']),
    );
    final rich = Text.rich(
      TextSpan(
        style: style(s),
        children: [
          if (spans.isEmpty) TextSpan(text: fallback),
          for (final span in spans)
            TextSpan(
              text: s['up'] == 1
                  ? _string(span['t']).toUpperCase()
                  : _string(span['t']),
              style: style(span).copyWith(
                backgroundColor: span['bg'] is String
                    ? _color(span['bg'])
                    : null,
              ),
            ),
        ],
      ),
      textAlign: s['ta'] == 'center'
          ? TextAlign.center
          : s['ta'] == 'right'
          ? TextAlign.right
          : TextAlign.left,
      softWrap: s['nowrap'] != 1,
    );
    final link = spans
        .where((x) => _index(x['b']) != null || _index(x['tap']) != null)
        .firstOrNull;
    if (link == null) return rich;
    return GestureDetector(
      key: ValueKey(
        '${actions.id}-link-${_index(link['b']) != null ? 'button' : 'tap'}-${_index(link['b']) ?? _index(link['tap'])}',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final b = _index(link['b']), t = _index(link['tap']);
        if (b != null) {
          actions.onButton(b);
        } else if (t != null) {
          actions.onTap(t);
        }
      },
      child: rich,
    );
  }

  Widget box(
    Map<String, dynamic> node,
    Widget child, {
    bool inRow = false,
    String parentTa = '',
  }) {
    final s = _map(node['s']), r = _sides(s['br']), m = _sides(s['m']);
    final bw = _number(s['bw']).clamp(0.0, double.infinity).toDouble(),
        fixed = node['fixed'] == 1;
    final ring = _map(s['ring']);
    final stripe = s['stripe'] is Map
        ? _map(s['stripe'])
        : s['checker'] is Map
        ? {..._map(s['checker']), 'checker': true}
        : <String, dynamic>{};
    Widget result = Container(
      width: fixed
          ? _number(node['w']).clamp(0.0, double.infinity).toDouble()
          : null,
      height: fixed
          ? _number(node['h']).clamp(0.0, double.infinity).toDouble()
          : null,
      alignment: fixed ? Alignment.center : null,
      padding: fixed ? null : _insets(s['p']),
      decoration: BoxDecoration(
        color: s['bg'] is String ? _color(s['bg']) : null,
        border: bw > 0 ? _border(s, bw, r) : null,
        borderRadius: r.any((v) => v > 0)
            ? BorderRadius.only(
                topLeft: Radius.circular(r[0]),
                topRight: Radius.circular(r[1]),
                bottomRight: Radius.circular(r[2]),
                bottomLeft: Radius.circular(r[3]),
              )
            : null,
        boxShadow: ring.isNotEmpty
            ? [
                BoxShadow(
                  color: _color(ring['c'], Colors.black26),
                  spreadRadius: _number(ring['w'])
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                ),
              ]
            : null,
      ),
      child: stripe.isEmpty
          ? child
          : ClipRRect(
              borderRadius: BorderRadius.circular(r[0] > bw ? r[0] - bw : 0),
              child: CustomPaint(
                painter: _PopupStripes(stripe),
                child: SizedBox.expand(child: Center(child: child)),
              ),
            ),
    );
    final index = _index(node['b']);
    if (index != null) {
      result = GestureDetector(
        key: ValueKey('${actions.id}-button-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.onButton(index),
        child: result,
      );
    }
    final tap = _index(node['tap']);
    if (index == null && tap != null) {
      result = GestureDetector(
        key: ValueKey('${actions.id}-tap-$tap'),
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.onTap(tap),
        child: result,
      );
    }
    if (fixed && !inRow) {
      return Align(
        alignment: ((m[1] - m[3]).abs() < 2 && m[1] > 0) || parentTa == 'center'
            ? Alignment.center
            : Alignment.centerLeft,
        child: result,
      );
    }
    if (_number(s['minw']) > 0) {
      result = ConstrainedBox(
        constraints: BoxConstraints(minWidth: _number(s['minw'])),
        child: result,
      );
    }
    if (m[1] > 0 || m[3] > 0) {
      result = Padding(
        padding: EdgeInsets.only(left: m[3], right: m[1]),
        child: result,
      );
    }
    return result;
  }

  Widget leaf(
    Map<String, dynamic> node, {
    bool inRow = false,
    String parentTa = '',
  }) {
    if (node['input'] is Map) {
      Widget field = _PopupField(
        key: ValueKey(
          '${actions.id}-input-${_fieldIndex(_map(node['input'])['i'])}',
        ),
        node: node,
        onInput: actions.onInput,
      );
      final m = _sides(_map(node['s'])['m']);
      if (m[1] > 0 || m[3] > 0) {
        field = Padding(
          padding: EdgeInsets.only(left: m[3], right: m[1]),
          child: field,
        );
      }
      return field;
    }
    Widget content = text(node);
    final src = node['img'], svg = node['svg'];
    final w = _number(node['w']).clamp(0.0, double.infinity).toDouble(),
        h = _number(node['h']).clamp(0.0, double.infinity).toDouble();
    if (svg is String) content = gSvg(svg, w, h: h);
    if (src is String) {
      content = SizedBox(width: w, height: h);
      if (src.startsWith('data:') && src.contains(',')) {
        try {
          content = Image.memory(
            base64Decode(src.substring(src.indexOf(',') + 1)),
            width: w,
            height: h,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
        } on FormatException {
          /* Keep empty media box. */
        }
      } else if (src.startsWith('http')) {
        content = Image.network(
          src,
          width: w,
          height: h,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
        );
      }
    }
    return box(node, content, inRow: inRow, parentTa: parentTa);
  }

  Widget layout(
    Map<String, dynamic> node,
    Widget Function(Map<String, dynamic>, bool, String) draw,
  ) {
    final children = _children(node).where((n) => n['br'] != 1).toList(),
        s = _map(node['s']);
    final gap = _number(node['gap']).clamp(0.0, double.infinity).toDouble(),
        rowGap = _number(
          node['rgap'],
          _number(node['gap']),
        ).clamp(0.0, double.infinity).toDouble();
    if (children.isEmpty) return const SizedBox.shrink();
    if (node['row'] == true && node['wrap'] == 1) {
      return Wrap(
        spacing: gap,
        runSpacing: rowGap,
        children: [for (final c in children) draw(c, true, '')],
      );
    }
    Widget verticalMargin(Map<String, dynamic> n, Widget child) {
      final m = _sides(_map(n['s'])['m']);
      return m[0] > 0 || m[2] > 0
          ? Padding(
              padding: EdgeInsets.only(top: m[0], bottom: m[2]),
              child: child,
            )
          : child;
    }

    if (node['row'] == true) {
      final jc = _string(node['jc']),
          ai = _string(node['ai']),
          kids = <Widget>[];
      for (final c0 in children) {
        if (kids.isNotEmpty && gap > 0) kids.add(SizedBox(width: gap));
        final cs = _map(c0['s']);
        final c = {...c0};
        if (c['row'] == true &&
            c['grow'] != 1 &&
            c['wrap'] != 1 &&
            cs['bg'] == null &&
            _number(cs['bw']) == 0 &&
            RegExp(r'^(normal|flex-start|start|)$')
                .hasMatch(_string(c['jc']))) {
          c['_min'] = 1;
        }
        final w = verticalMargin(c, draw(c, true, ''));
        final inner =
            _number(node['w']) - _sides(s['p'])[1] - _sides(s['p'])[3];
        if (c['grow'] == 1 ||
            (children.length == 1 &&
                c['fixed'] != 1 &&
                _number(c['w']) >= inner - 2)) {
          kids.add(Expanded(child: w));
        } else if (c['fixed'] == 1 ||
            c['svg'] != null ||
            c['img'] != null ||
            cs['nowrap'] == 1) {
          kids.add(w);
        } else {
          kids.add(Flexible(child: w));
        }
      }
      return Row(
        mainAxisSize: node['_min'] == 1 ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: jc.contains('space-between')
            ? MainAxisAlignment.spaceBetween
            : jc.contains('center')
            ? MainAxisAlignment.center
            : jc.contains('end')
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: ai.contains('center')
            ? CrossAxisAlignment.center
            : ai.contains('end')
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: kids,
      );
    }
    final columns = _number(node['grid']).toInt().clamp(0, 30).toInt();
    if (columns > 1) {
      final widths = node['colw'] is List
          ? (node['colw'] as List).map(_number).toList()
          : <double>[];
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += columns) {
        if (rows.isNotEmpty) rows.add(SizedBox(height: rowGap));
        final cells = <Widget>[];
        for (var j = 0; j < columns; j++) {
          if (j > 0) cells.add(SizedBox(width: gap));
          final flex = j < widths.length && widths[j] > 0
              ? (widths[j].clamp(0.0, 10000.0) * 10)
                    .round()
                    .clamp(1, 100000)
                    .toInt()
              : 10;
          cells.add(
            Expanded(
              flex: flex,
              child: i + j < children.length
                  ? verticalMargin(
                      children[i + j],
                      draw(children[i + j], true, ''),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
        rows.add(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }
    final kids = <Widget>[];
    double previous = 0;
    final center = node['col'] == 1 && _string(node['ai']).contains('center');
    for (final c in children) {
      final m = _sides(_map(c['s'])['m']);
      final space = m[0] > previous ? m[0] : previous;
      if (space > 0) kids.add(SizedBox(height: space));
      Widget child = draw(c, false, center ? 'center' : _string(s['ta']));
      if (center && c['fixed'] != 1 && _number(c['w']) > 0) {
        child = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _number(c['w']) + 1),
            child: child,
          ),
        );
      }
      kids.add(child);
      previous = m[2];
    }
    if (previous > 0) kids.add(SizedBox(height: previous));
    if (node['col'] == 1) {
      final jc = _string(node['jc']), ai = _string(node['ai']);
      return Column(
        mainAxisSize: node['abs'] is Map || node['fixed'] == 1
            ? MainAxisSize.max
            : MainAxisSize.min,
        mainAxisAlignment: jc.contains('center')
            ? MainAxisAlignment.center
            : jc.contains('space-between')
            ? MainAxisAlignment.spaceBetween
            : jc.contains('end')
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: ai.contains('center')
            ? CrossAxisAlignment.center
            : ai.contains('start')
            ? CrossAxisAlignment.start
            : ai.contains('end')
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.stretch,
        children: kids,
      );
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: kids,
    );
    return node['center'] == 1 ? Center(child: column) : column;
  }
}

class PopupFrame extends StatelessWidget {
  const PopupFrame({
    super.key,
    required this.model,
    required this.actions,
    required this.child,
  });
  final Map<String, dynamic> model;
  final PopupActions actions;
  final Widget child;
  bool hasInput(Object? v) {
    if (v is Map) return v.containsKey('input') || v.values.any(hasInput);
    if (v is List) return v.any(hasInput);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mq0 = MediaQuery.of(context), root = _map(model['box']);
    final mq = hasInput(root) ? mq0 : mq0.copyWith(viewInsets: EdgeInsets.zero);
    final center = model['kind'] == 'center',
        s = _map(root['s']),
        p = _sides(s['p']),
        r = _sides(s['br']);
    final body = Container(
      constraints: BoxConstraints(
        maxHeight: (mq.size.height - mq.viewInsets.bottom - (center ? 40 : 20))
            .clamp(0.0, double.infinity)
            .toDouble(),
      ),
      decoration: BoxDecoration(
        color: _color(s['bg'], Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(r[0]),
          topRight: Radius.circular(r[1]),
          bottomRight: Radius.circular(r[2]),
          bottomLeft: Radius.circular(r[3]),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          p[3],
          p[0],
          p[1],
          p[2] + (center ? 0 : mq.padding.bottom),
        ),
        child: child,
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: actions.onClose,
              child: ColoredBox(
                color: _color(model['scrim'], const Color(0x80141b26)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: center
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: body,
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: body,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PopupField extends StatefulWidget {
  const _PopupField({super.key, required this.node, required this.onInput});
  final Map<String, dynamic> node;
  final void Function(int, Object) onInput;
  @override
  State<_PopupField> createState() => _PopupFieldState();
}

class _PopupFieldState extends State<_PopupField> {
  late final controller = TextEditingController(
    text: _string(_map(widget.node['input'])['v']),
  );
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _PopupField old) {
    super.didUpdateWidget(old);
    final value = _string(_map(widget.node['input'])['v']);
    if (!focus.hasFocus && value != controller.text) controller.text = value;
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _map(widget.node['s']),
        input = _map(widget.node['input']),
        r = _sides(s['br']);
    final bw = _number(s['bw']).clamp(0.0, double.infinity).toDouble(),
        fs = _number(s['fs'], 13),
        lh = _number(s['lh']);
    final style = gText(
      fs > 0 ? fs : 13,
      c: _color(s['c'], const Color(0xff1e1e1e)),
      h: lh > 0 ? lh : null,
    );
    final index = _fieldIndex(input['i']);
    final options = input['options'];
    if (options is List) {
      final list = options.map((e) => e is String ? e : '').toList();
      final selected = _number(input['index'])
          .toInt()
          .clamp(0, list.isEmpty ? 0 : list.length - 1)
          .toInt();
      final p = _sides(s['p']);
      return Container(
        padding: EdgeInsets.fromLTRB(p[3], 0, p[1], 0),
        decoration: BoxDecoration(
          color: _color(s['bg'], Colors.white),
          border: bw > 0
              ? Border.all(
                  color: _color(s['bc'], const Color(0xffdfe3e9)),
                  width: bw,
                )
              : null,
          borderRadius: BorderRadius.circular(r[0]),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: list.isEmpty ? null : selected,
            style: style,
            items: [
              for (var k = 0; k < list.length; k++)
                DropdownMenuItem(
                  value: k,
                  child: Text(list[k], style: style),
                ),
            ],
            onChanged: (v) {
              if (v != null && index != null) widget.onInput(index, v);
            },
          ),
        ),
      );
    }
    return Container(
      padding: _insets(s['p']),
      decoration: BoxDecoration(
        color: _color(s['bg'], Colors.white),
        border: bw > 0
            ? Border.all(
                color: _color(s['bc'], const Color(0xffdfe3e9)),
                width: bw,
              )
            : null,
        borderRadius: BorderRadius.circular(r[0]),
      ),
      child: TextField(
        controller: controller,
        focusNode: focus,
        readOnly: input['ro'] == true,
        obscureText: input['secret'] == true,
        minLines: input['multi'] == true ? 2 : 1,
        maxLines: input['multi'] == true ? 5 : 1,
        style: style,
        cursorColor: gBrand,
        keyboardType: input['numeric'] == true
            ? input['decimal'] == true
                  ? const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    )
                  : TextInputType.number
            : input['multi'] == true
            ? TextInputType.multiline
            : TextInputType.text,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: _string(input['ph']),
          hintStyle: style.copyWith(color: const Color(0xffb0b4bf)),
        ),
        onChanged: (v) {
          if (index != null) widget.onInput(index, v);
        },
      ),
    );
  }
}

// Same stripe/checker painting as the current mirror, with safe style values.
class _PopupStripes extends CustomPainter {
  _PopupStripes(this.style);
  final Map<String, dynamic> style;
  @override
  void paint(Canvas canvas, Size size) {
    final colors = style['c'] is List
        ? (style['c'] as List).map((e) => _color(e, Colors.black)).toList()
        : <Color>[];
    if (colors.length < 2) return;
    if (style['checker'] == true) {
      final value = _number(style['s']);
      final q = value <= 0
          ? 12.0
          : (value / 2).clamp(0.5, double.infinity).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = colors[1]);
      final paint = Paint()..color = colors[0];
      for (var y = 0.0; y < size.height; y += q) {
        for (var x = 0.0; x < size.width; x += q) {
          if (((x / q).round() + (y / q).round()).isEven) {
            canvas.drawRect(Rect.fromLTWH(x, y, q, q), paint);
          }
        }
      }
      return;
    }
    final value = _number(style['w']),
        w = value <= 0 ? 8.0 : value.clamp(0.5, double.infinity).toDouble();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors[1]);
    final diag = size.width + size.height;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_number(style['deg']) * 3.1415926535 / 180);
    final paint = Paint()..color = colors[0];
    for (var x = -diag; x < diag; x += w * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, w, diag * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PopupStripes old) => old.style != style;
}
