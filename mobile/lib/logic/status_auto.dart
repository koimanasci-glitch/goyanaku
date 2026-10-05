// A6: pure timer decisions, late collection and reminder eligibility.
// HTML remains the storage writer until D2. No automatic ready/WA send here.

Map<String, dynamic> statusAutoPlan(Map<String, dynamic> state) {
  final now = (state['now'] as num).toInt();
  final rules = state['rules'] as Map;
  if (rules['p'] == true) {
    throw StateError('Hidden process automation is outside A6 fixtures');
  }
  final queue = <Map<String, dynamic>>[];
  final moves = <Map<String, dynamic>>[];
  final reminders = <Map<String, dynamic>>[];
  final lateDays = (state['lateDays'] as num).toDouble();
  final reminderDays = (state['reminderDays'] as num).toDouble();
  final log = state['log'] as Map? ?? const {};
  for (final card in (state['cards'] as List).whereType<Map>()) {
    final id = '${card['id']}';
    final ds = card['dataset'] as Map;
    final st = '${ds['st'] ?? ''}';
    if (st == 'antrian' && rules['q'] == true) {
      final ts = num.tryParse('${ds['ts133'] ?? ''}');
      final start = ts == null || ts == 0 ? now : ts;
      final min = (rules['qMin'] as num).toDouble() - (now - start) / 60000;
      final rounded = min.ceil().clamp(0, 9007199254740991);
      final h = rounded ~/ 60, m = rounded % 60;
      final label = min > 0
          ? '${h > 0 ? '${h}j ' : ''}${m > 0 || h == 0 ? '${m}m' : ''}'.trim()
          : '…';
      queue.add({
        'id': id,
        'min': _jsonNumber(min),
        'label': '⏱ $label',
        'next': min <= 0 ? 'cuci' : null,
      });
    }
    final since = num.tryParse('${ds['siap138'] ?? ''}');
    final int? age = '${ds['siap138'] ?? ''}'.isEmpty
        ? -1
        : since == null
        ? null
        : ((now - since) / 86400000).floor();
    if (st == 'siap' && ds['antar'] != '1' && age != null && age >= lateDays) {
      moves.add({'id': id, 'next': 'telat'});
    } else if (st == 'telat' && age != null && age < lateDays) {
      moves.add({'id': id, 'next': 'siap'});
    }
    if ((st == 'siap' || st == 'telat') &&
        since != null &&
        age != null &&
        age >= reminderDays) {
      reminders.add({
        'id': id,
        'days': age,
        'since': since,
        'count': (log[id] as List? ?? const []).length,
      });
    }
  }
  // List.sort is not stable; preserve DOM order for equal ages, like JS sort.
  final ordered = [
    for (var i = 0; i < reminders.length; i++) {'i': i, 'r': reminders[i]},
  ];
  ordered.sort((a, b) {
    final x = a['r'] as Map, y = b['r'] as Map;
    final age = (y['days'] as int).compareTo(x['days'] as int);
    return age != 0 ? age : (a['i'] as int).compareTo(b['i'] as int);
  });
  return {
    'queue': queue,
    'moves': moves,
    'reminders': [for (final r in ordered) r['r']],
    'notices': queueNoticePlan(state),
  };
}

/// Android notification IDs use JS unsigned 32-bit hashing (Array.from + charCodeAt(0)).
int queueNoticeId(String id) {
  var n = 0;
  for (final rune in id.runes) {
    final unit = rune > 0xffff ? 0xd800 + ((rune - 0x10000) >> 10) : rune;
    n = (n * 31 + unit) & 0xffffffff;
  }
  return n % 2147483647;
}

List<Map<String, dynamic>> queueNoticePlan(Map<String, dynamic> state) {
  final rules = state['rules'] as Map;
  final now = state['now'] as num;
  if (rules['q'] != true) return [];
  return [
    for (final card in (state['cards'] as List).whereType<Map>())
      if ((card['dataset'] as Map)['st'] == 'antrian')
        ..._notice(card, now, rules['qMin'] as num),
  ];
}

List<Map<String, dynamic>> _notice(Map card, num now, num minutes) {
  final ts = num.tryParse('${(card['dataset'] as Map)['ts133'] ?? ''}');
  final at = (ts == null || ts == 0 ? now : ts) + minutes * 60000;
  if (at <= now) return [];
  final id = '${card['id']}';
  return [
    {'id': queueNoticeId(id), 'at': _jsonNumber(at), 'order': id},
  ];
}

num _jsonNumber(num value) =>
    value == value.truncateToDouble() ? value.toInt() : value;
