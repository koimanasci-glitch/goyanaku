// Kas: Penambahan Kas, Pengeluaran, Tutup Kasir — widget yang sama dengan Mode Hibrida (NativeCash, NativeCashClose)
// dengan hitungan A7 (lib/logic/cash.dart).
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../logic/cash.dart';
import '../native/cash_page.dart';
import '../native/cashclose_page.dart';
import '../native/form_page.dart' show FormActions;
import 'page_templates.dart';
import 'pages.dart';

Map<String, int> _summary(Map kas) {
  try {
    return cashSummaryA7(kas);
  } catch (_) {
    return {'t': 0, 'q': 0, 'f': 0, 'omset': 0, 'ins': 0, 'outs': 0, 'expect': 0, 'nt': 0};
  }
}

class _CashAdapter implements CashActions {
  _CashAdapter(this.page, this.base);
  final CashEntryPage page;
  final FormActions base;
  @override
  void scan() => base.scan();
  @override
  void nav(String pageId) => base.nav(pageId);
  @override
  void caBack() => page.host.go(page.back);
  @override
  void caType(String option) => page.type = option;
  @override
  void caAmount(String text) => page.amount = text;
  @override
  void caNote(String text) => page.note = text;
  @override
  void caSubmit() => page.submit();
}

/// Penambahan Kas (cashin) / Pengeluaran (cashout).
class CashEntryPage extends PurePage {
  CashEntryPage(super.host, {required this.income});
  final bool income;
  String type = 'Tipe Kas', amount = '', note = '';
  @override
  String get title => income ? 'PENAMBAHAN KAS' : 'PENGELUARAN';
  @override
  String get back => 'reports';
  @override
  int get navActive => 2;
  @override
  void opened() {
    type = 'Tipe Kas';
    amount = '';
    note = '';
  }

  @override
  List<Map<String, dynamic>> items() => const [];

  Map<String, dynamic> model() {
    final c = _summary(host.business.kas);
    const types = ['Tipe Kas', 'Tunai', 'Non-Tunai'];
    return {
      'title': title, 'heading': 'Saldo Kas',
      'stats': [
        {'icon': r'$', 'kind': 'cash', 't': 'Saldo Tunai', 'v': rp(c['expect']!)},
        {'icon': '◌', 'kind': 'noncash', 't': 'Saldo Non-Tunai', 'v': rp(c['nt']!)},
      ],
      'type': {'v': type, 'options': types, 'index': types.indexOf(type).clamp(0, 2)},
      'amount': {'v': amount, 'ph': 'Jumlah'},
      'note': {'v': note, 'ph': 'Keterangan'},
      'submit': income ? 'Tambah Kas' : 'Kurangi Kas',
      'subtract': !income,
      // Kategori Pengeluaran (Pengaturan → Keuangan): diketuk untuk mengisi Keterangan.
      if (!income) 'cats': [for (final c in host.settings.raw['expenseCats'] as List? ?? const []) '$c'],
    };
  }

  @override
  Widget? custom(BuildContext context, FormActions actions) =>
      NativeCash(key: ValueKey('pure-cash-$income'), model: CashModel.fromJson(model()), actions: _CashAdapter(this, actions));

  void submit() {
    if (amount.trim().isEmpty) return host.toast('Isi jumlah terlebih dahulu');
    final a = parseRupiah(amount);
    if (a > 0) {
      final non = type.contains('Non'), at = host.now.toUtc().toIso8601String();
      final kas = host.business.kas;
      (kas.putIfAbsent(income ? 'ins' : 'outs', () => <dynamic>[]) as List).add(income
          ? {'m': non ? 'Non-Tunai' : 'Tunai', 'a': a, 't': note, 'at': at}
          : {if (non) 'm': 'Non-Tunai', 't': note.isEmpty ? 'Pengeluaran' : note, 'a': a, 'at': at});
      host.saveAll();
    }
    host.toast(income ? 'Penambahan kas tersimpan' : 'Pengeluaran kas tersimpan');
    amount = '';
    host.refresh();
  }
}

class _CloseAdapter implements CashCloseActions {
  _CloseAdapter(this.page, this.base);
  final CashClosePage page;
  final FormActions base;
  @override
  void scan() => base.scan();
  @override
  void nav(String pageId) => base.nav(pageId);
  @override
  void ccTap(String selector, int index, String? child) => page.tap(selector, index, child);
  @override
  void ccType(String selector, String value) => page.type(selector, value);
}

/// Tutup Kasir (cashclose/kc137).
class CashClosePage extends PurePage {
  CashClosePage(super.host);
  static const _hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
  static const _bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  String note = '', active = '', lastText = '', doneSub = '';
  @override
  String get title => 'TUTUP KASIR';
  @override
  String get back => 'reports';
  @override
  int get navActive => 2;
  Map<String, dynamic> get kas => host.business.kas;

  @override
  void opened() {
    note = '';
    active = '';
  }

  @override
  List<Map<String, dynamic>> items() => const [];

  ({int n, int a}) get _unpaid {
    var n = 0, a = 0;
    for (final o in host.business.orders) {
      if (!o.isCancelled && o.paid <= 0 && o.total > 0) {
        n++;
        a += o.total;
      }
    }
    return (n: n, a: a);
  }

  String _tgl(DateTime d) => '${_hari[d.weekday % 7]}, ${d.day} ${_bln[d.month - 1]} ${d.year}';

  Map<String, dynamic> model() {
    final k = kas;
    k.putIfAbsent('den', () => <String, dynamic>{});
    final Map<String, dynamic> m;
    try {
      m = cashCloseModelA7({'model': jsonDecode(cashCloseTemplate), 'kas': k, 'active': active});
    } catch (_) {
      return jsonDecode(cashCloseTemplate) as Map<String, dynamic>;
    }
    final sections = m['sections'] as List, u = _unpaid, now = host.now;
    m['date'] = _tgl(now);
    m['meta'] = '👤 ${k['kasir'] ?? ''} · ${k['outlet'] ?? ''} · 🕖 Dibuka ${k['openAt'] ?? ''}'.replaceAll(RegExp(r' +'), ' ').trim();
    (sections[0] as Map)['unpaid'] = u.n > 0 ? '⏳ ${u.n} pesanan belum dibayar${rp(u.a)}' : '';
    final den = k['den'] as Map;
    for (final d in ((sections[2] as Map)['denominations'] as List).whereType<Map>()) {
      d['v'] = '${den['${cashDenominations[(d['i'] as num).toInt()]}'] ?? 0}';
    }
    final rec = (sections[3] as Map)['reconcile'] as List;
    for (final (i, key) in const ['qrisReal', 'tfReal'].indexed) {
      ((rec[i] as Map)['input'] as Map)['v'] = '${k[key] ?? ''}';
    }
    ((sections[4] as Map)['note'] as Map)['v'] = note;
    final hist = (k['hist'] as List? ?? const []).whereType<Map>().toList();
    (sections[5] as Map)
      ..['empty'] = hist.isEmpty ? 'Belum ada riwayat' : ''
      ..['history'] = [
        for (final h in hist)
          () {
            final d = DateTime.tryParse('${h['d'] ?? h['at']}')?.toLocal() ?? now;
            final diff = (h['diff'] as num?)?.round() ?? 0;
            return {
              'date': '${d.day}${_bln[d.month - 1]}', 't': 'Omset ${rp((h['omset'] as num?) ?? 0)}',
              's': '${h['kasir'] ?? ''} · setor ${rp((h['setor'] as num?) ?? 0)}${'${h['note'] ?? ''}'.isEmpty ? '' : ' · ${h['note']}'}',
              'badge': {
                't': diff == 0 ? 'Pas' : '${diff < 0 ? '−' : '+'}${rp(diff.abs())}',
                'bg': diff == 0 ? 'rgb(232, 248, 240)' : (diff < 0 ? 'rgb(255, 240, 241)' : 'rgb(255, 247, 236)'),
                'c': diff == 0 ? 'rgb(21, 136, 93)' : (diff < 0 ? 'rgb(216, 50, 63)' : 'rgb(138, 75, 15)'),
              },
            };
          }(),
      ];
    return m;
  }

  @override
  Widget? custom(BuildContext context, FormActions actions) => NativeCashClose(key: const ValueKey('pure-cashclose'), model: model(), actions: _CloseAdapter(this, actions));

  int? _int(String v) => v.trim().isEmpty ? null : parseRupiah(v);

  void type(String selector, String value) {
    final k = kas;
    active = selector;
    final den = RegExp(r'#kc-den label:nth-child\((\d+)\) input').firstMatch(selector);
    if (den != null) {
      (k['den'] as Map)['${cashDenominations[int.parse(den.group(1)!) - 1]}'] = parseRupiah(value);
      _afterDen();
    } else {
      switch (selector) {
        case '#kc-start':
          k['start'] = parseRupiah(value);
        case '#kc-phys':
          k['phys'] = _int(value);
          k['setor'] = null;
        case '#kc-setor':
          k['setor'] = _int(value);
        case '#kc-qr':
          k['qrisReal'] = value;
        case '#kc-fr':
          k['tfReal'] = value;
        case '#kc-note':
          note = value;
          return;
      }
    }
    host.refresh();
  }

  void _afterDen() {
    final k = kas, total = cashDenTotalA7(k);
    k['phys'] = total > 0 ? total : null;
    k['setor'] = null;
  }

  void tap(String selector, int index, String? child) {
    final k = kas;
    active = '';
    if (selector == '#cashclose .back') return host.go(back);
    if (selector == '#kc-den label') {
      final key = '${cashDenominations[index.clamp(0, cashDenominations.length - 1)]}', den = k['den'] as Map;
      final cur = (den[key] as num?)?.toInt() ?? 0, next = cur + (child == 'button:first-of-type' ? -1 : 1);
      den[key] = next < 0 ? 0 : next;
      _afterDen();
      return host.refresh();
    }
    if (selector != '#cashclose .kc137-go') return;
    final c = _summary(k), den = cashDenTotalA7(k);
    final phys = den > 0 ? den : (k['phys'] as num?)?.toInt();
    if (phys == null) return host.toast('Hitung uang di laci dulu');
    final d = phys - c['expect']!, n = note.trim();
    if (d != 0 && n.isEmpty) return host.toast('Ada selisih ${rp(d.abs())} · isi catatan dulu');
    host.openFormSheet(FormSheetDef(
      'Tutup kas sekarang?',
      const [],
      'Ya, Tutup Kas',
      (_) {
        _close(phys, d, n, c);
        return null;
      },
      sub: 'Uang fisik ${rp(phys)} · ${d == 0 ? 'kas pas' : '${d < 0 ? 'kurang ' : 'lebih '}${rp(d.abs())}'}. Setelah ditutup, shift baru dimulai.',
    ));
  }

  void _close(int phys, int d, String n, Map<String, int> c) {
    final b = host.business, k = kas, now = host.now, u = _unpaid;
    final start = (k['start'] as num?)?.toInt() ?? 0;
    final setor = k['setor'] == null ? (phys - start < 0 ? 0 : phys - start) : ((k['setor'] as num).toInt() > phys ? phys : (k['setor'] as num).toInt());
    String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    String mark(int sys, Object? real) {
      final r = '${real ?? ''}'.trim();
      if (r.isEmpty) return '';
      final diff = parseRupiah(r) - sys;
      return diff == 0 ? ' ✓' : ' ⚠ selisih ${diff < 0 ? '−' : '+'}${rp(diff.abs())}';
    }

    lastText = '*TUTUP KAS · GOYANA ${'${k['outlet'] ?? ''}'.toUpperCase()}*\n${_tgl(now)} · ${k['openAt'] ?? ''}–${hm(now)}\nKasir: ${k['kasir'] ?? ''}\n\n'
        '*Penjualan* (${(k['sales'] as List? ?? const []).length} trx)\nTunai     : ${rp(c['t']!)}\nQRIS      : ${rp(c['q']!)}${mark(c['q']!, k['qrisReal'])}\nTransfer  : ${rp(c['f']!)}${mark(c['f']!, k['tfReal'])}\n*Omset     : ${rp(c['omset']!)}*\n'
        '${u.n > 0 ? 'Belum bayar: ${u.n} pesanan (${rp(u.a)})\n' : ''}'
        '\n*Laci*\nModal awal : ${rp(start)}\nKas masuk  : ${rp(c['ins']!)}\nPengeluaran: ${rp(c['outs']!)}\nSeharusnya : ${rp(c['expect']!)}\nUang fisik : ${rp(phys)}\n*Selisih    : ${d == 0 ? 'PAS ✓' : '${d < 0 ? 'KURANG ' : 'LEBIH '}${rp(d.abs())}'}*\n\nDisetor : ${rp(setor)}\nSisa laci: ${rp(phys - setor)}${n.isEmpty ? '' : '\nCatatan: $n'}';
    try {
      final after = closeCashA7(
        before: {cashBusinessKey: jsonEncode(b.raw)},
        inputs: {'start': start, 'phys': phys, 'den': Map<String, dynamic>.from(k['den'] as Map? ?? const {}), 'qrisReal': '${k['qrisReal'] ?? ''}', 'tfReal': '${k['tfReal'] ?? ''}', 'setor': k['setor']},
        at: now,
        note: n,
      );
      final next = jsonDecode(after[cashBusinessKey] as String) as Map<String, dynamic>;
      b.raw
        ..clear()
        ..addAll(next);
    } catch (_) {
      return host.toast('Gagal menyimpan tutup kas. Coba lagi.');
    }
    addAudit(host, '✓', 'Tutup kas', '${k['kasir'] ?? ''} · omset ${rp(c['omset']!)} · ${d == 0 ? 'pas' : '${d < 0 ? 'kurang ' : 'lebih '}${rp(d.abs())}'}');
    host.saveAll();
    note = '';
    doneSub = 'Shift baru dimulai ${hm(now)} · modal laci ${rp((host.business.kas['start'] as num?) ?? 0)}';
    host.openPageSheet('kc137s');
    host.refresh();
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) => id != 'kc137s'
      ? null
      : [
          {'type': 'title', 't': 'Kas Ditutup ✓', 's': ''},
          {'type': 'hint', 't': doneSub},
          {'type': 'hint', 't': lastText},
          {'type': 'buttons', 'options': [
            {'t': 'Kirim WA Owner', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 0},
            {'t': 'Selesai', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1},
          ]},
        ];

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (kind != 'button') return;
    if (index == 0) host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/?text=${Uri.encodeComponent(lastText)}'}).catchError((_) => null);
    host.closePageSheet('kc137s');
  }
}
