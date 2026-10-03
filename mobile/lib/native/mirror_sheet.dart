import 'dart:convert';

import 'package:flutter/material.dart';

import 'common.dart';

// Popup HTML yang digambar Flutter dari "cermin" HTML: susunan elemen + ukuran/warna/huruf hasil CSS (computed style).
// Logika tetap di HTML: tombol, ketukan dan isian diteruskan ke elemen HTML yang sama (indeks b / tap / input).

typedef MirrorTap = void Function(int index);
typedef MirrorInput = void Function(int index, Object value);

Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
double _d(Object? v) => v is num ? v.toDouble() : 0;
List<double> _q(Object? v) {
  final l = v is List ? v.map(_d).toList() : const <double>[];
  return l.length == 4 ? l : const [0, 0, 0, 0];
}

FontWeight _weight(int w) => w >= 600 ? FontWeight.w600 : (w >= 500 ? FontWeight.w500 : FontWeight.w400);

class NativeMirrorSheet extends StatelessWidget {
  const NativeMirrorSheet({super.key, required this.model, required this.onButton, required this.onTap, required this.onInput, required this.onClose});
  final Map<String, dynamic> model;
  final MirrorTap onButton, onTap;
  final MirrorInput onInput;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final box = _m(model['box']);
    final center = model['kind'] == 'center';
    final s = _m(box['s']);
    final p = _q(s['p']);
    final r = _q(s['br']);
    final body = Container(
      constraints: BoxConstraints(maxHeight: mq.size.height - mq.viewInsets.bottom - (center ? 40 : 20)),
      decoration: BoxDecoration(
        color: cssColor(s['bg'] as String?, Colors.white),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(r[0]), topRight: Radius.circular(r[1]), bottomRight: Radius.circular(r[2]), bottomLeft: Radius.circular(r[3])),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(p[3], p[0], p[1], p[2] + (center ? 0 : mq.padding.bottom)),
        child: _Node.children(this, box, inheritColor: cssColor(s['c'] as String?, const Color(0xff1e1e1e))),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: onClose, child: ColoredBox(color: cssColor(model['scrim'] as String?, const Color(0x80141b26))))),
        Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: center
              ? Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: body)))
              : Align(alignment: Alignment.bottomCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: body)),
        ),
      ]),
    );
  }
}

class _Node {
  /// Isi sebuah elemen (anak-anaknya), tanpa kotak/padding elemen itu sendiri.
  static Widget children(NativeMirrorSheet sheet, Map<String, dynamic> n, {required Color inheritColor}) {
    final s = _m(n['s']);
    final color = cssColor(s['c'] as String?, inheritColor);
    if (n['spans'] is List) return _text(sheet, n, color);
    final ch = _l(n['ch']).where((c) => c['br'] != 1).toList();
    if (ch.isEmpty) return const SizedBox.shrink();
    final gap = _d(n['gap']), rgap = n['rgap'] != null ? _d(n['rgap']) : gap;
    if (n['row'] == true && n['wrap'] == 1) {
      return Wrap(spacing: gap, runSpacing: rgap, children: [for (final c in ch) build(sheet, c, color, inRow: true)]);
    }
    if (n['row'] == true) {
      final jc = '${n['jc'] ?? ''}', ai = '${n['ai'] ?? ''}';
      final kids = <Widget>[];
      for (var i = 0; i < ch.length; i++) {
        if (i > 0 && gap > 0) kids.add(SizedBox(width: gap));
        final c = ch[i];
        final w = build(sheet, c, color, inRow: true);
        if (c['grow'] == 1) {
          kids.add(Expanded(child: w));
        } else if (c['fixed'] == 1 || c['svg'] != null || c['img'] != null || c['s'] != null && _m(c['s'])['nowrap'] == 1) {
          kids.add(w);
        } else {
          kids.add(Flexible(child: w));
        }
      }
      return Row(
        mainAxisAlignment: jc.contains('space-between') ? MainAxisAlignment.spaceBetween : (jc.contains('center') ? MainAxisAlignment.center : (jc.contains('end') ? MainAxisAlignment.end : MainAxisAlignment.start)),
        crossAxisAlignment: ai.contains('center') ? CrossAxisAlignment.center : (ai.contains('end') ? CrossAxisAlignment.end : CrossAxisAlignment.start),
        children: kids,
      );
    }
    final cols = (n['grid'] as num?)?.toInt() ?? 0;
    if (cols > 1) {
      final colw = n['colw'] is List ? (n['colw'] as List).map(_d).toList() : <double>[];
      final rows = <Widget>[];
      for (var i = 0; i < ch.length; i += cols) {
        final line = <Widget>[];
        for (var j = 0; j < cols; j++) {
          if (j > 0) line.add(SizedBox(width: gap));
          final flex = j < colw.length && colw[j] > 0 ? (colw[j] * 10).round() : 10;
          line.add(Expanded(flex: flex, child: i + j < ch.length ? build(sheet, ch[i + j], color, inRow: true) : const SizedBox.shrink()));
        }
        if (rows.isNotEmpty) rows.add(SizedBox(height: rgap));
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: line));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    }
    // Susunan blok: margin atas/bawah antar-saudara digabung seperti CSS (yang terbesar).
    final kids = <Widget>[];
    double prevBottom = 0;
    for (var i = 0; i < ch.length; i++) {
      final c = ch[i];
      final m = _q(_m(c['s'])['m']);
      final space = i == 0 ? m[0] : (m[0] > prevBottom ? m[0] : prevBottom);
      if (space > 0) kids.add(SizedBox(height: space));
      kids.add(build(sheet, c, color));
      prevBottom = m[2];
    }
    if (prevBottom > 0) kids.add(SizedBox(height: prevBottom));
    final col = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: kids);
    return n['center'] == 1 ? Center(child: col) : col;
  }

  static Widget _text(NativeMirrorSheet sheet, Map<String, dynamic> n, Color color) {
    final s = _m(n['s']);
    final fs = _d(s['fs']) == 0 ? 14.0 : _d(s['fs']);
    final lh = _d(s['lh']);
    final up = s['up'] == 1;
    TextStyle style(Map<String, dynamic> x, Color c) => gText(_d(x['fs']) == 0 ? fs : _d(x['fs']),
        w: _weight((x['fw'] as num?)?.toInt() ?? (s['fw'] as num?)?.toInt() ?? 400), c: c, h: lh > 0 ? lh : null, ls: _d(s['ls']));
    final spans = <InlineSpan>[];
    for (final sp in _l(n['spans'])) {
      var t = '${sp['t'] ?? ''}';
      if (up) t = t.toUpperCase();
      final c = cssColor(sp['c'] as String?, color);
      spans.add(TextSpan(text: t, style: style(sp, c).copyWith(backgroundColor: sp['bg'] == null ? null : cssColor(sp['bg'] as String?))));
    }
    final ta = '${s['ta'] ?? ''}';
    return Text.rich(
      TextSpan(children: spans, style: style(s, color)),
      textAlign: ta == 'center' ? TextAlign.center : (ta == 'right' ? TextAlign.right : TextAlign.left),
      softWrap: s['nowrap'] != 1,
    );
  }

  /// Satu elemen: kotak (padding, latar, garis, sudut) + isinya. Margin kiri/kanan dipasang di sini; atas/bawah oleh induk.
  static Widget build(NativeMirrorSheet sheet, Map<String, dynamic> n, Color inherit, {bool inRow = false}) {
    final s = _m(n['s']);
    final color = cssColor(s['c'] as String?, inherit);
    Widget child;
    if (n['svg'] is String) {
      child = gSvg(n['svg'] as String, _d(n['w']), h: _d(n['h']));
    } else if (n['img'] is String) {
      child = _image(n['img'] as String, _d(n['w']), _d(n['h']));
    } else if (n['input'] is Map) {
      child = _MirrorField(key: ValueKey('in-${_m(n['input'])['i']}'), node: n, onInput: sheet.onInput);
    } else {
      child = children(sheet, n, inheritColor: color);
    }
    final p = _q(s['p']), m = _q(s['m']), r = _q(s['br']);
    final bw = _d(s['bw']);
    final fixed = n['fixed'] == 1;
    final deco = BoxDecoration(
      color: s['bg'] == null ? null : cssColor(s['bg'] as String?),
      border: bw > 0 ? Border.all(color: cssColor(s['bc'] as String?, const Color(0xffe6e9ee)), width: bw) : null,
      borderRadius: r.any((x) => x > 0) ? BorderRadius.only(topLeft: Radius.circular(r[0]), topRight: Radius.circular(r[1]), bottomRight: Radius.circular(r[2]), bottomLeft: Radius.circular(r[3])) : null,
    );
    if (n['input'] is! Map) {
      child = Container(
        width: fixed ? _d(n['w']) : null,
        height: fixed ? _d(n['h']) : null,
        alignment: fixed ? Alignment.center : null,
        padding: fixed ? null : EdgeInsets.fromLTRB(p[3], p[0], p[1], p[2]),
        decoration: deco,
        child: child,
      );
    }
    final b = (n['b'] as num?)?.toInt(), tap = (n['tap'] as num?)?.toInt();
    if (b != null && b >= 0) {
      child = GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => sheet.onButton(b), child: child);
    } else if (tap != null && tap >= 0) {
      child = GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => sheet.onTap(tap), child: child);
    }
    // Kotak kecil berukuran tetap dengan margin kiri = kanan (margin auto di CSS): di tengah.
    if (fixed && !inRow) {
      final centered = (m[1] - m[3]).abs() < 2 && m[1] > 0;
      return Align(alignment: centered ? Alignment.center : Alignment.centerLeft, child: child);
    }
    if (m[1] > 0 || m[3] > 0) child = Padding(padding: EdgeInsets.only(left: m[3], right: m[1]), child: child);
    return child;
  }

  static Widget _image(String src, double w, double h) {
    if (src.startsWith('data:')) {
      final i = src.indexOf(',');
      try {
        return Image.memory(base64Decode(src.substring(i + 1)), width: w, height: h, fit: BoxFit.contain, gaplessPlayback: true);
      } catch (_) {
        return SizedBox(width: w, height: h);
      }
    }
    if (src.startsWith('http')) return Image.network(src, width: w, height: h, fit: BoxFit.contain, errorBuilder: (_, _, _) => SizedBox(width: w, height: h));
    return SizedBox(width: w, height: h);
  }
}

class _MirrorField extends StatefulWidget {
  const _MirrorField({super.key, required this.node, required this.onInput});
  final Map<String, dynamic> node;
  final MirrorInput onInput;
  @override
  State<_MirrorField> createState() => _MirrorFieldState();
}

class _MirrorFieldState extends State<_MirrorField> {
  late final Map<String, dynamic> _in = _m(widget.node['input']);
  late final TextEditingController _c = TextEditingController(text: '${_in['v'] ?? ''}');
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _MirrorField old) {
    super.didUpdateWidget(old);
    final v = '${_m(widget.node['input'])['v'] ?? ''}';
    if (!_focus.hasFocus && v != _c.text) _c.text = v;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node, s = _m(n['s']), inp = _m(n['input']);
    final p = _q(s['p']), r = _q(s['br']);
    final fs = _d(s['fs']) == 0 ? 13.0 : _d(s['fs']);
    final i = (inp['i'] as num?)?.toInt() ?? 0;
    final deco = BoxDecoration(
      color: cssColor(s['bg'] as String?, Colors.white),
      border: _d(s['bw']) > 0 ? Border.all(color: cssColor(s['bc'] as String?, const Color(0xffdfe3e9)), width: _d(s['bw'])) : null,
      borderRadius: BorderRadius.circular(r[0]),
    );
    final style = gText(fs, c: cssColor(s['c'] as String?, const Color(0xff1e1e1e)), h: _d(s['lh']) > 0 ? _d(s['lh']) : null);
    final opts = inp['options'];
    if (opts is List) {
      final list = opts.map((e) => '$e').toList();
      final idx = ((inp['index'] as num?)?.toInt() ?? 0).clamp(0, list.isEmpty ? 0 : list.length - 1);
      return Container(
        padding: EdgeInsets.fromLTRB(p[3], 0, p[1], 0),
        decoration: deco,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true, value: list.isEmpty ? null : idx, style: style,
            items: [for (var k = 0; k < list.length; k++) DropdownMenuItem(value: k, child: Text(list[k], style: style))],
            onChanged: (v) { if (v != null) widget.onInput(i, v); },
          ),
        ),
      );
    }
    final multi = inp['multi'] == true;
    return Container(
      padding: EdgeInsets.fromLTRB(p[3], p[0], p[1], p[2]),
      decoration: deco,
      child: TextField(
        controller: _c, focusNode: _focus, readOnly: inp['ro'] == true, obscureText: inp['secret'] == true,
        minLines: multi ? 2 : 1, maxLines: multi ? 5 : 1, style: style, cursorColor: gBrand,
        keyboardType: inp['numeric'] == true ? (inp['decimal'] == true ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number) : (multi ? TextInputType.multiline : TextInputType.text),
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: '${inp['ph'] ?? ''}', hintStyle: style.copyWith(color: const Color(0xffb0b4bf))),
        onChanged: (v) => widget.onInput(i, v),
      ),
    );
  }
}
