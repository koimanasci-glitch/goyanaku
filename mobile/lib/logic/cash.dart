// A7 cash arithmetic and close projection; HTML remains the storage writer.
import 'dart:convert';

const cashBusinessKey = 'goyana-business177';
const cashDenominations = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500];
const _maxSafe = 9007199254740991;
int _n(Object? n) => n is num ? n.toInt() : int.tryParse('$n') ?? 0;
String _rp(int n) =>
    '${n < 0 ? '−' : ''}Rp${n.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
String _format(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
Map<String, dynamic> _clone(Map m) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(m)) as Map);

Map<String, int> cashSummaryA7(Map kas) {
  var t = 0, q = 0, f = 0, deposit = 0, ins = 0, ntIns = 0, outs = 0;
  for (final s in (kas['sales'] as List? ?? const []).whereType<Map>()) {
    switch (s['m']) {
      case 'Tunai':
        t += _n(s['a']);
      case 'QRIS':
        q += _n(s['a']);
      case 'Transfer':
        f += _n(s['a']);
      case 'Deposit':
        deposit += _n(s['a']);
      default:
        throw StateError('Unknown sales method');
    }
  }
  for (final s in (kas['ins'] as List? ?? const []).whereType<Map>()) {
    if (s['m'] == 'Non-Tunai') {
      ntIns += _n(s['a']);
    } else {
      ins += _n(s['a']);
    }
  }
  for (final s in (kas['outs'] as List? ?? const []).whereType<Map>()) {
    if (s['m'] != 'Non-Tunai') outs += _n(s['a']);
  }
  return {
    't': t,
    'q': q,
    'f': f,
    'omset': t + q + f + deposit,
    'ins': ins,
    'outs': outs,
    'expect': _n(kas['start']) + t + ins - outs,
    'nt': q + f + ntIns,
  };
}

int cashDenTotalA7(Map kas) {
  final den = kas['den'] as Map? ?? const {};
  return cashDenominations.fold(0, (n, d) => n + d * _n(den['$d']));
}

/// Cash close uses live start/physical/deposit inputs, not a copied after snapshot.
Map<String, dynamic> closeCashA7({
  required Map<String, dynamic> before,
  required Map<String, dynamic> inputs,
  required DateTime at,
  required String note,
}) {
  final result = _clone(before);
  final b =
      jsonDecode(result[cashBusinessKey] as String) as Map<String, dynamic>;
  const allowed = {'start', 'phys', 'den', 'qrisReal', 'tfReal', 'setor'};
  if (inputs.keys.any((key) => !allowed.contains(key))) {
    throw StateError('Only cash close fields may change');
  }
  final k = _clone(b['kas'] as Map)..addAll(_clone(inputs));
  for (final key in ['start', 'phys', 'setor']) {
    final value = k[key];
    if (value != null &&
        (value is! num ||
            value != value.toInt() ||
            value < 0 ||
            value > _maxSafe)) {
      throw StateError('Invalid $key');
    }
  }
  for (final value in (k['den'] as Map? ?? const {}).values) {
    if (value is! num ||
        value != value.toInt() ||
        value < 0 ||
        value > _maxSafe) {
      throw StateError('Invalid denomination count');
    }
  }
  final total = cashSummaryA7(k), den = cashDenTotalA7(k);
  final physical = den > 0 ? den : k['phys'];
  if (physical == null) throw StateError('Count physical cash first');
  final phys = _n(physical);
  if (phys < 0 || phys > _maxSafe) throw StateError('Invalid physical cash');
  final diff = phys - total['expect']!;
  if (diff != 0 && note.trim().isEmpty)
    throw StateError('Discrepancy requires a note');
  final requested = k['setor'];
  final setor = requested == null
      ? (phys - _n(k['start'])).clamp(0, _maxSafe)
      : _n(requested).clamp(0, phys);
  final jkt = at.toUtc().add(const Duration(hours: 7));
  final hist = k['hist'] as List? ?? <dynamic>[];
  hist.insert(0, {
    'd': at.toUtc().toIso8601String(),
    'kasir': k['kasir'],
    'omset': total['omset'],
    'diff': diff,
    'setor': setor,
    'note': note.trim(),
  });
  k.addAll(<String, dynamic>{
    'hist': hist,
    'start': phys - setor,
    'openAt':
        '${jkt.hour.toString().padLeft(2, '0')}:${jkt.minute.toString().padLeft(2, '0')}',
    'sales': [],
    'ins': [],
    'outs': [],
    'den': <String, dynamic>{},
    'phys': null,
    'qrisReal': '',
    'tfReal': '',
    'setor': null,
  });
  b['kas'] = k;
  result[cashBusinessKey] = jsonEncode(b);
  return result;
}

Map<String, dynamic> cashEntryA7({
  required Map<String, dynamic> before,
  required bool income,
  required DateTime at,
  required String method,
  required int amount,
  required String note,
}) {
  if (amount <= 0 || amount > _maxSafe) throw StateError('Invalid amount');
  if (!income && method != 'Tunai')
    throw StateError('Non-cash expense requires HTML correction approval');
  if (method != 'Tunai' && method != 'Non-Tunai')
    throw StateError('Choose a cash method');
  final result = _clone(before),
      b = jsonDecode(before[cashBusinessKey] as String) as Map;
  final k = b['kas'] as Map;
  final entries = k[income ? 'ins' : 'outs'] as List;
  entries.add(
    income
        ? <String, dynamic>{
            'm': method,
            'a': amount,
            't': note,
            'at': at.toUtc().toIso8601String(),
          }
        : <String, dynamic>{
            't': note.isEmpty ? 'Pengeluaran' : note,
            'a': amount,
            'at': at.toUtc().toIso8601String(),
          },
  );
  result[cashBusinessKey] = jsonEncode(b);
  return result;
}

/// Preserve approved presentation; replace calculated amounts and reconciliation.
Map<String, dynamic> cashCloseModelA7(Map<String, dynamic> state) {
  final model = _clone(state['model'] as Map), k = state['kas'] as Map;
  final c = cashSummaryA7(k);
  final sections = model['sections'] as List;
  model['total'] = _rp(c['omset']!);
  final saleSection = sections[0] as Map;
  final sales = (k['sales'] as List? ?? const []).whereType<Map>().toList();
  saleSection['title'] = 'Penjualan per metode · ${sales.length} transaksi';
  final methods = saleSection['methods'] as List;
  for (var i = 0; i < 3; i++) {
    (methods[i] as Map)['v'] = _rp(c[['t', 'q', 'f'][i]]!);
    (methods[i] as Map)['s'] =
        '${sales.where((s) => s['m'] == ['Tunai', 'QRIS', 'Transfer'][i]).length} trx';
  }
  final rows = (sections[1] as Map)['rows'] as List;
  for (var i = 1; i < 5; i++) {
    (rows[i] as Map)['v'] = _rp(c[['t', 'ins', 'outs', 'expect'][i - 1]]!);
  }
  final den = cashDenTotalA7(k);
  final physical = den > 0 ? den : k['phys'];
  final diff = (sections[2] as Map)['diff'] as Map;
  if (physical == null) {
    diff.addAll(<String, dynamic>{
      't': '? Belum dihitung Hitung uang di laci lalu isi totalnya',
      'bg': 'rgb(246, 247, 249)',
      'c': 'rgb(138, 143, 163)',
    });
  } else {
    final d = _n(physical) - c['expect']!;
    diff.addAll(
      d == 0
          ? <String, dynamic>{
              't': '✓ Kas pas Uang fisik sama dengan sistem',
              'bg': 'rgb(232, 248, 240)',
              'c': 'rgb(15, 95, 63)',
            }
          : d < 0
          ? <String, dynamic>{
              't':
                  '− Kurang ${_rp(-d)} Cek ulang kembalian & pengeluaran yang belum dicatat',
              'bg': 'rgb(255, 240, 241)',
              'c': 'rgb(166, 30, 42)',
            }
          : <String, dynamic>{
              't':
                  '+ Lebih ${_rp(d)} Mungkin ada pembayaran yang belum dicatat',
              'bg': 'rgb(255, 247, 236)',
              'c': 'rgb(138, 75, 15)',
            },
    );
  }
  final reconcile = (sections[3] as Map)['reconcile'] as List;
  for (var i = 0; i < 2; i++) {
    final row = reconcile[i] as Map, sys = c[i == 0 ? 'q' : 'f']!;
    row['s'] = 'Sistem ${_rp(sys)}';
    final real = '${k[i == 0 ? 'qrisReal' : 'tfReal'] ?? ''}';
    final badge = row['badge'] as Map;
    if (real.trim().isEmpty) {
      badge.addAll(<String, dynamic>{
        't': 'Belum',
        'bg': 'rgb(241, 243, 246)',
        'c': 'rgb(138, 143, 163)',
      });
    } else {
      final digits = int.tryParse(real.replaceAll(RegExp(r'\D'), '')) ?? 0;
      final d = digits - sys;
      badge.addAll(
        d == 0
            ? <String, dynamic>{
                't': '✓ Cocok',
                'bg': 'rgb(232, 248, 240)',
                'c': 'rgb(21, 136, 93)',
              }
            : <String, dynamic>{
                't': '${d > 0 ? '+' : '−'}Rp ${_format(d.abs())}',
                'bg': 'rgb(255, 240, 241)',
                'c': 'rgb(216, 50, 63)',
              },
      );
    }
  }
  final phys = physical == null ? c['expect']! : _n(physical);
  final setor = k['setor'] == null
      ? (phys - _n(k['start'])).clamp(0, _maxSafe)
      : _n(k['setor']).clamp(0, phys);
  ((sections[4] as Map)['rows'][1] as Map)['v'] = _rp(phys - setor);
  void setInput(Map? input, Object? value) {
    if (input != null && input['sel'] != state['active']) {
      input['v'] = value == null ? '' : _format(_n(value));
    }
  }

  setInput((rows[0] as Map)['input'] as Map?, k['start']);
  setInput((sections[2] as Map)['physical'] as Map?, physical);
  setInput(((sections[4] as Map)['rows'][0] as Map)['input'] as Map?, setor);
  return model;
}
