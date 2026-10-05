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
       phone = '';
  const PaymentA5Action.topup({
    required this.name,
    required this.phone,
    required this.amount,
    required this.method,
    required this.at,
  }) : kind = 'topup',
       orderId = '';
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
      action.amount <= 0 ||
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
  if (action.kind == 'topup') {
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
    throw UnsupportedError(
      'Ralat A5 menunggu keputusan atas ketidakkonsistenan HTML',
    );
  }
  result[paymentBusinessKey] = jsonEncode(b);
  return result;
}

/// Hanya metadata satu entri baru dibaca; seluruh hasil dihitung ulang dari before.
/// Perubahan ralat atau transaksi gabungan tidak ditebak sebagai pembayaran baru.
PaymentA5Action? inferPaymentA5Action({
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
  String? orderId,
}) {
  final b = _business(before), a = _business(after);
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
