import 'package:flutter/material.dart';

import 'common.dart';

typedef PerfumeButtonAction = void Function(int index);

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

class _PerfumeItemData {
  const _PerfumeItemData({
    required this.name,
    required this.bottleSvg,
    required this.iconBackground,
    required this.swatch,
    required this.editButton,
    required this.deleteButton,
    required this.editSvg,
    required this.deleteSvg,
    required this.editBackground,
    required this.deleteBackground,
    required this.nameColor,
  });

  final String name;
  final String bottleSvg;
  final String iconBackground;
  final String swatch;
  final int? editButton;
  final int? deleteButton;
  final String editSvg;
  final String deleteSvg;
  final String editBackground;
  final String deleteBackground;
  final String nameColor;
}

class _PerfumePageData {
  const _PerfumePageData({
    required this.title,
    required this.titleUpper,
    required this.backLabel,
    required this.backButton,
    required this.addLabel,
    required this.addUpper,
    required this.addButton,
    required this.note,
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
    required this.noteColor,
    required this.items,
  });

  final String title;
  final bool titleUpper;
  final String backLabel;
  final int? backButton;
  final String addLabel;
  final bool addUpper;
  final int? addButton;
  final String note;
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
  final String noteColor;
  final List<_PerfumeItemData> items;

  factory _PerfumePageData.fromMirror(Map<String, dynamic> model) {
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
    Map<String, dynamic> noteNode = <String, dynamic>{};

    for (final node in contentParts) {
      final text = _text(node);
      if (addNode.isEmpty && text.contains('Tambah Parfum') && _buttonIndex(node) != null) {
        addNode = node;
        continue;
      }
      if (cardNode.isEmpty) {
        final rows = _children(node['ch']);
        if (rows.any((row) => row['row'] == true && _children(row['ch']).length >= 4)) {
          cardNode = node;
          continue;
        }
      }
      if (text.isNotEmpty && node['spans'] is List) noteNode = node;
    }

    final items = <_PerfumeItemData>[];
    for (final row in _children(cardNode['ch'])) {
      if (row['row'] != true) continue;
      final parts = _children(row['ch']);
      if (parts.length < 4) continue;
      final name = _text(parts[1]);
      if (name.isEmpty) continue;

      final actionNodes = _children(parts[3]['ch'])
          .where((node) => _buttonIndex(node) != null)
          .toList();
      final edit = actionNodes.isNotEmpty ? actionNodes[0] : <String, dynamic>{};
      final remove = actionNodes.length > 1 ? actionNodes[1] : <String, dynamic>{};

      items.add(_PerfumeItemData(
        name: name,
        bottleSvg: _firstSvg(parts[0]),
        iconBackground: _styleString(parts[0], 'bg', 'rgba(232, 73, 63, 0.12)'),
        swatch: _styleString(parts[2], 'bg', 'rgb(232, 73, 63)'),
        editButton: _buttonIndex(edit),
        deleteButton: _buttonIndex(remove),
        editSvg: _firstSvg(edit),
        deleteSvg: _firstSvg(remove),
        editBackground: _styleString(edit, 'bg', 'rgb(232, 73, 63)'),
        deleteBackground: _styleString(remove, 'bg', 'rgb(236, 238, 241)'),
        nameColor: _styleString(parts[1], 'c', 'rgb(30, 30, 30)'),
      ));
    }

    return _PerfumePageData(
      title: _text(titleNode).isEmpty ? 'Parfum' : _text(titleNode),
      titleUpper: _upper(titleNode),
      backLabel: _text(back).isEmpty ? '‹' : _text(back),
      backButton: _buttonIndex(back),
      addLabel: _text(addNode).isEmpty ? '+ Tambah Parfum' : _text(addNode),
      addUpper: _upper(addNode),
      addButton: _buttonIndex(addNode),
      note: _text(noteNode),
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
      noteColor: _styleString(noteNode, 'c', 'rgb(138, 143, 163)'),
      items: items,
    );
  }
}

/// Halaman Parfum Flutter asli. Bentuknya sengaja mengikuti halaman cermin lama
/// satu per satu; model HTML hanya dipakai sebagai data nama, warna, SVG botol,
/// teks, dan indeks aksi yang diteruskan kembali ke elemen HTML yang sama.
class NativePerfumePage extends StatelessWidget {
  const NativePerfumePage({
    super.key,
    required this.model,
    required this.onButton,
    required this.onNav,
    required this.onHeaderScan,
    this.topInset,
  });

  final Map<String, dynamic> model;
  final PerfumeButtonAction onButton;
  final ValueChanged<String> onNav;
  final VoidCallback onHeaderScan;
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final data = _PerfumePageData.fromMirror(model);
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
                        _PerfumeCard(data: data, onButton: onButton),
                        if (data.note.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              data.note,
                              style: gText(
                                11.5,
                                c: cssColor(data.noteColor, const Color(0xff8a8fa3)),
                                h: 17.25,
                              ),
                            ),
                          ),
                        ],
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

  final _PerfumePageData data;
  final PerfumeButtonAction onButton;

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
              key: const Key('perfume-back'),
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

  final _PerfumePageData data;
  final PerfumeButtonAction onButton;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('perfume-add'),
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

class _PerfumeCard extends StatelessWidget {
  const _PerfumeCard({required this.data, required this.onButton});

  final _PerfumePageData data;
  final PerfumeButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
              _PerfumeRow(
                index: i,
                item: data.items[i],
                first: i == 0,
                onButton: onButton,
              ),
          ],
        ),
      );
}

class _PerfumeRow extends StatelessWidget {
  const _PerfumeRow({
    required this.index,
    required this.item,
    required this.first,
    required this.onButton,
  });

  final int index;
  final _PerfumeItemData item;
  final bool first;
  final PerfumeButtonAction onButton;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: first
            ? null
            : const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xfff0f2f5)),
                ),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cssColor(item.iconBackground, const Color(0x1fe8493f)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.bottleSvg.isEmpty
                  ? const SizedBox.shrink()
                  : gSvg(item.bottleSvg, 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: gText(
                  14,
                  w: FontWeight.w500,
                  c: cssColor(item.nameColor, const Color(0xff1e1e1e)),
                  h: 19.6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cssColor(item.swatch, gBrand),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 114,
              height: 40,
              child: Row(
                children: [
                  _IconButton(
                    key: Key('perfume-edit-$index'),
                    index: item.editButton,
                    background: item.editBackground,
                    svg: item.editSvg,
                    onButton: onButton,
                  ),
                  const SizedBox(width: 10),
                  _IconButton(
                    key: Key('perfume-delete-$index'),
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
  final PerfumeButtonAction onButton;

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
