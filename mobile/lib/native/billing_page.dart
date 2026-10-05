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

/// B9: final billing header and empty-state layout. Production menu redirection
/// remains owned by HTML; this widget does not enable subscription purchases.
class NativeBillingPage extends StatelessWidget {
  const NativeBillingPage({
    super.key,
    required this.model,
    required this.onButton,
    required this.onNav,
    required this.onHeaderScan,
    this.topInset,
  });
  final Map<String, dynamic> model;
  final ValueChanged<int> onButton;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;
  Widget _text(Map<String, dynamic> node, [String fallback = '']) {
    if (node['spans'] is! List && fallback.isEmpty) {
      return const SizedBox.shrink();
    }
    final s = _map(node['s']);
    final fs = _number(s['fs'], 14);
    final lh = _number(s['lh']);
    final color = _color(_string(s['c']), const Color(0xff1e1e1e));
    TextStyle style(Map<String, dynamic> span) => gText(
      _number(span['fs'], fs) > 0 ? _number(span['fs'], fs) : 14,
      w: _weight(span['fw'] ?? s['fw']),
      c: _color(_string(span['c']), color),
      h: lh > 0 ? lh : null,
      ls: _number(s['ls']),
    );
    final spans = node['spans'] is List
        ? (node['spans'] as List).whereType<Map>().map(_map).toList()
        : <Map<String, dynamic>>[];
    final text = Text.rich(
      TextSpan(
        style: style(s),
        children: [
          if (spans.isEmpty)
            TextSpan(text: s['up'] == 1 ? fallback.toUpperCase() : fallback),
          for (final span in spans)
            TextSpan(
              text: s['up'] == 1
                  ? _string(span['t']).toUpperCase()
                  : _string(span['t']),
              style: style(span).copyWith(
                backgroundColor: span['bg'] is String
                    ? _color(span['bg'] as String)
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
    final link = spans.where((sp) => _index(sp['b']) != null).firstOrNull;
    return link == null
        ? text
        : GestureDetector(
            key: ValueKey('billing-button-${_index(link['b'])}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onButton(_index(link['b'])!),
            child: text,
          );
  }

  Widget _box(Map<String, dynamic> node, Widget child) {
    final s = _map(node['s']);
    final r = _sides(s['br']);
    final bw = _number(s['bw']).clamp(0.0, double.infinity).toDouble();
    final borderColor = _color(_string(s['bc']), const Color(0xffe6e9ee));
    BoxBorder? border;
    if (bw > 0) {
      if (s['bs'] is List && r.every((v) => v == 0)) {
        final bs = _sides(s['bs']);
        BorderSide side(double w) =>
            w > 0 ? BorderSide(color: borderColor, width: w) : BorderSide.none;
        border = Border(
          top: side(bs[0]),
          right: side(bs[1]),
          bottom: side(bs[2]),
          left: side(bs[3]),
        );
      } else {
        border = Border.all(color: borderColor, width: bw);
      }
    }
    final fixed = node['fixed'] == 1;
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
        color: s['bg'] is String ? _color(s['bg'] as String) : null,
        border: border,
        borderRadius: r.any((v) => v > 0)
            ? BorderRadius.only(
                topLeft: Radius.circular(r[0]),
                topRight: Radius.circular(r[1]),
                bottomRight: Radius.circular(r[2]),
                bottomLeft: Radius.circular(r[3]),
              )
            : null,
      ),
      child: child,
    );
    final index = _index(node['b']);
    if (index != null) {
      result = GestureDetector(
        key: ValueKey('billing-button-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onButton(index),
        child: result,
      );
    }
    final minw = _number(s['minw']);
    if (minw > 0) {
      result = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minw),
        child: result,
      );
    }
    final m = _sides(s['m']);
    if (m[1] > 0 || m[3] > 0) {
      result = Padding(
        padding: EdgeInsets.only(left: m[3], right: m[1]),
        child: result,
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final body = _map(model['body']);
    Map<String, dynamic> fallback(
      Map<String, dynamic> node,
      Map<String, dynamic> style,
    ) => {
      ...node,
      's': {...style, ..._map(node['s'])},
    };
    final heading = fallback(_child(body, 0), {
      'p': [8, 16, 8, 16],
      'bg': 'rgb(255, 255, 255)',
      'bw': 1,
      'bc': 'rgb(241, 242, 245)',
      'bs': [0, 0, 1, 0],
    });
    final content = fallback(_child(body, 1), {
      'p': [14, 16, 110, 16],
    });
    final backRaw = _child(heading, 0);
    final back = {
      ...fallback(backRaw, {
        'fs': 20,
        'fw': 500,
        'lh': 20,
        'bg': 'rgb(243, 244, 247)',
        'br': [9, 9, 9, 9],
      }),
      'fixed': 1,
      'w': _number(backRaw['w'], 38),
      'h': _number(backRaw['h'], 32),
    };
    final title = fallback(_child(heading, 1), {
      'fs': 14.5,
      'fw': 600,
      'lh': 18.85,
      'ls': 0.7,
      'up': 1,
    });
    final message = fallback(_child(content, 0), {
      'm': [12, 0, 12, 0],
      'p': [24, 12, 24, 12],
      'fs': 12,
      'lh': 16.8,
      'c': 'rgb(138, 143, 163)',
      'ta': 'center',
    });
    final margin = _sides(_map(message['s'])['m']);
    final padding = _sides(_map(body['s'])['p']);
    final nav = _index(model['nav']);
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: _color(model['bg'], Colors.white),
      child: Column(
        children: [
          if (model['head'] != false)
            GTopBar(top: top, onScan: onHeaderScan)
          else
            SizedBox(height: top),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding[3],
                padding[0],
                padding[1],
                padding[2] + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _box(
                    heading,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _box(back, _text(back, '‹')),
                        SizedBox(width: _number(heading['gap'], 10)),
                        Flexible(
                          child: _box(title, _text(title, 'BILLING & INVOICE')),
                        ),
                      ],
                    ),
                  ),
                  _box(
                    content,
                    Padding(
                      padding: EdgeInsets.only(
                        top: margin[0],
                        bottom: margin[2],
                      ),
                      child: _box(
                        message,
                        _text(message, 'Belum ada tagihan.'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nav != null || model.isEmpty)
            GBottomNav(onTap: onNav, active: (nav ?? 3) > 3 ? -1 : nav ?? 3),
        ],
      ),
    );
  }
}
