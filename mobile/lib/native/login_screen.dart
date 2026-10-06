import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'brand_intro.dart';
import 'common.dart';
import 'form_page.dart' show FormActions;

String _t(Object? v) => v is String ? v : (v == null ? '' : '$v');
int _n(Object? v) => (v as num?)?.toInt() ?? 0;

/// Indexes of the HTML login form (lg167) that the native screen drives.
/// Returns null when the HTML form does not have the expected shape, so the
/// generic native screen is used instead.
class LoginBindings {
  const LoginBindings(this.user, this.pass, this.login, this.forgot);
  final int user, pass, login;
  final int? forgot;

  static LoginBindings? from(List<Map<String, dynamic>> items) {
    final inputs = [for (final it in items) if (it['type'] == 'input') it];
    if (inputs.length < 2) {
      return null;
    }
    final pass = inputs.firstWhere((e) => e['secret'] == true, orElse: () => inputs[1]);
    final user = inputs.firstWhere((e) => !identical(e, pass), orElse: () => inputs[0]);
    int? login, forgot;
    for (final it in items) {
      if (it['type'] != 'button') {
        continue;
      }
      final label = _t(it['t']).toLowerCase();
      if (label.contains('lupa')) {
        forgot ??= _n(it['i']);
      } else if (label.contains('masuk') && !label.contains('google')) {
        login ??= _n(it['i']);
      }
    }
    if (login == null) {
      return null;
    }
    return LoginBindings(_n(user['i']), _n(pass['i']), login, forgot);
  }
}

/// Login screen: red gradient, frosted card, the G with the perched bird.
/// Fields and buttons act on the same elements of the HTML form.
class NativeLogin extends StatefulWidget {
  const NativeLogin({super.key, required this.items, required this.bindings, required this.actions});
  final List<Map<String, dynamic>> items;
  final LoginBindings bindings;
  final FormActions actions;
  @override
  State<NativeLogin> createState() => _NativeLoginState();
}

class _NativeLoginState extends State<NativeLogin> {
  late final _user = TextEditingController(text: _initial(widget.bindings.user));
  late final _pass = TextEditingController(text: _initial(widget.bindings.pass));
  bool _show = false, _remember = true;
  String _note = '';

  String _initial(int index) {
    for (final it in widget.items) {
      if (it['type'] == 'input' && _n(it['i']) == index) {
        return _t(it['v']);
      }
    }
    return '';
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    widget.actions.fmInput(widget.bindings.user, _user.text);
    widget.actions.fmInput(widget.bindings.pass, _pass.text);
    widget.actions.fmButton(widget.bindings.login);
  }

  Widget _field({
    required Key key,
    required TextEditingController c,
    required IconData icon,
    required String hint,
    required ValueChanged<String> onChanged,
    bool secret = false,
    TextInputType? type,
    TextInputAction? action,
    VoidCallback? onSubmit,
  }) =>
      Container(
        height: 54,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0x29ffffff),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x4dffffff)),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: key,
              controller: c,
              obscureText: secret && !_show,
              keyboardType: type,
              textInputAction: action,
              autocorrect: false,
              enableSuggestions: !secret,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit?.call(),
              cursorColor: Colors.white,
              style: gText(14.5, c: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: gText(14.5, c: const Color(0xb3ffffff)),
              ),
            ),
          ),
          if (secret)
            IconButton(
              key: const Key('login-eye'),
              onPressed: () => setState(() => _show = !_show),
              icon: Icon(_show ? Icons.visibility_rounded : Icons.visibility_off_outlined, color: Colors.white, size: 22),
            )
          else
            const SizedBox(width: 14),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.bindings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: const Color(0xffed0026),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffff7956), Color(0xffff2636), Color(0xffed0026)],
          ),
        ),
        child: Stack(children: [
          const Positioned.fill(child: BrandFloral()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(24, 36, 24, 24 + bottom),
                  children: [
                    const Center(child: BrandMarkWithBird(size: 150)),
                    const SizedBox(height: 4),
                    Center(child: Text('Goyana', style: gText(44, w: FontWeight.w600, c: Colors.white))),
                    Center(child: Text('KASIR LAUNDRY', style: gText(11, c: Colors.white, ls: 4))),
                    const SizedBox(height: 26),
                    Text('Selamat Datang', style: gText(22, w: FontWeight.w700, c: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Silakan masuk untuk melanjutkan', style: gText(15, c: Colors.white)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          decoration: BoxDecoration(
                            color: const Color(0x24ffffff),
                            border: Border.all(color: const Color(0x40ffffff)),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            _field(
                              key: const Key('login-user'),
                              c: _user,
                              icon: Icons.mail_outline_rounded,
                              hint: 'Masukkan email atau no HP',
                              type: TextInputType.emailAddress,
                              action: TextInputAction.next,
                              onChanged: (v) => widget.actions.fmInput(b.user, v),
                            ),
                            _field(
                              key: const Key('login-pass'),
                              c: _pass,
                              icon: Icons.lock_outline_rounded,
                              hint: 'Masukkan password',
                              secret: true,
                              action: TextInputAction.done,
                              onChanged: (v) => widget.actions.fmInput(b.pass, v),
                              onSubmit: _submit,
                            ),
                            Row(children: [
                              GestureDetector(
                                key: const Key('login-remember'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _remember = !_remember),
                                child: Row(children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _remember ? const Color(0xffff1f3d) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white, width: 1.4),
                                    ),
                                    child: _remember ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Ingat saya', style: gText(13.5, c: Colors.white)),
                                ]),
                              ),
                              const Spacer(),
                              if (b.forgot != null)
                                GestureDetector(
                                  key: const Key('login-forgot'),
                                  onTap: () => widget.actions.fmButton(b.forgot!),
                                  child: Text('Lupa Password?', style: gText(13.5, w: FontWeight.w500, c: Colors.white)),
                                ),
                            ]),
                            const SizedBox(height: 16),
                            GestureDetector(
                              key: const Key('login-submit'),
                              onTap: _submit,
                              child: Container(
                                height: 54,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(colors: [Color(0xffff1f3d), Color(0xffd9001f)]),
                                  boxShadow: const [BoxShadow(color: Color(0x59780014), blurRadius: 14, offset: Offset(0, 6))],
                                ),
                                child: Row(children: [
                                  const SizedBox(width: 24),
                                  Expanded(child: Center(child: Text('Login', style: gText(17, w: FontWeight.w600, c: Colors.white)))),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [
                              const Expanded(child: Divider(color: Color(0x80ffffff))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('atau masuk dengan', style: gText(13, c: Colors.white)),
                              ),
                              const Expanded(child: Divider(color: Color(0x80ffffff))),
                            ]),
                            const SizedBox(height: 14),
                            GestureDetector(
                              key: const Key('login-google'),
                              onTap: () => setState(() => _note = 'Masuk dengan Google belum tersedia di versi ini.'),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('G', style: gText(22, w: FontWeight.w700, c: const Color(0xff4285f4))),
                                  const SizedBox(width: 12),
                                  Text('Masuk dengan Google', style: gText(15.5, w: FontWeight.w600, c: const Color(0xff1e1e1e))),
                                ]),
                              ),
                            ),
                            if (_note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(_note, textAlign: TextAlign.center, style: gText(12.5, c: Colors.white)),
                              ),
                            const SizedBox(height: 16),
                            Center(child: Text('Belum punya akun?', style: gText(13.5, c: Colors.white))),
                            const SizedBox(height: 8),
                            GestureDetector(
                              key: const Key('login-register'),
                              onTap: () => setState(() => _note = 'Pendaftaran akun baru menyusul.'),
                              child: Container(
                                height: 48,
                                margin: const EdgeInsets.symmetric(horizontal: 36),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xb3ffffff)),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text('Buat Akun Baru', style: gText(14.5, w: FontWeight.w600, c: Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
