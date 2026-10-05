import 'dart:convert';
import 'dart:io';

import '../../mobile/lib/logic/payments.dart';

void main() {
  var count = 0;
  for (final file in [
    'flows_a4_a5_a7.json',
    'payments_a5_extra.json',
    'payments_a5_corrected.json',
  ]) {
    final fixture = jsonDecode(
      File('mobile/test/fixtures/parity/$file').readAsStringSync(),
    ) as Map;
    for (final c in (fixture['steps'] as List).whereType<Map>().where(
      (c) => c['part'] == 'A5',
    )) {
      final before = Map<String, dynamic>.from(c['before'] as Map);
      final after = Map<String, dynamic>.from(c['after'] as Map);
      final action = inferPaymentA5Action(before: before, after: after);
      if (action == null) throw StateError('Action missing ${c['name']}');
      final got = applyPaymentA5(before: before, action: action);
      if (jsonEncode(got) != jsonEncode(after)) {
        File('/tmp/a5-got.json').writeAsStringSync(jsonEncode(got));
        File('/tmp/a5-after.json').writeAsStringSync(jsonEncode(after));
        throw StateError('Parity mismatch ${c['name']}');
      }
      print('PASS ${c['name']}');
      count++;
    }
  }
  print('$count A5 snapshot cases passed');
}
