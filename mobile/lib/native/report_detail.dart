import 'package:flutter/material.dart';

import '../logic/reports_a8.dart';
import 'common.dart';

// Detail laporan (A8): digambar dari hasil hitungan Dart (reports_a8.dart), bukan dari HTML.

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);

/// Potongan teks sel tabel laporan (HTML mini: <small>, <b>, <span class="tag x">).
class RepSeg {
  const RepSeg(this.text, {this.bold = false, this.tag});
  final String text;
  final bool bold;
  final String? tag;
}

String repDecode(String t) => t
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

List<RepSeg> _segs(String html) {
  final out = <RepSeg>[];
  final re = RegExp(r'<span class="tag ([a-z]*)">(.*?)</span>|<b>(.*?)</b>');
  var i = 0;
  for (final m in re.allMatches(html)) {
    if (m.start > i) out.add(RepSeg(repDecode(html.substring(i, m.start))));
    if (m.group(2) != null) {
      out.add(RepSeg(repDecode(m.group(2)!), tag: m.group(1)));
    } else {
      out.add(RepSeg(repDecode(m.group(3)!), bold: true));
    }
    i = m.end;
  }
  if (i < html.length) out.add(RepSeg(repDecode(html.substring(i))));
  return out;
}

/// (teks utama, teks kecil) dari satu sel; `raw` = sel boleh berisi HTML mini.
(List<RepSeg>, List<RepSeg>) parseRepCell(Object? v, {bool raw = true}) {
  final s = v is num ? '${v == v.truncate() ? v.toInt() : v}' : '${v ?? ''}';
  if (!raw) return ([RepSeg(s)], const []);
  final m = RegExp(r'^(.*?)<small>(.*)</small>$', dotAll: true).firstMatch(s);
  if (m == null) return (_segs(s), const []);
  return (_segs(m.group(1)!), _segs(m.group(2)!));
}

class ReportDetailModel {
  const ReportDetailModel({
    required this.id,
    required this.title,
    required this.category,
    required this.desc,
    required this.periodKey,
    required this.periodLabel,
    required this.data,
    this.isExport = false,
  });
  final String id, title, category, desc, periodKey, periodLabel;
  final Object data; // Map (laporan) atau List (export)
  final bool isExport;
}

abstract class ReportDetailActions {
  void rdBack();
  void rdScan();
  void rdNav(String page);
  void rdPeriod(String key);
  void rdCsv();
  void rdShare();
  void rdOpen(String page);
}

class NativeReportDetail extends StatefulWidget {
  const NativeReportDetail({super.key, required this.model, required this.actions, this.topInset});
  final ReportDetailModel model;
  final ReportDetailActions actions;
  final double? topInset;
  @override
  State<NativeReportDetail> createState() => _NativeReportDetailState();
}

class _NativeReportDetailState extends State<NativeReportDetail> {
  int _limit = 30;

  @override
  void didUpdateWidget(NativeReportDetail old) {
    super.didUpdateWidget(old);
    if (old.model.id != widget.model.id) _limit = 30;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: const Color(0xfff6f7f9),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.rdScan)),
          Container(
            height: 55, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
            child: Row(children: [
              GestureDetector(
                key: const ValueKey('rd-back'),
                onTap: a.rdBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                    child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7)),
                  Text('${m.category} · ${m.periodLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(10.5, c: _muted)),
                ]),
              ),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: _body(m))),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 2, onTap: a.rdNav)),
      ]),
    );
  }

  List<Widget> _body(ReportDetailModel m) {
    final a = widget.actions;
    final w = <Widget>[
      _Periods(current: m.periodKey, onTap: a.rdPeriod),
      const SizedBox(height: 10),
      Padding(padding: const EdgeInsets.only(left: 2, bottom: 10), child: Text(m.desc, style: gText(12, c: _muted, h: 17))),
    ];
    if (m.isExport) {
      final rows = (m.data as List).map((r) => (r as List).toList()).toList();
      final n = rows.isEmpty ? 0 : rows.length - 1;
      w.add(_Kpis(kpis: [
        ['Siap diexport', '$n baris', m.periodLabel, 'w']
      ]));
      if (rows.isNotEmpty) {
        w.add(_Card(
          title: 'Pratinjau',
          sub: '${n < 5 ? n : 5} baris pertama',
          child: _Table(cols: rows.first.map((e) => '$e').toList(), rows: rows.skip(1).take(5).toList(), raw: false, scroll: true),
        ));
      }
    } else {
      final o = Map<String, dynamic>.from(m.data as Map);
      final kpis = (o['k'] as List? ?? const []).map((e) => (e as List).toList()).toList();
      if (kpis.isNotEmpty) w.add(_Kpis(kpis: kpis));
      if (o['note'] != null) {
        w.add(Container(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Text('💡 ${o['note']}', style: gText(11.5, c: _muted, h: 17)),
        ));
      }
      final ch = o['ch'];
      if (ch is Map && (ch['d'] as List? ?? const []).isNotEmpty) w.add(_Chart(ch: Map<String, dynamic>.from(ch)));
      final rows = (o['rows'] as List? ?? const []).map((r) => (r as List).toList()).toList();
      final cols = (o['cols'] as List? ?? const []).map((e) => '$e').toList();
      final raw = o['raw'] == 1;
      w.add(_Card(
        title: 'Rincian',
        sub: '${rows.length} baris',
        child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('${o['empty'] ?? 'Tidak ada data pada periode ini'}', textAlign: TextAlign.center, style: gText(12, c: _muted))))
            : Column(children: [
                _Table(cols: cols, rows: rows.take(_limit).toList(), raw: raw),
                if (rows.length > _limit)
                  GestureDetector(
                    key: const ValueKey('rd-more'),
                    onTap: () => setState(() => _limit += 30),
                    child: Container(
                      height: 38, margin: const EdgeInsets.only(top: 10), alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xfff6f7f9), borderRadius: BorderRadius.circular(10)),
                      child: Text('Tampilkan lebih banyak (${rows.length - _limit})', style: gText(12.5, c: _ink)),
                    ),
                  ),
              ]),
      ));
      if (o['go2'] != null) {
        w.add(GestureDetector(
          key: const ValueKey('rd-go2'),
          onTap: () => a.rdOpen('${o['go2']}'),
          child: Container(
            height: 38, margin: const EdgeInsets.only(bottom: 10), alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text('Kelola ${m.title} ›', style: gText(12.5, c: _ink)),
          ),
        ));
      }
    }
    w.add(Row(children: [
      Expanded(child: _Action(key: const ValueKey('rd-csv'), label: m.isExport ? '⬇ Unduh CSV (Excel)' : '⬇ Unduh CSV', onTap: a.rdCsv)),
      const SizedBox(width: 8),
      Expanded(child: _Action(key: const ValueKey('rd-wa'), label: 'Kirim ke WA', green: true, onTap: a.rdShare)),
    ]));
    return w;
  }
}

class _Periods extends StatelessWidget {
  const _Periods({required this.current, required this.onTap});
  final String current;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final p in reportPeriodsA8)
            GestureDetector(
              key: ValueKey('rd-per-${p.$1}'),
              onTap: () => onTap(p.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.$1 == current ? gBrand : Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.$1 == current ? gBrand : const Color(0xffe6e8ec)),
                ),
                child: Text(p.$2, style: gText(12, w: FontWeight.w500, c: p.$1 == current ? Colors.white : _ink)),
              ),
            ),
        ]),
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.kpis});
  final List<List<dynamic>> kpis;
  @override
  Widget build(BuildContext context) {
    Widget tile(List k) {
      final tone = k.length > 3 ? '${k[3]}' : '';
      final hero = tone == 'w';
      final vc = hero ? Colors.white : (tone == 'g' ? const Color(0xff3e8a2e) : tone == 'r' ? const Color(0xffc62f3b) : _ink);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hero ? null : Colors.white, borderRadius: BorderRadius.circular(14),
          gradient: hero ? const LinearGradient(colors: [Color(0xffff6b48), Color(0xffe23e2b)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          boxShadow: hero ? null : [gShadow(const Color(0xffeef0f3), 1, 0)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${k[0]}', style: gText(11, c: hero ? const Color(0xffffe3dd) : _muted)),
          const SizedBox(height: 2),
          Text('${k[1]}', maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(hero ? 22 : 16, w: FontWeight.w600, c: vc, h: hero ? 30 : 22)),
          if ('${k.length > 2 ? k[2] : ''}'.isNotEmpty)
            Text('${k[2]}', style: gText(10.5, c: hero ? const Color(0xffffe3dd) : _muted)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(builder: (context, c) {
        final half = (c.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in kpis) SizedBox(width: (k.length > 3 && '${k[3]}' == 'w') ? c.maxWidth : half, child: tile(k)),
        ]);
      }),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.sub, required this.child});
  final String title, sub;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [gShadow(const Color(0xffeef0f3), 1, 0)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: gText(13, w: FontWeight.w600, c: _ink))),
            Text(sub, style: gText(11, c: _muted)),
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.ch});
  final Map<String, dynamic> ch;
  @override
  Widget build(BuildContext context) {
    final d = (ch['d'] as List).map((e) => e as List).toList();
    final money = ch['money'] == 1;
    String f(num v) {
      if (money) return shA8(v);
      final r = jsRound(v * 10) / 10;
      return r == r.truncate() ? '${r.toInt()}' : '$r';
    }
    final mx = d.fold<num>(0, (s, x) => (x[1] as num) > s ? x[1] as num : s);
    final scale = mx == 0 ? 1 : mx;
    if (ch['t'] == 'hb') {
      return _Card(
        title: '${ch['title'] ?? ''}', sub: '',
        child: Column(children: [
          for (final x in d)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('${x[0]}', style: gText(12, c: _ink))),
                  Text(f(x[1] as num), style: gText(12, w: FontWeight.w600, c: _ink)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LayoutBuilder(builder: (context, c) => Stack(children: [
                    Container(height: 8, width: c.maxWidth, color: const Color(0xfff1f2f5)),
                    Container(
                      height: 8, width: c.maxWidth * ((x[1] as num) / scale).clamp(.02, 1).toDouble(),
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xffff8a65), gBrand])),
                    ),
                  ])),
                ),
              ]),
            ),
        ]),
      );
    }
    var pk = 0;
    for (var i = 0; i < d.length; i++) {
      if ((d[i][1] as num) > (d[pk][1] as num)) pk = i;
    }
    final every = (d.length / 12).ceil();
    return _Card(
      title: '${ch['title'] ?? ''}', sub: 'tertinggi ${f(d[pk][1] as num)}',
      child: SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < d.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                SizedBox(
                  height: 16,
                  child: i == pk && (d[i][1] as num) != 0
                      ? OverflowBox(maxWidth: 80, child: Text(f(d[i][1] as num), maxLines: 1, style: gText(9, w: FontWeight.w600, c: gBrand)))
                      : null,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: ((d[i][1] as num) / scale * 90).clamp(2, 90).toDouble(),
                  decoration: BoxDecoration(
                    color: (d[i][1] as num) == 0 ? const Color(0xffeef0f3) : (i == pk ? gBrand : const Color(0xffff9b84)),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: i % every == 0 ? OverflowBox(maxWidth: 48, child: Text('${d[i][0]}', maxLines: 1, style: gText(9, c: const Color(0xff9aa0ac)))) : null,
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.cols, required this.rows, required this.raw, this.scroll = false});
  final List<String> cols;
  final List<List<dynamic>> rows;
  final bool raw, scroll;

  Widget _cell(Object? v, int i, int n) {
    final (main, small) = parseRepCell(v, raw: raw);
    final right = i == n - 1 && n > 1;
    InlineSpan span(RepSeg s) => s.tag != null
        ? WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _tagBg(s.tag!), borderRadius: BorderRadius.circular(6)),
              child: Text(s.text, style: gText(10, c: _tagFg(s.tag!))),
            ))
        : TextSpan(text: s.text, style: s.bold ? const TextStyle(fontWeight: FontWeight.w700) : null);
    return Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [for (final s in main) span(s)]), textAlign: right ? TextAlign.right : TextAlign.left, style: gText(12, c: _ink, h: 16)),
      if (small.isNotEmpty)
        Text.rich(TextSpan(children: [for (final s in small) span(s)]), textAlign: right ? TextAlign.right : TextAlign.left, style: gText(10.5, c: _muted, h: 15)),
    ]);
  }

  static Color _tagBg(String t) => switch (t) {
        'g' => const Color(0xffeaf7e4), 'r' => const Color(0xfffff0f1), 'y' => const Color(0xfffff6df), 'b' => const Color(0xffeaf2fd), _ => const Color(0xfff1f2f5),
      };
  static Color _tagFg(String t) => switch (t) {
        'g' => const Color(0xff3e8a2e), 'r' => const Color(0xffc62f3b), 'y' => const Color(0xffa06a00), 'b' => const Color(0xff2b6aa6), _ => const Color(0xff5b5f6e),
      };

  @override
  Widget build(BuildContext context) {
    final n = cols.length;
    Widget row(List<Widget> cells, {bool head = false}) => Container(
          padding: EdgeInsets.symmetric(vertical: head ? 0 : 9).copyWith(bottom: head ? 8 : 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xfff5f6f8)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cells.length; i++)
              scroll ? SizedBox(width: 96, child: cells[i]) : Expanded(flex: i == n - 1 && n > 1 ? 3 : 4, child: cells[i]),
          ]),
        );
    final table = Column(children: [
      row([
        for (var i = 0; i < n; i++)
          Align(alignment: (i == n - 1 && n > 1 && !scroll) ? Alignment.centerRight : Alignment.centerLeft, child: Text(cols[i], style: gText(11, c: _muted))),
      ], head: true),
      for (final r in rows) row([for (var i = 0; i < n; i++) i < r.length ? _cell(r[i], i, scroll ? 0 : n) : const SizedBox()]),
    ]);
    return scroll ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 96.0 * n, child: table)) : table;
  }
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.label, required this.onTap, this.green = false});
  final String label;
  final VoidCallback onTap;
  final bool green;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: green ? const Color(0xff25d366) : Colors.white, borderRadius: BorderRadius.circular(12),
            border: green ? null : Border.all(color: const Color(0xffe6e8ec)),
          ),
          child: Text(label, style: gText(13, w: FontWeight.w600, c: green ? Colors.white : _ink)),
        ),
      );
}
