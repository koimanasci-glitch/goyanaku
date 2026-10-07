// Pohon tampilan (format yang sama dengan tangkapan HTML) dibuat langsung dari data Dart,
// sehingga halaman Mode Murni memakai widget yang persis sama dengan Mode Hibrida.
const _ink = 'rgb(30, 30, 30)';

Map<String, dynamic> _base({Map<String, dynamic>? s}) => {
      'm': [0, 0, 0, 0],
      'p': [0, 0, 0, 0],
      'fs': 14,
      'fw': 400,
      'lh': 19.6,
      'c': _ink,
      ...?s,
    };

const pencilSvg =
    "<svg fill=\"#ffffff\" xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M3 17.25V21h3.75L17.8 9.94l-3.75-3.75L3 17.25zm17.7-10.2a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z'/></svg>";
const trashSvg =
    "<svg fill=\"#6b7280\" xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M6 19a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'/></svg>";

Map<String, dynamic> _iconBtn(int b, String bg, String svg) => {
      's': _base(s: {'fs': 0, 'fw': 500, 'lh': 0, 'c': 'rgba(0, 0, 0, 0)', 'bg': bg, 'br': [14, 14, 14, 14], 'ta': 'center', 'minw': 52}),
      'w': 52,
      'h': 40,
      'b': b,
      'center': 1,
      'fixed': 1,
      'ch': [
        {'s': {'m': [0, 0, 0, 0], 'p': [0, 0, 0, 0]}, 'w': 22, 'h': 22, 'fixed': 1, 'svg': svg},
      ],
    };

Map<String, dynamic> _actions(int edit, int del) => {
      's': _base(),
      'w': 114,
      'h': 40,
      'row': true,
      'jc': 'normal',
      'ai': 'normal',
      'gap': 10,
      'rgap': 10,
      'ch': [_iconBtn(edit, 'rgb(232, 73, 63)', pencilSvg), _iconBtn(del, 'rgb(236, 238, 241)', trashSvg)],
    };

Map<String, dynamic> _subhead(String title) => {
      's': _base(s: {'p': [8, 16, 8, 16], 'bg': 'rgb(255, 255, 255)', 'bw': 1, 'bc': 'rgb(241, 242, 245)', 'bs': [0, 0, 1, 0]}),
      'w': 390,
      'h': 50,
      'row': true,
      'jc': 'normal',
      'ai': 'center',
      'gap': 10,
      'rgap': 10,
      'ch': [
        {
          's': _base(s: {'p': [0, 0, 2, 0], 'fs': 20, 'fw': 500, 'lh': 20, 'bg': 'rgb(243, 244, 247)', 'br': [9, 9, 9, 9], 'ta': 'center', 'minw': 38}),
          'w': 38,
          'h': 32,
          'b': 1,
          'center': 1,
          'fixed': 1,
          'spans': [
            {'t': '‹'}
          ],
        },
        {
          's': _base(s: {'fs': 14.5, 'fw': 600, 'lh': 18.85, 'ls': 0.7, 'up': 1}),
          'w': 80,
          'h': 19,
          'spans': [
            {'t': title}
          ],
        },
      ],
    };

Map<String, dynamic> _addButton(String text) => {
      's': _base(s: {'p': [14, 14, 14, 14], 'fs': 12, 'fw': 500, 'lh': 16.8, 'c': 'rgb(255, 255, 255)', 'bg': 'rgb(232, 73, 63)', 'br': [10, 10, 10, 10], 'ls': 0.3, 'up': 1, 'ta': 'center'}),
      'w': 362,
      'h': 45,
      'b': 2,
      'spans': [
        {'t': text}
      ],
    };

Map<String, dynamic> _card(List<Map<String, dynamic>> rows) => {
      's': _base(s: {'m': [12, 0, 12, 0], 'p': [4, 14, 4, 14], 'bg': 'rgb(255, 255, 255)', 'bw': 1, 'bc': 'rgb(241, 242, 245)', 'br': [18, 18, 18, 18]}),
      'w': 362,
      'h': 62.0 * rows.length,
      'ch': rows,
    };

Map<String, dynamic> _rowShell(int k, List<Map<String, dynamic>> ch) => {
      's': _base(s: {
        'p': [10, 0, 10, 0],
        if (k > 0) ...{'bw': 1, 'bc': 'rgb(240, 242, 245)', 'bs': [1, 0, 0, 0]},
      }),
      'w': 332,
      'h': 62,
      'row': true,
      'jc': 'normal',
      'ai': 'center',
      'gap': 12,
      'rgap': 12,
      'ch': ch,
    };

Map<String, dynamic> _page(String title, List<Map<String, dynamic>> content) => {
      'kind': 'page',
      'bg': 'rgb(255, 255, 255)',
      'head': true,
      'scan': 0,
      'nav': 3,
      'body': {
        's': _base(s: {'bg': 'rgb(255, 255, 255)'}),
        'w': 390,
        'h': 839,
        'ch': [
          _subhead(title),
          {
            's': _base(s: {'p': [14, 14, 110, 14], 'bg': 'rgb(246, 247, 249)'}),
            'w': 390,
            'h': 694,
            'ch': content,
          },
        ],
      },
    };

Map<String, dynamic> _hint(String t) => {
      's': _base(s: {'m': [10, 4, 0, 4], 'fs': 11.5, 'lh': 17.25, 'c': 'rgb(138, 143, 163)'}),
      'w': 354,
      'h': 35,
      'spans': [
        {'t': t}
      ],
    };

/// Halaman Parfum. Tombol: 1 kembali, 2 tambah, 3+2k ubah, 4+2k hapus. [items] = [nama, warna css].
Map<String, dynamic> perfumeMirror(List<List<String>> items, String Function(String css) bottleSvg) {
  final rows = <Map<String, dynamic>>[];
  for (var k = 0; k < items.length; k++) {
    final color = items[k].length > 1 ? items[k][1] : 'rgb(232, 73, 63)';
    rows.add(_rowShell(k, [
      {
        's': _base(s: {'bg': _alpha(color), 'br': [12, 12, 12, 12]}),
        'w': 42,
        'h': 42,
        'center': 1,
        'fixed': 1,
        'ch': [
          {'s': _base(), 'w': 28, 'h': 28, 'svg': bottleSvg(color)},
        ],
      },
      {
        's': _base(s: {'fw': 500}),
        'w': 130,
        'h': 20,
        'grow': 1,
        'spans': [
          {'t': items[k][0]}
        ],
      },
      {'s': _base(s: {'bg': color, 'br': [5, 5, 5, 5]}), 'w': 10, 'h': 10, 'fixed': 1, 'ch': []},
      _actions(3 + 2 * k, 4 + 2 * k),
    ]));
  }
  return _page('Parfum', [
    _addButton('+ Tambah Parfum'),
    _card(rows),
    _hint('Warna label membantu kasir & bagian produksi mengenali parfum dengan cepat.'),
  ]);
}

String _alpha(String css) {
  final m = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(css);
  if (m == null) return 'rgba(232, 73, 63, 0.12)';
  return 'rgba(${m.group(1)}, ${m.group(2)}, ${m.group(3)}, 0.12)';
}


/// Halaman Durasi. Tombol: 1 kembali, 3 tambah, 4+2k ubah, 5+2k hapus. [rows] = [nama, jam].
Map<String, dynamic> durationMirror(List<MapEntry<String, int>> rows) {
  Map<String, dynamic> row(int k, MapEntry<String, int> e) => {
        's': _base(s: {'p': [14, 2, 14, 2], 'bw': 1, 'bc': 'rgb(237, 240, 243)', 'bs': [0, 0, 1, 0]}),
        'w': 358,
        'h': 69,
        'row': true,
        'jc': 'space-between',
        'ai': 'center',
        'ch': [
          {
            's': _base(),
            'w': 164,
            'h': 20.3,
            'row': true,
            'jc': 'normal',
            'ai': 'center',
            'ch': [
              {
                's': _base(s: {'fs': 14.5, 'fw': 500, 'lh': 20.3, 'nowrap': 1, 'minw': 92}),
                'w': 92,
                'h': 20.3,
                'spans': [
                  {'t': e.key}
                ],
              },
              {'s': {'m': [0, 12, 0, 12], 'p': [0, 0, 0, 0], 'bg': 'rgb(217, 222, 229)', 'br': [0, 0, 0, 0]}, 'w': 1, 'h': 16, 'fixed': 1},
              {
                's': _base(s: {'fw': 500, 'lh': 16.8, 'c': 'rgb(107, 116, 133)'}),
                'w': 47,
                'h': 16.8,
                'spans': [
                  {'t': '${e.value} '},
                  {'t': 'jam', 'fw': 400, 'c': 'rgb(107, 116, 133)', 'fs': 14},
                ],
              },
            ],
          },
          _actions(4 + 2 * k, 5 + 2 * k),
        ],
      };
  final body = _page('Durasi', [
    {
      's': _base(s: {'m': [12, 0, 10, 0], 'p': [14, 14, 14, 14], 'fs': 12, 'fw': 500, 'lh': 16.8, 'c': 'rgb(255, 255, 255)', 'bg': 'rgb(232, 73, 63)', 'br': [10, 10, 10, 10], 'ls': 0.3, 'up': 1, 'ta': 'center'}),
      'w': 358,
      'h': 45,
      'b': 3,
      'spans': [
        {'t': '+ Tambah Durasi'}
      ],
    },
    for (var k = 0; k < rows.length; k++) row(k, rows[k]),
  ]);
  final content = ((body['body'] as Map)['ch'] as List)[1] as Map<String, dynamic>;
  content['s'] = _base(s: {'p': [14, 16, 24, 16]});
  return body;
}
