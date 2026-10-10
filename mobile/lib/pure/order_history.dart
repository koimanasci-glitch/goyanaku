// Riwayat Transaksi & Koreksi Transaksi (keputusan Paduka 10 Oktober 2026, pengganti jatah koreksi).
// Sumbernya catatan server (order_events): siapa membuat, membayar, mengubah, mengembalikan uang, membatalkan, dan memajukan tahap.
// Perubahan setelah pesanan diproses atau dibayar ditandai, dan laporan koreksi merangkumnya per kasir.

import '../core/money.dart';
import 'pages.dart';
import 'server_sync.dart' show ServerFailure;

String _two(int n) => n.toString().padLeft(2, '0');

String _when(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return t == null ? '' : '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}.${_two(t.minute)}';
}

String _qty(Object? q) {
  final n = q is num ? q : num.tryParse('$q') ?? 0;
  return n == n.roundToDouble() ? '${n.round()}' : '$n'.replaceAll('.', ',');
}

String _items(Object? list) {
  final l = list is List ? list.whereType<Map>().toList() : const <Map>[];
  if (l.isEmpty) return 'kosong';
  return l.map((i) => '${i['n']} ${_qty(i['q'])}').join(', ');
}

int _int(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;

const _stageNames = {
  'jemput': 'Penjemputan', 'antrian': 'Antrian', 'cuci': 'Cuci', 'kering': 'Kering', 'setrika': 'Setrika', 'packing': 'Packing',
  'selesaiproses': 'Selesai Proses', 'siap': 'Siap Ambil', 'telat': 'Telat', 'diantar': 'Diantar', 'diambil': 'Selesai', 'batal': 'Batal',
};
String _stage(Object? s) => _stageNames['$s'] ?? '${s ?? ''}';

/// Satu kejadian: [judul, rincian, tanda] — tanda kosong = biasa.
(String, String, String) historyText(Map e) {
  final d = e['details'] is Map ? e['details'] as Map : const {};
  switch ('${e['kind']}') {
    case 'buat':
      return ('Pesanan dibuat', _stage(e['to']), '');
    case 'bayar':
      return ('Dibayar ${d['method'] ?? ''} ${rp(_int(d['amount']))}'.replaceAll('  ', ' '), '', '');
    case 'isi':
      return ('Ditimbang / diisi', '${_items((d['after'] as Map?)?['items'])} · ${rp(_int((d['after'] as Map?)?['total']))}', '');
    case 'ubah':
      final b = d['before'] is Map ? d['before'] as Map : const {}, a = d['after'] is Map ? d['after'] as Map : const {};
      final flag = d['flag'] == true;
      final why = _int(d['paid_before']) > 0 ? 'Setelah dibayar' : 'Setelah diproses';
      return ('Diubah · ${rp(_int(b['total']))} → ${rp(_int(a['total']))}', '${_items(b['items'])} → ${_items(a['items'])}', flag ? why : '');
    case 'kembali':
      return ('Uang dikembalikan ${rp(_int(d['amount']))}', '', 'Pengembalian');
    case 'batal':
      final paid = _int(d['paid']);
      return ('Dibatalkan', paid > 0 ? 'sudah dibayar ${rp(paid)}' : '', paid > 0 ? 'Batal setelah bayar' : '');
    case 'timbang':
      return ('Timbangan kurir dicek kasir', d['changed'] == true ? 'ada perubahan berat' : 'sesuai', '');
    case 'mundur':
      return ('Tahap mundur ${_stage(e['from'])} → ${_stage(e['to'])}', '${d['reason'] ?? ''}', 'Mundur');
    case 'lompat':
      return ('Tahap ${_stage(e['from'])} → ${_stage(e['to'])}', 'melewati ${(d['skipped'] as List?)?.join(', ') ?? ''}', '');
    default:
      final item = d['item'] == null ? '' : ' · ${d['item']}';
      return ('Tahap ${_stage(e['from'])} → ${_stage(e['to'])}$item'.replaceAll('Tahap  → ', 'Tahap '), d['auto'] == true ? 'otomatis' : '', '');
  }
}

/// Butir popup Riwayat Transaksi satu nota.
List<Map<String, dynamic>> historySheetItems(String orderId, List events, {required bool showOutlet, String note = ''}) {
  final out = <Map<String, dynamic>>[
    {'type': 'title', 't': 'Riwayat Transaksi', 's': orderId},
    if (note.isNotEmpty) {'type': 'hint', 't': note},
  ];
  for (final e in events.whereType<Map>()) {
    final (t, sub, flag) = historyText(e);
    out.add({
      'type': 'entry', 't': t,
      'lines': [if (sub.isNotEmpty) sub, '${_when(e['at'])} · ${e['by'] ?? ''}${showOutlet && '${e['outlet_name'] ?? ''}'.isNotEmpty ? ' · ${e['outlet_name']}' : ''}'],
      'badge': flag.isEmpty ? '' : '⚠ $flag', 'avatar': '', 'svg': '', 'color': flag.isEmpty ? '' : 'r', 'amount': '', 'btns': <dynamic>[],
    });
  }
  if (events.isEmpty && note.isEmpty) out.add({'type': 'hint', 't': 'Belum ada catatan di server untuk nota ini.'});
  out.add({'type': 'hint', 't': 'Dicatat server dari setiap HP. Tidak bisa diubah atau dihapus.'});
  out.add({'type': 'button', 't': 'Tutup', 'primary': false, 'file': '', 'after': false, 'i': 0});
  return out;
}

/// Pengaturan → Audit Aktivitas → Koreksi Transaksi: perubahan setelah diproses/dibayar, pengembalian uang, batal setelah bayar.
class CorrectionsPage extends PurePage {
  CorrectionsPage(super.host);

  @override
  String get title => 'KOREKSI TRANSAKSI';
  @override
  String get back => 'audit';

  static const _periods = [['Bulan ini', 'month'], ['Bulan lalu', 'last'], ['7 hari', '7']];
  int _period = 0, _outlet = 0; // _outlet 0 = semua cabang (pemilik)
  Map<String, dynamic>? _data;
  String _note = '';

  bool get _owner => host.server.isOwner;

  @override
  void opened() {
    _period = 0;
    _outlet = 0;
    _load();
  }

  (DateTime, DateTime) _range() {
    final n = host.now;
    return switch (_periods[_period][1]) {
      'last' => (DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0)),
      '7' => (n.subtract(const Duration(days: 6)), n),
      _ => (DateTime(n.year, n.month, 1), n),
    };
  }

  String _d(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  Future<void> _load() async {
    if (!host.server.loggedIn) {
      _note = 'Masuk ke akun GOYANA dulu. Koreksi transaksi dihitung server dari semua HP.';
      return host.refresh();
    }
    _note = 'Memuat koreksi…';
    _data = null;
    host.refresh();
    final (from, to) = _range();
    final outs = [for (final o in host.business.outlets) if (o.id.startsWith('srv-')) o];
    final pick = _owner && _outlet > 0 && _outlet <= outs.length ? '&outlet_id=${outs[_outlet - 1].id.substring(4)}' : '';
    try {
      _data = await host.server.api('GET', '/corrections?from=${_d(from)}&to=${_d(to)}$pick');
      _note = '';
    } on ServerFailure catch (e) {
      _note = e.offline ? 'Butuh internet untuk memuat koreksi transaksi.' : e.message;
    }
    host.refresh();
  }

  @override
  List<Map<String, dynamic>> items() {
    final outs = [for (final o in host.business.outlets) if (o.id.startsWith('srv-')) o];
    final data = _data;
    final people = (data?['people'] as List? ?? const []).whereType<Map>().toList();
    final events = (data?['events'] as List? ?? const []).whereType<Map>().toList();
    return [
      {'type': 'hint', 't': 'Pesanan yang diubah setelah diproses atau dibayar, uang yang dikembalikan, dan batal setelah bayar. Tidak memblokir kasir, hanya mencatat.'},
      {'type': 'buttons', 'options': [for (var k = 0; k < _periods.length; k++) {'t': _periods[k][0], 'on': k == _period, 'i': 10 + k}]},
      if (_owner && outs.length > 1)
        {'type': 'buttons', 'options': [
          {'t': 'Semua Cabang', 'on': _outlet == 0, 'i': 20},
          for (var k = 0; k < outs.length; k++) {'t': outs[k].name, 'on': _outlet == k + 1, 'i': 21 + k},
        ]},
      if (_note.isNotEmpty) {'type': 'hint', 't': _note},
      if (data != null) ...[
        {'type': 'title', 't': 'Per kasir'},
        if (people.isEmpty) {'type': 'hint', 't': 'Tidak ada koreksi pada periode ini.'},
        for (final p in people)
          {
            'type': 'entry', 't': '${p['name']}',
            'lines': ['${p['count']} koreksi · ${p['lowered']} menurunkan nilai${_int(p['refund']) > 0 ? ' · uang kembali ${rp(_int(p['refund']))}' : ''}'],
            'badge': '', 'avatar': '${p['name']}'.isEmpty ? '?' : '${p['name']}'[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[],
          },
        if (events.isNotEmpty) {'type': 'title', 't': 'Rincian'},
        for (var k = 0; k < events.length; k++)
          () {
            final (t, sub, flag) = historyText(events[k]);
            return {
              'type': 'entry', 't': '${events[k]['key']} · $t',
              'lines': [if (sub.isNotEmpty) sub, '${_when(events[k]['at'])} · ${events[k]['by']}${_owner ? ' · ${events[k]['outlet_name']}' : ''}'],
              'badge': flag.isEmpty ? '' : '⚠ $flag', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
              'btns': [{'t': 'Buka Nota', 'on': false, 'i': 1000 + k}],
            };
          }(),
      ],
    ];
  }

  @override
  void button(int i) {
    if (i >= 10 && i < 10 + _periods.length) {
      _period = i - 10;
      _load();
      return;
    }
    if (i >= 20 && i < 1000) {
      _outlet = i - 20;
      _load();
      return;
    }
    if (i >= 1000) {
      final events = (_data?['events'] as List? ?? const []).whereType<Map>().toList();
      if (i - 1000 >= events.length) return;
      final key = '${events[i - 1000]['key']}';
      if (host.business.orderById(key) == null) return host.toast('Nota $key belum ada di HP ini');
      host.openOrder(key);
    }
  }
}
