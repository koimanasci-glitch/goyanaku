import 'dart:convert';
import 'dart:io';

import '../../mobile/lib/logic/status_auto.dart';

Object? canonical(Object? x) {
  if (x is Map) {
    final keys = x.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: canonical(x[k])};
  }
  if (x is List) return x.map(canonical).toList();
  return x;
}

void main() {
  final data = jsonDecode(
    File('mobile/test/fixtures/parity/status_a6.json').readAsStringSync(),
  );
  for (final shot in data['shots']) {
    final before = jsonEncode(shot);
    final got = statusAutoPlan(Map<String, dynamic>.from(shot));
    if (jsonEncode(canonical(got)) != jsonEncode(canonical(shot['expected']))) {
      stderr.writeln(
        '${shot['name']}\nEXPECTED ${jsonEncode(shot['expected'])}\nACTUAL ${jsonEncode(got)}',
      );
      exit(1);
    }
    if (before != jsonEncode(shot)) throw StateError('Input mutated');
    print('PASS A6 ${shot['name']}');
  }
}
