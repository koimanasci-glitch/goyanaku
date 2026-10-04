import 'package:flutter/material.dart';

import 'common.dart';

Map<String, dynamic> _map(Object? value) => value is Map
    ? {for (final entry in value.entries) if (entry.key is String) entry.key as String: entry.value}
    : <String, dynamic>{};

List<Map<String, dynamic>> _children(Map<String, dynamic> node) {
  final value = node['ch'];
  return value is List ? value.whereType<Map>().map(_map).toList() : [];
}

double _number(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;

String _string(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

Map<String, dynamic> _at(List<Map<String, dynamic>> nodes, int index) =>
    index < nodes.length ? nodes[index] : <String, dynamic>{};

Map<String, dynamic> _withDefaults(Map<String, dynamic> node, String label,
    Map<String, dynamic> style) {
  final spans = node['spans'];
  return {
    ...node,
    's': {
      ..._map(node['s']),
      for (final entry in style.entries)
        entry.key: entry.value is num
            ? _number(_map(node['s'])[entry.key], (entry.value as num).toDouble())
            : entry.value is String
                ? _string(_map(node['s'])[entry.key], entry.value as String)
                : entry.value,
    },
    'spans': spans is List && spans.whereType<Map>().isNotEmpty
        ? spans : [{'t': label}],
  };
}

String _label(Map<String, dynamic> node) {
  final spans = node['spans'];
  return spans is List
      ? spans.whereType<Map>().map((span) => '${span['t'] ?? ''}').join()
      : '';
}

/// The final HTML deliberately clears the legacy catalog. Keep its current
/// empty page, with data and action indices supplied by the same mirror model.
class NativePickservicePage extends StatelessWidget {
  const NativePickservicePage({
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

  Widget _text(Map<String, dynamic> node) {
    final style = _map(node['s']);
    final textStyle = gText(
      _number(style['fs'], 14) > 0 ? _number(style['fs'], 14) : 14,
      w: FontWeight.values[(_number(style['fw'], 400).toInt() ~/ 100 - 1).clamp(0, 8)],
      c: cssColor(_string(style['c'], 'rgb(30, 30, 30)')),
      h: _number(style['lh'], 19.6) > 0 ? _number(style['lh'], 19.6) : 19.6,
      ls: _number(style['ls'], 0),
    );
    final label = _label(node);
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: [TextSpan(
          text: style['up'] == 1 ? label.toUpperCase() : label,
          style: textStyle,
        )],
      ),
      textAlign: style['ta'] == 'center' ? TextAlign.center : TextAlign.left,
      softWrap: style['nowrap'] != 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _children(_map(model['body']));
    final heading = _children(_at(sections, 0));
    final back = _withDefaults(_at(heading, 0), '‹', {
      'fs': 20, 'fw': 500, 'lh': 20, 'c': 'rgb(30, 30, 30)',
      'bg': 'rgb(243, 244, 247)', 'ta': 'center',
    });
    final title = _withDefaults(_at(heading, 1), 'Pilih Layanan', {
      'fs': 14.5, 'fw': 600, 'lh': 18.85, 'ls': .7, 'up': 1,
      'c': 'rgb(30, 30, 30)',
    });
    final backStyle = _map(back['s']);
    final message = _withDefaults(_at(_children(_at(sections, 1)), 0),
        'Belum ada layanan.', {
      'fs': 12, 'fw': 400, 'lh': 16.8, 'ta': 'center',
      'c': 'rgb(138, 143, 163)',
    });
    final nav = _number(model['nav'], 1).toInt();
    final backIndex = back['b'];
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: cssColor(_string(model['bg'], 'rgb(255, 255, 255)'), Colors.white),
      child: Column(children: [
        if (model['head'] != false)
          GTopBar(top: top, onScan: onHeaderScan)
        else
          SizedBox(height: top),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        key: const Key('pickservice-back'),
                        behavior: HitTestBehavior.opaque,
                        onTap: backIndex is num && backIndex.isFinite && backIndex >= 0
                            ? () => onButton(backIndex.toInt()) : null,
                        child: Container(
                          width: 38,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cssColor(_string(backStyle['bg'], 'rgb(243, 244, 247)')),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: _text(back),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: _text(title)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                      child: _text(message),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (nav >= 0) GBottomNav(onTap: onNav, active: nav > 3 ? -1 : nav),
      ]),
    );
  }
}
