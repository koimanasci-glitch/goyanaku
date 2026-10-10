// Komplain & Klaim (Tahap 2 fitur 9, 10 Oktober 2026): Kelola Usaha › Operasional. Semua paket.
// Kasir mencatat komplain per nota (kurang/hilang, rusak, luntur, kurang bersih, telat, lainnya), memproses, dan
// menyelesaikan dengan cuci ulang gratis, damai, atau ditolak. Ganti rugi uang diputuskan pemilik/kepala cabang dan
// dicatat sebagai pengeluaran laci kas. Foto cucian saat masuk/diambil (Foto Dokumentasi di nota) jadi bukti.
// Tersinkron ke server per cabang (koleksi complaints, App\Support\CaseGuard).

import 'dart:convert';

import '../core/models.dart' show Order;
import '../core/money.dart';
import 'pages.dart';
import 'server_sync.dart' show complaintsKey;

class ComplaintPage extends PurePage {
  ComplaintPage(super.host);

  static const types = [['kurang', 'Kurang / hilang'], ['rusak', 'Rusak / sobek'], ['luntur', 'Luntur'], ['kotor', 'Kurang bersih / bau'], ['telat', 'Telat selesai'], ['lain', 'Lainnya']];
  static const results = [['ulang', 'Cuci ulang gratis'], ['ganti', 'Ganti rugi uang'], ['damai', 'Damai / potongan nota berikut'], ['tolak', 'Ditolak']];
  static const _form = 'kp-form', _done = 'kp-done';

  List<Map<String, dynamic>> _list = [];
  int _filter = 0; // 0 terbuka, 1 selesai, 2 semua
  String _query = '', _order = '', _note = '', _amount = '';
  int _type = 0, _result = 0;
  String _cur = '';

  @override
  String get title => 'KOMPLAIN & KLAIM';
  @override
  String get back => 'kelola';

  @override
  void opened() {
    _filter = 0;
    _load();
  }

  Future<void> _load() async {
    final raw = await host.kv.get(complaintsKey);
    try {
      _list = [for (final c in (jsonDecode(raw ?? '[]') as List).whereType<Map>()) Map<String, dynamic>.from(c)];
    } catch (_) {
      _list = [];
    }
    host.refresh();
  }

  Future<void> _store() async {
    await host.kv.set(complaintsKey, jsonEncode(_list));
    await host.saveAll();
  }

  bool get _boss => !host.server.loggedIn || const ['owner', 'manager'].contains(host.server.role);
  String get _me => host.server.loggedIn ? '${host.server.user['name'] ?? ''}' : 'Admin';
  static String _label(List<List<String>> l, Object? k) => l.where((e) => e[0] == '$k').firstOrNull?[1] ?? '$k';
  int _photos(String order) {
    final ph = host.business.orderById(order)?.detail['photos'];
    return ph is Map ? [...(ph['in'] as List? ?? const []), ...(ph['out'] as List? ?? const [])].length : 0;
  }

  List<Map<String, dynamic>> get _shown {
    final l = _list.reversed.where((c) => _filter == 2 || (_filter == 1) == (c['status'] == 'selesai')).toList();
    return l;
  }

  String _when(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return t == null ? '' : '${two(t.day)}/${two(t.month)} ${two(t.hour)}.${two(t.minute)}';
  }

  @override
  List<Map<String, dynamic>> items() {
    final open = _list.where((c) => c['status'] != 'selesai').length;
    final shown = _shown;
    return [
      {'type': 'hint', 't': 'Catat keluhan pelanggan per nota. Foto cucian saat masuk & diambil (menu ⋮ nota › Foto) jadi bukti.'},
      {'type': 'button', 't': '+ Komplain Baru', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'buttons', 'cols': 3, 'options': [
        {'t': 'Terbuka ($open)', 'on': _filter == 0, 'i': 10},
        {'t': 'Selesai', 'on': _filter == 1, 'i': 11},
        {'t': 'Semua', 'on': _filter == 2, 'i': 12},
      ]},
      if (shown.isEmpty) {'type': 'hint', 't': _filter == 0 ? 'Tidak ada komplain terbuka.' : 'Belum ada komplain.'},
      for (var k = 0; k < shown.length && k < 100; k++) _row(shown[k], k),
    ];
  }

  Map<String, dynamic> _row(Map<String, dynamic> c, int k) {
    final st = '${c['status'] ?? 'baru'}';
    final n = _photos('${c['order']}');
    final res = st == 'selesai'
        ? '✅ ${_label(results, c['result'])}${(c['amount'] as num? ?? 0) > 0 ? ' ${rp(c['amount'] as num)}' : ''}${'${c['closedBy'] ?? ''}'.isEmpty ? '' : ' · ${c['closedBy']}'}'
        : (st == 'proses' ? '🔧 Sedang ditangani' : '🆕 Baru');
    return {
      'type': 'entry', 't': '${c['order']} · ${c['customer'] ?? ''}',
      'lines': [
        '${_label(types, c['type'])}${'${c['note'] ?? ''}'.isEmpty ? '' : ' · ${c['note']}'}',
        '$res · ${_when(c['at'])}${'${c['by'] ?? ''}'.isEmpty ? '' : ' · ${c['by']}'}',
        n > 0 ? '📷 $n foto cucian' : '📷 Belum ada foto cucian',
      ],
      'badge': st == 'selesai' ? '' : '⚠', 'avatar': st == 'selesai' ? '✅' : '❗', 'svg': '', 'color': '', 'amount': '',
      'btns': [
        {'t': 'Buka Nota', 'on': false, 'i': 1000 + k},
        if (st == 'baru') {'t': 'Proses', 'on': false, 'i': 2000 + k},
        if (st != 'selesai') {'t': 'Selesaikan', 'on': false, 'i': 3000 + k},
      ],
    };
  }

  List<Order> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return host.business.orders.where((o) => o.id.toLowerCase().contains(q) || o.name.toLowerCase().contains(q)).take(5).toList();
  }

  @override
  void button(int i) {
    if (i == 0) {
      _query = _order = _note = '';
      _type = 0;
      return host.openPageSheet(_form);
    }
    if (i >= 10 && i <= 12) {
      _filter = i - 10;
      return host.refresh();
    }
    final shown = _shown;
    final k = i % 1000;
    if (i < 1000 || k >= shown.length) return;
    final c = shown[k];
    switch (i ~/ 1000) {
      case 1:
        if (host.business.orderById('${c['order']}') == null) return host.toast('Nota ${c['order']} belum ada di HP ini');
        return host.openOrder('${c['order']}');
      case 2:
        _update(c, {'status': 'proses'}, 'Komplain sedang ditangani');
      case 3:
        _cur = '${c['id']}';
        _result = 0;
        _amount = _note = '';
        host.openPageSheet(_done);
    }
  }

  Map<String, dynamic> _inp(String v, String ph, int i, {bool numeric = false}) =>
      {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id == _form) {
      final o = _order.isEmpty ? null : host.business.orderById(_order);
      final m = _matches;
      return [
        {'type': 'title', 't': 'Komplain Baru', 's': ''},
        {'type': 'label', 't': 'Nota'},
        if (o != null)
          {'type': 'entry', 't': '${o.id} · ${o.name}', 'lines': ['${_photos(o.id)} foto cucian'], 'badge': '', 'avatar': '🧾', 'svg': '', 'color': '', 'amount': rp(o.total), 'btns': [{'t': 'Ganti', 'on': false, 'i': 99}]}
        else ...[
          _inp(_query, 'Ketik nomor nota atau nama pelanggan', 0),
          for (var k = 0; k < m.length; k++) {'type': 'button', 't': '${m[k].id} · ${m[k].name}', 'primary': false, 'file': '', 'after': false, 'i': 100 + k},
        ],
        {'type': 'label', 't': 'Jenis komplain'},
        {'type': 'select', 'options': [for (final t in types) t[1]], 'index': _type, 'i': 1},
        {'type': 'label', 't': 'Keterangan'},
        _inp(_note, 'Mis. kemeja putih kena warna', 2),
        {'type': 'button', 't': 'Simpan Komplain', 'primary': true, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
      ];
    }
    if (id == _done) {
      final ganti = results[_result][0] == 'ganti';
      return [
        {'type': 'title', 't': 'Selesaikan Komplain', 's': ''},
        {'type': 'label', 't': 'Hasil'},
        {'type': 'select', 'options': [for (final r in results) r[1]], 'index': _result, 'i': 0},
        if (ganti) ...[
          {'type': 'label', 't': 'Jumlah ganti rugi'},
          _inp(_amount, 'Rp', 1, numeric: true),
          {'type': 'hint', 't': _boss ? 'Dicatat sebagai pengeluaran laci kas HP ini.' : 'Ganti rugi uang diputuskan pemilik atau kepala cabang.'},
        ],
        {'type': 'label', 't': 'Catatan penyelesaian'},
        _inp(_note, 'Opsional', 2),
        {'type': 'button', 't': 'Simpan', 'primary': true, 'file': '', 'after': false, 'i': 0},
        {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
      ];
    }
    return null;
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    final v = '${value ?? ''}';
    if (id == _form) {
      if (kind == 'input') {
        if (index == 0) {
          _query = v;
          host.refresh();
        }
        if (index == 1) _type = (value is int ? value : int.tryParse(v) ?? 0).clamp(0, types.length - 1);
        if (index == 2) _note = v;
        return;
      }
      if (kind != 'button') return;
      if (index == 1) return host.closePageSheet(_form);
      if (index == 99) {
        _order = '';
        return host.refresh();
      }
      if (index >= 100) {
        final m = _matches;
        if (index - 100 < m.length) _order = m[index - 100].id;
        return host.refresh();
      }
      _create();
      return;
    }
    if (id == _done) {
      if (kind == 'input') {
        if (index == 0) {
          _result = (value is int ? value : int.tryParse(v) ?? 0).clamp(0, results.length - 1);
          host.refresh();
        }
        if (index == 1) _amount = v;
        if (index == 2) _note = v;
        return;
      }
      if (kind != 'button') return;
      if (index == 1) return host.closePageSheet(_done);
      _finish();
    }
  }

  Future<void> _create() async {
    final o = _order.isEmpty ? null : host.business.orderById(_order);
    if (o == null) return host.toast('Pilih nota yang dikomplain');
    final n = host.now;
    final c = {
      'id': 'kp-${n.microsecondsSinceEpoch}', 'order': o.id, 'customer': o.name, 'type': types[_type][0], 'note': _note.trim(),
      'status': 'baru', 'at': n.toUtc().toIso8601String(), 'by': _me, 'o': o.outlet.isNotEmpty ? o.outlet : host.business.activeOutlet,
    };
    _list.add(c);
    addAudit(host, '❗', 'Komplain ${o.id}', '${_label(types, c['type'])}${_note.trim().isEmpty ? '' : ' · ${_note.trim()}'}', outlet: '${c['o']}');
    await _store();
    host.closePageSheet(_form);
    host.toast(_photos(o.id) == 0 ? 'Komplain tersimpan · belum ada foto cucian nota ini' : 'Komplain tersimpan');
    host.refresh();
  }

  Future<void> _update(Map<String, dynamic> c, Map<String, dynamic> change, String toast) async {
    final i = _list.indexWhere((x) => x['id'] == c['id']);
    if (i < 0) return;
    _list[i] = {..._list[i], ...change};
    await _store();
    host.toast(toast);
    host.refresh();
  }

  Future<void> _finish() async {
    final c = _list.where((x) => x['id'] == _cur).firstOrNull;
    if (c == null) return host.closePageSheet(_done);
    final r = results[_result][0];
    final amount = r == 'ganti' ? parseRupiah(_amount) : 0;
    if (r == 'ganti') {
      if (!_boss) return host.toast('Ganti rugi uang diputuskan pemilik atau kepala cabang');
      if (amount <= 0) return host.toast('Isi jumlah ganti rugi');
    }
    final n = host.now;
    if (amount > 0) {
      host.business.kasEntry(income: false, type: 'Ganti rugi komplain ${c['order']}', amount: amount, now: n);
    }
    addAudit(host, '✅', 'Komplain ${c['order']} selesai', '${results[_result][1]}${amount > 0 ? ' ${rp(amount)}' : ''}', outlet: '${c['o'] ?? ''}');
    host.closePageSheet(_done);
    await _update(c, {
      'status': 'selesai', 'result': r, if (amount > 0) 'amount': amount, 'resNote': _note.trim(), 'closedAt': n.toUtc().toIso8601String(), 'closedBy': _me,
    }, 'Komplain selesai');
  }
}
