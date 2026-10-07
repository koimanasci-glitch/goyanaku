// Popup g181-modal (Stok, Kurir) memakai widget khusus Hibrida (NativeG181ModalSheet).
// Butir lembar Mode Murni diubah menjadi pohon tampilan dengan gaya yang sama dengan HTML v181.

import 'package:flutter/material.dart';

import '../native/g181_modal_sheet.dart';
import '../native/popup_components.dart';
import 'pages.dart';

const _base = {'fs': 14, 'fw': 400, 'lh': 19.6, 'c': 'rgb(30, 30, 30)'};
Map<String, dynamic> _s(Map<String, dynamic> extra) => {'m': [0, 0, 0, 0], 'p': [0, 0, 0, 0], ..._base, ...extra};

Map<String, dynamic> _input(Map it, {List? options, int index = -1}) => {
      's': _s({'m': [5, 0, 9, 0], 'p': [10, 10, 10, 10], 'fs': 12, 'lh': 16.8, 'bg': 'rgb(255, 255, 255)', 'bw': 1, 'bc': 'rgb(221, 226, 232)', 'br': [10, 10, 10, 10]}),
      'input': {
        'i': it['i'] ?? 0, 'v': '${it['v'] ?? ''}', 'ph': '${it['ph'] ?? ''}', 'multi': it['multiline'] == true, 'numeric': it['numeric'] == true, 'decimal': it['decimal'] == true,
        'secret': it['secret'] == true, 'ro': it['ro'] == true, 'options': options, 'index': index,
      },
    };

Map<String, dynamic> _note(String t, {int? tap}) => {
      's': _s({'m': [0, 0, 6, 0], 'p': [9, 9, 9, 9], 'fs': 11, 'lh': 15.4, 'c': 'rgb(126, 135, 149)', 'bg': 'rgb(247, 248, 250)', 'br': [10, 10, 10, 10]}),
      'spans': [{'t': t}],
      'tap': ?tap,
    };

/// Pohon tampilan g181-modal dari butir lembar (title, input, select, label/hint, toggle, date, entry, button).
Map<String, dynamic> g181Mirror(List<Map<String, dynamic>> items) {
  final fields = <Map<String, dynamic>>[], buttons = <Map<String, dynamic>>[];
  var title = '';
  for (final it in items) {
    switch (it['type']) {
      case 'title':
        if (title.isEmpty) {
          title = '${it['t']}';
        } else {
          fields.add(_note('${it['t']}'));
        }
      case 'input':
        fields.add(_input(it));
      case 'date':
        fields.add(_input({...it, 'ph': 'Jatuh tempo (tttt-bb-hh)'}));
      case 'select':
        fields.add(_input(it, options: (it['options'] as List? ?? const []).map((e) => '$e').toList(), index: (it['index'] as num?)?.toInt() ?? 0));
      case 'label' || 'hint':
        fields.add(_note('${it['t']}'));
      case 'toggle':
        fields.add({
          's': _s({'p': [7, 7, 7, 7]}),
          'spans': [{'t': '${it['on'] == true ? '☑' : '☐'}  ${it['t']}'}],
          'tap': it['i'] ?? 0,
        });
      case 'entry':
        fields.add(_note(['${it['t']}', ...(it['lines'] as List? ?? const []).map((e) => '$e'), if ('${it['amount'] ?? ''}'.isNotEmpty) '${it['amount']}'].join(' · ')));
      case 'button':
        buttons.add(it['primary'] == true
            ? {
                's': _s({'m': [6, 0, 0, 0], 'p': [14, 14, 14, 14], 'fs': 13.5, 'fw': 500, 'lh': 18.9, 'c': 'rgb(255, 255, 255)', 'bg': 'rgb(232, 73, 63)', 'br': [10, 10, 10, 10], 'ta': 'center'}),
                'b': it['i'] ?? 0, 'spans': [{'t': '${it['t']}'}],
              }
            : {
                's': _s({'m': [8, 0, 8, 0], 'p': [12, 12, 12, 12], 'fs': 13, 'fw': 500, 'lh': 18.2, 'bg': 'rgb(255, 255, 255)', 'bw': 1, 'bc': 'rgb(230, 233, 238)', 'br': [14, 14, 14, 14], 'ta': 'left'}),
                'b': it['i'] ?? 0, 'row': true, 'jc': 'normal', 'ai': 'center', 'gap': 12, 'rgap': 12,
                'ch': [{'s': _s({'fs': 13, 'fw': 500, 'lh': 18.2, 'ta': 'left'}), 'spans': [{'t': '${it['t']}'}], 'anon': 1}],
              });
    }
  }
  return {
    'kind': 'bottom', 'scrim': 'rgba(20, 27, 38, 0.5)',
    'box': {
      's': _s({'p': [8, 18, 16, 18], 'bg': 'rgb(255, 255, 255)', 'br': [22, 22, 0, 0]}),
      'ch': [
        {'s': _s({'m': [0, 157, 12, 157], 'bg': 'rgb(217, 221, 226)', 'br': [4, 4, 4, 4]}), 'w': 40, 'h': 4, 'fixed': 1},
        {'s': _s({'m': [4, 0, 3, 0], 'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'}), 'spans': [{'t': title}]},
        {'s': _s(const {}), 'ch': fields},
        ...buttons,
      ],
    },
  };
}

/// Widget popup g181-modal milik [page] (butir dari `sheetItems`, kejadian ke `sheetEvent`).
Widget? g181Sheet(PurePage page, String id) {
  final items = page.sheetItems(id);
  if (id != 'g181-modal' || items == null) return null;
  return NativeG181ModalSheet(
    key: ValueKey('pure-g181-${items.length}-${items.first['t']}'),
    model: g181Mirror(items),
    actions: PopupActions(
      id: id,
      onButton: (i) => page.sheetEvent(id, 'button', i, null),
      onTap: (i) => page.sheetEvent(id, 'toggle', i, null),
      onInput: (i, v) => page.sheetEvent(id, 'input', i, v),
      onClose: () => page.host.closePageSheet(id),
    ),
  );
}
