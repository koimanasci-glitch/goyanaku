// A4 Rincian Pesanan: status, batal, riwayat. UI tetap memakai presentasi yang sama.
import 'dart:convert';

import '../core/money.dart';
import '../core/store.dart';

class OrderDetailA4Action {
  const OrderDetailA4Action.advance({required this.orderId, required this.at})
      : kind = 'advance',
        reason = '';

  const OrderDetailA4Action.cancel({
    required this.orderId,
    required this.at,
    required this.reason,
  }) : kind = 'cancel';

  final String kind;
  final String orderId;
  final DateTime at;
  final String reason;
}

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

num _num(Object? value) => value is num ? value : num.tryParse('$value') ?? 0;

List<Map<String, dynamic>> _maps(Object? value) =>
    (value is List ? value : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

String _field(Map card, int index) {
  final fields = card['fields'];
  if (fields is! List || fields.length <= index) return '';
  final row = fields[index];
  return row is List && row.isNotEmpty ? '${row.first}' : '';
}

String _cardId(Map card) => _field(card, 1);

Map<String, dynamic> _business(Map<String, dynamic> store) {
  final raw = store[Keys.business];
  if (raw is! String) throw const FormatException('goyana-business177 tidak ada');
  final value = jsonDecode(raw);
  if (value is! Map) throw const FormatException('goyana-business177 bukan object');
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _cardById(Map<String, dynamic> business, String id) {
  for (final raw in business['orders'] as List? ?? const []) {
    if (raw is Map && _cardId(raw) == id) return Map<String, dynamic>.from(raw);
  }
  throw StateError('Pesanan $id tidak ditemukan');
}

Map<String, dynamic> _detailById(Map<String, dynamic> business, String id) {
  final details = business['details'];
  if (details is Map && details[id] is Map) {
    return Map<String, dynamic>.from(details[id] as Map);
  }
  throw StateError('Rincian $id tidak ditemukan');
}

String? orderDetailA4NextStatus(String current, String handover) {
  if (current == 'antrian') return 'cuci';
  if (const {'cuci', 'kering', 'setrika', 'packing'}.contains(current)) return 'siap';
  if (current == 'siap' || current == 'telat') {
    return handover.toLowerCase().contains('antar') ? 'diantar' : 'diambil';
  }
  if (current == 'diantar') return 'diambil';
  return null;
}

/// Menghasilkan penyimpanan HTML sesudah satu aksi A4. Tidak menulis storage.
Map<String, dynamic> applyOrderDetailA4({
  required Map<String, dynamic> before,
  required OrderDetailA4Action action,
}) {
  final result = _copyMap(before);
  final business = _business(result);
  final orders = business['orders'] as List? ?? const [];
  Map<String, dynamic>? card;
  for (var i = 0; i < orders.length; i++) {
    final raw = orders[i];
    if (raw is Map && _cardId(raw) == action.orderId) {
      card = Map<String, dynamic>.from(raw);
      orders[i] = card;
      break;
    }
  }
  if (card == null) throw StateError('Pesanan ${action.orderId} tidak ditemukan');

  final details = business['details'];
  if (details is! Map || details[action.orderId] is! Map) {
    throw StateError('Rincian ${action.orderId} tidak ditemukan');
  }
  final detail = Map<String, dynamic>.from(details[action.orderId] as Map);
  details[action.orderId] = detail;
  final dataset = Map<String, dynamic>.from(card['dataset'] as Map? ?? const {});
  card['dataset'] = dataset;
  final current = '${dataset['st'] ?? 'antrian'}';

  final String next;
  if (action.kind == 'cancel') {
    next = 'batal';
  } else if (action.kind == 'advance') {
    next = orderDetailA4NextStatus(current, '${detail['handover'] ?? ''}') ??
        (throw UnsupportedError('Transisi A4 $current belum dipatok fixture'));
  } else {
    throw UnsupportedError('Aksi A4 ${action.kind} tidak dikenal');
  }

  final at = action.at.toUtc();
  final millis = '${at.millisecondsSinceEpoch}';
  dataset['st'] = next;
  dataset['ts133'] = millis;
  dataset['auto133'] = '';

  final chips = (card['chips'] as List? ?? <dynamic>[]).toList();
  card['chips'] = chips;
  if (next == 'siap') {
    dataset['siap138'] = millis;
    if (!chips.any((c) => c is Map && '${c['text']}' == '💬 Kabari WA')) {
      chips.add(<String, dynamic>{'text': '💬 Kabari WA', 'hidden': false});
    }
  } else {
    chips.removeWhere((c) => c is Map && '${c['text']}' == '💬 Kabari WA');
  }

  final hist = (detail['hist'] as List? ?? <dynamic>[]).toList();
  detail['hist'] = hist;
  final row = <String, dynamic>{
    'st': next,
    'at': at.toIso8601String(),
    'by': 'Koko',
  };
  if (action.kind == 'cancel' && action.reason.isNotEmpty) row['note'] = action.reason;
  hist.add(row);

  result[Keys.business] = jsonEncode(business);
  return result;
}

/// Membaca aksi yang benar-benar dilakukan HTML agar guard bisa menghitung ulang
/// dari snapshot SEBELUM aksi. `after` hanya dipakai untuk mengenali aksi/jam,
/// bukan sebagai sumber hasil Dart.
OrderDetailA4Action? inferOrderDetailA4Action({
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
  String? orderId,
}) {
  final b0 = _business(before), b1 = _business(after);
  final ids = <String>[];
  if (orderId != null && orderId.isNotEmpty) {
    ids.add(orderId);
  } else {
    for (final raw in b1['orders'] as List? ?? const []) {
      if (raw is Map) {
        final id = _cardId(raw);
        if (id.isNotEmpty) ids.add(id);
      }
    }
  }

  final found = <OrderDetailA4Action>[];
  for (final id in ids) {
    Map<String, dynamic> c0, c1, d0, d1;
    try {
      c0 = _cardById(b0, id);
      c1 = _cardById(b1, id);
      d0 = _detailById(b0, id);
      d1 = _detailById(b1, id);
    } catch (_) {
      continue;
    }
    final s0 = '${(c0['dataset'] as Map?)?['st'] ?? ''}';
    final s1 = '${(c1['dataset'] as Map?)?['st'] ?? ''}';
    if (s0 == s1) continue;
    final h0 = d0['hist'] as List? ?? const [];
    final h1 = d1['hist'] as List? ?? const [];
    if (h1.length != h0.length + 1 || h1.last is! Map) continue;
    final last = Map<String, dynamic>.from(h1.last as Map);
    if ('${last['st']}' != s1 || '${last['by']}' != 'Koko') continue;
    final at = DateTime.tryParse('${last['at'] ?? ''}');
    if (at == null) continue;
    if (s1 == 'batal') {
      found.add(OrderDetailA4Action.cancel(
        orderId: id,
        at: at,
        reason: '${last['note'] ?? ''}',
      ));
    } else if (orderDetailA4NextStatus(s0, '${d0['handover'] ?? ''}') == s1) {
      found.add(OrderDetailA4Action.advance(orderId: id, at: at));
    }
  }
  return found.length == 1 ? found.single : null;
}

Map<String, Object> _statusView(String status, String handover) {
  if (status == 'batal') {
    return const {
      'label': 'Batal', 'bg': 'rgb(255, 240, 241)',
      'upper': 'PESANAN DIBATALKAN', 'button': 'Pesanan Dibatalkan', 'level': -1,
    };
  }
  if (status == 'antrian') {
    return const {
      'label': 'Antrian', 'bg': 'rgb(238, 241, 245)',
      'upper': 'MULAI PROSES', 'button': 'Mulai Proses', 'level': 0,
    };
  }
  if (const {'cuci', 'kering', 'setrika', 'packing'}.contains(status)) {
    return const {
      'label': 'Proses', 'bg': 'rgb(234, 242, 253)',
      'upper': 'TANDAI SIAP', 'button': 'Tandai Siap', 'level': 1,
    };
  }
  if (status == 'siap' || status == 'telat') {
    final antar = handover.toLowerCase().contains('antar');
    return {
      'label': 'Siap Ambil', 'bg': 'rgb(232, 248, 240)',
      'upper': antar ? 'ANTAR' : 'SERAHKAN',
      'button': antar ? 'Antar' : 'Serahkan', 'level': 2,
    };
  }
  if (status == 'diantar') {
    return const {
      'label': 'Diantar', 'bg': 'rgb(234, 242, 253)',
      'upper': 'TANDAI DIAMBIL', 'button': 'Tandai Diambil', 'level': 2,
    };
  }
  if (status == 'diambil') {
    return const {
      'label': 'Diambil', 'bg': 'rgb(241, 243, 246)',
      'upper': 'SELESAI ✓', 'button': 'Selesai ✓', 'level': 3,
    };
  }
  throw UnsupportedError('Status detail $status belum dipatok A4');
}

List<Map<String, dynamic>> _innerSteps(int level) => [
  for (var i = 0; i < 4; i++)
    {
      'n': '${i + 1}',
      't': const ['Diterima', 'Proses', 'Siap Ambil', 'Diambil'][i],
      'on': level >= 0 && level < 3 && i == level,
      'done': level >= 0 && i < level || level == 3,
    },
];

List<Map<String, dynamic>> _outerSteps(int level) => [
  for (var i = 0; i < 4; i++)
    {
      'n': '${i + 1}',
      't': const ['Diterima', 'Proses', 'Siap Ambil', 'Diambil'][i],
      'on': level >= i && level >= 0,
    },
];

Map<String, dynamic> _unpaidBanner(String id) => <String, dynamic>{
  'bg': 'rgb(255, 248, 236)',
  'line': 'rgb(255, 230, 194)',
  'ic': 'rgb(224, 161, 0)',
  'c': 'rgb(138, 75, 15)',
  'icon': '!',
  't': 'Pesanan tersimpan · Belum dibayar',
  's': '',
  'ok': false,
  'label': {'t': '🏷 Label kantong', 'b': 3},
};

Map<String, dynamic> _paidBanner(String id, String method) => <String, dynamic>{
  'bg': 'rgb(239, 250, 244)',
  'line': 'rgb(215, 240, 227)',
  'ic': 'rgb(21, 163, 107)',
  'c': 'rgb(15, 95, 63)',
  'icon': '✓',
  't': 'Pesanan tersimpan · Lunas via $method',
  's': '',
  'ok': true,
  'label': {'t': '🏷 Label kantong', 'b': 3},
};

/// Model Rincian Pesanan A4. Presentasi membawa teks/ikon yang tidak dihitung A4;
/// status, langkah, tombol, pembayaran dan indeks tombol dibentuk ulang oleh Dart.
Map<String, dynamic> orderDetailA4Model({
  required Map<String, dynamic> store,
  required String orderId,
  required Map<String, dynamic> presentation,
}) {
  final model = _copyMap(presentation);
  final business = _business(store);
  final card = _cardById(business, orderId);
  final detail = _detailById(business, orderId);
  final dataset = Map<String, dynamic>.from(card['dataset'] as Map? ?? const {});
  final status = '${dataset['st'] ?? 'antrian'}';
  final handover = '${detail['handover'] ?? ''}';
  final view = _statusView(status, handover);
  final level = view['level'] as int;
  final showBanner = status != 'diambil';
  final shift = showBanner ? 0 : -1;
  final total = _num(card['total']);
  final paidAmount = _num(detail['paid'] ?? dataset['paid177']);
  final paid = total <= 0 ? paidAmount > 0 : paidAmount >= total;
  final remaining = (total - paidAmount).clamp(0, double.infinity);
  final payText = paid ? 'Lunas' : paidAmount > 0 ? 'Sisa ${rpSpaced(remaining)}' : 'Belum dibayar';
  final payColor = paid ? 'rgb(21, 136, 93)' : 'rgb(216, 50, 63)';
  final method = '${dataset['method177'] ?? 'Tunai'}';
  final banner = paid ? _paidBanner(orderId, method) : _unpaidBanner(orderId);

  final odRaw = model['od'];
  if (odRaw is! Map) throw const FormatException('Model detail tidak memiliki od');
  final od = Map<String, dynamic>.from(odRaw);
  model['od'] = od;
  od['sub'] = '$orderId · ${_field(card, 0)}';
  od['banner'] = showBanner ? banner : null;
  od['steps'] = _innerSteps(level);

  if (od['customer'] is Map) {
    final customer = Map<String, dynamic>.from(od['customer'] as Map);
    od['customer'] = customer;
    customer['wa'] = {'t': '', 'b': 4 + shift};
    customer['print'] = {'t': '', 'b': 5 + shift};
  }
  od['edit'] = {'t': 'Edit', 'b': 7 + shift};

  final rows = _maps(od['rows']);
  od['rows'] = rows;
  for (final row in rows) {
    if ('${row['k']}' == 'Status') {
      row['v'] = view['label'];
      row['pill'] = true;
      row['bg'] = view['bg'];
      row['c'] = 'rgb(30, 30, 30)';
    }
  }
  od['actions'] = <Map<String, dynamic>>[
    {'t': view['upper'], 'b': 8 + shift, 'green': false, 'primary': true},
    {'t': 'KIRIM NOTA WA', 'b': 9 + shift, 'green': true, 'primary': false},
  ];
  od['total'] = <String, dynamic>{
    'label': 'Total', 'v': rpSpaced(total), 's': payText, 'c': payColor,
    'paid': paid,
    'pay': {'t': paid ? 'LUNAS ✓' : 'BAYAR', 'b': 12 + shift},
  };

  final items = _maps(model['items']);
  model['items'] = items;
  final header = items.where((e) => e['type'] == 'entry' && '${e['t']}'.toLowerCase().contains('rincian pesanan')).firstOrNull;
  if (header != null) {
    header['lines'] = ['$orderId · ${_field(card, 0)}'];
    if (header['btns'] is List) {
      header['btns'] = [
        {'t': '⋯', 'i': 1, 'on': false},
        {'t': '×', 'i': 2, 'on': false},
      ];
    }
  }

  final bannerIndex = items.indexWhere((e) => e['type'] == 'row' && '${e['t']}'.startsWith('Pesanan tersimpan'));
  if (!showBanner && bannerIndex >= 0) {
    items.removeAt(bannerIndex);
  } else if (showBanner) {
    final row = <String, dynamic>{
      'type': 'row', 't': banner['t'],
      's': '$orderId · tekan tombol WA hijau untuk kirim nota',
      'btn': '🏷 Label kantong', 'svg': '', 'i': 3,
    };
    if (bannerIndex >= 0) {
      items[bannerIndex] = row;
    } else {
      items.insert(items.isEmpty ? 0 : 1, row);
    }
  }

  for (final entry in items) {
    if (entry['type'] == 'entry' && entry['btns'] is List && '${entry['t']}' != 'Detail Order' && !'${entry['t']}'.toLowerCase().contains('rincian pesanan')) {
      entry['btns'] = [
        {'t': 'Kirim nota WA', 'i': 4 + shift, 'on': false},
        {'t': 'Cetak struk', 'i': 5 + shift, 'on': false},
      ];
      break;
    }
  }
  final detailHeader = items.where((e) => e['type'] == 'entry' && '${e['t']}' == 'Detail Order').firstOrNull;
  if (detailHeader != null) {
    detailHeader['btns'] = [
      {'t': 'Edit', 'i': 7 + shift, 'on': false},
    ];
  }
  final steps = items.where((e) => e['type'] == 'steps').firstOrNull;
  if (steps != null) steps['steps'] = _outerSteps(level);
  for (final pair in items.where((e) => e['type'] == 'pair')) {
    if ('${pair['t']}' == 'Status') pair['v'] = view['label'];
  }
  final buttons = items.where((e) => e['type'] == 'button').toList();
  if (buttons.isNotEmpty) {
    buttons[0]
      ..['t'] = view['button']
      ..['i'] = 8 + shift
      ..['primary'] = true;
  }
  if (buttons.length > 1) {
    buttons[1]
      ..['t'] = 'Kirim Nota WA'
      ..['i'] = 9 + shift
      ..['primary'] = false;
  }
  final totals = items.where((e) => e['type'] == 'total').toList();
  if (totals.isNotEmpty) {
    totals.first
      ..['v'] = rpSpaced(total)
      ..['s'] = payText
      ..['btn'] = paid ? 'LUNAS ✓' : 'Bayar'
      ..['i'] = 12 + shift;
  }
  return model;
}
