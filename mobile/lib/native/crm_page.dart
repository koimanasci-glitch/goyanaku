import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../logic/crm.dart';
import 'common.dart';

// CRM Pelanggan (A9): halaman Dart penuh dengan data tersimpan sendiri (goyana-crm203).

const _ink = Color(0xff1e1e1e);
const _muted = Color(0xff8a8fa3);

class NativeCrm extends StatefulWidget {
  const NativeCrm({
    super.key,
    required this.store,
    required this.onBack,
    required this.onNav,
    required this.onScan,
    required this.openUrl,
    this.outlet = 'Outlet',
    this.topInset,
    this.now,
  });
  final KvStore store;
  final VoidCallback onBack, onScan;
  final ValueChanged<String> onNav;
  final ValueChanged<String> openUrl;
  final String outlet;
  final double? topInset;
  final DateTime Function()? now;
  @override
  State<NativeCrm> createState() => _NativeCrmState();
}

class _NativeCrmState extends State<NativeCrm> {
  late final CrmStore _db = CrmStore(widget.store);
  CrmState _st = CrmState();
  CrmData _data = CrmData({}, [], {}, {'all': [], 'setia': [], 'pasif': [], 'baru': []});
  String _tab = 'rem';
  bool _ready = false;
  String _msg = '';

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await _db.load();
    final b = await _db.loadBusiness();
    if (!mounted) return;
    setState(() {
      _st = st;
      _data = crmFromBusiness(b, st, _now);
      _ready = true;
    });
  }

  void _save({String? toast}) {
    setState(() {
      if (toast != null) _msg = toast;
    });
    _db.save(_st);
  }

  Future<void> _reloadBusiness() async {
    final b = await _db.loadBusiness();
    if (!mounted) return;
    setState(() => _data = crmFromBusiness(b, _st, _now));
  }

  void _toast(String t) => setState(() => _msg = t);

  @override
  Widget build(BuildContext context) {
    final top = widget.topInset ?? MediaQuery.paddingOf(context).top;
    return Material(
      color: const Color(0xfff6f7f9),
      child: Stack(children: [
        Column(children: [
          RepaintBoundary(child: GTopBar(top: top, onScan: widget.onScan)),
          Container(
            height: 55, padding: const EdgeInsets.symmetric(horizontal: 16), color: Colors.white,
            child: Row(children: [
              GestureDetector(
                key: const ValueKey('crm-back'),
                onTap: widget.onBack,
                child: Container(width: 38, height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(9)),
                    child: Text('‹', style: gText(20, w: FontWeight.w500, c: _ink, h: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('CRM PELANGGAN', style: gText(14.5, w: FontWeight.w600, c: _ink, ls: .7))),
            ]),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator(color: gBrand))
                : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), children: [
                    _tabs(),
                    const SizedBox(height: 10),
                    if (_tab == 'rem') ..._rem() else if (_tab == 'pt') ..._pt() else ..._vc(),
                  ]),
          ),
        ]),
        if (_msg.isNotEmpty)
          Positioned(
            left: 24, right: 24, bottom: 96,
            child: GestureDetector(
              onTap: () => setState(() => _msg = ''),
              child: Container(
                key: const ValueKey('crm-toast'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: const Color(0xff27323e), borderRadius: BorderRadius.circular(12)),
                child: Text(_msg, textAlign: TextAlign.center, style: gText(12.5, c: Colors.white)),
              ),
            ),
          ),
        Positioned(left: 0, right: 0, bottom: 0, child: GBottomNav(active: 0, onTap: widget.onNav)),
      ]),
    );
  }

  Widget _tabs() => Row(children: [
        for (final t in const [('rem', 'Pengingat'), ('pt', 'Poin Member'), ('vc', 'Voucher')])
          Expanded(
            child: GestureDetector(
              key: ValueKey('crm-tab-${t.$1}'),
              onTap: () => setState(() {
                _tab = t.$1;
                _msg = '';
              }),
              child: Container(
                height: 36, margin: const EdgeInsets.only(right: 6), alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tab == t.$1 ? gBrand : Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _tab == t.$1 ? gBrand : const Color(0xffe6e8ec)),
                ),
                child: Text(t.$2, style: gText(12.5, w: FontWeight.w500, c: _tab == t.$1 ? Colors.white : _ink)),
              ),
            ),
          ),
      ]);

  // ---------- umum ----------
  Widget _card(String title, List<Widget> children, {String sub = '', Widget? trailing}) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [gShadow(const Color(0xffeef0f3), 1, 0)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: gText(13, w: FontWeight.w600, c: _ink))),
            if (sub.isNotEmpty) Text(sub, style: gText(11, c: _muted)),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _btn(String t, VoidCallback f, {Key? key, bool primary = true, bool small = false}) => GestureDetector(
        key: key,
        onTap: f,
        child: Container(
          height: small ? 30 : 42, padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16), alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? gBrand : Colors.white, borderRadius: BorderRadius.circular(small ? 9 : 12),
            border: primary ? null : Border.all(color: const Color(0xffe6e8ec)),
          ),
          child: Text(t, style: gText(small ? 11.5 : 13, w: FontWeight.w600, c: primary ? Colors.white : _ink)),
        ),
      );

  static String _initials(String n) {
    final w = n.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    return w.take(2).map((x) => x[0]).join().toUpperCase();
  }

  Widget _avatar(String n, {String? e}) => Container(
        width: 38, height: 38, alignment: Alignment.center, margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: e == null ? const Color(0xfff3efff) : const Color(0xfffff1d6), borderRadius: BorderRadius.circular(12)),
        child: Text(e ?? _initials(n), style: gText(13, w: FontWeight.w600, c: const Color(0xff6c4fd0))),
      );

  Widget _switch(bool v, ValueChanged<bool> f, {Key? key}) => Switch(key: key, value: v, activeThumbColor: Colors.white, activeTrackColor: gBrand, onChanged: f);

  Widget _row(String t, String sub, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: gText(12.5, w: FontWeight.w500, c: _ink)),
            if (sub.isNotEmpty) Text(sub, style: gText(10.5, c: _muted)),
          ])),
          trailing,
        ]),
      );

  Widget _num(int v, ValueChanged<int> f, {String prefix = '', String suffix = '', Key? key}) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (prefix.isNotEmpty) Text('$prefix ', style: gText(12, c: _muted)),
        SizedBox(
          width: 72, height: 34,
          child: TextFormField(
            key: key, initialValue: '$v', keyboardType: TextInputType.number, textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: gText(12.5, c: _ink),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(9))),
            onFieldSubmitted: (s) => f(int.tryParse(s) ?? v),
            onChanged: (s) {
              final n = int.tryParse(s);
              if (n != null && n > 0) f(n);
            },
          ),
        ),
        if (suffix.isNotEmpty) Text(' $suffix', style: gText(12, c: _muted)),
      ]);

  Future<void> _sheet(String title, String hint, List<(String, String, bool)> fields, String ok, void Function(List<String>) onOk) async {
    final ctl = [for (final f in fields) TextEditingController(text: f.$2)];
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: gText(15, w: FontWeight.w600, c: _ink)),
          if (hint.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text(hint, style: gText(11.5, c: _muted, h: 16))),
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                key: ValueKey('crm-f$i'), controller: ctl[i], maxLines: fields[i].$3 ? 4 : 1, minLines: 1,
                decoration: InputDecoration(labelText: fields[i].$1, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: _btn(ok, () {
            Navigator.of(c).pop();
            onOk([for (final t in ctl) t.text.trim()]);
          }, key: const ValueKey('crm-ok'))),
        ]),
      ),
    );
  }

  // ---------- 1) Pengingat ----------
  List<Widget> _rem() {
    final s = _st;
    final list = [..._data.uncollected]..sort((a, b) => b.days.compareTo(a.days));
    return [
      _card('Cucian belum diambil', sub: '${list.length} pesanan', [
        if (list.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: Text('Tidak ada cucian yang menunggu diambil 👍', style: gText(12, c: _muted)))),
        for (final u in list) _uncollected(u),
      ]),
      _card('Pengingat otomatis', trailing: _switch(s.remOn, (v) {
        s.remOn = v;
        _save(toast: v ? 'Pengingat otomatis aktif' : 'Pengingat otomatis mati');
      }, key: const ValueKey('crm-rem-on')), [
        _row('Kirim pengingat pada hari ke-', 'Dihitung sejak status Siap Ambil', const SizedBox()),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in const [1, 2, 3, 5, 7, 10])
            GestureDetector(
              key: ValueKey('crm-day-$d'),
              onTap: () {
                if (s.remDays.contains(d)) {
                  if (s.remDays.length == 1) {
                    _toast('Minimal 1 jadwal pengingat');
                    return;
                  }
                  s.remDays.remove(d);
                } else {
                  s.remDays.add(d);
                }
                s.remDays.sort();
                _save();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: s.remDays.contains(d) ? gBrand : const Color(0xfff3f4f7), borderRadius: BorderRadius.circular(10)),
                child: Text('H+$d', style: gText(12, c: s.remDays.contains(d) ? Colors.white : _ink)),
              ),
            ),
        ]),
        _row('Peringatan terakhir', 'Pesan tegas sebelum aturan berlaku', _num(s.remLast, (v) { s.remLast = v; _save(); }, prefix: 'H+', key: const ValueKey('crm-last'))),
        _row('Aturan setelah', 'Hari sejak siap diambil', _num(s.remAfter, (v) { s.remAfter = v; _save(); }, suffix: 'hari', key: const ValueKey('crm-after'))),
        _row('Tindakan', '', DropdownButton<String>(
          key: const ValueKey('crm-rule'), value: s.rule, underline: const SizedBox(),
          items: const [DropdownMenuItem(value: 'fee', child: Text('Biaya simpan')), DropdownMenuItem(value: 'donate', child: Text('Disumbangkan')), DropdownMenuItem(value: 'none', child: Text('Tanpa aturan'))],
          onChanged: (v) {
            s.rule = v ?? 'fee';
            _save(toast: 'Aturan tersimpan');
          },
        )),
        if (s.rule == 'fee') _row('Biaya simpan per hari', '', _num(s.fee, (v) { s.fee = v; _save(); }, prefix: 'Rp', key: const ValueKey('crm-fee'))),
        _row('Cetak aturan di nota', 'Jadi dasar yang jelas bila pelanggan protes', _switch(s.printRule, (v) { s.printRule = v; _save(); })),
        Text('Teks di nota: "${s.ruleText}"', style: gText(11, c: _muted, h: 16)),
      ]),
      _card('Template pesan pengingat', [
        Text(s.tpl, style: gText(12, c: _ink, h: 17)),
        const SizedBox(height: 6),
        Text('Variabel: {nama} {kode} {hari} {total} {outlet}', style: gText(10.5, c: _muted)),
        const SizedBox(height: 8),
        _btn('Ubah Template', () => _sheet('Template pengingat', 'Variabel: {nama} {kode} {hari} {total} {outlet}', [('Isi pesan', s.tpl, true)], 'Simpan', (v) {
          if (v[0].isNotEmpty) s.tpl = v[0];
          _save(toast: 'Template pengingat tersimpan');
        }), key: const ValueKey('crm-tpl'), primary: false),
      ]),
    ];
  }

  Widget _uncollected(CrmUncollected u) {
    final (label, tone) = crmStage(_st, u.days);
    final sent = _st.reminded[u.id] ?? const <int>[];
    final c = tone == 'red' ? const Color(0xffc62f3b) : tone == 'org' ? const Color(0xffa06a00) : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _avatar(u.name),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name, style: gText(12.5, w: FontWeight.w500, c: _ink)),
          Text('${u.id} · siap ${u.days} hari · ${crmRp(u.total)}', style: gText(10.5, c: _muted)),
          Text(sent.isEmpty ? 'Belum diingatkan' : 'Sudah diingatkan: H+${sent.join(', H+')}', style: gText(10.5, c: _muted)),
          Text(label, style: gText(10.5, w: FontWeight.w600, c: c)),
        ])),
        _btn('Ingatkan', () => _remind(u), small: true, key: ValueKey('crm-remind-${u.id}')),
      ]),
    );
  }

  void _remind(CrmUncollected u) {
    final msg = crmReminderText(_st, u, widget.outlet);
    _sheet('Kirim pengingat ke ${u.name}', 'Periksa pesan, lalu kirim lewat WhatsApp.', [('Pesan', msg, true)], 'Kirim via WhatsApp', (v) {
      final l = _st.reminded.putIfAbsent(u.id, () => []);
      if (!l.contains(u.days)) l.add(u.days);
      final phone = _waPhone(u.phone.isNotEmpty ? u.phone : (_data.customers[u.name] ?? ''));
      _save(toast: phone.isEmpty ? 'Pengingat dicatat (nomor WA ${u.name} belum ada)' : 'Pengingat dikirim ke ${u.name} · tercatat');
      if (phone.isNotEmpty) widget.openUrl('https://wa.me/$phone?text=${Uri.encodeComponent(v[0])}');
    });
  }

  String _waPhone(String p) {
    var d = p.replaceAll(RegExp(r'[^\d]'), '');
    if (d.startsWith('0')) d = '62${d.substring(1)}';
    return d;
  }

  // ---------- 2) Poin ----------
  List<Widget> _pt() {
    final s = _st;
    final bal = crmBalances(_data, s);
    final names = bal.keys.toList()..sort((a, b) => bal[b]!.compareTo(bal[a]!));
    return [
      _card('Aturan poin', trailing: _switch(s.ptOn, (v) { s.ptOn = v; _save(toast: v ? 'Poin member aktif' : 'Poin member mati'); }), [
        _row('Setiap belanja', 'Poin masuk otomatis dari pesanan lunas', _num(s.per, (v) { s.per = v; _save(); _reloadBusiness(); }, prefix: 'Rp', suffix: '= 1 poin', key: const ValueKey('crm-per'))),
        _row('Masa berlaku poin', '', _num(s.expMonths, (v) { s.expMonths = v; _save(); }, suffix: 'bulan')),
      ]),
      _card('Hadiah tukar poin', sub: '${s.rewards.length} hadiah', [
        if (s.rewards.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Belum ada hadiah. Tambah hadiah agar pelanggan bisa menukar poin.', style: gText(12, c: _muted))),
        for (var i = 0; i < s.rewards.length; i++)
          _row(s.rewards[i].t, 'senilai ${crmRp(s.rewards[i].v)}', Row(children: [
            Text('⭐ ${s.rewards[i].p}', style: gText(12, w: FontWeight.w600, c: _ink)),
            const SizedBox(width: 8),
            GestureDetector(key: ValueKey('crm-rw-del-$i'), onTap: () { s.rewards.removeAt(i); _save(); }, child: const Icon(Icons.close_rounded, size: 18, color: _muted)),
          ])),
        const SizedBox(height: 6),
        _btn('+ Tambah Hadiah', _addReward, key: const ValueKey('crm-rw-add')),
      ]),
      _card('Poin pelanggan', sub: '${names.length} member', [
        if (names.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('Belum ada poin. Poin muncul saat pesanan lunas.', style: gText(12, c: _muted)))),
        for (final n in names) _member(n, bal[n]!),
      ]),
    ];
  }

  Widget _member(String n, int pts) {
    final can = _st.rewards.where((w) => pts >= w.p).toList();
    final next = _st.rewards.where((w) => pts < w.p).map((w) => w.p - pts).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _avatar(n),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: gText(12.5, w: FontWeight.w500, c: _ink)),
          Text(can.isNotEmpty ? 'Bisa tukar ${can.length} hadiah' : (next != null ? 'Kumpulkan $next poin lagi' : 'Belum ada hadiah'), style: gText(10.5, c: _muted)),
        ])),
        Text('⭐ $pts', style: gText(12.5, w: FontWeight.w600, c: _ink)),
        if (can.isNotEmpty) ...[const SizedBox(width: 8), _btn('Tukar', () => _redeem(n, pts, can), small: true, key: ValueKey('crm-redeem-$n'))],
      ]),
    );
  }

  void _addReward() => _sheet('Tambah hadiah', 'Hadiah yang bisa ditukar dengan poin', [('Nama hadiah', '', false), ('Poin dibutuhkan', '', false), ('Nilai hadiah (Rp)', '', false)], 'Simpan', (v) {
        final p = int.tryParse(v[1].replaceAll(RegExp(r'\D'), '')) ?? 0, nv = int.tryParse(v[2].replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (v[0].isEmpty || p <= 0) {
          _toast('Isi nama hadiah dan poin yang dibutuhkan');
          return;
        }
        _st.rewards.add(CrmReward(v[0], p, nv));
        _save(toast: 'Hadiah ditambahkan');
      });

  void _redeem(String who, int pts, List<CrmReward> ok) => _sheet(
        'Tukar poin $who',
        'Poin saat ini: $pts. Pilih nomor: ${[for (var i = 0; i < ok.length; i++) '${i + 1}) ${ok[i].t} (${ok[i].p} poin)'].join(' · ')}',
        [('Nomor hadiah', '1', false)],
        'Tukar',
        (v) {
          final i = (int.tryParse(v[0]) ?? 0) - 1;
          if (i < 0 || i >= ok.length) {
            _toast('Nomor hadiah tidak ada');
            return;
          }
          final voucher = crmRedeem(_st, crmBalances(_data, _st), who, ok[i]);
          _save(toast: voucher == null ? 'Poin tidak cukup' : 'Poin ditukar · kode ${voucher.code} untuk $who');
        },
      );

  // ---------- 3) Voucher ----------
  List<Widget> _vc() {
    final v = _st.vouchers;
    final now = _now;
    final active = v.where((x) => !x.used).length;
    return [
      _btn('+ Buat Voucher Kode Unik', _newVoucher, key: const ValueKey('crm-vc-new')),
      const SizedBox(height: 10),
      _card('Kode voucher', sub: '$active belum dipakai · ${v.length - active} terpakai', [
        if (v.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('Belum ada voucher. Buat voucher, lalu tiap pelanggan dapat kode unik yang dipakai di kasir.', textAlign: TextAlign.center, style: gText(12, c: _muted, h: 17))),
        for (var i = 0; i < v.length; i++) _voucher(i, v[i], now),
      ]),
    ];
  }

  Widget _voucher(int i, CrmVoucher x, DateTime now) {
    final st = x.status(now);
    final c = st == 'Aktif' ? const Color(0xff3e8a2e) : st == 'Kedaluwarsa' ? const Color(0xffc62f3b) : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _avatar('', e: '🎟'),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(x.code, style: gText(12.5, w: FontWeight.w700, c: _ink, ls: .5)),
          Text('${x.who} · ${x.name}', style: gText(10.5, c: _muted)),
          Text('${x.type == 'p' ? '${x.val}%' : crmRp(x.val)}${x.min > 0 ? ' · min ${crmRp(x.min)}' : ''}${x.until.isNotEmpty ? ' · s.d. ${x.until}' : ''}', style: gText(10.5, c: _muted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(st, style: gText(10.5, w: FontWeight.w600, c: c)),
          if (st == 'Aktif') Row(mainAxisSize: MainAxisSize.min, children: [
            _btn('Kirim', () => _sendVoucher(x), small: true, primary: false, key: ValueKey('crm-vc-send-$i')),
            const SizedBox(width: 6),
            _btn('Terpakai', () { x.used = true; _save(toast: 'Voucher ${x.code} ditandai terpakai'); }, small: true, key: ValueKey('crm-vc-used-$i')),
          ]),
        ]),
      ]),
    );
  }

  void _sendVoucher(CrmVoucher x) {
    final text = 'Halo ${x.who}, ini voucher khusus untuk Anda 🎁 Kode: ${x.code} · potongan ${x.type == 'p' ? '${x.val}%' : crmRp(x.val)}${x.min > 0 ? ' (min ${crmRp(x.min)})' : ''}${x.until.isNotEmpty ? ' · berlaku s.d. ${x.until}' : ''}. Tunjukkan kode ini ke kasir ya!';
    _sheet('Kirim voucher ke ${x.who}', '', [('Pesan', text, true)], 'Kirim via WhatsApp', (v) {
      final phone = _waPhone(_data.customers[x.who] ?? '');
      if (phone.isEmpty) {
        _toast('Nomor WA ${x.who} belum ada');
        return;
      }
      widget.openUrl('https://wa.me/$phone?text=${Uri.encodeComponent(v[0])}');
      _toast('Voucher dikirim ke ${x.who}');
    });
  }

  void _newVoucher() {
    final until = _now.add(const Duration(days: 30));
    final iso = '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}';
    _sheet(
      'Buat voucher kode unik',
      'Penerima (ketik): semua / setia (≥3 order) / pasif (>30 hari) / baru (≤30 hari) / atau nama pelanggan. Jenis: persen atau nominal.',
      [('Nama voucher', '', false), ('Jenis (persen / nominal)', 'persen', false), ('Besar potongan', '', false), ('Minimal belanja (Rp)', '', false), ('Berlaku sampai (YYYY-MM-DD)', iso, false), ('Penerima', 'semua', false)],
      'Buat Voucher',
      (v) {
        final isPct = !v[1].toLowerCase().startsWith('n');
        final val = int.tryParse(v[2].replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (v[0].isEmpty) {
          _toast('Isi nama voucher');
          return;
        }
        if (val <= 0) {
          _toast('Isi besar potongan');
          return;
        }
        if (isPct && val > 100) {
          _toast('Persen maksimal 100');
          return;
        }
        final key = v[5].toLowerCase();
        final seg = {'semua': 'all', 'setia': 'setia', 'pasif': 'pasif', 'baru': 'baru'}[key];
        final who = seg != null ? _data.segments[seg]! : [if (_data.customers.keys.any((n) => n.toLowerCase() == key)) _data.customers.keys.firstWhere((n) => n.toLowerCase() == key)];
        if (who.isEmpty) {
          _toast('Tidak ada pelanggan yang cocok dengan "${v[5]}"');
          return;
        }
        final n = crmCreateVouchers(_st, name: v[0], type: isPct ? 'p' : 'n', val: val, min: int.tryParse(v[3].replaceAll(RegExp(r'\D'), '')) ?? 0, until: v[4], who: who);
        _save(toast: '$n kode unik dibuat · tekan Kirim untuk bagikan lewat WA');
      },
    );
  }
}
