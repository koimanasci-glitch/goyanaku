// 3c: fungsi murni; runtime guard di shell yang memutuskan kapan snapshot ini dipakai.
import 'dart:convert';

String _pad(int n) => '$n'.padLeft(2, '0');
String _iso(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
      d.millisecondsSinceEpoch, isUtc: true).toIso8601String();

/// nextCode136: jumlah kartu .new107, termasuk yang direstore/dibatalkan.
/// Tidak reset harian; awalan '0' literal, bukan padLeft(4).
String nextOrderCode(DateTime localNow, int newCardCount) =>
    'GY-${'${localNow.year}'.substring(2)}${_pad(localNow.month)}'
    '${_pad(localNow.day)}-0${133 + newCardCount}';

/// durHours199: parseInt basis 10, nilai tidak positif kembali ke bawaan.
int orderDurationHours(String name, String? durationsJson) {
  dynamic settings;
  try {
    settings = jsonDecode(durationsJson ?? '{}');
  } on FormatException {
    settings = null;
  }
  final key = RegExp('Kilat', caseSensitive: false).hasMatch(name)
      ? 'Kilat'
      : RegExp('Express|Ekspres', caseSensitive: false).hasMatch(name)
          ? 'Express' : 'Reguler';
  final value = settings is Map ? settings[key] : null;
  final prefix = RegExp(r'^\s*([+-]?\d+)').firstMatch('$value');
  final hours = int.tryParse(prefix?.group(1) ?? '') ?? 0;
  return hours > 0 ? hours : {'Reguler': 72, 'Express': 24, 'Kilat': 6}[key]!;
}

DateTime orderEstimatedFinish(DateTime entered, String duration,
        String? durationsJson) =>
    entered.add(Duration(hours: orderDurationHours(duration, durationsJson)));

/// Kalender lokal diberikan pemanggil, tidak bergantung timezone mesin CI.
String orderEstimateText(DateTime localDue) =>
    'Estimasi · ${_pad(localDue.day)}/${_pad(localDue.month)}/${localDue.year}'
    ' · ${_pad(localDue.hour)}:${_pad(localDue.minute)}';

num _digits(Object? value) =>
    num.tryParse('${value ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
String _jsNumber(num n) => n == n.truncateToDouble() ? '${n.toInt()}' : '$n';
Map<String, dynamic> _copy(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

// v180: validasi outlet aktif; bila tidak ada, gunakan outlet pertama.
String _activeOutlet(Map<String, dynamic> store) {
  dynamic read(String key, dynamic fallback) {
    try {
      return jsonDecode(store[key] as String? ?? 'null') ?? fallback;
    } on FormatException {
      return fallback;
    }
  }
  final outlets = read('goyana-outlets180', <dynamic>[]) as List;
  final active = read('goyana-active-outlet180', '') as String;
  if (outlets.any((dynamic o) => o['id'] == active)) return active;
  return outlets.isEmpty ? '' : (outlets.first['id'] as String? ?? '');
}

/// Snapshot sinkron tepat setelah f61Finish + flushTransactions177.
/// Input draft adalah snapshot sebelum finish (payamount dan total berbeda).
/// Batas capture saat ini: Datang Langsung, outlet dari store, tanpa diskon/picked customer,
/// cart tidak kosong; hanya empat metode fixture. Jalur di luar fixture tetap HTML.
/// Sejak df4aaef, estimasi kartu dan details.due sama-sama mengikuti durHours199.
Map<String, dynamic> prepareAddOrderSave({
  required Map<String, dynamic> before,
  required Map<String, dynamic> draft,
  required Map<String, dynamic> store,
  required DateTime now,
  required Duration localOffset,
}) {
  final method = draft['method'] as String;
  if (draft['handover'] != 'Datang Langsung' ||
      !['Bayar Nanti', 'Tunai', 'QRIS', 'Transfer'].contains(method) ||
      (draft['cart'] as List).isEmpty) {
    throw UnsupportedError('Jalur ini memerlukan capture HTML tambahan 3c');
  }
  final result = _copy(before);
  final orders = result['orders'] as List;
  final localNow = now.toUtc().add(localOffset);
  final id = nextOrderCode(localNow, orders.length);
  final at = _iso(now);
  final dur = draft['dur'] as String;
  final durationsJson = store['goyana-durations199'] as String?;
  final durationHours = orderDurationHours(
      draft['durationLabel'] as String, durationsJson);
  final due = localNow.add(Duration(hours: durationHours));
  // v116 mengambil nama tanpa akhiran durasi, urutan properti JSON dipertahankan.
  final items = (draft['cart'] as List).map((dynamic it) => <String, dynamic>{
    'n': (it['name'] as String).replaceFirst(RegExp(r' \(.*\)$'), ''),
    'ic': it['ic'], 'unit': it['unit'], 'price': it['price'], 'qty': it['qty'],
  }).toList();
  final total = draft['total'] as num;
  final paid = method == 'Bayar Nanti' ? 0 : total;
  final paymentMethod = method == 'Bayar Nanti' ? 'Tunai' : method;
  // v107 memakai teks payamount, bukan menghitung ulang qty*price.
  // Fixture dengan outlet aktif memiliki payamount Rp 17.500.
  final amountText = draft['payamount'] as String;
  final cardTotal = amountText.isEmpty ? total.round() : _digits(amountText);
  final kasAmount = _digits(amountText) == 0 ? total : _digits(amountText);
  final itemTotal = items.fold<num>(0,
      (sum, it) => sum + ((it['qty'] as num) * (it['price'] as num)).round());
  final remaining = (itemTotal - paid).clamp(0, double.infinity);
  final payments = paid == 0 ? [] : [
    {'m': paymentMethod, 'a': paid, 'at': at},
  ];
  final card = <String, dynamic>{
    'dataset': {
      'v108': '1', 'st': 'antrian', 'items': jsonEncode(items), 'v136': '1',
      'created177': at, 'method177': paymentMethod,
      'paid177': _jsNumber(paid), 'perfume178': draft['perfume'],
      'payments178': jsonEncode(payments),
    },
    'fields': [
      [dur], [id], [draft['name']],
      ['Masuk · baru saja', orderEstimateText(due)], [], [],
    ],
    'total': cardTotal,
    'payment': remaining == 0 ? 'Lunas' : 'Belum Bayar',
    'paid': remaining == 0,
    'chips': [
      {'text': 'Prioritas', 'hidden': draft['priority'] != true},
      {'text': draft['handover'], 'hidden': false},
    ],
  };
  final outlet = _activeOutlet(store);
  if (outlet.isNotEmpty) (card['dataset'] as Map)['outlet180'] = outlet;
  orders.insert(0, card);
  (result['details'] as Map)[id] = {
    'id': id, 'name': draft['name'], 'phone': '', 'dur': dur,
    'items': items, 'discKey': '0', 'ongkir': 0, 'paid': paid,
    'perfume': draft['perfume'], 'note': '-', 'handover': draft['handover'],
    'masuk': at, 'due': _iso(now.add(Duration(hours: durationHours))),
    'photos': {'in': [], 'out': []},
    'hist': [{'st': 'antrian', 'at': at, 'by': 'Kasir'}],
  };
  if (method != 'Bayar Nanti' && kasAmount != 0) {
    ((result['kas'] as Map)['sales'] as List).add(
        {'m': paymentMethod, 'a': kasAmount, 'id': id, 'at': at});
  }
  return result;
}
