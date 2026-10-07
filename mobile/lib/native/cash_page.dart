import 'package:flutter/material.dart';

import 'common.dart';

// Kas Masuk (#cashin) & Pengeluaran (#cashout). Formulir native: setiap isian ditulis ke input HTML yang sama,
// tombol simpan menjalankan logika HTML (validasi, saldo, catatan kas).

String _s(Object? v) => v is String ? v.trim() : (v == null ? '' : '$v');

class CashModel {
  const CashModel({this.title = '', this.heading = '', this.stats = const [], this.typeIndex = 0, this.types = const [],
      this.amount = '', this.amountHint = 'Jumlah', this.note = '', this.noteHint = 'Keterangan', this.submit = '', this.subtract = false, this.cats = const []});
  factory CashModel.fromJson(Map<String, dynamic> j) {
    final type = j['type'] is Map ? Map<String, dynamic>.from(j['type'] as Map) : const <String, dynamic>{};
    final amount = j['amount'] is Map ? Map<String, dynamic>.from(j['amount'] as Map) : const <String, dynamic>{};
    final note = j['note'] is Map ? Map<String, dynamic>.from(j['note'] as Map) : const <String, dynamic>{};
    return CashModel(
      title: _s(j['title']), heading: _s(j['heading']),
      stats: (j['stats'] is List ? j['stats'] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      typeIndex: (type['index'] as num?)?.toInt() ?? 0, types: (type['options'] as List?)?.map(_s).toList() ?? const [],
      amount: _s(amount['v']), amountHint: _s(amount['ph']), note: _s(note['v']), noteHint: _s(note['ph']),
      submit: _s(j['submit']), subtract: j['subtract'] == true,
      cats: (j['cats'] as List?)?.map(_s).toList() ?? const [],
    );
  }
  final String title, heading, amount, amountHint, note, noteHint, submit;
  final List<Map<String, dynamic>> stats;
  final int typeIndex;
  final List<String> types;
  final bool subtract;
  /// Kategori cepat (hanya Mode Murni): diketuk = mengisi Keterangan.
  final List<String> cats;
}

abstract class CashActions {
  void scan();
  void nav(String pageId);
  void caBack();
  void caType(String option);
  void caAmount(String text);
  void caNote(String text);
  void caSubmit();
}

const _ink = Color(0xff1e1e1e);

class NativeCash extends StatefulWidget {
  const NativeCash({super.key, required this.model, required this.actions, this.topInset});
  final CashModel model;
  final CashActions actions;
  final double? topInset;
  @override
  State<NativeCash> createState() => _NativeCashState();
}

class _NativeCashState extends State<NativeCash> {
  late final _amount = TextEditingController(text: widget.model.amount);
  late final _note = TextEditingController(text: widget.model.note);
  final _amountFocus = FocusNode(), _noteFocus = FocusNode();

  @override
  void didUpdateWidget(NativeCash old) {
    super.didUpdateWidget(old);
    // The HTML clears the fields after saving; follow it when the user is not typing.
    if (!_amountFocus.hasFocus && _amount.text != widget.model.amount) _amount.text = widget.model.amount;
    if (!_noteFocus.hasFocus && _note.text != widget.model.note) _note.text = widget.model.note;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Widget _field({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text('›', style: gText(18, w: FontWeight.w600, c: const Color(0xffc4a447))),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 52, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffd8dbe4))),
              child: child,
            ),
          ),
        ]),
      );

  InputDecoration _dec(String hint) => InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: hint, hintStyle: gText(13.5, c: const Color(0xffb0b4bf)));

  @override
  Widget build(BuildContext context) {
    final m = widget.model, a = widget.actions;
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    final types = m.types;
    return Material(
      color: const Color(0xfff6f7f9),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: a.scan)),
          Container(
            height: 55, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              GestureDetector(
                onTap: a.caBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                    child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(m.title.toUpperCase(), style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7))),
            ]),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              children: [
                Row(children: [
                  Text(m.heading, style: gText(14, w: FontWeight.w500, c: _ink)),
                  const SizedBox(width: 10),
                  const Expanded(child: Divider(color: Color(0xffe6e8ec), height: 1)),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffeceef4))),
                  child: Column(children: [
                    for (final st in m.stats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(width: 30, height: 30, alignment: Alignment.center,
                              decoration: BoxDecoration(color: st['kind'] == 'noncash' ? const Color(0xffeaf2fd) : const Color(0xffffeef0), borderRadius: BorderRadius.circular(9)),
                              child: Text(_s(st['icon']), style: gText(14, c: st['kind'] == 'noncash' ? const Color(0xff2b6aa6) : gBrand))),
                          const SizedBox(width: 11),
                          Expanded(child: Text(_s(st['t']), style: gText(13, c: const Color(0xff6b7280)))),
                          Text(_s(st['v']), style: gText(14, w: FontWeight.w500, c: _ink)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xffeceef4))),
                  child: Column(children: [
                    _field(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: m.typeIndex.clamp(0, types.isEmpty ? 0 : types.length - 1),
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xff8a8f9c)),
                          style: gText(13.5, c: _ink),
                          items: [
                            for (var i = 0; i < types.length; i++)
                              DropdownMenuItem(value: i, child: Text(types[i], style: gText(13.5, c: i == 0 ? const Color(0xff8a8f9c) : _ink))),
                          ],
                          onChanged: types.isEmpty ? null : (i) { if (i != null) a.caType(types[i]); },
                        ),
                      ),
                    ),
                    _field(
                      child: Row(children: [
                        Text('Rp', style: gText(15, w: FontWeight.w500, c: const Color(0xff4c4d56))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _amount, focusNode: _amountFocus, keyboardType: TextInputType.number, cursorColor: gBrand,
                            style: gText(14, c: _ink), decoration: _dec(m.amountHint), onChanged: a.caAmount)),
                      ]),
                    ),
                    _field(child: TextField(controller: _note, focusNode: _noteFocus, cursorColor: gBrand, textCapitalization: TextCapitalization.sentences,
                        style: gText(14, c: _ink), decoration: _dec(m.noteHint), onChanged: a.caNote)),
                    if (m.cats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Kategori', style: gText(12, c: const Color(0xff8a8f9c))),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final c in m.cats)
                                GestureDetector(
                                  onTap: () {
                                    _note.text = c;
                                    a.caNote(c);
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _note.text == c ? const Color(0xfffff0ee) : const Color(0xfff7f9fc), borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: _note.text == c ? gBrand : const Color(0xffe1e5ea)),
                                    ),
                                    child: Text(c, style: gText(12, w: FontWeight.w500, c: _note.text == c ? gBrand : _ink)),
                                  ),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () { FocusScope.of(context).unfocus(); a.caSubmit(); },
                  child: Container(
                    height: 52, alignment: Alignment.center,
                    decoration: BoxDecoration(color: gBrand, borderRadius: BorderRadius.circular(10)),
                    child: Text(m.submit.toUpperCase(), style: gText(14, w: FontWeight.w600, c: Colors.white, ls: .3)),
                  ),
                ),
              ],
            ),
          ),
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 2, onTap: a.nav)),
      ]),
    );
  }
}
