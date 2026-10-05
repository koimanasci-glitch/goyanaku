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

/// Native category form: icon picker, unit, process choices and three fields.
/// HTML still owns the scoped action handlers and persistence.
class NativeCat99Sheet extends StatelessWidget {
  const NativeCat99Sheet({
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
        key: ValueKey('cat99-button-$index'),
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

  Widget _input(Map<String, dynamic> node) => _Cat99Field(
    key: ValueKey('cat99-input-${_index(_map(node['input'])['i'])}'),
    node: node,
    onInput: onInput,
  );

  Widget _icon(Map<String, dynamic> option) {
    final image = _child(option, 0);
    final svg = _string(image['svg']);
    final child = _blocks(
      [image],
      (node) => _box(
        node,
        svg.isEmpty
            ? const SizedBox.shrink()
            : gSvg(
                svg,
                _number(node['w'], 30).clamp(0.0, double.infinity).toDouble(),
                h: _number(
                  node['h'],
                  30,
                ).clamp(0.0, double.infinity).toDouble(),
              ),
      ),
    );
    return _box(
      option,
      option['center'] == 1 ? Center(child: child) : child,
      inRow: true,
    );
  }

  Widget _grid(
    Map<String, dynamic> node,
    int fallbackColumns,
    Widget Function(Map<String, dynamic>) draw,
  ) {
    final columns = _number(
      node['grid'],
      fallbackColumns.toDouble(),
    ).toInt().clamp(1, 30).toInt();
    final options = _children(node);
    final widths = node['colw'] is List
        ? (node['colw'] as List).map(_number).toList()
        : <double>[];
    final gap = _number(node['gap']).clamp(0.0, double.infinity).toDouble();
    final rowGap = _number(
      node['rgap'],
      gap,
    ).clamp(0.0, double.infinity).toDouble();
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
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
        Widget cell = const SizedBox.shrink();
        if (i + j < options.length) {
          final option = options[i + j],
              m = _sides(_map(options[i + j]['s'])['m']);
          cell = draw(option);
          if (m[0] > 0 || m[2] > 0) {
            cell = Padding(
              padding: EdgeInsets.only(top: m[0], bottom: m[2]),
              child: cell,
            );
          }
        }
        cells.add(Expanded(flex: flex, child: cell));
      }
      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
      );
    }
    return _box(
      node,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _process(Map<String, dynamic> node) => _box(
    node,
    Wrap(
      spacing: _number(node['gap']).clamp(0.0, double.infinity).toDouble(),
      runSpacing: _number(
        node['rgap'],
        _number(node['gap']),
      ).clamp(0.0, double.infinity).toDouble(),
      children: [
        for (final option in _children(node))
          _box(option, _text(option), inRow: true),
      ],
    ),
  );

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
    final nodes = _children(box);
    final hasInput = nodes.any((n) => n['input'] is Map);
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
                      {'t': 'Kategori Baru'},
                    ],
                    's': {'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'},
                  },
                ]
              : nodes,
          (node) {
            final position = nodes.indexOf(node);
            if (position == 6) return _grid(node, 5, _icon);
            if (position == 8) {
              return _grid(
                node,
                3,
                (option) => _box(option, _text(option), inRow: true),
              );
            }
            if (position == 10) return _process(node);
            if (node['input'] is Map) return _input(node);
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

class _Cat99Field extends StatefulWidget {
  const _Cat99Field({super.key, required this.node, required this.onInput});
  final Map<String, dynamic> node;
  final void Function(int, Object) onInput;
  @override
  State<_Cat99Field> createState() => _Cat99FieldState();
}

class _Cat99FieldState extends State<_Cat99Field> {
  late final controller = TextEditingController(
    text: _string(_map(widget.node['input'])['v']),
  );
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _Cat99Field old) {
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
