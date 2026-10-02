import 'dart:async';

import 'package:flutter/material.dart';

import 'common.dart';

// Layanan (HTML #services, sv99): daftar layanan, alur proses, harga & saklar per durasi.
// Saklar dan pencarian memakai logika HTML; Edit / + Kategori membuka sheet HTML.

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class ServicesModel {
  const ServicesModel({this.title = 'Layanan', this.search = '', this.placeholder = '', this.add = '', this.cats = const [], this.empty = '', this.note = ''});
  factory ServicesModel.fromJson(Map<String, dynamic> j) {
    final search = j['search'] is Map ? Map<String, dynamic>.from(j['search'] as Map) : const <String, dynamic>{};
    return ServicesModel(title: _s(j['title']), search: _s(search['v']), placeholder: _s(search['ph']), add: _s(j['add']),
        cats: _list(j['cats']), empty: _s(j['empty']), note: _s(j['note']));
  }
  final String title, search, placeholder, add, empty, note;
  final List<Map<String, dynamic>> cats;
}

abstract class ServicesActions {
  void scan();
  void nav(String pageId);
  void svBack();
  void svSearch(String text);
  void svAdd();
  void svEdit(int index);
  void svToggle(int index, int variant);
}

const _ink = Color(0xff1e1e1e);

class NativeServices extends StatefulWidget {
  const NativeServices({super.key, required this.model, required this.actions, this.topInset});
  final ServicesModel model;
  final ServicesActions actions;
  final double? topInset;
  @override
  State<NativeServices> createState() => _NativeServicesState();
}

class _NativeServicesState extends State<NativeServices> {
  late final _search = TextEditingController(text: widget.model.search);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(NativeServices old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _search.text != widget.model.search) _search.text = widget.model.search;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final rows = <Widget>[
      Row(children: [
        Expanded(
          child: Container(
            height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe3e6ea))),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18, color: Color(0xff8f98a4)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search, focusNode: _focus, cursorColor: gBrand, style: gText(13, c: _ink), textInputAction: TextInputAction.search,
                  onChanged: (v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 180), () => a.svSearch(v)); },
                  decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: m.placeholder, hintStyle: gText(13, c: const Color(0xffb4b8c4))),
                ),
              ),
            ]),
          ),
        ),
        if (m.add.isNotEmpty) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: a.svAdd,
            child: Container(height: 44, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
                decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(12)),
                child: Text(m.add, style: gText(13, w: FontWeight.w500, c: Colors.white))),
          ),
        ],
      ]),
      for (final c in m.cats) Padding(padding: const EdgeInsets.only(top: 12), child: _Card(cat: c, actions: a)),
      if (m.cats.isEmpty && m.empty.isNotEmpty) Padding(padding: const EdgeInsets.all(28), child: Text(m.empty, textAlign: TextAlign.center, style: gText(13, c: const Color(0xff8a8fa3)))),
      if (m.note.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 0), child: Text(m.note, style: gText(11.5, c: const Color(0xff9aa0ac), h: 17))),
    ];
    return Material(
      color: const Color(0xfff4f5f7),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          Container(
            height: 55, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              GestureDetector(
                onTap: a.svBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                    child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Text(m.title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 3, onTap: a.nav)),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.cat, required this.actions});
  final Map<String, dynamic> cat;
  final ServicesActions actions;
  @override
  Widget build(BuildContext context) {
    final i = (cat['i'] as num?)?.toInt() ?? 0;
    final chain = _list(cat['chain']), vars = _list(cat['vars']);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffeceef2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xfff6f7f9), borderRadius: BorderRadius.circular(12)),
              child: _s(cat['svg']).isEmpty ? null : gSvg(_s(cat['svg']), 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_s(cat['t']), style: gText(14.5, w: FontWeight.w500, c: _ink)),
              Text(_s(cat['s']), style: gText(11.5, c: const Color(0xff8a8fa3))),
            ]),
          ),
          if (cat['edit'] == true)
            GestureDetector(
              onTap: () => actions.svEdit(i),
              child: Container(width: 40, height: 36, alignment: Alignment.center,
                  decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white)),
            ),
        ]),
        if (chain.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final st in chain)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: st['on'] == true ? const Color(0xffe8f7ee) : const Color(0xfff1f2f5), borderRadius: BorderRadius.circular(7)),
                child: Text(_s(st['t']), style: gText(11, c: st['on'] == true ? const Color(0xff1f8a55) : const Color(0xffa0a4ac))),
              ),
          ]),
        ],
        const SizedBox(height: 6),
        for (final v in vars)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xfff1f2f5)))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(v['t']), style: gText(13, w: FontWeight.w500, c: v['on'] == true ? _ink : const Color(0xffa0a4ac))),
                  Text(_s(v['s']), style: gText(10.5, c: const Color(0xff9aa0ac))),
                ]),
              ),
              Text(_s(v['price']), style: gText(13, w: FontWeight.w500, c: v['on'] == true ? _ink : const Color(0xffa0a4ac))),
              if (v['toggle'] == true) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => actions.svToggle(i, (v['j'] as num?)?.toInt() ?? 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40, height: 22, padding: const EdgeInsets.all(2),
                    alignment: v['on'] == true ? Alignment.centerRight : Alignment.centerLeft,
                    decoration: BoxDecoration(color: v['on'] == true ? gBrand : const Color(0xffe4e6ea), borderRadius: BorderRadius.circular(99)),
                    child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}
