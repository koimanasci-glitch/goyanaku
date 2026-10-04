import 'package:flutter/material.dart';

import 'common.dart';

typedef DurationButtonAction = void Function(int index);

Map<String, dynamic> _m(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _children(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const <Map<String, dynamic>>[];

String _text(Map<String, dynamic> node) {
  final spans = node['spans'];
  if (spans is List) {
    return spans
        .whereType<Map>()
        .map((e) => '${e['t'] ?? ''}')
        .join()
        .trim();
  }
  final out = StringBuffer();
  for (final child in _children(node['ch'])) {
    final value = _text(child);
    if (value.isEmpty) continue;
    if (out.isNotEmpty) out.write(' ');
    out.write(value);
  }
  return out.toString().trim();
}

int? _buttonIndex(Map<String, dynamic> node) {
  final raw = node['b'];
  if (raw is num) return raw.toInt();
  for (final child in _children(node['ch'])) {
    final value = _buttonIndex(child);
    if (value != null) return value;
  }
  return null;
}

String _firstSvg(Map<String, dynamic> node) {
  final raw = node['svg'];
  if (raw is String && raw.isNotEmpty) return raw;
  for (final child in _children(node['ch'])) {
    final value = _firstSvg(child);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _styleString(Map<String, dynamic> node, String key, String fallback) {
  final value = _m(node['s'])[key];
  return value is String && value.isNotEmpty ? value : fallback;
}

bool _upper(Map<String, dynamic> node) => _m(node['s'])['up'] == 1;

class _DurationItemData {
  const _DurationItemData({
    required this.name,
    required this.hours,
    required this.nameColor,
    required this.hoursColor,
    required this.separatorColor,
    required this.borderColor,
    required this.editButton,
    required this.deleteButton,
    required this.editSvg,
    required this.deleteSvg,
    required this.editBackground,
    required this.deleteBackground,
  });

  final String name;
  final String hours;
  final String nameColor;
  final String hoursColor;
  final String separatorColor;
  final String borderColor;
  final int? editButton;
  final int? deleteButton;
  final String editSvg;
  final String deleteSvg;
  final String editBackground;
  final String deleteBackground;
}

class _DurationPageData {
  const _DurationPageData({
    required this.title,
    required this.titleUpper,
    required this.backLabel,
    required this.backButton,
    required this.addLabel,
    required this.addUpper,
    required this.addButton,
    required this.nav,
    required this.pageBackground,
    required this.contentBackground,
    required this.subheadBackground,
    required this.subheadBorder,
    required this.backBackground,
    required this.backColor,
    required this.titleColor,
    required this.addBackground,
    required this.addColor,
    required this.items,
  });

  final String title;
  final bool titleUpper;
  final String backLabel;
  final int? backButton;
  final String addLabel;
  final bool addUpper;
  final int? addButton;
  final int nav;
  final String pageBackground;
  final String contentBackground;
  final String subheadBackground;
  final String subheadBorder;
  final String backBackground;
  final String backColor;
  final String titleColor;
  final String addBackground;
  final String addColor;
  final List<_DurationItemData> items;

  factory _DurationPageData.fromMirror(Map<String, dynamic> model) {
    final body = _m(model['body']);
    final root = _children(body['ch']);
    final subhead = root.isNotEmpty ? root.first : <String, dynamic>{};
    final content = root.length > 1 ? root[1] : <String, dynamic>{};
    final headParts = _children(subhead['ch']);
    final contentParts = _children(content['ch']);
    final back = headParts.isNotEmpty ? headParts.first : <String, dynamic>{};
    final titleNode = headParts.length > 1 ? headParts[1] : <String, dynamic>{};

    Map<String, dynamic> addNode = <String, dynamic>{};
    final rows = <Map<String, dynamic>>[];
    for (final node in contentParts) {
      final text = _text(node);
      if (addNode.isEmpty &&
          text.contains('Tambah Durasi') &&
          _buttonIndex(node) != null) {
        addNode = node;
      } else if (node['row'] == true) {
        rows.add(node);
      }
    }

    final items = <_DurationItemData>[];
    for (final row in rows) {
      final parts = _children(row['ch']);
      if (parts.length < 2) continue;
      final info = _children(parts[0]['ch']);
      if (info.length < 3) continue;
      final name = _text(info[0]);
      final hours = _text(info[2]);
      if (name.isEmpty || hours.isEmpty) continue;

      final actions = _children(parts[1]['ch'])
          .where((node) => _buttonIndex(node) != null)
          .toList();
      final edit = actions.isNotEmpty ? actions[0] : <String, dynamic>{};
      final remove = actions.length > 1 ? actions[1] : <String, dynamic>{};

      items.add(_DurationItemData(
        name: name,
        hours: hours,
        nameColor: _styleString(info[0], 'c', 'rgb(30, 30, 30)'),
        hoursColor: _styleString(info[2], 'c', 'rgb(107, 116, 133)'),
        separatorColor: _styleString(info[1], 'bg', 'rgb(217, 222, 229)'),
        borderColor: _styleString(row, 'bc', 'rgb(237, 240, 243)'),
        editButton: _buttonIndex(edit),
        deleteButton: _buttonIndex(remove),
        editSvg: _firstSvg(edit),
        deleteSvg: _firstSvg(remove),
        editBackground: _styleString(edit, 'bg', 'rgb(232, 73, 63)'),
        deleteBackground: _styleString(remove, 'bg', 'rgb(236, 238, 241)'),
      ));
    }

    final pageBackground = _styleString(body, 'bg', 'rgb(255, 255, 255)');
    return _DurationPageData(
      title: _text(titleNode).isEmpty ? 'Durasi' : _text(titleNode),
      titleUpper: _upper(titleNode),
      backLabel: _text(back).isEmpty ? '‹' : _text(back),
      backButton: _buttonIndex(back),
      addLabel: _text(addNode).isEmpty ? '+ Tambah Durasi' : _text(addNode),
      addUpper: _upper(addNode),
      addButton: _buttonIndex(addNode),
      nav: (model['nav'] as num?)?.toInt() ?? 3,
      pageBackground: pageBackground,
      contentBackground: _styleString(content, 'bg', pageBackground),
      subheadBackground: _styleString(subhead, 'bg', 'rgb(255, 255, 255)'),
      subheadBorder: _styleString(subhead, 'bc', 'rgb(241, 242, 245)'),
      backBackground: _styleString(back, 'bg', 'rgb(243, 244, 247)'),
      backColor: _styleString(back, 'c', 'rgb(30, 30, 30)'),
      titleColor: _styleString(titleNode, 'c', 'rgb(30, 30, 30)'),
      addBackground: _styleString(addNode, 'bg', 'rgb(232, 73, 63)'),
      addColor: _styleString(addNode, 'c', 'rgb(255, 255, 255)'),
      items: items,
    );
  }
}

/// Halaman Durasi Flutter asli. Data teks, SVG, warna, dan indeks aksi tetap
/// berasal dari model cermin lama; yang dipindahkan hanya render tampilannya.
class NativeDurationPage extends StatelessWidget {
  const NativeDurationPage({
    super.key,
    required this.model,
    required this.onButton,
    required this.onNav,
    required this.onHeaderScan,
    this.topInset,
  });

  final Map<String, dynamic> model;
  final DurationButtonAction onButton;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final data = _DurationPageData.fromMirror(model);
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: cssColor(data.pageBackground, Colors.white),
      child: Column(
        children: [
          GTopBar(top: top, onScan: onHeaderScan),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Subhead(data: data, onButton: onButton),
                  Container(
                    color: cssColor(data.contentBackground, Colors.white),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _AddButton(data: data, onButton: onButton),
                        const SizedBox(height: 10),
                        for (var i = 0; i < data.items.length; i++)
                          _DurationRow(
                            index: i,
                            item: data.items[i],
                            onButton: onButton,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          GBottomNav(
            onTap: onNav,
            active: data.nav > 3 ? -1 : data.nav,
          ),
        ],
      ),
    );
  }
}

class _Subhead extends StatelessWidget {
  const _Subhead({required this.data, required this.onButton});

  final _DurationPageData data;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cssColor(data.subheadBackground, Colors.white),
          border: Border(
            bottom: BorderSide(
              color: cssColor(data.subheadBorder, const Color(0xfff1f2f5)),
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              key: const Key('duration-back'),
              behavior: HitTestBehavior.opaque,
              onTap: data.backButton == null ? null : () => onButton(data.backButton!),
              child: Container(
                width: 38,
                height: 32,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: cssColor(data.backBackground, const Color(0xfff3f4f7)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  data.backLabel,
                  style: gText(
                    20,
                    w: FontWeight.w500,
                    c: cssColor(data.backColor, const Color(0xff1e1e1e)),
                    h: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              data.titleUpper ? data.title.toUpperCase() : data.title,
              style: gText(
                14.5,
                w: FontWeight.w600,
                c: cssColor(data.titleColor, const Color(0xff1e1e1e)),
                h: 18.85,
                ls: .7,
              ),
            ),
          ],
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.data, required this.onButton});

  final _DurationPageData data;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('duration-add'),
        behavior: HitTestBehavior.opaque,
        onTap: data.addButton == null ? null : () => onButton(data.addButton!),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cssColor(data.addBackground, gBrand),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            data.addUpper ? data.addLabel.toUpperCase() : data.addLabel,
            textAlign: TextAlign.center,
            style: gText(
              12,
              w: FontWeight.w500,
              c: cssColor(data.addColor, Colors.white),
              h: 16.8,
              ls: .3,
            ),
          ),
        ),
      );
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.index,
    required this.item,
    required this.onButton,
  });

  final int index;
  final _DurationItemData item;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        height: 69,
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cssColor(item.borderColor, const Color(0xffedf0f3)),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: gText(
                      14.5,
                      w: FontWeight.w500,
                      c: cssColor(item.nameColor, const Color(0xff1e1e1e)),
                      h: 20.3,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: cssColor(item.separatorColor, const Color(0xffd9dee5)),
                ),
                _HoursText(item: item),
              ],
            ),
            SizedBox(
              width: 114,
              height: 40,
              child: Row(
                children: [
                  _IconButton(
                    key: Key('duration-edit-$index'),
                    buttonIndex: item.editButton,
                    background: item.editBackground,
                    svg: item.editSvg,
                    onButton: onButton,
                  ),
                  const SizedBox(width: 10),
                  _IconButton(
                    key: Key('duration-delete-$index'),
                    buttonIndex: item.deleteButton,
                    background: item.deleteBackground,
                    svg: item.deleteSvg,
                    onButton: onButton,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HoursText extends StatelessWidget {
  const _HoursText({required this.item});

  final _DurationItemData item;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(.*?)(\s+jam)$', caseSensitive: false).firstMatch(item.hours);
    final color = cssColor(item.hoursColor, const Color(0xff6b7485));
    if (match == null) {
      return Text(
        item.hours,
        style: gText(14, w: FontWeight.w500, c: color, h: 16.8),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: match.group(1),
            style: gText(14, w: FontWeight.w500, c: color, h: 16.8),
          ),
          TextSpan(
            text: match.group(2),
            style: gText(14, w: FontWeight.w400, c: color, h: 16.8),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    super.key,
    required this.buttonIndex,
    required this.background,
    required this.svg,
    required this.onButton,
  });

  final int? buttonIndex;
  final String background;
  final String svg;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: buttonIndex == null ? null : () => onButton(buttonIndex!),
        child: Container(
          width: 52,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cssColor(background, const Color(0xffeceef1)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: svg.isEmpty ? const SizedBox.shrink() : gSvg(svg, 22),
        ),
      );
}
