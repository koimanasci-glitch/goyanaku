// Paritas logika Dart dengan HTML: setiap fixture berisi isi penyimpanan HTML, waktu, dan model yang ditampilkan HTML.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/logic/home.dart';
import 'package:goyana_flutter/logic/orders.dart';

void main() {
  final files = Directory('test/fixtures/parity').listSync().whereType<File>().where((f) => f.path.contains('home_')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    test('Beranda sama dengan HTML: ${f.uri.pathSegments.last}', () async {
      final fx = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final store = MemoryKvStore({for (final e in (fx['store'] as Map).entries) '${e.key}': '${e.value}'});
      final b = await Business.load(store);
      final got = homeModel(b, DateTime.parse(fx['now'] as String));
      expect(jsonDecode(jsonEncode(got)), fx['home']);
    });
  }

  final orderFiles = Directory('test/fixtures/parity').listSync().whereType<File>().where((f) => f.path.contains('orders_')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in orderFiles) {
    final fx = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final tabs = fx['tabs'] as List;
    for (var t = 0; t < tabs.length; t++) {
      test('Pesanan sama dengan HTML: ${f.uri.pathSegments.last} tab $t', () async {
        final store = MemoryKvStore({for (final e in (fx['store'] as Map).entries) '${e.key}': '${e.value}'});
        final b = await Business.load(store);
        final got = ordersModel(b, tab: t, now: DateTime.parse(fx['now'] as String));
        expect(jsonDecode(jsonEncode(got)), tabs[t]);
      });
    }
    test('Pesanan pencarian sama dengan HTML: ${f.uri.pathSegments.last}', () async {
      final store = MemoryKvStore({for (final e in (fx['store'] as Map).entries) '${e.key}': '${e.value}'});
      final b = await Business.load(store);
      final s = fx['search'] as Map;
      final got = ordersModel(b, tab: (s['tab'] as num).toInt(), search: '${s['q']}', now: DateTime.parse(fx['now'] as String));
      expect(jsonDecode(jsonEncode(got)), s['model']);
    });
  }
}
