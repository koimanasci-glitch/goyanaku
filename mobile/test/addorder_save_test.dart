import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/addorder_save.dart';

void main() {
  final fixture = jsonDecode(File('test/fixtures/parity/save_orders.json')
      .readAsStringSync()) as Map<String, dynamic>;
  for (final dynamic c in fixture['cases'] as List) {
    test('3c snapshot HTML lengkap: ${c['name']}', () {
      final before = c['before'] as Map<String, dynamic>;
      final draft = c['draft'] as Map<String, dynamic>;
      final store = c['store'] as Map<String, dynamic>;
      final original = jsonEncode(c);
      final now = DateTime.parse(c['now'] as String);
      final got = prepareAddOrderSave(before: before, draft: draft,
          store: store, now: now, localOffset: const Duration(hours: 7));
      expect(got, c['htmlModel']);
      expect(jsonEncode(c), original, reason: 'Input tidak boleh dimutasi');
      // Snapshot keluaran tidak boleh berbagi referensi ledger dengan input.
      (got['deposits178'] as Map)['uji'] = 1;
      expect(jsonEncode(c), original);
    });
    test('3c nomor dan estimasi HTML: ${c['name']}', () {
      final now = DateTime.parse(c['now'] as String);
      final local = now.toUtc().add(const Duration(hours: 7));
      expect(nextOrderCode(local, (c['before']['orders'] as List).length),
          c['code']);
      final due = orderEstimatedFinish(local, c['draft']['durationLabel'] as String,
          c['store']['goyana-durations199'] as String?);
      expect(orderEstimateText(due), c['htmlModel']['orders'][0]['fields'][3][1]);
    });
  }
}
