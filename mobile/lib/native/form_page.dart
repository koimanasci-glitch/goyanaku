import 'dart:convert';

import 'package:flutter/material.dart';

import 'common.dart';

// Formulir generik native untuk halaman pengaturan sederhana (mis. Printer & Nota).
// Isi diambil berurutan dari DOM (formModel di capacitor.js); setiap isian/tombol ditulis ke elemen HTML yang sama.

String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class FormModel {
  const FormModel({this.page = '', this.title = '', this.items = const []});
  factory FormModel.fromJson(String page, Map<String, dynamic> j) => FormModel(page: page, title: _s(j['title']).trim(), items: _list(j['items']));
  final String page, title;
  final List<Map<String, dynamic>> items;
}

abstract class FormActions {
  void scan();
  void nav(String pageId);
  void fmBack();
  void fmInput(int index, Object value);
  void fmToggle(int index);
  void fmRadio(int index);
  void fmButton(int index);
  void fmFile(String inputId);
}

const _ink = Color(0xff1e1e1e);

class NativeForm extends StatelessWidget {
  const NativeForm({super.key, required this.model, required this.actions, this.navActive = 3, this.topInset});
  final FormModel model;
  final FormActions actions;
  final int navActive;
  final double? topInset;

  @override
  Widget build(BuildContext context) {
    final top = topInset ?? MediaQuery.paddingOf(context).top;
    final a = actions;
    return Material(
      color: Colors.white,
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          Container(
            height: 55, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
            child: Row(children: [
              GestureDetector(
                onTap: a.fmBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                    child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(model.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              itemCount: model.items.length,
              itemBuilder: (context, i) => _item(model.items[i]),
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: navActive, onTap: a.nav)),
      ]),
    );
  }

  Widget _item(Map<String, dynamic> it) {
    final a = actions;
    switch (it['type']) {
      case 'card':
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => a.fmButton(_i(it['i'])),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffe8ecf2))),
              child: Row(children: [
                Container(width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                    child: _s(it['svg']).isNotEmpty
                        ? gSvg(_s(it['svg']), 26)
                        : (_s(it['ic']).isNotEmpty ? Text(_s(it['ic']), style: gText(19, c: gBrand)) : const Icon(Icons.print_rounded, color: gBrand))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_s(it['t']), style: gText(14, w: FontWeight.w500, c: _ink)),
                    Text(_s(it['s']), style: gText(11.5, c: const Color(0xff8a8fa3))),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xffa0a4ac)),
              ]),
            ),
          ),
        );
      case 'title':
        return Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(_s(it['t']), style: gText(15, w: FontWeight.w600, c: _ink)));
      case 'label':
        return Padding(padding: const EdgeInsets.only(top: 6, bottom: 6), child: Text(_s(it['t']), style: gText(12.5, w: FontWeight.w500, c: const Color(0xff4c5260))));
      case 'hint':
        return Padding(padding: const EdgeInsets.only(top: 2, bottom: 10), child: Text(_s(it['t']), style: gText(11.5, c: const Color(0xff9aa0ac), h: 16.5)));
      case 'input':
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: _FormInput(key: ValueKey('in${it['i']}'), item: it, onChanged: (v) => a.fmInput(_i(it['i']), v)));
      case 'select':
        final options = (it['options'] as List?)?.map(_s).toList() ?? const <String>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 46, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true, value: options.isEmpty ? null : _i(it['index']).clamp(0, options.length - 1), style: gText(13.5, c: _ink),
                items: [for (var k = 0; k < options.length; k++) DropdownMenuItem(value: k, child: Text(options[k], style: gText(13.5, c: _ink)))],
                onChanged: (k) { if (k != null) a.fmInput(_i(it['i']), k); },
              ),
            ),
          ),
        );
      case 'row':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (_s(it['svg']).isNotEmpty) ...[
              Container(width: 40, height: 40, alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xfff6f7f9), borderRadius: BorderRadius.circular(12)), child: gSvg(_s(it['svg']), 28)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s(it['t']), style: gText(13.5, c: _ink)),
                if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: const Color(0xff8a8fa3))),
              ]),
            ),
            GestureDetector(
              onTap: () => a.fmButton(_i(it['i'])),
              child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffe1e5ea))),
                  child: Text(_s(it['btn']), style: gText(12, w: FontWeight.w500, c: _ink))),
            ),
          ]),
        );
      case 'toggle':
        final on = it['on'] == true;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => a.fmToggle(_i(it['i'])),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(it['t']), style: gText(13.5, c: _ink)),
                  if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: const Color(0xff8a8fa3))),
                ]),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42, height: 24, padding: const EdgeInsets.all(2),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(color: on ? gBrand : const Color(0xffe4e6ea), borderRadius: BorderRadius.circular(99)),
                child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ]),
          ),
        );
      case 'choice':
        final options = _list(it['options']);
        if (options.any((o) => _s(o['s']).isNotEmpty)) {
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_s(it['t']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_s(it['t']), style: gText(13.5, w: FontWeight.w500, c: _ink))),
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => a.fmRadio(_i(o['i'])),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: o['on'] == true ? const Color(0xfffff6f5) : Colors.white, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffe1e5ea))),
                      child: Row(children: [
                        Icon(o['on'] == true ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: o['on'] == true ? gBrand : const Color(0xffb0b4bf)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_s(o['t']), style: gText(13.5, w: FontWeight.w500, c: _ink)),
                            if (_s(o['s']).isNotEmpty) Text(_s(o['s']), style: gText(11, c: const Color(0xff8a8fa3))),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(it['t']), style: gText(13.5, w: FontWeight.w500, c: _ink)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in options)
                GestureDetector(
                  onTap: () => a.fmRadio(_i(o['i'])),
                  child: Container(
                    height: 38, padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: o['on'] == true ? const Color(0xfffff0ee) : Colors.white, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffe1e5ea))),
                    // widthFactor 1: the chip hugs its label instead of filling the row.
                    child: Center(widthFactor: 1, child: Text(_s(o['t']), style: gText(13, w: FontWeight.w500, c: o['on'] == true ? gBrand : _ink))),
                  ),
                ),
            ]),
          ]),
        );
      case 'entry':
        final btns = _list(it['btns']);
        final badge = _s(it['badge']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffe8ecf2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                if (_s(it['svg']).isNotEmpty || _s(it['avatar']).isNotEmpty) ...[
                  Container(width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xfffff0f2), borderRadius: BorderRadius.circular(12)),
                      child: _s(it['svg']).isNotEmpty ? gSvg(_s(it['svg']), 26) : Text(_s(it['avatar']), style: gText(16, w: FontWeight.w700, c: gBrand))),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_s(it['t']), style: gText(14, w: FontWeight.w600, c: _ink)),
                    for (final l in (it['lines'] as List? ?? const [])) Text(_s(l), style: gText(11.5, c: const Color(0xff8a8fa3))),
                  ]),
                ),
                if (badge.isNotEmpty)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xffe8f7ee), borderRadius: BorderRadius.circular(8)),
                      child: Text(badge, style: gText(11, w: FontWeight.w500, c: const Color(0xff1f8a55)))),
              ]),
              if (btns.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  for (var k = 0; k < btns.length; k++) ...[
                    if (k > 0) const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => a.fmButton(_i(btns[k]['i'])),
                        child: Container(height: 36, alignment: Alignment.center,
                            decoration: BoxDecoration(color: k == btns.length - 1 ? gBrand : Colors.white, borderRadius: BorderRadius.circular(10),
                                border: k == btns.length - 1 ? null : Border.all(color: const Color(0xffe1e5ea))),
                            child: Text(_s(btns[k]['t']), style: gText(12.5, w: FontWeight.w500, c: k == btns.length - 1 ? Colors.white : _ink))),
                      ),
                    ),
                  ],
                ]),
              ],
            ]),
          ),
        );
      case 'image':
        final src = _s(it['src']);
        Widget? pic;
        final comma = src.indexOf(',');
        if (src.startsWith('data:image') && comma > 0) {
          try {
            pic = Image.memory(base64Decode(src.substring(comma + 1)), fit: BoxFit.contain, gaplessPlayback: true);
          } catch (_) {}
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Container(
              width: pic != null ? 200 : null, height: pic != null ? 200 : null,
              constraints: const BoxConstraints(minWidth: 84, minHeight: 84),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: pic != null ? Colors.white : const Color(0xfffff0f2), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xffffd7db))),
              child: pic ?? Column(mainAxisSize: MainAxisSize.min, children: [
                if (_s(it['svg']).isNotEmpty) gSvg(_s(it['svg']), 34)
                else if (_s(it['mark']).isNotEmpty) Text(_s(it['mark']), style: gText(26, w: FontWeight.w700, c: gBrand)),
                if (_s(it['t']).isNotEmpty) Text(_s(it['t']), style: gText(13, w: FontWeight.w600, c: _ink)),
                if (_s(it['s']).isNotEmpty) Text(_s(it['s']), textAlign: TextAlign.center, style: gText(11, c: const Color(0xff8a8fa3))),
              ]),
            ),
          ),
        );
      case 'buttons':
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _list(it['options']))
              GestureDetector(
                onTap: () { FocusManager.instance.primaryFocus?.unfocus(); _s(o['file']).isNotEmpty ? a.fmFile(_s(o['file'])) : a.fmButton(_i(o['i'])); },
                child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffe1e5ea))),
                    child: Center(widthFactor: 1, child: Text(_s(o['t']), style: gText(12.5, w: FontWeight.w500, c: _ink)))),
              ),
          ]),
        );
      case 'button':
        final primary = it['primary'] == true;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () { FocusManager.instance.primaryFocus?.unfocus(); _s(it['file']).isNotEmpty ? a.fmFile(_s(it['file'])) : a.fmButton(_i(it['i'])); },
            child: Container(height: 50, alignment: Alignment.center,
                decoration: BoxDecoration(color: primary ? gBrand : Colors.white, borderRadius: BorderRadius.circular(12),
                    border: primary ? null : Border.all(color: const Color(0xffe1e5ea))),
                child: Text(_s(it['t']), style: gText(14, w: FontWeight.w600, c: primary ? Colors.white : _ink, ls: .3))),
          ),
        );
    }
    return const SizedBox.shrink();
  }
}

class _FormInput extends StatefulWidget {
  const _FormInput({super.key, required this.item, required this.onChanged});
  final Map<String, dynamic> item;
  final ValueChanged<String> onChanged;
  @override
  State<_FormInput> createState() => _FormInputState();
}

class _FormInputState extends State<_FormInput> {
  late final _c = TextEditingController(text: _s(widget.item['v']));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_FormInput old) {
    super.didUpdateWidget(old);
    final v = _s(widget.item['v']);
    if (!_focus.hasFocus && _c.text != v) _c.text = v;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item, multi = it['multiline'] == true, ro = it['ro'] == true;
    final label = _s(it['label']), pre = _s(it['pre']), suf = _s(it['suf']);
    if (label.isEmpty && pre.isEmpty && suf.isEmpty) return _field(it, multi, ro);
    return Row(children: [
      if (label.isNotEmpty) Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(right: 10), child: Text(label, style: gText(13, c: _ink)))),
      Expanded(
        flex: 5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: ro ? const Color(0xfff6f7f9) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
          child: Row(children: [
            if (pre.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: Text(pre, style: gText(13, w: FontWeight.w500, c: const Color(0xff6b7280)))),
            Expanded(child: _text(it, false, ro)),
            if (suf.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text(suf, style: gText(13, w: FontWeight.w500, c: const Color(0xff6b7280)))),
          ]),
        ),
      ),
    ]);
  }

  Widget _field(Map<String, dynamic> it, bool multi, bool ro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: ro ? const Color(0xfff6f7f9) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
      child: _text(it, multi, ro),
    );
  }

  Widget _text(Map<String, dynamic> it, bool multi, bool ro) {
    return TextField(
        controller: _c, focusNode: _focus, readOnly: ro, onChanged: widget.onChanged, cursorColor: gBrand,
        obscureText: it['secret'] == true, enableSuggestions: it['secret'] != true, autocorrect: it['secret'] != true,
        minLines: multi ? 2 : 1, maxLines: multi ? 5 : 1,
        keyboardType: it['numeric'] == true ? TextInputType.number : (it['email'] == true ? TextInputType.emailAddress : (multi ? TextInputType.multiline : TextInputType.text)),
        style: gText(13.5, c: ro ? const Color(0xff8a8fa3) : _ink, h: 19),
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _s(it['ph']), hintStyle: gText(13.5, c: const Color(0xffb0b4bf))),
      );
  }
}
