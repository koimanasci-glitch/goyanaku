import 'package:flutter/material.dart';

import 'popup_components.dart';

/// Dedicated native td175 popup. Scoped HTML actions remain unchanged.
class NativeTd175Sheet extends StatelessWidget {
  const NativeTd175Sheet({
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
    Widget accountSection(Map<String, dynamic> n, bool row, String ta) =>
        popupChildren(n).isEmpty ||
            n['spans'] is List ||
            n['input'] is Map ||
            n['img'] is String
        ? leaf(n, row, ta)
        : style.box(n, style.layout(n, simple), inRow: row, parentTa: ta);
    Widget accountDetail(Map<String, dynamic> n, bool row, String ta) =>
        popupChildren(n).isEmpty ||
            n['spans'] is List ||
            n['input'] is Map ||
            n['img'] is String
        ? leaf(n, row, ta)
        : style.box(
            n,
            style.layout(n, accountSection),
            inRow: row,
            parentTa: ta,
          );
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
                  {'t': 'Detail Laundry'},
                ],
                's': {'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'},
              },
            ],
          }
        : raw;
    var position = 0;
    final content = style.layout(root, (n, row, ta) {
      final i = position++;
      if (i == 1) return accountDetail(n, row, ta);
      return simple(n, row, ta);
    });
    return PopupFrame(
      model: {...model, 'box': root},
      actions: actions,
      child: content,
    );
  }
}
