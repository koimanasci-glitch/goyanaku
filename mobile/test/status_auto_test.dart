import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/status_auto.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parity/status_a6.json').readAsStringSync(),
  ) as Map;
  for (final raw in fixture['shots'] as List) {
    final state = Map<String, dynamic>.from(raw as Map);
    test('A6 original timer plan ${state['name']}', () {
      final original = jsonEncode(state);
      final plan = statusAutoPlan(state);
      expect(plan, state['expected']);
      expect(jsonEncode(state), original);
      final before = {
        for (final c in state['cards'] as List) c['id']: c['dataset']['st'],
      };
      for (final q in plan['queue'] as List) {
        if (q['next'] != null) before[q['id']] = q['next'];
      }
      for (final m in plan['moves'] as List) {
        before[m['id']] = m['next'];
      }
      expect(before, {
        for (final c in state['after'] as List) c['id']: c['st'],
      });
    });
    test('A6 future local reminders ${state['name']}', () {
      final plan = queueNoticePlan(state);
      if ((state['rules'] as Map)['q'] == false) {
        expect(plan, isEmpty);
      } else {
        expect(plan.map((n) => n['order']), [
          'q_before',
          'q_future',
          'q_missing',
        ]);
        for (final n in plan) {
          expect(n['at'], greaterThan(state['now'] as num));
          expect(n['id'], inInclusiveRange(0, 2147483646));
        }
      }
    });
  }
  test('A6 no hidden stage automation until supported', () {
    final state = Map<String, dynamic>.from((fixture['shots'] as List).first);
    state['rules'] = {...state['rules'] as Map, 'p': true};
    expect(() => statusAutoPlan(state), throwsStateError);
  });
  test('A6 unsigned notification hash handles UTF16', () {
    expect(queueNoticeId('GY-261006-0133'), 732311147);
    expect(queueNoticeId('😀'), 55357);
  });
}
