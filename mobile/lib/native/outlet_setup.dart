// Layar pertama kali (Mode Murni): "Siapkan Outlet". Logo GOYANA, tiga isian berikon, tombol Mulai.
// Rancangan dari gambar Paduka 9 Oktober 2026; kejadian tetap ke FormActions lingkup 'setup' (isian 0–2, tombol 1).

import 'package:flutter/material.dart';

import 'common.dart';
import 'form_page.dart' show FormActions;

const _coral = Color(0xfff4604f);
const _line = Color(0xffdfe2ea);
const _muted = Color(0xff8a90a2);
const _ink = Color(0xff141a24);

class NativeOutletSetup extends StatefulWidget {
  const NativeOutletSetup({super.key, required this.actions, this.name = '', this.address = '', this.phone = ''});
  final FormActions actions;
  final String name, address, phone;
  @override
  State<NativeOutletSetup> createState() => _NativeOutletSetupState();
}

class _NativeOutletSetupState extends State<NativeOutletSetup> {
  late final _name = TextEditingController(text: widget.name);
  late final _address = TextEditingController(text: widget.address);
  late final _phone = TextEditingController(text: widget.phone);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Widget _field(String label, IconData icon, String hint, TextEditingController c, int i, {bool phone = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: gText(15, w: FontWeight.w600, c: _ink)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            keyboardType: phone ? TextInputType.phone : TextInputType.text,
            textInputAction: i == 2 ? TextInputAction.done : TextInputAction.next,
            textCapitalization: phone ? TextCapitalization.none : TextCapitalization.words,
            cursorColor: _coral,
            style: gText(15, c: _ink),
            onChanged: (v) => widget.actions.fmScoped('setup', 'input', i, v),
            onSubmitted: i == 2 ? (_) => widget.actions.fmScoped('setup', 'button', 1) : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: gText(15, c: _muted),
              prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 12), child: Icon(icon, size: 24, color: const Color(0xff5a6072))),
              prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 24),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line, width: 1.2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _coral, width: 1.6)),
            ),
          ),
          const SizedBox(height: 22),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfffbfbfc),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: (box.maxHeight * 0.1).clamp(28.0, 96.0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/branding/mark.png', width: 46, height: 46, color: _coral),
                      const SizedBox(width: 10),
                      Text('GOYANA', style: gText(30, w: FontWeight.w600, c: _coral, ls: 3)),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text('SIAPKAN OUTLET', textAlign: TextAlign.center, style: gText(20, w: FontWeight.w600, c: _ink, ls: 0.8)),
                  const SizedBox(height: 4),
                  Text('Lengkapi profil laundry Anda.', textAlign: TextAlign.center, style: gText(15, c: const Color(0xff5f6677))),
                  const SizedBox(height: 34),
                  _field('Nama outlet', Icons.storefront_outlined, 'Contoh: Goyana Laundry', _name, 0),
                  _field('Alamat outlet', Icons.location_on_outlined, 'Masukkan alamat outlet', _address, 1),
                  _field('WhatsApp outlet', Icons.phone_outlined, '08xxxxxxxxx', _phone, 2, phone: true),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => widget.actions.fmScoped('setup', 'button', 1),
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Mulai', style: gText(17, w: FontWeight.w600, c: Colors.white)),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Bisa diubah nanti di Pengaturan → Profil Outlet.', textAlign: TextAlign.center, style: gText(12.5, c: _muted)),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
