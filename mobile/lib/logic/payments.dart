// A5: perhitungan murni. HTML tetap menjadi penulis storage selama migrasi.
import 'dart:convert';

const paymentBusinessKey = 'goyana-business177';
const _methods = {'Tunai', 'QRIS', 'Transfer', 'Deposit'};
const _maxSafe = 9007199254740991;

class PaymentA5Action {
  const PaymentA5Action.pay({
    required this.orderId,
    required this.amount,
    required this.method,
    required this.at,
  }) : kind = 'payment',
       name = '',
       phone = '',
       correction = null;
  const PaymentA5Action.topup({
    required this.name,
    required this.phone,
    required this.amount,
    required this.method,
    required this.at,
  }) : kind = 'topup',
       orderId = '',
       correction = null;
  const PaymentA5Action.correct({
    required this.orderId,
    required this.amount,
    required this.method,
    required this.at,
    required this.correction,
  }) : kind = 'correction',
       name = '',
       phone = '';
  final Map<String, dynamic>? correction;
  final String kind, orderId, name, phone, method;
  final int amount;
  final DateTime at;
}

String paymentCustomerKey(String name, String phone) {
  var p = phone.replaceAll(RegExp(r'\D'), '');
  if (p.startsWith('0')) p = '62${p.substring(1)}';
  return p.isEmpty ? 'name:${name.trim().toLowerCase()}' : 'phone:$p';
}

Map<String, dynamic> _business(Map<String, dynamic> store) =>
    Map<String, dynamic>.from(
      jsonDecode(store[paymentBusinessKey] as String) as Map,
    );
String _id(Map c) => '${(c['fields'] as List)[1][0]}';
int _number(Object? n) => n is num ? n.toInt() : int.tryParse('$n') ?? 0;
String _rp(int n) =>
    'Rp${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

/// Tidak mengubah input. Nominal selalu rupiah bulat; pembayaran dibatasi sisa tagihan.
Map<String, dynamic> applyPaymentA5({
  required Map<String, dynamic> before,
  required PaymentA5Action action,
}) {
  if (!_methods.contains(action.method) ||
      (action.amount <= 0 &&
          !(action.kind == 'correction' &&
              action.correction?['void'] == true &&
              action.amount == 0)) ||
      action.amount > _maxSafe) {
    throw ArgumentError('Metode atau nominal pembayaran tidak valid');
  }
  final result = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
  final b = _business(result);
  final kas = b['kas'] as Map;
  final deposits = b['deposits178'] as Map;
  final at = action.at.toUtc().toIso8601String();
  Map account(String name, String phone) =>
      deposits[paymentCustomerKey(name, phone)] as Map? ??
      <String, dynamic>{
        'name': name,
        'phone': phone,
        'balance': 0,
        'history': <dynamic>[],
      };
  if (action.kind == 'correction') {
    _correct(b, action);
  } else if (action.kind == 'topup') {
    if (action.name.trim().isEmpty || action.method == 'Deposit') {
      throw ArgumentError('Pelanggan atau metode tambah saldo tidak valid');
    }
    final record = account(action.name, action.phone);
    final balance = _number(record['balance']) + action.amount;
    if (balance > _maxSafe) throw ArgumentError('Saldo terlalu besar');
    record['balance'] = balance;
    (record['history'] as List).add({
      'type': 'topup',
      'amount': action.amount,
      'at': at,
      'method': action.method,
    });
    deposits[paymentCustomerKey(action.name, action.phone)] = record;
    (kas['ins'] as List).add({
      'm': action.method == 'Tunai' ? 'Tunai' : 'Non-Tunai',
      'actualMethod178': action.method,
      'a': action.amount,
      't': 'Titipan deposit ${action.name}',
      'deposit178': true,
      'at': at,
    });
  } else if (action.kind == 'payment') {
    final card = (b['orders'] as List).whereType<Map>().firstWhere(
      (c) => _id(c) == action.orderId,
    );
    final ds = card['dataset'] as Map;
    final detail = (b['details'] as Map)[action.orderId] as Map;
    final total = _number(card['total']);
    final paid = _number(detail['paid']);
    if (ds['st'] == 'batal' || action.amount > total - paid) {
      throw ArgumentError('Nominal melebihi tagihan atau pesanan batal');
    }
    if (action.method == 'Deposit') {
      final name = '${detail['name']}';
      final phone = '${ds['phone'] ?? detail['phone'] ?? ''}';
      final record = account(name, phone);
      if (_number(record['balance']) < action.amount) {
        throw StateError('Saldo deposit tidak cukup');
      }
      record['balance'] = _number(record['balance']) - action.amount;
      (record['history'] as List).add({
        'type': 'payment',
        'amount': action.amount,
        'order': action.orderId,
        'at': at,
      });
      deposits[paymentCustomerKey(name, phone)] = record;
    }
    final next = paid + action.amount;
    detail['paid'] = next;
    ds['paid177'] = '$next';
    ds['method177'] = action.method;
    final entries = jsonDecode('${ds['payments178'] ?? '[]'}') as List;
    entries.add({'m': action.method, 'a': action.amount, 'at': at});
    ds['payments178'] = jsonEncode(entries);
    card['payment'] = next == total
        ? 'Lunas'
        : 'DP · sisa ${_rp(total - next)}';
    card['paid'] = next == total;
    (kas['sales'] as List).add({
      'm': action.method,
      'a': action.amount,
      'id': action.orderId,
      'at': at,
    });
  } else {
    throw UnsupportedError('Aksi pembayaran A5 tidak dikenali');
  }
  result[paymentBusinessKey] = jsonEncode(b);
  return result;
}

void _correct(Map<String, dynamic> b, PaymentA5Action action) {
  final audit = action.correction!;
  final legacy = audit['legacy'] == true, voided = audit['void'] == true;
  if ('${audit['reason'] ?? ''}'.trim().isEmpty) {
    throw ArgumentError('Alasan ralat wajib');
  }
  final card = (b['orders'] as List).whereType<Map>().firstWhere(
    (c) => _id(c) == action.orderId,
  );
  final ds = card['dataset'] as Map;
  final detail = (b['details'] as Map)[action.orderId] as Map;
  final kas = b['kas'] as Map, deposits = b['deposits178'] as Map;
  final sales = kas['sales'] as List;
  var entries = jsonDecode('${ds['payments178'] ?? '[]'}') as List;
  final saleIndex = sales.indexWhere(
    (s) => s is Map && s['rid'] == audit['rid'],
  );
  final Map sale = legacy
      ? {'id': action.orderId, 'a': detail['paid']}
      : (saleIndex < 0
            ? throw StateError('Pembayaran sudah dibatalkan')
            : sales[saleIndex] as Map);
  var index = -1;
  if (!legacy) {
    for (var i = entries.length - 1; i >= 0; i--) {
      final e = entries[i] as Map;
      if (e['m'] == sale['m'] && e['a'] == sale['a'] && e['at'] == sale['at']) {
        index = i;
        break;
      }
    }
    if (index < 0) throw StateError('Riwayat tidak cocok');
  }
  final at = action.at.toUtc().toIso8601String();
  final old = legacy
      ? (entries.isNotEmpty
            ? entries
            : [
                {'m': audit['oldMethod'], 'a': sale['a'], 'at': at},
              ])
      : [entries[index]];
  final oldAmount = old.fold<int>(0, (n, e) => n + _number((e as Map)['a']));
  final amount = voided ? 0 : action.amount;
  final next = _number(detail['paid']) - oldAmount + amount;
  if (oldAmount != _number(sale['a']) ||
      next < 0 ||
      next > _number(card['total']) ||
      next > _maxSafe) {
    throw ArgumentError(
      'Nominal ralat melebihi tagihan atau riwayat tidak cocok',
    );
  }
  final oldDeposit = old.fold<int>(
    0,
    (n, e) => n + ((e as Map)['m'] == 'Deposit' ? _number(e['a']) : 0),
  );
  final delta = oldDeposit - (action.method == 'Deposit' ? amount : 0);
  if (delta != 0) {
    final name = '${detail['name']}',
        phone = '${ds['phone'] ?? detail['phone'] ?? ''}';
    final key = paymentCustomerKey(name, phone);
    final record =
        deposits[key] as Map? ??
        {'name': name, 'phone': phone, 'balance': 0, 'history': <dynamic>[]};
    final balance = _number(record['balance']) + delta;
    if (balance < 0 || balance > _maxSafe) {
      throw StateError('Saldo tidak cukup atau terlalu besar');
    }
    record['balance'] = balance;
    (record['history'] as List).add({
      'type': delta > 0 ? 'refund' : 'payment',
      'amount': delta.abs(),
      'order': action.orderId,
      'at': at,
      'reason': audit['reason'],
    });
    deposits[key] = record;
  }
  final replacement = amount > 0
      ? [
          {
            'm': action.method,
            'a': amount,
            'at': legacy ? at : (entries[index] as Map)['at'],
          },
        ]
      : <dynamic>[];
  if (legacy) {
    final rids = audit['rids'] as List;
    if (rids.length != old.length + (amount > 0 ? 1 : 0)) {
      throw StateError('ID koreksi tidak cocok');
    }
    for (var i = 0; i < old.length; i++) {
      final e = old[i] as Map;
      sales.add({
        'm': e['m'],
        'a': -_number(e['a']),
        'id': action.orderId,
        'adj': 1,
        'rid': rids[i],
        'at': at,
      });
    }
    if (amount > 0) {
      sales.add({
        'm': action.method,
        'a': amount,
        'id': action.orderId,
        'adj': 1,
        'rid': rids.last,
        'at': at,
      });
    }
    entries = replacement;
  } else if (voided) {
    sales.removeAt(saleIndex);
    (kas['voided'] as List).add({...sale, 'voidAt': at});
    entries.removeAt(index);
  } else {
    sales[saleIndex] = {...sale, 'm': action.method, 'a': amount, 'edited': 1};
    entries[index] = replacement.single;
  }
  detail['paid'] = next;
  ds['paid177'] = '$next';
  ds['payments178'] = jsonEncode(entries);
  ds['method177'] = entries.isNotEmpty
      ? (entries.last as Map)['m']
      : audit['oldMethod'];
  final remain = _number(card['total']) - next;
  card['payment'] = remain == 0
      ? 'Lunas'
      : next > 0
      ? 'DP · sisa ${_rp(remain)}'
      : 'Belum Bayar';
  card['paid'] = remain == 0;
  detail['paymentCorrections178'] = [
    ...(detail['paymentCorrections178'] as List? ?? []),
    {...audit, 'oldAmount': oldAmount, 'oldEntries': old},
  ];
}

/// Hanya metadata satu entri baru dibaca; seluruh hasil dihitung ulang dari before.
/// Perubahan ralat atau transaksi gabungan tidak ditebak sebagai pembayaran baru.
PaymentA5Action? inferPaymentA5Action({
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
  String? orderId,
}) {
  final b = _business(before), a = _business(after);
  final details = a['details'] as Map, previousDetails = b['details'] as Map;
  for (final id in details.keys) {
    if (orderId != null && id != orderId) continue;
    final old =
        (previousDetails[id] as Map?)?['paymentCorrections178'] as List? ?? [];
    final next = (details[id] as Map)['paymentCorrections178'] as List? ?? [];
    if (next.length != old.length + 1 ||
        jsonEncode(next.take(old.length).toList()) != jsonEncode(old)) {
      continue;
    }
    final record = Map<String, dynamic>.from(next.last as Map);
    final at = DateTime.tryParse('${record['at']}');
    if (at == null) continue;
    return PaymentA5Action.correct(
      orderId: '$id',
      amount: _number(record['amount']),
      method: '${record['method']}',
      at: at,
      correction: record,
    );
  }
  final bk = b['kas'] as Map, ak = a['kas'] as Map;
  for (final key in ['sales', 'ins']) {
    final old = bk[key] as List, next = ak[key] as List;
    if (next.length != old.length + 1) continue;
    if (jsonEncode(next.take(old.length).toList()) != jsonEncode(old)) continue;
    final row = next.last as Map;
    final amount = _number(row['a']);
    final at = DateTime.tryParse('${row['at']}');
    if (at == null || amount <= 0) continue;
    if (key == 'sales') {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty || (orderId != null && id != orderId)) continue;
      return PaymentA5Action.pay(
        orderId: id,
        amount: amount,
        method: '${row['m']}',
        at: at,
      );
    }
    if (row['deposit178'] != true) continue;
    final ledger = a['deposits178'] as Map;
    final oldLedger = b['deposits178'] as Map;
    final changed = ledger.keys
        .where((k) => jsonEncode(ledger[k]) != jsonEncode(oldLedger[k]))
        .toList();
    if (changed.length != 1) continue;
    final record = ledger[changed.single] as Map;
    return PaymentA5Action.topup(
      name: '${record['name']}',
      phone: '${record['phone']}',
      amount: amount,
      method: '${row['actualMethod178']}',
      at: at,
    );
  }
  return null;
}
