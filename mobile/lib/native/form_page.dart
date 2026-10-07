import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'common.dart';
import 'login_screen.dart';

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

/// A simple HTML sheet (e.g. "Tambah Kurir", "Batalkan Pesanan?") drawn by Flutter over any native page.
/// Every field and button acts on the same element inside the HTML sheet.
class NativeSheet extends StatelessWidget {
  const NativeSheet({super.key, required this.id, required this.items, required this.actions, this.full = false, this.screen = false});
  final String id;
  /// Whole screen (login, first-run setup) instead of a bottom sheet.
  final bool screen;
  /// Full-height sheet (order detail).
  final bool full;
  final List<Map<String, dynamic>> items;
  final FormActions actions;

  @override
  Widget build(BuildContext context) {
    final sa = _SheetActions(actions, id);
    final form = NativeForm(model: FormModel(page: id, items: items), actions: sa);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    if (screen && id == 'lg167') {
      final bindings = LoginBindings.from(items);
      if (bindings != null) {
        return NativeLogin(items: items, bindings: bindings, actions: sa);
      }
    }
    if (screen) {
      return Material(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + bottom),
                children: [
                  for (final it in items)
                    if (it['type'] == 'title' && _s(it['t']) == 'GOYANA')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(children: [
                          Container(width: 44, height: 44, alignment: Alignment.center,
                              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(13)),
                              child: Text('G', style: gText(22, w: FontWeight.w700, c: Colors.white))),
                          const SizedBox(width: 12),
                          Text('GOYANA', style: gText(24, w: FontWeight.w700, c: gBrand, ls: 1)),
                        ]),
                      )
                    else if (it['type'] == 'title' && _s(it['t']).toLowerCase() == 'atau')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          const Expanded(child: Divider(color: Color(0xffe6e8ec))),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('atau', style: gText(12, c: const Color(0xff9aa0ac)))),
                          const Expanded(child: Divider(color: Color(0xffe6e8ec))),
                        ]),
                      )
                    else if (it['type'] == 'title' && it.containsKey('s'))
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(_s(it['t']), style: gText(22, w: FontWeight.w700, c: _ink)))
                    // Password fields have their own show/hide eye.
                    else if (!(it['type'] == 'button' && _s(it['t']).toLowerCase().startsWith('tampilkan password')))
                      form._item(context, it),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Popup tanpa kolom isian selalu menempel di bawah (tidak ikut terdorong keyboard).
    final hasInput = items.any((it) => it['type'] == 'input');
    // Popup pilih Pria/Wanita: di tengah layar (permintaan Koko).
    if (id == 'gp128') {
      return Material(
        color: const Color(0x80141b26),
        child: Stack(children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: sa.fmBack)),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(17, 20, 17, 20),
                children: [for (final it in items) form._item(context, it)],
              ),
            ),
          ),
        ]),
      );
    }
    return Material(
      color: const Color(0x80141b26),
      child: Column(children: [
        Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: sa.fmBack)),
        AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.only(bottom: hasInput ? bottom : 0),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * (full ? .94 : .85)),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(17, 8, 17, 18 + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xffd9dde2), borderRadius: BorderRadius.circular(9)))),
                for (final it in items) form._item(context, it),
              ],
            ),
          ),
        ),
      ]),
    );
  }
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
  /// Clickable non-button element (e.g. "Foto Dokumentasi ›"), n-th [onclick] element.
  void fmTap(int index);
  /// Same actions inside another container (a sheet): kind is input/toggle/radio/button/close.
  void fmScoped(String scope, String kind, int index, [Object? value]);
}

/// Routes a sheet's taps to its own element instead of the page.
class _SheetActions implements FormActions {
  _SheetActions(this.base, this.scope);
  final FormActions base;
  final String scope;
  @override
  void scan() => base.scan();
  @override
  void nav(String pageId) => base.nav(pageId);
  @override
  void fmBack() => base.fmScoped(scope, 'close', 0);
  @override
  void fmInput(int index, Object value) => base.fmScoped(scope, 'input', index, value);
  @override
  void fmToggle(int index) => base.fmScoped(scope, 'toggle', index);
  @override
  void fmRadio(int index) => base.fmScoped(scope, 'radio', index);
  @override
  void fmButton(int index) => base.fmScoped(scope, 'button', index);
  @override
  void fmFile(String inputId) => base.fmFile(inputId);
  @override
  void fmTap(int index) => base.fmScoped(scope, 'tap', index);
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) => base.fmScoped(scope, kind, index, value);
}

const _ink = Color(0xff1e1e1e);

List<String> _list2(Object? v) => v is List ? [for (final x in v) '$x'] : const <String>[];

/// A button: plain click, or a native file pick (optionally after running the button's own JS first).
void _press(FormActions a, Map<String, dynamic> b) {
  final file = _s(b['file']);
  if (file.isEmpty) return a.fmButton(_i(b['i']));
  if (b['after'] == true) a.fmButton(_i(b['i']));
  a.fmFile(file);
}

String _dmy(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

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
              itemBuilder: (context, i) => _item(context, model.items[i]),
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: navActive, onTap: a.nav)),
      ]),
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> it) {
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
                        : (_s(it['ic']).isNotEmpty
                            ? Text(_s(it['ic']), style: gText(19, c: gBrand))
                            : Icon(_s(it['t']).contains('rinter') ? Icons.print_rounded : Icons.apps_rounded, color: gBrand))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_s(it['t']), style: gText(14, w: it['on'] == true ? FontWeight.w600 : FontWeight.w500, c: _ink)),
                    Text(_s(it['s']), style: gText(11.5, c: const Color(0xff8a8fa3))),
                    if (_s(it['badge']).isNotEmpty)
                      Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xfffff0eb), borderRadius: BorderRadius.circular(7)),
                          child: Text(_s(it['badge']), style: gText(11, c: const Color(0xffbc493d)))),
                  ]),
                ),
                if (_s(it['meta']).isNotEmpty) Padding(padding: const EdgeInsets.only(left: 8), child: Text(_s(it['meta']), style: gText(10.5, c: const Color(0xff9aa0ac)))),
                if (it['on'] == true) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6), decoration: const BoxDecoration(color: gBrand, shape: BoxShape.circle)),
                const Icon(Icons.chevron_right_rounded, color: Color(0xffa0a4ac)),
              ]),
            ),
          ),
        );
      case 'title':
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(_s(it['t']), style: gText(15, w: FontWeight.w600, c: _ink))),
            if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: const Color(0xff8a8fa3))),
          ]),
        );
      case 'date':
        final v = _s(it['v']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final init = DateTime.tryParse(v) ?? now;
              final d = await showDatePicker(context: context, initialDate: init, firstDate: DateTime(2020), lastDate: DateTime(now.year + 2));
              if (d != null) {
                a.fmInput(_i(it['i']), '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
              }
            },
            child: Container(
              height: 46, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffdfe3e8))),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xff8a8fa3)),
                const SizedBox(width: 10),
                Text(v.isEmpty ? 'Pilih tanggal' : _dmy(v), style: gText(13.5, c: v.isEmpty ? const Color(0xffb0b4bf) : _ink)),
              ]),
            ),
          ),
        );
      case 'bars':
        final bars = _list(it['bars']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final b in bars)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: ((b['tap'] as num?)?.toInt() ?? -1) >= 0 ? () => a.fmTap(_i(b['tap'])) : null,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(_s(b['v']), style: gText(9, c: const Color(0xff6b7280)))),
                      const SizedBox(height: 2),
                      Container(height: 4 + 100 * ((b['h'] as num?)?.toDouble() ?? 0).clamp(0, 1),
                          decoration: BoxDecoration(color: b['on'] == true ? const Color(0xff1e1e1e) : gBrand, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 3),
                      SizedBox(height: 14, child: FittedBox(fit: BoxFit.scaleDown, child: Text(_s(b['t']), style: gText(9, c: const Color(0xff8a8fa3))))),
                    ]),
                  ),
                  ),
                ),
            ]),
          ),
        );
      case 'hbars':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(children: [
            for (final b in _list(it['bars']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(_s(b['t']), style: gText(12.5, c: _ink))),
                    Text(_s(b['v']), style: gText(12.5, w: FontWeight.w600, c: _ink)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: ((b['w'] as num?)?.toDouble() ?? 0).clamp(0, 1), minHeight: 7, color: gBrand, backgroundColor: const Color(0xfff1f2f5)),
                  ),
                ]),
              ),
          ]),
        );
      case 'table':
        final rows = (it['rows'] as List? ?? const []).map((r) => _list(r)).toList();
        final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
        if (cols == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe8ecf2))),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 34),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    for (var r = 0; r < rows.length; r++)
                      TableRow(
                        decoration: BoxDecoration(color: rows[r].any((c) => c['h'] == true) ? const Color(0xfff7f9fc) : (r.isEven ? Colors.white : const Color(0xfffcfcfd))),
                        children: [
                          for (var k = 0; k < cols; k++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: k < rows[r].length
                                  ? Text(_s(rows[r][k]['t']), textAlign: rows[r][k]['n'] == true ? TextAlign.right : TextAlign.left,
                                      style: gText(rows[r][k]['h'] == true ? 11 : 12, w: rows[r][k]['b'] == true ? FontWeight.w600 : FontWeight.w400,
                                          c: rows[r][k]['h'] == true ? const Color(0xff6b7280) : _ink))
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
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
                        Container(
                          width: 20, height: 20, alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffb0b4bf), width: 2)),
                          child: o['on'] == true ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: gBrand, shape: BoxShape.circle)) : null,
                        ),
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
        if (it['compact'] == true) {
          final dot = cssColor(_s(it['color']), Colors.transparent);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffe8ecf2))),
              child: Row(children: [
                if (_s(it['svg']).isNotEmpty) ...[gSvg(_s(it['svg']), 28), const SizedBox(width: 10)]
                else if (_s(it['avatar']).isNotEmpty) ...[Text(_s(it['avatar']), style: gText(18, c: gBrand)), const SizedBox(width: 10)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_s(it['t']), style: gText(14, w: FontWeight.w500, c: _ink)),
                    for (final l in (it['lines'] as List? ?? const [])) Text(_s(l), style: gText(11.5, c: const Color(0xff8a8fa3))),
                  ]),
                ),
                if (_s(it['color']).isNotEmpty) ...[
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                ],
                for (final b in btns)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => a.fmButton(_i(b['i'])),
                      child: Container(constraints: const BoxConstraints(minWidth: 34), height: 34, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.center,
                          decoration: BoxDecoration(color: b['on'] == true ? gBrand : const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(10)),
                          child: Text(_s(b['t']), style: gText(14, w: FontWeight.w500, c: b['on'] == true ? Colors.white : _ink))),
                    ),
                  ),
              ]),
            ),
          );
        }
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
                if (_s(it['amount']).isNotEmpty) Text(_s(it['amount']), style: gText(13.5, w: FontWeight.w600, c: _ink)),
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
                    Builder(builder: (_) {
                      // Segmented choices mark the chosen one; otherwise the last button is the main action.
                      final hl = btns.any((b) => b['on'] == true) ? btns[k]['on'] == true : k == btns.length - 1;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => a.fmButton(_i(btns[k]['i'])),
                          child: Container(height: 36, alignment: Alignment.center,
                              decoration: BoxDecoration(color: hl ? gBrand : Colors.white, borderRadius: BorderRadius.circular(10),
                                  border: hl ? null : Border.all(color: const Color(0xffe1e5ea))),
                              child: Text(_s(btns[k]['t']), style: gText(12.5, w: FontWeight.w500, c: hl ? Colors.white : _ink))),
                        ),
                      );
                    }),
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
              width: pic != null ? ((it['w'] as num?)?.toDouble() ?? 200).clamp(120, 300) : null,
              height: pic != null && it['w'] == null ? 200 : null,
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
      case 'plan':
        final feats = _list(it['features']);
        final on = it['on'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => a.fmButton(_i(it['i'])),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? gBrand : const Color(0xffe8ecf2), width: on ? 1.6 : 1), boxShadow: [gShadow(const Color(0x0a172235), 2, 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(it['t']), style: gText(15, w: FontWeight.w700, c: _ink, ls: .4)),
                      const SizedBox(height: 2),
                      Text(_s(it['s']), style: gText(11.5, c: const Color(0xff6b7280), h: 16)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_s(it['price']), style: gText(16, w: FontWeight.w700, c: gBrand)),
                    if (_s(it['per']).isNotEmpty) Text(_s(it['per']), style: gText(10.5, c: const Color(0xff8a8fa3))),
                    if (_s(it['more']).isNotEmpty)
                      Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xfffff0ee), borderRadius: BorderRadius.circular(8)),
                          child: Text(_s(it['more']), style: gText(11, w: FontWeight.w600, c: gBrand))),
                  ]),
                ]),
                if (feats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xfff1f2f5)),
                  const SizedBox(height: 8),
                  for (final f in feats)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(width: 18, height: 18, alignment: Alignment.center,
                            decoration: BoxDecoration(color: f['on'] == true ? const Color(0xffe8f7ee) : const Color(0xfff1f2f5), shape: BoxShape.circle),
                            child: Icon(f['on'] == true ? Icons.check_rounded : Icons.close_rounded, size: 12, color: f['on'] == true ? const Color(0xff1f8a55) : const Color(0xffa0a4ac))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_s(f['t']), style: gText(12, c: f['on'] == true ? _ink : const Color(0xffa0a4ac)))),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
        );
      case 'hero':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff1e1e1e), Color(0xff2c3e5c)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_s(it['t']), style: gText(11.5, c: const Color(0xffaeb8c7))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_s(it['v']), style: gText(26, w: FontWeight.w500, c: Colors.white, h: 36))),
              if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: const Color(0xffc9d1dd))),
            ]),
          ),
        );
      case 'stats':
        final cells = _list(it['cells']);
        final n = cells.length, cols = n <= 3 ? n : (n % 3 == 0 ? 3 : 2);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LayoutBuilder(builder: (context, box) => Wrap(spacing: 8, runSpacing: 8, children: [
            for (var k = 0; k < cells.length; k++)
              GestureDetector(
                onTap: cells[k]['i'] is num ? () => a.fmButton(_i(cells[k]['i'])) : null,
                child: SizedBox(
                width: (box.maxWidth - 8 * (cols - 1)) / cols,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffe8ecf2))),
                  child: Column(children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(_s(cells[k]['v']), style: gText(18, w: FontWeight.w600,
                        c: cells[k]['tone'] == 'g' ? const Color(0xff1f8a55) : (cells[k]['tone'] == 'r' ? gBrand : _ink)))),
                    Text(_s(cells[k]['t']), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(11, c: const Color(0xff8a8fa3))),
                    if (_s(cells[k]['n']).isNotEmpty) Text(_s(cells[k]['n']), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(10, c: const Color(0xffa0a4ac))),
                  ]),
                ),
              )),
          ])),
        );
      case 'pair':
        final tone = _s(it['tone']), tap = (it['tap'] as num?)?.toInt() ?? -1;
        final vc = tone == 'r' ? gBrand : (tone == 'g' ? const Color(0xff1f8a55) : _ink);
        final row = Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xfff1f2f5)))),
          child: Row(children: [
            Expanded(flex: 5, child: Text(_s(it['t']), style: gText(13, c: const Color(0xff6b7280)))),
            const SizedBox(width: 10),
            if (tone == 'p')
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xfffff0ee), borderRadius: BorderRadius.circular(8)),
                  child: Text(_s(it['v']), style: gText(11.5, w: FontWeight.w600, c: gBrand)))
            else
              Expanded(flex: 6, child: Text(_s(it['v']), textAlign: TextAlign.right, style: gText(13, w: FontWeight.w600, c: tap >= 0 ? const Color(0xff2b6aa6) : vc))),
          ]),
        );
        return tap >= 0 ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => a.fmTap(tap), child: row) : row;
      case 'steps':
        final steps = _list(it['steps']);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            for (var k = 0; k < steps.length; k++) ...[
              if (k > 0) Expanded(child: Container(height: 2, color: steps[k]['on'] == true ? gBrand : const Color(0xffe4e6ea))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 28, height: 28, alignment: Alignment.center,
                    decoration: BoxDecoration(color: steps[k]['on'] == true ? gBrand : const Color(0xfff1f2f5), shape: BoxShape.circle),
                    child: Text(_s(steps[k]['n']), style: gText(12, w: FontWeight.w600, c: steps[k]['on'] == true ? Colors.white : const Color(0xff8a8fa3)))),
                const SizedBox(height: 4),
                Text(_s(steps[k]['t']), style: gText(10.5, c: steps[k]['on'] == true ? _ink : const Color(0xff8a8fa3))),
              ]),
            ],
          ]),
        );
      case 'total':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(color: const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffe8ecf2))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(it['t']), style: gText(11, c: const Color(0xff8a8fa3))),
                  Text(_s(it['v']), style: gText(18, w: FontWeight.w700, c: _ink)),
                  if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: gBrand)),
                ]),
              ),
              GestureDetector(
                onTap: () => a.fmButton(_i(it['i'])),
                child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 22), alignment: Alignment.center,
                    constraints: const BoxConstraints(maxWidth: 170),
                    decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(12)),
                    child: Text(_s(it['btn']), maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(14, w: FontWeight.w600, c: Colors.white))),
              ),
            ]),
          ),
        );
      case 'qr':
        // Kode QR digambar Flutter (QRIS dinamis di mode murni).
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffe8ecf2))),
              child: QrImageView(data: _s(it['data']), size: ((it['size'] as num?)?.toDouble() ?? 220), backgroundColor: Colors.white),
            ),
          ),
        );
      case 'labelprev':
        final lines = (it['lines'] as List? ?? const []).map(_s).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Center(
            child: Container(
              width: 260, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xff1e1e1e), width: 1.4)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var k = 0; k < lines.length; k++)
                  Text(lines[k], style: gText(k == 1 ? 15 : 11, w: k == 1 ? FontWeight.w700 : FontWeight.w500, c: _ink)),
                if (_s(it['svg']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: SizedBox(height: 56, child: gSvg(_s(it['svg']), 236, h: 56))),
              ]),
            ),
          ),
        );
      case 'stepper':
        Widget sb(String t, int i) => GestureDetector(
              onTap: () => a.fmButton(i),
              child: Container(width: 42, height: 42, alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(12)),
                  child: Text(t, style: gText(20, w: FontWeight.w500, c: _ink))),
            );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_s(it['t']).isNotEmpty)
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(it['t']), style: gText(14, w: FontWeight.w600, c: _ink)),
                  if (_s(it['s']).isNotEmpty) Text(_s(it['s']), style: gText(11, c: const Color(0xff8a8fa3))),
                ]),
              ),
            sb(_s(it['mt']), _i(it['minus'])),
            SizedBox(width: 70, child: Text(_s(it['v']), textAlign: TextAlign.center, style: gText(20, w: FontWeight.w600, c: _ink))),
            sb(_s(it['pt']), _i(it['plus'])),
          ]),
        );
      case 'swatches':
        // Pilihan warna label (popup Tambah/Edit Parfum): bulatan berwarna, yang terpilih diberi cincin.
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 12),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (var k = 0; k < _list2(it['colors']).length; k++)
              GestureDetector(
                onTap: () => a.fmInput(_i(it['i']), k),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: cssColor(_list2(it['colors'])[k], Colors.grey), shape: BoxShape.circle,
                    border: Border.all(color: _i(it['sel']) == k ? _ink : Colors.white, width: 2.5),
                    boxShadow: _i(it['sel']) == k ? [gShadow(const Color(0x33000000), 1, 4)] : null,
                  ),
                ),
              ),
          ]),
        );
      case 'buttons':
        // 'cols' (hanya Mode Murni): kisi sama lebar selebar penuh, mis. popup Pria/Wanita & pilih ikon.
        final cols = it['cols'] is int ? it['cols'] as int : 0;
        if (cols > 0) {
          final opts = _list(it['options']);
          final small = cols >= 4;
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: LayoutBuilder(builder: (context, box) {
              final w = ((box.maxWidth - 8 * (cols - 1)) / cols).floorToDouble();
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final o in opts)
                  GestureDetector(
                    onTap: () { FocusManager.instance.primaryFocus?.unfocus(); _press(a, o); },
                    child: Container(
                      width: w, height: _s(o['svg']).isEmpty ? 40 : (small ? 68 : 96), padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: o['on'] == true ? const Color(0xfffff0ee) : const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffe1e5ea))),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (_s(o['svg']).isNotEmpty) Padding(padding: EdgeInsets.only(bottom: small ? 4 : 6), child: gSvg(_s(o['svg']), small ? 28 : 44)),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(_s(o['t']), maxLines: 1, style: gText(small ? 10.5 : 12.5, w: FontWeight.w500, c: o['on'] == true ? gBrand : _ink))),
                      ]),
                    ),
                  ),
              ]);
            }),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _list(it['options']))
              GestureDetector(
                onTap: () { FocusManager.instance.primaryFocus?.unfocus(); _press(a, o); },
                child: Container(height: _s(o['svg']).isNotEmpty ? 92 : 36, padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: BoxConstraints(minWidth: _s(o['svg']).isNotEmpty ? 120 : 0),
                    decoration: BoxDecoration(color: o['on'] == true ? const Color(0xfffff0ee) : const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: o['on'] == true ? gBrand : const Color(0xffe1e5ea))),
                    child: Center(
                      widthFactor: 1,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_s(o['svg']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: gSvg(_s(o['svg']), 44)),
                        Text(_s(o['t']), style: gText(12.5, w: FontWeight.w500, c: o['on'] == true ? gBrand : _ink)),
                      ]),
                    )),
              ),
          ]),
        );
      case 'button':
        final primary = it['primary'] == true;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () { FocusManager.instance.primaryFocus?.unfocus(); _press(a, it); },
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
  bool _show = false;

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
      if (label.isNotEmpty)
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: gText(13, c: _ink)),
              if (_s(it['sub']).isNotEmpty) Text(_s(it['sub']), style: gText(10.5, c: const Color(0xff8a8fa3))),
            ]),
          ),
        ),
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
      child: it['secret'] == true
          ? Row(children: [
              Expanded(child: _text(it, multi, ro)),
              GestureDetector(
                onTap: () => setState(() => _show = !_show),
                child: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: const Color(0xff8a8fa3)),
              ),
            ])
          : _text(it, multi, ro),
    );
  }

  Widget _text(Map<String, dynamic> it, bool multi, bool ro) {
    return TextField(
        controller: _c, focusNode: _focus, readOnly: ro, onChanged: widget.onChanged, cursorColor: gBrand,
        obscureText: it['secret'] == true && !_show, enableSuggestions: it['secret'] != true, autocorrect: it['secret'] != true,
        minLines: multi ? 2 : 1, maxLines: multi ? 5 : 1,
        keyboardType: it['numeric'] == true ? (it['decimal'] == true ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.number) : (it['email'] == true ? TextInputType.emailAddress : (multi ? TextInputType.multiline : TextInputType.text)),
        style: gText(13.5, c: ro ? const Color(0xff8a8fa3) : _ink, h: 19),
        decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _s(it['ph']), hintStyle: gText(13.5, c: const Color(0xffb0b4bf))),
      );
  }
}
