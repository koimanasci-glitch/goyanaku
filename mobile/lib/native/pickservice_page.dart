import 'package:flutter/material.dart';

import 'common.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _children(Map<String, dynamic> node) =>
    (node['ch'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();

String _label(Map<String, dynamic> node) =>
    (node['spans'] as List? ?? const [])
        .whereType<Map>()
        .map((span) => '${span['t'] ?? ''}')
        .join();

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
      (style['fs'] as num).toDouble(),
      w: FontWeight.values[(style['fw'] as num).toInt() ~/ 100 - 1],
      c: cssColor(style['c'] as String?),
      h: (style['lh'] as num).toDouble(),
      ls: (style['ls'] as num?)?.toDouble() ?? 0,
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
    final heading = _children(sections[0]);
    final back = heading[0];
    final backStyle = _map(back['s']);
    final message = _children(sections[1]).single;
    final nav = (model['nav'] as num?)?.toInt() ?? -1;
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: cssColor(model['bg'] as String?, Colors.white),
      child: Column(children: [
        if (model['head'] == true)
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
                        onTap: () => onButton((back['b'] as num).toInt()),
                        child: Container(
                          width: 38,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cssColor(backStyle['bg'] as String?),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: _text(back),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: _text(heading[1])),
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
