import 'package:flutter/material.dart';

import 'common.dart';

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

/// Native shared form/confirmation popup. Only gs107's heading, fields,
/// color choices and actions are laid out here; HTML still owns their handlers.
class NativeGs107Sheet extends StatelessWidget {
  const NativeGs107Sheet({
    super.key,
    required this.model,
    required this.onButton,
    required this.onInput,
    required this.onClose,
  });
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final void Function(int, Object) onInput;
  final VoidCallback onClose;

  Widget _text(Map<String, dynamic> node, [String fallback = '']) {
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
    return Text.rich(
      TextSpan(
        style: style(s),
        children: [
          if (spans.isEmpty) TextSpan(text: fallback),
          for (final span in spans)
            TextSpan(
              text: s['up'] == 1
                  ? _string(span['t']).toUpperCase()
                  : _string(span['t']),
              style: style(span),
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
  }

  Widget _box(Map<String, dynamic> node, Widget child, {bool inRow = false}) {
    final s = _map(node['s']), r = _sides(s['br']), m = _sides(s['m']);
    final bw = _number(s['bw']).clamp(0.0, double.infinity).toDouble(),
        fixed = node['fixed'] == 1;
    final ring = _map(s['ring']);
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
        border: bw > 0
            ? Border.all(
                color: _color(s['bc'], const Color(0xffe6e9ee)),
                width: bw,
              )
            : null,
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
      child: child,
    );
    final index = _index(node['b']);
    if (index != null) {
      result = GestureDetector(
        key: ValueKey('gs107-button-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onButton(index),
        child: result,
      );
    }
    if (fixed && !inRow) {
      return Align(
        alignment: (m[1] - m[3]).abs() < 2 && m[1] > 0
            ? Alignment.center
            : Alignment.centerLeft,
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

  Widget _field(Map<String, dynamic> node) {
    if (node['input'] is Map) {
      return _Gs107Field(
        key: ValueKey('gs107-input-${_index(_map(node['input'])['i'])}'),
        node: node,
        onInput: onInput,
      );
    }
    if (node['row'] == true) {
      return _box(
        node,
        Wrap(
          spacing: _number(node['gap']).clamp(0.0, double.infinity).toDouble(),
          runSpacing: _number(
            node['rgap'],
            _number(node['gap']),
          ).clamp(0.0, double.infinity).toDouble(),
          children: [
            for (final option in _children(node))
              _box(option, const SizedBox.shrink(), inRow: true),
          ],
        ),
      );
    }
    return _box(node, _text(node));
  }

  Widget _blocks(
    List<Map<String, dynamic>> nodes,
    Widget Function(Map<String, dynamic>) draw,
  ) {
    final widgets = <Widget>[];
    double previous = 0;
    for (final node in nodes) {
      final m = _sides(_map(node['s'])['m']);
      final space = m[0] > previous ? m[0] : previous;
      if (space > 0) widgets.add(SizedBox(height: space));
      widgets.add(draw(node));
      previous = m[2];
    }
    if (previous > 0) widgets.add(SizedBox(height: previous));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = _map(model['box']);
    final box = {
      ...raw,
      's': {
        'bg': 'rgb(255, 255, 255)',
        'p': [8, 18, 16, 18],
        'br': [22, 22, 0, 0],
        ..._map(raw['s']),
      },
    };
    final nodes = _children(box), fields = _child(box, 3);
    final hasInput = _children(fields).any((n) => n['input'] is Map);
    final mq = MediaQuery.of(context),
        keyboard = hasInput ? mq.viewInsets.bottom : 0.0;
    final s = _map(box['s']), r = _sides(s['br']), p = _sides(s['p']);
    final body = Container(
      constraints: BoxConstraints(
        maxHeight: (mq.size.height - keyboard - 20)
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
          p[2] + mq.padding.bottom,
        ),
        child: _blocks(
          nodes.isEmpty
              ? [
                  {
                    'spans': [
                      {'t': 'Judul'},
                    ],
                    's': {'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'},
                  },
                ]
              : nodes,
          (node) {
            if (nodes.indexOf(node) == 3) {
              return _box(node, _blocks(_children(node), _field));
            }
            return _box(node, _text(node));
          },
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: ColoredBox(
                color: _color(model['scrim'], const Color(0x80141b26)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Align(
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

class _Gs107Field extends StatefulWidget {
  const _Gs107Field({super.key, required this.node, required this.onInput});
  final Map<String, dynamic> node;
  final void Function(int, Object) onInput;
  @override
  State<_Gs107Field> createState() => _Gs107FieldState();
}

class _Gs107FieldState extends State<_Gs107Field> {
  late final controller = TextEditingController(
    text: _string(_map(widget.node['input'])['v']),
  );
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _Gs107Field old) {
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
    final index = _index(input['i']);
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
