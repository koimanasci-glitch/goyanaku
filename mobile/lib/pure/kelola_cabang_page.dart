// Kelola Cabang Ini (Tahap 2, 10 Oktober 2026): pemilik mencatat untuk satu cabang tertentu dari HP-nya —
// kas masuk, tarik uang, pengeluaran, stok masuk, kirim stok, minta cek stok, dan koreksi nota — dengan banner oranye
// "Simpan ke Cabang X" supaya tidak salah cabang. Catatan kas cabang lain dikirim lewat server ke laci kas HP kasir
// cabang itu (App\Support\BranchTask); cabang rumah HP ini langsung masuk laci HP ini.

import 'dart:convert';

import '../core/money.dart';
import '../core/stock.dart';
import 'pages.dart';
import 'server_sync.dart' show ServerSync, branchTasksKey, branchCashKinds;

class KelolaCabangPage extends PurePage {
  KelolaCabangPage(super.host);

  /// Cabang yang dikelola (id lokal, atau `srv-N`).
  static String outletId = '';
  static const _form = 'kc-form';

  /// [jenis, judul tombol, keterangan]
  static const kinds = [
    ['kas_in', 'Kas Masuk', 'Tambah uang ke laci kas cabang (mis. uang kembalian)'],
    ['kas_out', 'Tarik Uang', 'Pemilik mengambil uang dari laci kas cabang'],
    ['expense', 'Pengeluaran', 'Belanja/biaya cabang dibayar dari laci kas cabang'],
    ['opname', 'Minta Cek Stok', 'Minta cabang menghitung stok bahan (stock opname)'],
  ];

  List<Map<String, dynamic>> _tasks = [];
  StockBook? _stock;
  int _kind = 0;
  String _amount = '', _note = '';

  @override
  String get title => 'KELOLA CABANG INI';
  @override
  String get back => 'cabang';

  @override
  void opened() {
    _load();
  }

  Future<void> _load() async {
    final raw = await host.kv.get(branchTasksKey);
    final list = raw == null || raw.isEmpty ? const [] : (jsonDecode(raw) as List? ?? const []);
    _tasks = [for (final t in list.whereType<Map>()) Map<String, dynamic>.from(t)];
    _stock = await StockBook.load(host.kv);
    host.refresh();
  }

  bool get _home => outletId == host.business.activeOutlet;
  bool get _online => host.server.isOwner && ServerSync.outletNumber(outletId) != null;
  String _name(String id) => host.business.outlets.where((o) => o.id == id).firstOrNull?.name ?? 'cabang';

  /// Permintaan cek stok selesai bila sudah ada catatan Cek Stok di cabang itu setelah diminta.
  bool _opnameDone(Map t) {
    final at = '${t['at'] ?? ''}';
    return ((_stock?.raw['ledger'] as List?) ?? const []).whereType<Map>()
        .any((x) => x['type'] == 'Stock Opname' && '${x['outletId']}' == outletId && '${x['at'] ?? ''}'.compareTo(at) > 0);
  }

  List<Map<String, dynamic>> get _mine => [for (final t in _tasks.reversed) if ('${t['o']}' == outletId) t];

  @override
  List<Map<String, dynamic>> items() {
    final o = host.business.outlets.where((x) => x.id == outletId).firstOrNull;
    if (o == null) return [{'type': 'hint', 't': 'Cabang tidak ditemukan.'}];
    final remoteOk = _home || _online;
    Map<String, dynamic> btn(String t, int i) => {'t': t, 'on': false, 'i': i};
    final mine = _mine;
    return [
      if (_home)
        {'type': 'hint', 't': '🏠 Ini cabang rumah HP ini: kas langsung masuk laci kas HP ini.'}
      else
        {'type': 'banner', 't': 'Simpan ke Cabang ${o.name}', 's': 'Semua yang dicatat di halaman ini masuk ke ${o.name}, bukan ke ${_name(host.business.activeOutlet)} (cabang rumah HP ini).'},
      {'type': 'title', 't': 'Kas cabang'},
      if (!remoteOk) {'type': 'hint', 't': 'Kas cabang lain dikirim lewat server: masuk ke akun GOYANA sebagai pemilik dan tunggu cabang ini tersimpan di server.'},
      {'type': 'buttons', 'cols': 3, 'options': [btn('Kas Masuk', 1), btn('Tarik Uang', 2), btn('Pengeluaran', 3)]},
      if (!_home) {'type': 'hint', 't': 'Masuk ke laci kas HP kasir cabang ini saat HP itu tersambung, sehingga tutup omset cabang tetap cocok.'},
      {'type': 'title', 't': 'Stok cabang'},
      {'type': 'buttons', 'cols': 3, 'options': [btn('Stok Masuk', 4), btn('Kirim Stok', 5), btn('Minta Cek Stok', 6)]},
      {'type': 'title', 't': 'Nota cabang'},
      {'type': 'button', 't': 'Koreksi Nota Cabang Ini', 'primary': false, 'file': '', 'after': false, 'i': 7},
      {'type': 'hint', 't': 'Buka nota cabang ini lalu ubah. Perubahan setelah diproses/dibayar tercatat di Koreksi Transaksi.'},
      if (mine.isNotEmpty) {'type': 'title', 't': 'Catatan untuk cabang ini'},
      for (var k = 0; k < mine.length && k < 50; k++) _row(mine[k], k),
    ];
  }

  Map<String, dynamic> _row(Map<String, dynamic> t, int k) {
    final kind = '${t['kind']}';
    final label = kinds.where((e) => e[0] == kind).firstOrNull?[1] ?? kind;
    final cash = branchCashKinds.contains(kind);
    final done = cash ? '${t['claimedBy'] ?? ''}'.isNotEmpty : _opnameDone(t);
    final at = DateTime.tryParse('${t['at'] ?? ''}')?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final when = at == null ? '' : '${two(at.day)}/${two(at.month)} ${two(at.hour)}.${two(at.minute)}';
    return {
      'type': 'entry', 't': '$label${'${t['note'] ?? ''}'.isEmpty ? '' : ' · ${t['note']}'}',
      'lines': ['$when · ${done ? (cash ? '✅ sudah masuk laci kas cabang' : '✅ sudah dicek') : (cash ? '⏳ menunggu HP kasir cabang' : '⏳ menunggu dicek')}'],
      'badge': '', 'avatar': cash ? (kind == 'kas_in' ? '⬇' : '⬆') : '📋', 'svg': '', 'color': '',
      'amount': cash ? '${kind == 'kas_in' ? '+' : '-'}${rp((t['amount'] as num?) ?? 0)}' : '',
      'btns': [if (!done) {'t': 'Batalkan', 'on': false, 'i': 100 + k}],
    };
  }

  @override
  void button(int i) {
    switch (i) {
      case 1 || 2 || 3 || 6:
        if (!_home && !_online) return host.toast('Butuh akun pemilik di server untuk mencatat ke cabang lain');
        if (i == 6 && _home) {
          StockPage.nextOutlet = outletId;
          return host.go('stock');
        }
        _kind = i == 6 ? 3 : i - 1;
        _amount = _note = '';
        return host.openPageSheet(_form);
      case 4 || 5:
        StockPage.nextOutlet = outletId;
        if (i == 5) host.toast('Pilih "Kirim ke Cabang Lain" di bawah');
        return host.go('stock');
      case 7:
        BranchMonitorPage.outletId = outletId;
        BranchMonitorPage.startTab = 1;
        return host.go('branchmonitor58');
    }
    final mine = _mine;
    if (i >= 100 && i - 100 < mine.length) _cancel(mine[i - 100]);
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id != _form) return null;
    final k = kinds[_kind], cash = branchCashKinds.contains(k[0]);
    Map<String, dynamic> inp(String v, String ph, int i, {bool numeric = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    final name = _name(outletId);
    return [
      {'type': 'title', 't': '${k[1]} · $name', 's': ''},
      if (!_home) {'type': 'banner', 't': 'Simpan ke Cabang $name', 's': k[2]},
      if (_home) {'type': 'hint', 't': k[2]},
      if (cash) ...[
        {'type': 'label', 't': 'Jumlah'},
        inp(_amount, 'Rp', 0, numeric: true),
      ],
      {'type': 'label', 't': cash ? 'Keterangan' : 'Catatan untuk cabang'},
      inp(_note, k[0] == 'expense' ? 'Mis. beli gas, listrik' : (cash ? 'Opsional' : 'Mis. cek deterjen & parfum'), 1),
      {'type': 'button', 't': _home ? 'Simpan' : 'Simpan ke $name', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id != _form) return;
    if (kind == 'input') {
      if (index == 0) _amount = '${value ?? ''}';
      if (index == 1) _note = '${value ?? ''}';
      return;
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet(_form);
    _save();
  }

  Future<void> _save() async {
    final k = kinds[_kind], cash = branchCashKinds.contains(k[0]);
    final amount = parseRupiah(_amount);
    if (cash && amount <= 0) return host.toast('Isi jumlah uang');
    final note = _note.trim();
    final name = _name(outletId), now = host.now;
    if (_home && cash) {
      // Cabang rumah HP ini: langsung ke laci kas HP ini, sama dengan menu Kas.
      host.business.kasEntry(income: k[0] == 'kas_in', type: note.isEmpty ? k[1] : '${k[1]} · $note', amount: amount, now: now);
    } else {
      _tasks.add({
        'id': 'bt-${now.microsecondsSinceEpoch}', 'kind': k[0], if (cash) 'amount': amount, 'note': note, 'o': outletId,
        'at': now.toUtc().toIso8601String(), 'by': '${host.server.user['name'] ?? ''}',
      });
      await host.kv.set(branchTasksKey, jsonEncode(_tasks));
    }
    addAudit(host, cash ? '💵' : '📋', '${k[1]} · $name', cash ? '${rp(amount)}${note.isEmpty ? '' : ' · $note'}' : note, outlet: outletId);
    await host.saveAll();
    host.closePageSheet(_form);
    host.toast(_home ? '${k[1]} tersimpan' : '${k[1]} tersimpan ke $name');
    host.refresh();
  }

  Future<void> _cancel(Map<String, dynamic> t) async {
    if ('${t['claimedBy'] ?? ''}'.isNotEmpty) return host.toast('Sudah masuk ke laci kas cabang');
    _tasks.removeWhere((x) => x['id'] == t['id']);
    await host.kv.set(branchTasksKey, jsonEncode(_tasks));
    addAudit(host, '↩', 'Catatan cabang dibatalkan', '${t['kind']} · ${_name(outletId)}', outlet: outletId);
    await host.saveAll();
    host.toast('Catatan dibatalkan');
    host.refresh();
  }
}
