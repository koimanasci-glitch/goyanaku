import 'dart:convert';

List<Map> _entries(Object? value) =>
    value is List ? value.whereType<Map>().toList() : [];
DateTime? _date(Object? value) =>
    value is DateTime ? value : DateTime.tryParse('$value');
String _day(DateTime d) =>
    d.toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 10);
int _amount(Object? value) =>
    value is num ? value.round() : int.tryParse('$value') ?? 0;
String _key(Map s) => jsonEncode([
  s['m'],
  _amount(s['a']),
  _date(s['at'])?.millisecondsSinceEpoch,
]);
const _methods = {'Tunai', 'QRIS', 'Transfer', 'Deposit'};

/// Archive receipt dates survive shift close; topups are not sales.
/// Old aggregate histories are recovered only from dated order receipts.
int cashDayRevenue(Map kas, DateTime now, {Map business = const {}}) {
  final today = _day(now), known = <String, int>{};
  var sum = 0;
  DateTime? legacyUntil;
  void add(Map s, {bool fallback = false}) {
    if (!_methods.contains(s['m'])) {
      return;
    }
    final at = _date(s['at']);
    if ((at != null && _day(at) == today) || (at == null && fallback)) {
      sum += _amount(s['a']);
    }
    final key = _key(s);
    known[key] = (known[key] ?? 0) + 1;
  }

  for (final s in _entries(kas['sales'])) {
    add(s, fallback: true);
  }
  for (final h in _entries(kas['hist'])) {
    if (h['ledgerSales'] is List) {
      for (final s in _entries(h['ledgerSales'])) {
        add(s);
      }
    } else {
      final at = _date(h['d'] ?? h['at']);
      if (at != null && (legacyUntil == null || at.isAfter(legacyUntil))) {
        legacyUntil = at;
      }
    }
  }
  if (legacyUntil != null) {
    for (final o in _entries(business['orders'])) {
      Object? receipts;
      try {
        receipts = jsonDecode(
          '${(o['dataset'] as Map?)?['payments178'] ?? '[]'}',
        );
      } catch (_) {
        continue;
      }
      for (final s in _entries(receipts)) {
        final at = _date(s['at']);
        if (at == null || at.isAfter(legacyUntil)) {
          continue;
        }
        final key = _key(s), count = known[key] ?? 0;
        if (count > 0) {
          known[key] = count - 1;
          continue;
        }
        if (_day(at) == today && _methods.contains(s['m'])) {
          sum += _amount(s['a']);
        }
      }
    }
  }
  return sum;
}
