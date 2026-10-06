// Popup Tambah Transaksi Mode Murni, ditiru dari tampilan HTML asli:
// jumlah layanan, Pembayaran Tunai, QRIS, DP / Uang Muka dan Saldo Deposit.
// Tombol memakai indeks yang sama dengan lembar lama sehingga logika di pure_shell tidak berubah.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../native/common.dart';
import '../native/form_page.dart';

const _ink = Color(0xff1e1e1e);
const _gray = Color(0xff8a8fa3);
const _line = Color(0xffe6e9ee);
const _pinkLine = Color(0xfff7c9cd);

String _s(Object? v) => v == null ? '' : '$v';

/// Dipakai bila item pertama lembar bertipe 'ao'.
bool isAoPopup(List<Map<String, dynamic>> items) => items.isNotEmpty && items.first['type'] == 'ao';

class AoPopup extends StatefulWidget {
  const AoPopup({super.key, required this.id, required this.data, required this.actions});
  final String id;
  final Map<String, dynamic> data;
  final FormActions actions;
  @override
  State<AoPopup> createState() => _AoPopupState();
}

class _AoPopupState extends State<AoPopup> {
  late final TextEditingController _c = TextEditingController(text: _s(widget.data['v']));

  @override
  void didUpdateWidget(AoPopup old) {
    super.didUpdateWidget(old);
    final v = _s(widget.data['v']);
    if (_c.text != v) _c.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(int i) => widget.actions.fmScoped(widget.id, 'button', i);
  void _typed(String v) => widget.actions.fmScoped(widget.id, 'input', 0, v);

  @override
  Widget build(BuildContext context) {
    final kind = _s(widget.data['kind']);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final body = switch (kind) {
      'qty' => _qty(),
      'cash' => _cash(),
      'dp' => _dp(),
      'qris' => _qris(),
      _ => _deposit(),
    };
    return Material(
      color: const Color(0x80141b26),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.actions.fmScoped(widget.id, 'close', 0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(18, 8, 18, 16 + bottom),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xffd9dde2), borderRadius: BorderRadius.circular(4)))),
                    ...body,
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({String? ph, String? suffix, String? prefix, bool hot = false, Key? key, TextAlign align = TextAlign.left, double size = 18}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: hot ? _pinkLine : _ink, width: 1)),
      child: Row(children: [
        if (prefix != null) Padding(padding: const EdgeInsets.only(right: 6), child: Text(prefix, style: gText(14, c: _gray))),
        Expanded(
          child: TextField(
            key: key,
            controller: _c,
            onChanged: _typed,
            textAlign: align,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: gText(size, c: _ink),
            decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: ph, hintStyle: gText(size, c: const Color(0xffb6bcc8))),
          ),
        ),
        if (suffix != null) Text(suffix, style: gText(14, c: _gray)),
      ]),
    );
  }

  Widget _primary(String t, int i, {Color color = gBrand}) => SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: () => _tap(i),
          style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: Text(t, style: gText(14, w: FontWeight.w500, c: Colors.white)),
        ),
      );

  Widget _outlineRed(String t, int i) => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: () => _tap(i),
          style: OutlinedButton.styleFrom(foregroundColor: gBrand, side: const BorderSide(color: _pinkLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(t, style: gText(14, w: FontWeight.w500, c: gBrand)),
        ),
      );

  Widget _outlineLeft(String t, int i) => SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: () => _tap(i),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: _ink, side: const BorderSide(color: _line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(t, style: gText(14, c: _ink)),
        ),
      );

  Widget _title(String t, {String sub = ''}) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Column(children: [
          Text(t, textAlign: TextAlign.center, style: gText(sub.isEmpty ? 17 : 20, w: FontWeight.w500, c: _ink)),
          if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, textAlign: TextAlign.center, style: gText(12.5, c: _gray))),
        ]),
      );

  List<Widget> _qty() => [
        const SizedBox(height: 4),
        _field(ph: '0,0', suffix: _s(widget.data['unit']), key: const Key('ao-qty')),
        const SizedBox(height: 12),
        _primary('SIMPAN', 1),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: () => _tap(3),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffeceefb), foregroundColor: const Color(0xff5a5fd0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text('BATAL', style: gText(13.5, w: FontWeight.w500, c: const Color(0xff5a5fd0))),
          ),
        ),
        if (widget.data['hasRemove'] == true) TextButton(onPressed: () => _tap(2), child: Text('Hapus layanan ini', style: gText(13, c: gBrand))),
      ];

  List<Widget> _cash() {
    final chips = [for (final c in (widget.data['chips'] as List? ?? const [])) c as Map];
    return [
      _title('Pembayaran Tunai'),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
        child: Column(children: [
          Text('Total Tagihan', style: gText(13, c: _gray)),
          const SizedBox(height: 6),
          Text(_s(widget.data['total']), style: gText(27, w: FontWeight.w500, c: _ink)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        height: 52,
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Row(children: [
          Text('Uang diterima', style: gText(13.5, c: _gray)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: _pinkLine)),
              child: TextField(
                key: const Key('ao-cash'),
                controller: _c,
                onChanged: _typed,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: gText(17, c: _ink),
                decoration: InputDecoration(border: InputBorder.none, hintText: '0', hintStyle: gText(17, c: const Color(0xffb6bcc8))),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        for (var k = 0; k < chips.length; k++) ...[
          if (k > 0) const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => _tap((chips[k]['i'] as num).toInt()),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: _ink, side: const BorderSide(color: _line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                child: Text(_s(chips[k]['t']), style: gText(13.5, w: FontWeight.w500, c: _ink)),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: const Color(0xfff4f5f7), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text('Kembalian', style: gText(13.5, c: _gray)),
          const Spacer(),
          Text(_s(widget.data['change']), style: gText(15, w: FontWeight.w500, c: widget.data['changeOk'] == true ? const Color(0xff15885d) : _ink)),
        ]),
      ),
      const SizedBox(height: 12),
      _primary(_s(widget.data['ok']), 1),
      const SizedBox(height: 10),
      _outlineRed('BATAL', 2),
    ];
  }

  List<Widget> _dp() {
    final methods = const ['Tunai', 'QRIS', 'Transfer'];
    final sel = _s(widget.data['method']);
    return [
      _title('DP / Uang Muka', sub: _s(widget.data['sub'])),
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 2), child: Text('Nominal DP', style: gText(13.5, c: _ink))),
      _field(prefix: 'Rp', key: const Key('ao-dp'), size: 15),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 2), child: Text('Metode pembayaran', style: gText(13.5, c: _ink))),
      Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: methods.contains(sel) ? sel : 'Tunai',
            isExpanded: true,
            style: gText(13, c: _ink),
            items: [for (final m in methods) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) {
              if (v != null) _tap(20 + methods.indexOf(v));
            },
          ),
        ),
      ),
      const SizedBox(height: 14),
      _primary('Simpan DP', 1),
      const SizedBox(height: 10),
      _outlineLeft('Batal', 2),
    ];
  }

  List<Widget> _qris() {
    final qr = _s(widget.data['qr']);
    return [
      Container(
        height: 340,
        margin: const EdgeInsets.fromLTRB(26, 6, 26, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (qr.isNotEmpty)
            QrImageView(data: qr, size: 220, backgroundColor: Colors.white)
          else ...[
            Text('QRIS outlet belum diatur', style: gText(14, c: _ink)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _tap(4),
              style: OutlinedButton.styleFrom(foregroundColor: gBrand, side: const BorderSide(color: _pinkLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Pengaturan Pembayaran', style: gText(13, c: gBrand)),
            ),
          ],
          const SizedBox(height: 28),
          Text(_s(widget.data['total']), style: gText(27, w: FontWeight.w500, c: _ink)),
        ]),
      ),
      _primary('SUDAH LUNAS', 1, color: const Color(0xff15a36b)),
      const SizedBox(height: 10),
      _outlineRed('Batal', 2),
    ];
  }

  List<Widget> _deposit() => [
        _title(_s(widget.data['title']), sub: _s(widget.data['sub'])),
        _primary(_s(widget.data['ok']), 1),
        const SizedBox(height: 10),
        _outlineLeft('Batal', 2),
      ];
}
