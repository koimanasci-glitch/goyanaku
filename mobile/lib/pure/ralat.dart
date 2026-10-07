// Ralat & Log Koreksi (v139): koreksi pembayaran & pengeluaran shift berjalan, dengan log permanen.
// Hitungan ralat pembayaran memakai logika A5 yang sama dengan Mode Hibrida (applyPaymentA5).
import 'dart:convert';

import '../core/money.dart';
import '../logic/payments.dart';
import 'pages.dart';

class RalatPage extends PurePage {
  RalatPage(super.host);
  static const _methods = ['Tunai', 'QRIS', 'Transfer'];
  static const _cats = ['Gaji', 'Bonus', 'Bahan Baku', 'Listrik', 'Air', 'Sewa', 'Lain-Lain'];
  static const _reasonPay = ['Salah pilih metode', 'Salah input nominal', 'Pembayaran belum masuk', 'Pelanggan batal bayar'];
  static const _reasonOut = ['Salah input nominal', 'Salah kategori', 'Tercatat dobel', 'Pengeluaran batal'];
  bool owner = true;
  String tab = 'bayar';
  String mode = ''; // 'bayar' / 'keluar'
  String rid = '';
  int method = 0, cat = 0, reason = -1;
  String amount = '', keterangan = '', note = '', pin = '';
  void Function(String by)? _afterPin;
  int _fail = 0;

  @override
  String get title => 'RALAT & LOG KOREKSI';
  @override
  String get back => 'reports';
  @override
  int get navActive => 2;

  Map<String, dynamic> get kas => host.business.kas;
  List<Map<String, dynamic>> _l(String k) => ((kas.putIfAbsent(k, () => <dynamic>[])) as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  String get _admin => '${host.settings.raw['adminName'] ?? 'Admin'}';
  String get _who => owner ? '$_admin (Admin Utama)' : 'Kasir (Kasir)';
  String get _pin => '${host.settings.raw['adminPin'] ?? '1234'}'; // bawaan HTML; bisa diganti lewat "Ganti PIN Admin"

  static String _hm(Object? at) {
    final d = DateTime.tryParse('$at')?.toLocal();
    return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _dt(Object? at) {
    final d = DateTime.tryParse('$at')?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${_hm(at)}';
  }

  /// Beri id ralat pada catatan yang belum punya (S… pembayaran, E… pengeluaran) dan lengkapi kategori pengeluaran.
  void _norm() {
    var seq = (kas['ralatSeq'] as num?)?.toInt() ?? 0;
    for (final s in (kas['sales'] as List? ?? const []).whereType<Map>()) {
      s['rid'] ??= 'S${++seq}';
    }
    for (final o in (kas['outs'] as List? ?? const []).whereType<Map>()) {
      o['rid'] ??= 'E${++seq}';
      final parts = '${o['t'] ?? ''}'.split(' · ');
      o['cat'] ??= parts.first.isEmpty ? 'Lain-Lain' : parts.first;
      o['note'] ??= '${o['n'] ?? ''}'.isNotEmpty ? '${o['n']}' : parts.skip(1).join(' · ');
    }
    kas['ralatSeq'] = seq;
  }

  @override
  void opened() {
    tab = 'bayar';
    _norm();
  }

  List<Map<String, dynamic>> get _sales => _l('sales').reversed.toList();
  List<Map<String, dynamic>> get _outs => _l('outs').reversed.toList();

  @override
  List<Map<String, dynamic>> items() {
    _norm();
    final log = _l('ralatLog');
    Map<String, dynamic> row(String t, String line, String av, String amt, [int? btn]) => {
          'type': 'entry', 't': t, 'lines': [line], 'badge': '', 'avatar': av, 'svg': '', 'color': '', 'amount': amt,
          'btns': [if (btn != null) {'t': 'Ralat', 'on': false, 'i': btn}],
        };
    String ico(Map s) => s['adj'] == 1 ? 'KO' : ('${s['m']}' == 'Transfer' ? 'TR' : '${s['m']}'.padRight(2).substring(0, 2));
    final list = <Map<String, dynamic>>[];
    var next = 5;
    if (tab == 'bayar') {
      final voided = _l('voided').reversed.toList();
      for (final s in _sales) {
        final name = host.business.orderById('${s['id'] ?? ''}')?.name ?? '';
        final id = '${s['id'] ?? ''}'.isEmpty ? 'Pembayaran' : '${s['id']}';
        list.add(row('$id${s['edited'] == 1 ? 'diralat' : ''}${s['adj'] == 1 ? 'koreksi' : ''}', '${name.isEmpty ? '' : '$name · '}${s['m']} · ${_hm(s['at'])}', ico(s), rpSigned(parseSigned(s['a'])),
            s['adj'] == 1 ? null : next++));
      }
      for (final s in voided) {
        list.add(row('${'${s['id'] ?? ''}'.isEmpty ? 'Pembayaran' : s['id']}dibatalkan', '${s['m']} · batal ${_hm(s['voidAt'])}', ico(s), rpSigned(parseSigned(s['a']))));
      }
      if (list.isEmpty) list.add({'type': 'title', 't': 'Belum ada pembayaran di shift ini'});
    } else if (tab == 'keluar') {
      for (final o in _outs) {
        final n = '${o['note'] ?? ''}';
        list.add(row('${o['cat']}${o['edited'] == 1 ? 'diralat' : ''}', '${n.isEmpty ? '' : '$n · '}${_hm(o['at'])}', 'OU', rp(parseRupiah(o['a'])), next++));
      }
      for (final o in _l('outsVoid').reversed) {
        list.add(row('${o['cat']}dibatalkan', 'batal ${_hm(o['voidAt'])}', 'OU', rp(parseRupiah(o['a']))));
      }
      if (list.isEmpty) list.add({'type': 'title', 't': 'Belum ada pengeluaran di shift ini'});
    } else {
      for (final e in log) {
        list.add({
          'type': 'entry', 't': '${e['title']}', 'lines': ['${e['before']} → ${e['after']}', 'Alasan: ${e['reason']}', 'Oleh: ${e['by']}${'${e['tag'] ?? ''}'.isEmpty ? '' : ' · ${e['tag']}'}'],
          'badge': '', 'avatar': const {'bayar': '💳', 'keluar': '🧾', 'order': '⚖️'}['${e['type']}'] ?? '✎', 'svg': '', 'color': '', 'amount': _dt(e['t']), 'btns': <dynamic>[],
        });
      }
      if (log.isEmpty) list.add({'type': 'hint', 't': 'Belum ada ralat. Semua transaksi sesuai input awal 👍'});
      list.add({'type': 'hint', 't': '🔒 Log permanen · tidak bisa diedit atau dihapus siapa pun'});
    }
    return [
      {
        'type': 'entry', 't': 'Login: $_who', 'lines': [owner ? 'Bisa meralat langsung' : 'Ralat perlu PIN Admin Utama'], 'badge': '', 'avatar': owner ? '👑' : '👤', 'svg': '', 'color': '', 'amount': '',
        'btns': [{'t': 'Admin Utama', 'on': owner, 'i': 0}, {'t': 'Kasir', 'on': !owner, 'i': 1}],
      },
      {'type': 'title', 't': '🔒'},
      {'type': 'hint', 't': 'Data tidak pernah dihapus. Setiap ralat menyimpan nilai lama → baru, alasan, siapa & jam. Hanya Admin Utama yang bisa meralat; kasir butuh PIN owner.'},
      {'type': 'buttons', 'options': [
        for (final (k, t) in const [['bayar', 'Pembayaran'], ['keluar', 'Pengeluaran'], ['log', 'Log']].indexed)
          {'t': t[0] == 'log' && log.isNotEmpty ? 'Log${log.length}' : t[1], 'svg': '', 'file': '', 'after': false, 'on': tab == t[0], 'i': 2 + k},
      ]},
      ...list,
    ];
  }

  static int parseSigned(Object? v) => v is num ? v.round() : (int.tryParse('$v') ?? 0);
  static String rpSigned(int n) => '${n < 0 ? '−' : ''}${rp(n.abs())}';

  Map<String, dynamic>? get _sale => _l('sales').where((s) => s['rid'] == rid).firstOrNull;
  Map<String, dynamic>? get _out => _l('outs').where((s) => s['rid'] == rid).firstOrNull;
  static String _fmt(int n) => rp(n).substring(2);

  @override
  void button(int i) {
    if (i == 0 || i == 1) {
      owner = i == 0;
      host.toast(owner ? 'Login sebagai Admin Utama' : 'Login sebagai Kasir · ralat perlu PIN');
      return host.refresh();
    }
    if (i >= 2 && i <= 4) {
      tab = const ['bayar', 'keluar', 'log'][i - 2];
      return host.refresh();
    }
    final k = i - 5;
    reason = -1;
    note = '';
    if (tab == 'bayar') {
      final rows = _sales.where((s) => s['adj'] != 1).toList();
      if (k < 0 || k >= rows.length) return;
      final s = rows[k];
      mode = 'bayar';
      rid = '${s['rid']}';
      method = _methods.indexOf('${s['m']}').clamp(0, 2);
      amount = _fmt(parseSigned(s['a']));
    } else if (tab == 'keluar') {
      final rows = _outs;
      if (k < 0 || k >= rows.length) return;
      final o = rows[k];
      mode = 'keluar';
      rid = '${o['rid']}';
      cat = _cats.indexOf('${o['cat']}');
      amount = _fmt(parseRupiah(o['a']));
      keterangan = '${o['note'] ?? ''}';
    } else {
      return;
    }
    host.openPageSheet('rs139');
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    Map<String, dynamic> inp(String v, int i, {String ph = '', bool numeric = false, bool secret = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': secret, 'email': false, 'i': i};
    Map<String, dynamic> opt(String t, bool on, int i) => {'t': t, 'svg': '', 'file': '', 'after': false, 'on': on, 'i': i};
    if (id == 'pin139') {
      return [
        {'type': 'title', 't': 'PIN Admin Utama', 's': ''},
        {'type': 'hint', 't': 'Minta Admin Utama memasukkan PIN'},
        inp(pin, 0, ph: 'PIN 4 angka', numeric: true, secret: true),
        {'type': 'button', 't': 'Lanjut', 'primary': true, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
        // Perbaikan atas HTML (PIN tertanam 1234 dan tidak bisa diganti): PIN Admin bisa diganti di sini.
        {'type': 'button', 't': 'Ganti PIN Admin', 'primary': false, 'file': '', 'after': false, 'i': 2},
      ];
    }
    if (id != 'rs139') return null;
    if (mode == 'bayar') {
      final s = _sale;
      if (s == null) return const [];
      final old = parseSigned(s['a']), a = parseRupiah(amount), m = _methods[method], om = '${s['m']}';
      final prev = <String>[
        if (m != om) 'Laporan $om −${rpSpaced(old)} · $m +${rpSpaced(a)}' else if (a != old) '$m: ${rp(old)} → ${rp(a)}',
        if (m != om && (om == 'Tunai' || m == 'Tunai')) 'Uang di laci seharusnya ikut berubah',
      ];
      return [
        {'type': 'title', 't': 'Ralat Pembayaran', 's': ''},
        {'type': 'hint', 't': '${s['id'] ?? ''}'},
        {'type': 'pair', 't': 'Tercatat', 'v': '$om · ${rp(old)}${'${s['id'] ?? ''}'.isEmpty ? '' : ' · ${s['id']}'}', 'tone': '', 'tap': -1},
        {'type': 'label', 't': 'Metode yang benar'},
        {'type': 'buttons', 'options': [for (var k = 0; k < 3; k++) opt(_methods[k], k == method, k)]},
        {'type': 'label', 't': 'Nominal yang benar'},
        inp(amount, 0, numeric: true),
        {'type': 'label', 't': 'Alasan ralat *'},
        {'type': 'buttons', 'options': [for (var k = 0; k < 4; k++) opt(_reasonPay[k], k == reason, 3 + k)]},
        inp(note, 1, ph: 'Catatan tambahan (opsional)'),
        if (prev.isNotEmpty) {'type': 'hint', 't': prev.join()},
        {'type': 'buttons', 'options': [opt('Batalkan Bayar', false, 7), opt('Simpan Ralat', false, 8)]},
      ];
    }
    final o = _out;
    if (o == null) return const [];
    final old = parseRupiah(o['a']), a = parseRupiah(amount), oc = '${o['cat']}';
    final cats = [..._cats, if (!_cats.contains(oc)) oc];
    return [
      {'type': 'title', 't': 'Ralat Pengeluaran', 's': ''},
      {'type': 'hint', 't': '${_dt(o['at'])} · dicatat kasir'},
      {'type': 'pair', 't': 'Tercatat', 'v': '$oc · ${rp(old)}', 'tone': '', 'tap': -1},
      {'type': 'label', 't': 'Kategori'},
      {'type': 'select', 'options': cats, 'index': cat < 0 ? cats.length - 1 : cat, 'i': 0},
      {'type': 'label', 't': 'Nominal yang benar'},
      inp(amount, 1, numeric: true),
      {'type': 'label', 't': 'Keterangan'},
      inp(keterangan, 2),
      {'type': 'label', 't': 'Alasan ralat *'},
      {'type': 'buttons', 'options': [for (var k = 0; k < 4; k++) opt(_reasonOut[k], k == reason, k)]},
      inp(note, 3, ph: 'Catatan tambahan (opsional)'),
      if (a != old) {'type': 'hint', 't': 'Uang di laci seharusnya ${a > old ? 'berkurang ' : 'bertambah '}${rp((a - old).abs())}'},
      {'type': 'buttons', 'options': [opt('Batalkan', false, 4), opt('Simpan Ralat', false, 5)]},
    ];
  }

  String get _reason {
    final list = mode == 'bayar' ? _reasonPay : _reasonOut;
    final r = reason >= 0 ? list[reason] : '', n = note.trim();
    return '$r${r.isNotEmpty && n.isNotEmpty ? ' · ' : ''}$n';
  }

  void _admin139(void Function(String by) cb) {
    if (owner) return cb('$_admin (Admin Utama)');
    pin = '';
    _afterPin = cb;
    host.openPageSheet('pin139');
  }

  void _log(Map<String, dynamic> e) {
    (kas.putIfAbsent('ralatLog', () => <dynamic>[]) as List).insert(0, {...e, 't': host.now.toIso8601String()});
    addAudit(host, '✎', '${e['title']}', '${e['by']} · ${e['before']} → ${e['after']} · ${e['reason']}');
    host.saveAll();
    host.closePageSheet('rs139');
    host.refresh();
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id == 'pin139') {
      if (kind == 'input') {
        pin = '$value'.replaceAll(RegExp(r'\D'), '');
        return;
      }
      if (kind != 'button') return;
      if (index == 1) return host.closePageSheet('pin139');
      if (index == 2) {
        if (pin != _pin) return host.toast('Masukkan PIN Admin yang sekarang dulu');
        return host.openFormSheet(FormSheetDef('Ganti PIN Admin', const [FormSheetField('PIN baru', placeholder: '4–6 angka', numeric: true, required: true)], 'Simpan', (v) {
          final n = v.first.replaceAll(RegExp(r'\D'), '');
          if (n.length < 4 || n.length > 6) {
            host.toast('PIN harus 4–6 angka');
            return false;
          }
          host.settings.raw['adminPin'] = n;
          host.settings.save();
          pin = '';
          addAudit(host, '🔒', 'PIN Admin diganti', _admin);
          host.saveAll();
          host.toast('PIN Admin diganti');
          host.refresh();
          return true;
        }, sub: 'Dipakai untuk menyetujui ralat & edit transaksi'));
      }
      if (pin == _pin) {
        _fail = 0;
        host.closePageSheet('pin139');
        final cb = _afterPin;
        _afterPin = null;
        cb?.call('$_admin (Admin Utama) · disetujui untuk Kasir');
      } else if (++_fail >= 3) {
        _fail = 0;
        host.closePageSheet('pin139');
        addAudit(host, '⚠', 'PIN Admin salah 3×', 'Kasir mencoba ralat');
        host.saveAll();
        host.toast('PIN salah 3× · percobaan dicatat di Audit');
      } else {
        host.toast('PIN salah');
      }
      return;
    }
    if (id != 'rs139') return;
    if (kind == 'input') {
      if (value is int) {
        cat = value;
        return host.refresh();
      }
      final v = '$value';
      if (mode == 'bayar') {
        index == 0 ? amount = v : note = v;
      } else {
        if (index == 1) amount = v;
        if (index == 2) keterangan = v;
        if (index == 3) note = v;
      }
      if ((mode == 'bayar' && index == 0) || (mode == 'keluar' && index == 1)) host.refresh();
      return;
    }
    if (kind != 'button') return;
    mode == 'bayar' ? _payButton(index) : _outButton(index);
  }

  void _payButton(int i) {
    final s = _sale;
    if (s == null) return;
    if (i <= 2) {
      method = i;
      return host.refresh();
    }
    if (i <= 6) {
      reason = i - 3;
      return host.refresh();
    }
    final old = parseSigned(s['a']), om = '${s['m']}', m = _methods[method], a = parseRupiah(amount), r = _reason, id = '${s['id'] ?? ''}';
    final voiding = i == 7;
    if (voiding) {
      if (r.isEmpty) return host.toast('Pilih alasan dulu');
    } else {
      if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+)$').hasMatch(amount.trim())) return host.toast('Isi nominal rupiah bulat yang benar');
      if (a == 0) return host.toast('Nominal tidak boleh 0 · pakai Batalkan Bayar');
      if (m == om && a == old) return host.toast('Belum ada yang diubah');
      if (r.isEmpty) return host.toast('Pilih alasan ralat dulu');
    }
    _admin139((by) {
      try {
        kas.putIfAbsent('voided', () => <dynamic>[]);
        final b = host.business;
        final after = applyPaymentA5(
          before: {paymentBusinessKey: jsonEncode(b.raw)},
          action: PaymentA5Action.correct(orderId: id, amount: voiding ? 0 : a, method: voiding ? om : m, at: host.now,
              correction: {'rid': rid, 'reason': r, 'by': by, 'legacy': false, 'oldMethod': om, if (voiding) 'void': true}),
        );
        final next = jsonDecode(after[paymentBusinessKey] as String) as Map<String, dynamic>;
        b.raw
          ..clear()
          ..addAll(next);
      } catch (e) {
        return host.toast(e is ArgumentError ? '${e.message}' : (e is StateError ? e.message : 'Ralat tidak dapat disimpan'));
      }
      _log({'type': 'bayar', 'title': '${voiding ? 'Pembayaran dibatalkan' : 'Ralat pembayaran'} $id', 'before': '$om ${rp(old)}', 'after': voiding ? 'Dibatalkan · Belum bayar' : '$m ${rp(a)}', 'reason': r, 'by': by});
      host.toast(voiding ? 'Pembayaran dibatalkan · pesanan jadi Belum Bayar' : 'Ralat tersimpan · tercatat di Log Ralat');
    });
  }

  void _outButton(int i) {
    if (i <= 3) {
      reason = i;
      return host.refresh();
    }
    final outs = kas['outs'] as List? ?? <dynamic>[];
    final o = outs.whereType<Map>().where((x) => x['rid'] == rid).firstOrNull;
    if (o == null) return;
    final old = parseRupiah(o['a']), oc = '${o['cat']}', on = '${o['note'] ?? ''}', r = _reason;
    final cats = [..._cats, if (!_cats.contains(oc)) oc];
    final c = cats[(cat < 0 ? cats.length - 1 : cat).clamp(0, cats.length - 1)], a = parseRupiah(amount), k = keterangan.trim();
    if (i == 4) {
      if (r.isEmpty) return host.toast('Pilih alasan dulu');
      return _admin139((by) {
        outs.remove(o);
        (kas.putIfAbsent('outsVoid', () => <dynamic>[]) as List).add({...o, 'voidAt': host.now.toIso8601String()});
        _log({'type': 'keluar', 'title': 'Pengeluaran dibatalkan', 'before': '$oc ${rp(old)}', 'after': 'Dibatalkan', 'reason': r, 'by': by});
        host.toast('Pengeluaran dibatalkan · tercatat di Log Ralat');
      });
    }
    if (a == 0) return host.toast('Nominal tidak boleh 0 · pakai Batalkan');
    if (c == oc && a == old && k == on) return host.toast('Belum ada yang diubah');
    if (r.isEmpty) return host.toast('Pilih alasan ralat dulu');
    _admin139((by) {
      o
        ..['cat'] = c
        ..['a'] = a
        ..['note'] = k
        ..['n'] = k
        ..['t'] = '$c${k.isEmpty ? '' : ' · $k'}'
        ..['edited'] = 1;
      _log({'type': 'keluar', 'title': 'Ralat pengeluaran', 'before': '$oc ${rp(old)}${on.isEmpty ? '' : ' · $on'}', 'after': '$c ${rp(a)}${k.isEmpty ? '' : ' · $k'}', 'reason': r, 'by': by});
      host.toast('Ralat tersimpan · tercatat di Log Ralat');
    });
  }
}
