import 'package:flutter/material.dart';

import 'addorder_page.dart';
import 'common.dart';

// Sheet "Atur Pesanan" (#f61-options) dan "Pembayaran" (#f61-payment) digambar Flutter.
// Setiap pilihan ditulis ke elemen HTML yang sama; popup lanjutan (tunai, QRIS, transfer, DP, deposit) tetap HTML.

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');
List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

const _ink = Color(0xff1e1e1e);

class AoSheet extends StatelessWidget {
  const AoSheet({super.key, required this.sheet, required this.actions});
  final Map<String, dynamic> sheet;
  final AddOrderActions actions;

  @override
  Widget build(BuildContext context) {
    final payment = sheet['kind'] == 'payment';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: const Color(0x80141b26),
      child: Column(children: [
        Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: payment ? null : actions.aoSheetClose)),
        AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(17, 8, 17, 18 + MediaQuery.paddingOf(context).bottom),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xffd9dde2), borderRadius: BorderRadius.circular(9)))),
                const SizedBox(height: 14),
                Text(_s(sheet['title']), textAlign: TextAlign.center, style: gText(17, w: FontWeight.w500, c: _ink, h: 24)),
                const SizedBox(height: 14),
                if (payment) _Payment(sheet: sheet, actions: actions) else _Options(sheet: sheet, actions: actions),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Payment extends StatelessWidget {
  const _Payment({required this.sheet, required this.actions});
  final Map<String, dynamic> sheet;
  final AddOrderActions actions;
  @override
  Widget build(BuildContext context) {
    final methods = _list(sheet['methods']);
    final cancel = _s(sheet['cancel']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff1e1e1e), Color(0xff2c3e5c)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s(sheet['label']), style: gText(11.5, c: const Color(0xffaeb8c7))),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(_s(sheet['total']), style: gText(28, w: FontWeight.w500, c: Colors.white, h: 39))),
          Text(_s(sheet['id']), style: gText(11, c: const Color(0xffc9d1dd))),
        ]),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final m in methods)
            GestureDetector(
              onTap: () => actions.aoPay((m['i'] as num?)?.toInt() ?? 0),
              child: Container(
                width: w, height: _s(m['svg']).isNotEmpty ? 96 : 77, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffeceff3)),
                    boxShadow: _s(m['svg']).isNotEmpty ? [gShadow(const Color(0x0a172235), 2, 8)] : null),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_s(m['svg']).isNotEmpty)
                    Container(width: 38, height: 38, alignment: Alignment.center,
                        decoration: BoxDecoration(color: cssColor(_s(m['bg']), const Color(0xfff2f4f7)), borderRadius: BorderRadius.circular(11)),
                        child: gSvg(_s(m['svg']), 22))
                  else
                    Text(_s(m['icon']), style: gText(20, c: cssColor(_s(m['ic']), gBrand))),
                  const SizedBox(height: 8),
                  Text(_s(m['t']), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: gText(13.5, w: FontWeight.w500, c: _ink)),
                  if (_s(m['s']).isNotEmpty) Text(_s(m['s']), style: gText(10.5, c: const Color(0xff8a8fa3))),
                ]),
              ),
            ),
        ]);
      }),
      if (cancel.isNotEmpty) ...[
        const SizedBox(height: 14),
        GestureDetector(
          onTap: actions.aoPayCancel,
          child: Container(height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(12)),
              child: Text(cancel.toUpperCase(), style: gText(14, w: FontWeight.w600, c: Colors.white, ls: .3))),
        ),
      ],
    ]);
  }
}

class _Options extends StatefulWidget {
  const _Options({required this.sheet, required this.actions});
  final Map<String, dynamic> sheet;
  final AddOrderActions actions;
  @override
  State<_Options> createState() => _OptionsState();
}

class _OptionsState extends State<_Options> {
  late final _note = TextEditingController(text: _noteValue);
  final _focus = FocusNode();
  String get _noteValue => _s((widget.sheet['note'] is Map ? widget.sheet['note'] as Map : const {})['v']);

  @override
  void didUpdateWidget(_Options old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _note.text != _noteValue) _note.text = _noteValue;
  }

  @override
  void dispose() {
    _note.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actions;
    final fields = _list(widget.sheet['fields']);
    final note = widget.sheet['note'] is Map ? Map<String, dynamic>.from(widget.sheet['note'] as Map) : null;
    final main = _s(widget.sheet['main']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: f['type'] == 'switch' ? _switch(f) : _select(f),
        ),
      if (note != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffdfe3e8))),
          child: TextField(
            controller: _note, focusNode: _focus, minLines: 2, maxLines: 4, cursorColor: gBrand, style: gText(13, c: _ink),
            textCapitalization: TextCapitalization.sentences, onChanged: a.aoSheetNote,
            decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: _s(note['ph']), hintStyle: gText(13, c: const Color(0xffb0b4bf), h: 18)),
          ),
        ),
      if (main.isNotEmpty) ...[
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () { _focus.unfocus(); a.aoSheetMain(); },
          child: Container(height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(13), boxShadow: [gShadow(const Color(0x38ef3f4d), 6, 16)]),
              child: Text(main, style: gText(14, w: FontWeight.w600, c: Colors.white))),
        ),
      ],
    ]);
  }

  Widget _select(Map<String, dynamic> f) {
    final options = (f['options'] as List?)?.map(_s).toList() ?? const <String>[];
    final index = ((f['index'] as num?)?.toInt() ?? 0).clamp(0, options.isEmpty ? 0 : options.length - 1);
    final k = (f['k'] as num?)?.toInt() ?? 0;
    return Row(children: [
      Expanded(flex: 4, child: Text(_s(f['label']), style: gText(13, c: const Color(0xff7f8894)))),
      Expanded(
        flex: 6,
        child: Container(
          height: 42, padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffdfe3e8))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true, value: options.isEmpty ? null : index, style: gText(13, c: _ink),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xff8a8f9c)),
              items: [for (var i = 0; i < options.length; i++) DropdownMenuItem(value: i, child: Text(options[i], overflow: TextOverflow.ellipsis, style: gText(13, c: _ink)))],
              onChanged: (i) { if (i != null && i != index) widget.actions.aoSheetSelect(k, i); },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _switch(Map<String, dynamic> f) {
    final on = f['on'] == true, k = (f['k'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.actions.aoSheetSwitch(k),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40, height: 22, padding: const EdgeInsets.all(2),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: on ? gBrand : const Color(0xffe4e6ea), borderRadius: BorderRadius.circular(99)),
          child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(f['label']), style: gText(12.5, c: const Color(0xff222b39))),
            if (_s(f['sub']).isNotEmpty) Text(_s(f['sub']), style: gText(10.5, c: const Color(0xff8a8fa3))),
          ]),
        ),
      ]),
    );
  }
}
