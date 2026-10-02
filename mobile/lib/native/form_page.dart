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
                    child: _s(it['svg']).isEmpty ? const Icon(Icons.print_rounded, color: gBrand) : gSvg(_s(it['svg']), 26)),
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
            Expanded(child: Text(_s(it['t']), style: gText(13.5, c: _ink))),
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
              Expanded(child: Text(_s(it['t']), style: gText(13.5, c: _ink))),
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
                    height: 38, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                    decoration: BoxDecoration(color: o['on'] == true ? const Color(0xfffff0ee) : Colors.white, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffe1e5ea))),
                    child: Text(_s(o['t']), style: gText(13, w: FontWeight.w500, c: o['on'] == true ? gBrand : _ink)),
                  ),
                ),
            ]),
          ]),
        );
      case 'button':
        final primary = it['primary'] == true;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () { FocusManager.instance.primaryFocus?.unfocus(); a.fmButton(_i(it['i'])); },
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: ro ? const Color(0xfff6f7f9) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
      child: TextField(
        controller: _c, focusNode: _focus, readOnly: ro, onChanged: widget.onChanged, cursorColor: gBrand,
        minLines: multi ? 2 : 1, maxLines: multi ? 5 : 1,
        keyboardType: it['numeric'] == true ? TextInputType.number : (multi ? TextInputType.multiline : TextInputType.text),
        style: gText(13.5, c: ro ? const Color(0xff8a8fa3) : _ink, h: 19),
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _s(it['ph']), hintStyle: gText(13.5, c: const Color(0xffb0b4bf))),
      ),
    );
  }
}
