import 'package:flutter/material.dart';

import 'popup_components.dart';

/// Dedicated native wa131 popup. Scoped HTML actions remain unchanged.
class NativeWa131Sheet extends StatelessWidget {
  const NativeWa131Sheet({
    super.key,
    required this.model,
    required this.actions,
  });
  final Map<String, dynamic> model;
  final PopupActions actions;
  @override
  Widget build(BuildContext context) {
    final style = PopupStyle(actions);
    Widget leaf(Map<String, dynamic> n, bool row, String ta) =>
        style.leaf(n, inRow: row, parentTa: ta);
    Widget simple(Map<String, dynamic> n, bool row, String ta) =>
        popupChildren(n).isEmpty ||
            n['spans'] is List ||
            n['input'] is Map ||
            n['img'] is String ||
            n['svg'] is String
        ? leaf(n, row, ta)
        : style.box(n, style.layout(n, leaf), inRow: row, parentTa: ta);
    Widget receiptLines(Map<String, dynamic> n, bool row, String ta) =>
        popupChildren(n).isEmpty ||
            n['spans'] is List ||
            n['input'] is Map ||
            n['img'] is String
        ? leaf(n, row, ta)
        : style.box(n, style.layout(n, leaf), inRow: row, parentTa: ta);
    Widget receiptPanel(Map<String, dynamic> n, bool row, String ta) =>
        popupChildren(n).isEmpty ||
            n['spans'] is List ||
            n['input'] is Map ||
            n['img'] is String
        ? leaf(n, row, ta)
        : style.box(n, style.layout(n, receiptLines), inRow: row, parentTa: ta);
    final raw = popupMap(model['box']);
    final root = popupChildren(raw).isEmpty
        ? {
            's': {
              'bg': 'rgb(255,255,255)',
              'p': [8, 18, 16, 18],
              'br': [22, 22, 0, 0],
            },
            'ch': [
              {
                'spans': [
                  {'t': 'Nota WhatsApp'},
                ],
                's': {'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'},
              },
            ],
          }
        : raw;
    var position = 0;
    final content = style.layout(root, (n, row, ta) {
      final i = position++;
      if (i == 3) return receiptPanel(n, row, ta);
      return simple(n, row, ta);
    });
    return PopupFrame(
      model: {...model, 'box': root},
      actions: actions,
      child: content,
    );
  }
}
