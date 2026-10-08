import 'dart:async';

import 'package:flutter/material.dart';

import 'addorder_sheet.dart';
import 'common.dart';

// Tambah Transaksi (HTML #addorder, flow f61). Langkah 1 (pilih pelanggan) dan 2 (layanan) native;
// durasi, jumlah, opsi, pembayaran & QRIS tetap sheet HTML (logika harga/DP tidak diubah).

String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class AoField {
  const AoField({this.value = '', this.placeholder = ''});
  factory AoField.fromJson(Object? j) => j is Map ? AoField(value: _s(j['v']), placeholder: _s(j['ph'])) : const AoField();
  final String value, placeholder;
}

class AoPerson {
  const AoPerson({required this.index, required this.name, this.avatar = '', this.lines = const [], this.button = 'Pilih'});
  factory AoPerson.fromJson(Map<String, dynamic> j) => AoPerson(
        index: (j['i'] as num?)?.toInt() ?? 0, name: _s(j['name']).trim(), avatar: _s(j['avatar']),
        lines: (j['lines'] as List?)?.map(_s).toList() ?? const [], button: _s(j['btn']).isEmpty ? 'Pilih' : _s(j['btn']));
  final int index;
  final String name, avatar, button;
  final List<String> lines;
}

class AoTab {
  const AoTab({required this.title, this.sub = '', this.on = false, this.svg = ''});
  final String title, sub, svg;
  final bool on;
}

class AoItem {
  const AoItem({this.header = false, this.index = 0, this.svg = '', this.title = '', this.sub = '', this.button = '', this.on = false});
  factory AoItem.fromJson(Map<String, dynamic> j) => AoItem(
        header: j['h'] == 1 || j['h'] == true, index: (j['i'] as num?)?.toInt() ?? 0, svg: _s(j['svg']),
        title: _s(j['t']), sub: _s(j['s']), button: _s(j['btn']), on: j['on'] == true);
  final bool header, on;
  final int index;
  final String svg, title, sub, button;
}

class AoFooter {
  const AoFooter({this.name = '', this.sum = '', this.label = '', this.total = '', this.button = ''});
  final String name, sum, label, total, button;
}

class AddOrderModel {
  const AddOrderModel({
    this.title = '', this.step = '', this.stage = 'customer', this.search = const AoField(), this.add = '',
    this.people = const [], this.empty = '', this.customerName = '', this.customerSub = '', this.customerAvatar = '',
    this.durations = const [], this.cats = const [], this.items = const [], this.footer, this.sheet,
  });

  factory AddOrderModel.fromJson(Map<String, dynamic> j) {
    final c = j['customer'] is Map ? Map<String, dynamic>.from(j['customer'] as Map) : const <String, dynamic>{};
    final f = j['footer'] is Map ? Map<String, dynamic>.from(j['footer'] as Map) : null;
    return AddOrderModel(
      title: _s(j['title']), step: _s(j['step']), stage: _s(j['stage']), search: AoField.fromJson(j['search']), add: _s(j['add']),
      people: _list(j['people']).map(AoPerson.fromJson).toList(), empty: _s(j['empty']),
      customerName: _s(c['name']).trim(), customerSub: _s(c['sub']).trim(), customerAvatar: _s(c['avatar']),
      durations: _list(j['durations']).map((d) => AoTab(title: _s(d['t']), sub: _s(d['s']), on: d['on'] == true)).toList(),
      cats: _list(j['cats']).map((d) => AoTab(title: _s(d['t']), on: d['on'] == true, svg: _s(d['svg']))).toList(),
      items: _list(j['items']).map(AoItem.fromJson).toList(),
      sheet: j['sheet'] is Map ? Map<String, dynamic>.from(j['sheet'] as Map) : null,
      footer: f == null ? null : AoFooter(name: _s(f['name']).trim(), sum: _s(f['sum']), label: _s(f['label']), total: _s(f['total']), button: _s(f['btn']).trim()),
    );
  }

  final String title, step, stage, add, empty, customerName, customerSub, customerAvatar;
  final AoField search;
  final List<AoPerson> people;
  final List<AoTab> durations, cats;
  final List<AoItem> items;
  final AoFooter? footer;
  /// Sheet drawn natively over the page: {kind: 'options'|'payment', ...} from addorderSheet() in capacitor.js.
  final Map<String, dynamic>? sheet;
}

abstract class AddOrderActions {
  void scan();
  void aoBack();
  void aoSearchCustomer(String text);
  void aoAddCustomer();
  void aoPickCustomer(int index);
  void aoDuration(int index);
  void aoSearchService(String text);
  void aoCategory(int index);
  void aoService(int index);
  void aoNext();
  void aoSheetSelect(int field, int option);
  void aoSheetSwitch(int field);
  void aoSheetNote(String text);
  void aoSheetMain();
  void aoSheetClose();
  void aoPay(int index);
  void aoPayCancel();
}

const _muted = Color(0xff8a8fa3);
const _ink = Color(0xff1e1e1e);

class NativeAddOrder extends StatefulWidget {
  const NativeAddOrder({super.key, required this.model, required this.actions, this.topInset});
  final AddOrderModel model;
  final AddOrderActions actions;
  final double? topInset;
  @override
  State<NativeAddOrder> createState() => _NativeAddOrderState();
}

class _NativeAddOrderState extends State<NativeAddOrder> {
  late final TextEditingController _search = TextEditingController(text: widget.model.search.value);
  final _focus = FocusNode();
  Timer? _debounce;
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(NativeAddOrder old) {
    super.didUpdateWidget(old);
    if (old.model.stage != widget.model.stage) {
      _debounce?.cancel();
      _focus.unfocus();
      _search.text = widget.model.search.value;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (!_focus.hasFocus && _search.text != widget.model.search.value) {
      _search.text = widget.model.search.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    final stage = widget.model.stage;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (stage == 'services') {
        widget.actions.aoSearchService(v);
      } else {
        widget.actions.aoSearchCustomer(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final services = m.stage == 'services';
    final search = _SearchBox(controller: _search, focus: _focus, placeholder: m.search.placeholder, onChanged: _onSearch);
    final rows = <Widget>[];
    if (services) {
      rows
        ..add(_CustomerBar(name: m.customerName, sub: m.customerSub, avatar: m.customerAvatar))
        ..add(const SizedBox(height: 9))
        ..add(_Durations(tabs: m.durations, onTap: a.aoDuration))
        ..add(const SizedBox(height: 10))
        ..add(search)
        ..add(const SizedBox(height: 14))
        ..add(_Cats(cats: m.cats, onTap: a.aoCategory));
      for (final it in m.items) {
        rows.add(it.header ? _CatHeader(item: it) : _ServiceRow(item: it, onTap: () => a.aoService(it.index)));
      }
      if (m.empty.isNotEmpty) rows.add(_Empty(m.empty));
    } else {
      rows
        ..add(search)
        ..add(const SizedBox(height: 8));
      if (m.add.isNotEmpty) rows.add(_BigButton(label: '＋  ${m.add}', onTap: a.aoAddCustomer, radius: 13));
      for (final p in m.people) {
        rows.add(_PersonRow(person: p, onTap: () => a.aoPickCustomer(p.index)));
      }
      if (m.people.isEmpty) rows.add(_Empty(m.empty.isNotEmpty ? m.empty : 'Belum ada pelanggan'));
    }
    final page = Material(
      color: Colors.white,
      child: Column(children: [
        RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
        _SubHead(title: m.title, step: m.step, onBack: a.aoBack),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 14, 16, services ? 24 : 40),
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i],
          ),
        ),
        if (services && m.footer != null) _Footer(footer: m.footer!, onNext: a.aoNext),
      ]),
    );
    final sheet = m.sheet;
    if (sheet == null) return page;
    return Stack(children: [
      Positioned.fill(child: page),
      Positioned.fill(child: AoSheet(sheet: sheet, actions: a)),
    ]);
  }
}

class _SubHead extends StatelessWidget {
  const _SubHead({required this.title, required this.step, required this.onBack});
  final String title, step;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 32, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
              child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7, h: 18.85)),
              if (step.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(step, style: gText(11.5, c: _muted, h: 16.1)),
              ],
            ]),
          ),
        ]),
      );
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.focus, required this.placeholder, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 47,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xffe0e4e9))),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xff8f98a4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller, focusNode: focus, onChanged: onChanged,
              textInputAction: TextInputAction.search, cursorColor: gBrand,
              style: gText(13.5, c: _ink),
              decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: placeholder,
                  hintStyle: gText(13.5, c: const Color(0xffb4b8c4))),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () { controller.clear(); onChanged(''); },
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: Color(0xff929ba7))),
                  ),
          ),
        ]),
      );
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap, this.radius = 11});
  final String label;
  final VoidCallback onTap;
  final double radius;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 45, alignment: Alignment.center,
          decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(radius)),
          child: Text(label, style: gText(13.5, w: FontWeight.w500, c: Colors.white)),
        ),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.svg, this.name);
  final String svg, name;
  @override
  Widget build(BuildContext context) => Container(
        width: 56, height: 56, padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffedf0f4)), boxShadow: [gShadow(const Color(0x0f142038), 6, 16)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: svg.isEmpty ? const Icon(Icons.person_rounded, color: Color(0xff5c97f8), size: 30) : gAvatar(svg, name, 54),
        ),
      );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});
  final AoPerson person;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xfff0f2f5)))),
          child: Row(children: [
            _Avatar(person.avatar, person.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(15, w: FontWeight.w500, c: _ink, h: 21)),
                for (final l in person.lines) ...[
                  const SizedBox(height: 3),
                  Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11.5, c: const Color(0xff8f98a4), h: 16.1)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              height: 38, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(11)),
              child: Text(person.button, style: gText(12.5, w: FontWeight.w500, c: Colors.white)),
            ),
          ]),
        ),
      );
}

class _CustomerBar extends StatelessWidget {
  const _CustomerBar({required this.name, required this.sub, required this.avatar});
  final String name, sub, avatar;
  // The HTML bar uses 10px/8px text; Flutter shows it readable (fix approved by the owner).
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xfff7f8fa), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _Avatar(avatar, name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14, w: FontWeight.w500, c: _ink, h: 19.6)),
              if (sub.isNotEmpty) Text(sub, style: gText(11.5, c: const Color(0xff929ba7), h: 16)),
            ]),
          ),
        ]),
      );
}

class _Durations extends StatelessWidget {
  const _Durations({required this.tabs, required this.onTap});
  final List<AoTab> tabs;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xffeef0f4), borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 48,
                  decoration: BoxDecoration(
                    color: tabs[i].on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10),
                    boxShadow: tabs[i].on ? [gShadow(const Color(0x14172235), 2, 8)] : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(tabs[i].title, style: gText(12.5, w: FontWeight.w500, c: tabs[i].on ? gBrand : const Color(0xff6b7485), h: 17.5)),
                    Text(tabs[i].sub, style: gText(10, c: tabs[i].on ? gBrand : const Color(0xff6b7485), h: 14)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

class _Cats extends StatelessWidget {
  const _Cats({required this.cats, required this.onTap});
  final List<AoTab> cats;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (context, i) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final c = cats[i];
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.on ? _ink : Colors.white, borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.on ? _ink : const Color(0xffe1e5ea)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (c.svg.isNotEmpty) ...[gSvg(c.svg, 18), const SizedBox(width: 5)],
                  Text(c.title, style: gText(12, w: FontWeight.w500, c: c.on ? Colors.white : const Color(0xff5b5f6e))),
                ]),
              ),
            );
          },
        ),
      );
}

class _CatHeader extends StatelessWidget {
  const _CatHeader({required this.item});
  final AoItem item;
  @override
  Widget build(BuildContext context) {
    final parts = item.sub.split(RegExp(r'\s*›+\s*')).where((p) => p.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 6),
      child: Row(children: [
        SizedBox(width: 42, height: 42, child: Center(child: item.svg.isEmpty ? null : gSvg(item.svg, 26))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: gText(13, w: FontWeight.w500, c: _ink, h: 18.2)),
            if (parts.isNotEmpty)
              Text.rich(TextSpan(children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0) TextSpan(text: '  ›››  ', style: gText(9, c: const Color(0xffc3c9d2))),
                  TextSpan(text: parts[i]),
                ],
              ]), style: gText(10.5, c: _muted, h: 14.7)),
          ]),
        ),
      ]),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.item, required this.onTap});
  final AoItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: item.on ? const Color(0xfffffafa) : Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffe6e9ee)),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xfff6f7f9), borderRadius: BorderRadius.circular(12)),
              child: item.svg.isEmpty ? null : gSvg(item.svg, 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(13, w: FontWeight.w500, c: _ink, h: 18.2)),
                const SizedBox(height: 1),
                Text(item.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: gText(11, c: _muted, h: 15.4)),
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 64),
              height: 33, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.on ? Colors.white : gBrand, borderRadius: BorderRadius.circular(10),
                border: item.on ? Border.all(color: gBrand) : null,
              ),
              child: Text(item.button.isEmpty ? 'Pilih' : item.button, style: gText(12, c: item.on ? gBrand : Colors.white)),
            ),
          ]),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.footer, required this.onNext});
  final AoFooter footer;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [gShadow(const Color(0x0f172235), -6, 20)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(footer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(12.5, w: FontWeight.w500, c: _ink, h: 17.5)),
                Text(footer.sum, style: gText(10.5, c: const Color(0xff9099a5), h: 14.7)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(footer.label, style: gText(10.5, c: const Color(0xff929ba7), h: 14.7)),
              Text(footer.total, style: gText(17, w: FontWeight.w500, c: _ink, h: 23.8)),
            ]),
          ]),
          const SizedBox(height: 7),
          _BigButton(label: footer.button.isEmpty ? 'LANJUT ›' : footer.button, onTap: onNext),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        child: Text(text, textAlign: TextAlign.center, style: gText(13, c: const Color(0xff8f98a4))),
      );
}
