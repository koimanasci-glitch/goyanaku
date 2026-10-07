// Popup g181-modal (Stok, Kurir) memakai widget khusus Hibrida (NativeG181ModalSheet).
// Butir lembar Mode Murni diubah menjadi pohon tampilan dengan gaya yang sama dengan HTML v181.

import 'package:flutter/material.dart';

import '../native/g181_modal_sheet.dart';
import '../native/popup_components.dart';
import '../native/rs139_sheet.dart';
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

// ---------- rs139 (Ralat): gaya HTML v139 ----------

Map<String, dynamic> _lbl(String t) => {'s': _s({'m': [10, 0, 5, 0], 'fs': 11.5, 'lh': 16.1, 'c': 'rgb(91, 95, 110)'}), 'spans': [{'t': t}]};
Map<String, dynamic> _field(Map it, {List? options, int index = -1, bool gap = false}) => {
      's': _s({'m': [gap ? 8 : 0, 0, 0, 0], 'p': [11, 12, 11, 12], 'fs': 12, 'lh': 16.8, 'bg': 'rgb(255, 255, 255)', 'bw': 1, 'bc': 'rgb(223, 227, 233)', 'br': [12, 12, 12, 12]}),
      'input': {
        'i': it['i'] ?? 0, 'v': '${it['v'] ?? ''}', 'ph': '${it['ph'] ?? ''}', 'multi': false, 'numeric': it['numeric'] == true, 'decimal': it['decimal'] == true,
        'secret': false, 'ro': false, 'options': options, 'index': index,
      },
    };

/// Pohon tampilan popup ralat (rs139) dari butir lembar: kotak "Tercatat", label, pilihan (chip), isian, pratinjau, tombol aksi.
Map<String, dynamic> rs139Mirror(List<Map<String, dynamic>> items) {
  var title = '', sub = '';
  final fields = <Map<String, dynamic>>[];
  final lastButtons = items.lastIndexWhere((e) => e['type'] == 'buttons');
  for (var k = 0; k < items.length; k++) {
    final it = items[k];
    switch (it['type']) {
      case 'title':
        title = '${it['t']}';
      case 'hint':
        if (sub.isEmpty && fields.isEmpty) {
          sub = '${it['t']}';
        } else {
          fields.add({
            's': _s({'m': [10, 0, 0, 0], 'p': [9, 11, 9, 11], 'fs': 11.5, 'lh': 16.1, 'c': 'rgb(138, 75, 15)', 'bg': 'rgb(255, 248, 236)', 'br': [12, 12, 12, 12]}),
            'spans': [{'t': '${it['t']}'}],
          });
        }
      case 'pair':
        fields.add({
          's': _s({'p': [9, 11, 9, 11], 'fs': 12, 'lh': 16.8, 'c': 'rgb(107, 114, 128)', 'bg': 'rgb(246, 247, 249)', 'br': [12, 12, 12, 12]}),
          'row': true, 'jc': 'space-between', 'ai': 'center', 'gap': 10, 'rgap': 10,
          'ch': [
            {'s': _s({'fs': 12, 'lh': 16.8, 'c': 'rgb(107, 114, 128)'}), 'spans': [{'t': '${it['t']}'}]},
            {'s': _s({'fs': 12, 'fw': 500, 'lh': 16.8, 'ta': 'right'}), 'grow': 1, 'spans': [{'t': '${it['v']}'}]},
          ],
        });
      case 'label':
        fields.add(_lbl('${it['t']}'));
      case 'input':
        fields.add(_field(it, gap: k > 0 && items[k - 1]['type'] == 'buttons'));
      case 'select':
        fields.add(_field(it, options: (it['options'] as List? ?? const []).map((e) => '$e').toList(), index: (it['index'] as num?)?.toInt() ?? 0));
      case 'button':
        fields.add({
          's': _s({'m': [14, 0, 0, 0], 'p': [13, 13, 13, 13], 'fs': 13, 'fw': 500, 'lh': 18.2, 'c': 'rgb(255, 255, 255)', 'bg': 'rgb(232, 73, 63)', 'br': [14, 14, 14, 14], 'ta': 'center'}),
          'b': it['i'] ?? 0, 'spans': [{'t': '${it['t']}'}],
        });
      case 'buttons':
        final opts = (it['options'] as List? ?? const []).whereType<Map>().toList();
        if (k == lastButtons && opts.length == 2) {
          // Aksi: kiri lunak merah (Batalkan), kanan merah penuh (Simpan Ralat).
          fields.add({
            's': _s({'m': [14, 0, 0, 0]}), 'row': true, 'jc': 'normal', 'ai': 'normal', 'gap': 8, 'rgap': 8,
            'ch': [
              for (final (n, o) in opts.indexed)
                {
                  's': _s({'p': [13, 13, 13, 13], 'fs': 13, 'fw': 500, 'lh': 18.2, 'c': n == 0 ? 'rgb(216, 50, 63)' : 'rgb(255, 255, 255)', 'bg': n == 0 ? 'rgb(255, 240, 241)' : 'rgb(232, 73, 63)', 'br': [14, 14, 14, 14], 'ta': 'center'}),
                  'b': o['i'] ?? 0, 'grow': 1, 'spans': [{'t': '${o['t']}'}],
                },
            ],
          });
        } else {
          fields.add({
            's': _s(const {}), 'row': true, 'wrap': 1, 'jc': 'normal', 'ai': 'normal', 'gap': 7, 'rgap': 7,
            'ch': [
              for (final o in opts)
                {
                  's': _s({
                    'p': [7, 11, 7, 11], 'fs': 11.5, 'fw': 500, 'lh': 16.1, 'c': o['on'] == true ? 'rgb(232, 73, 63)' : 'rgb(91, 95, 110)',
                    'bg': o['on'] == true ? 'rgb(255, 248, 248)' : 'rgb(255, 255, 255)', 'bw': 1, 'bc': o['on'] == true ? 'rgb(232, 73, 63)' : 'rgb(225, 229, 234)', 'br': [18, 18, 18, 18], 'ta': 'center',
                  }),
                  'b': o['i'] ?? 0, 'spans': [{'t': '${o['t']}'}],
                },
            ],
          });
        }
    }
  }
  return {
    'kind': 'bottom', 'scrim': 'rgba(20, 27, 38, 0.5)',
    'box': {
      's': _s({'p': [8, 18, 16, 18], 'bg': 'rgb(255, 255, 255)', 'br': [22, 22, 0, 0]}),
      'ch': [
        {'s': _s({'m': [0, 157, 12, 157], 'bg': 'rgb(217, 221, 226)', 'br': [4, 4, 4, 4]}), 'w': 40, 'h': 4, 'fixed': 1},
        {'s': _s({'m': [4, 0, 3, 0], 'fs': 17, 'fw': 500, 'lh': 23.8, 'ta': 'center'}), 'spans': [{'t': title}]},
        {'s': _s({'m': [0, 0, 14, 0], 'fs': 12, 'lh': 16.8, 'c': 'rgb(138, 143, 163)', 'ta': 'center'}), 'spans': [{'t': sub}]},
        {'s': _s(const {}), 'ch': fields},
      ],
    },
  };
}

/// Widget popup ralat dari butir + penangan kejadian.
Widget rs139Widget(String id, List<Map<String, dynamic>> items, void Function(String kind, int i, Object? v) on, VoidCallback close) => NativeRs139Sheet(
      key: ValueKey('pure-$id-${items.length}'),
      model: rs139Mirror(items),
      actions: PopupActions(id: id, onButton: (i) => on('button', i, null), onTap: (i) => on('button', i, null), onInput: (i, v) => on('input', i, v), onClose: close),
    );
