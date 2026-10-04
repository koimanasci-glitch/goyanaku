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
    required this.editButton,
    required this.deleteButton,
    required this.editSvg,
    required this.deleteSvg,
    required this.editBackground,
    required this.deleteBackground,
    required this.nameColor,
    required this.hoursColor,
  });

  final String name;
  final String hours;
  final int? editButton;
  final int? deleteButton;
  final String editSvg;
  final String deleteSvg;
  final String editBackground;
  final String deleteBackground;
  final String nameColor;
  final String hoursColor;
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
    required this.cardBackground,
    required this.cardBorder,
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
  final String cardBackground;
  final String cardBorder;
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
    Map<String, dynamic> cardNode = <String, dynamic>{};

    for (final node in contentParts) {
      final text = _text(node);
      if (addNode.isEmpty && text.contains('Tambah Durasi') && _buttonIndex(node) != null) {
        addNode = node;
        continue;
      }
      if (cardNode.isEmpty) {
        final rows = _children(node['ch']);
        if (rows.any((row) => row['row'] == true && _children(row['ch']).length >= 2)) {
          cardNode = node;
          continue;
        }
      }
    }

    final items = <_DurationItemData>[];
    for (final row in _children(cardNode['ch'])) {
      if (row['row'] != true) continue;
      final parts = _children(row['ch']);
      if (parts.length < 2) continue;

      // parts[0] should contain name and hours info
      // parts[1] should contain actions (edit/delete buttons)
      final infoNode = parts[0];
      final infoParts = _children(infoNode['ch']);

      String name = '';
      String hours = '';

      // Extract name and hours from the info section
      if (infoParts.length >= 2) {
        name = _text(infoParts[0]);
        // Skip separator (parts[1])
        if (infoParts.length >= 3) {
          hours = _text(infoParts[2]);
        }
      }

      if (name.isEmpty) continue;

      final actionNodes = _children(parts[1]['ch'])
          .where((node) => _buttonIndex(node) != null)
          .toList();
      final edit = actionNodes.isNotEmpty ? actionNodes[0] : <String, dynamic>{};
      final remove = actionNodes.length > 1 ? actionNodes[1] : <String, dynamic>{};

      items.add(_DurationItemData(
        name: name,
        hours: hours,
        editButton: _buttonIndex(edit),
        deleteButton: _buttonIndex(remove),
        editSvg: _firstSvg(edit),
        deleteSvg: _firstSvg(remove),
        editBackground: _styleString(edit, 'bg', 'rgb(232, 73, 63)'),
        deleteBackground: _styleString(remove, 'bg', 'rgb(236, 238, 241)'),
        nameColor: _styleString(infoParts.isNotEmpty ? infoParts[0] : <String, dynamic>{}, 'c', 'rgb(30, 30, 30)'),
        hoursColor: _styleString(infoParts.length >= 3 ? infoParts[2] : <String, dynamic>{}, 'c', 'rgb(107, 116, 133)'),
      ));
    }

    return _DurationPageData(
      title: _text(titleNode).isEmpty ? 'Durasi' : _text(titleNode),
      titleUpper: _upper(titleNode),
      backLabel: _text(back).isEmpty ? '‹' : _text(back),
      backButton: _buttonIndex(back),
      addLabel: _text(addNode).isEmpty ? '+ Tambah Durasi' : _text(addNode),
      addUpper: _upper(addNode),
      addButton: _buttonIndex(addNode),
      nav: (model['nav'] as num?)?.toInt() ?? 3,
      pageBackground: _styleString(body, 'bg', 'rgb(255, 255, 255)'),
      contentBackground: _styleString(content, 'bg', 'rgb(246, 247, 249)'),
      subheadBackground: _styleString(subhead, 'bg', 'rgb(255, 255, 255)'),
      subheadBorder: _styleString(subhead, 'bc', 'rgb(241, 242, 245)'),
      backBackground: _styleString(back, 'bg', 'rgb(243, 244, 247)'),
      backColor: _styleString(back, 'c', 'rgb(30, 30, 30)'),
      titleColor: _styleString(titleNode, 'c', 'rgb(30, 30, 30)'),
      addBackground: _styleString(addNode, 'bg', 'rgb(232, 73, 63)'),
      addColor: _styleString(addNode, 'c', 'rgb(255, 255, 255)'),
      cardBackground: _styleString(cardNode, 'bg', 'rgb(255, 255, 255)'),
      cardBorder: _styleString(cardNode, 'bc', 'rgb(241, 242, 245)'),
      items: items,
    );
  }
}

/// Halaman Durasi Flutter asli. Bentuknya sengaja mengikuti halaman cermin lama
/// satu per satu; model HTML hanya dipakai sebagai data nama, jam, SVG tombol,
/// teks, dan indeks aksi yang diteruskan kembali ke elemen HTML yang sama.
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
                    color: cssColor(data.contentBackground, const Color(0xfff6f7f9)),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AddButton(data: data, onButton: onButton),
                        const SizedBox(height: 12),
                        _DurationCard(data: data, onButton: onButton),
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
        color: cssColor(data.subheadBackground, Colors.white),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cssColor(data.subheadBorder, const Color(0xfff1f2f5)),
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: data.backButton == null ? null : () => onButton(data.backButton!),
              child: Container(
                width: 38,
                height: 32,
                alignment: Alignment.center,
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
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.title,
                style: gText(
                  14.5,
                  w: FontWeight.w600,
                  c: cssColor(data.titleColor, const Color(0xff1e1e1e)),
                  h: 18.85,
                  l: 0.7,
                ),
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
        behavior: HitTestBehavior.opaque,
        onTap: data.addButton == null ? null : () => onButton(data.addButton!),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: cssColor(data.addBackground, const Color(0xffe8493f)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            data.addLabel,
            style: gText(
              12,
              w: FontWeight.w500,
              c: cssColor(data.addColor, Colors.white),
              h: 16.8,
              l: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.data, required this.onButton});

  final _DurationPageData data;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: cssColor(data.cardBackground, Colors.white),
          border: Border.all(
            color: cssColor(data.cardBorder, const Color(0xfff1f2f5)),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var i = 0; i < data.items.length; i++)
              _DurationRow(
                index: i,
                item: data.items[i],
                first: i == 0,
                onButton: onButton,
              ),
          ],
        ),
      );
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.index,
    required this.item,
    required this.first,
    required this.onButton,
  });

  final int index;
  final _DurationItemData item;
  final bool first;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 14),
        decoration: first
            ? null
            : const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffedf0f3)),
                ),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: gText(
                      14.5,
                      w: FontWeight.w500,
                      h: 20.3,
                      c: cssColor(item.nameColor, const Color(0xff1e1e1e)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 1,
                    height: 16,
                    child: Container(
                      color: const Color(0xffd9dee5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.hours.replaceAll(' jam', ''),
                          style: gText(
                            14,
                            w: FontWeight.w500,
                            h: 16.8,
                            c: cssColor(item.hoursColor, const Color(0xff6b7485)),
                          ),
                        ),
                        TextSpan(
                          text: ' jam',
                          style: gText(
                            14,
                            w: FontWeight.w400,
                            h: 16.8,
                            c: cssColor(item.hoursColor, const Color(0xff6b7485)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 114,
              height: 40,
              child: Row(
                children: [
                  _IconButton(
                    key: Key('duration-edit-$index'),
                    index: item.editButton,
                    background: item.editBackground,
                    svg: item.editSvg,
                    onButton: onButton,
                  ),
                  const SizedBox(width: 10),
                  _IconButton(
                    key: Key('duration-delete-$index'),
                    index: item.deleteButton,
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

class _IconButton extends StatelessWidget {
  const _IconButton({
    super.key,
    required this.index,
    required this.background,
    required this.svg,
    required this.onButton,
  });

  final int? index;
  final String background;
  final String svg;
  final DurationButtonAction onButton;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: index == null ? null : () => onButton(index!),
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
