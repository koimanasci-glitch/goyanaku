// Paritas logika Dart dengan HTML: setiap fixture berisi isi penyimpanan HTML, waktu, dan model yang ditampilkan HTML.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/logic/home.dart';
import 'package:goyana_flutter/logic/orders.dart';
import 'package:goyana_flutter/logic/addorder.dart';

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
  final draftFixture = jsonDecode(File('test/fixtures/parity/addorder_cart.json').readAsStringSync()) as Map<String, dynamic>;
  for (final shot in draftFixture['shots'] as List) {
    test('Tambah Transaksi sama dengan HTML: ${shot['name']}', () async {
      final store = MemoryKvStore(Map<String, String>.from(shot['store'] as Map));
      final b = await Business.load(store);
      final got = addorderModel(b, Map<String, dynamic>.from(shot['draft'] as Map), Map<String, dynamic>.from(shot['htmlModel'] as Map));
      expect(got, shot['htmlModel']);
      // Angka yang salah di presentasi tidak boleh menjadi sumber perhitungan.
      final changed = jsonDecode(jsonEncode(shot['htmlModel'])) as Map<String, dynamic>;
      (changed['footer'] as Map).addAll({'total': 'SALAH', 'sum': 'SALAH'});
      expect(addorderModel(b, Map<String, dynamic>.from(shot['draft'] as Map), changed), shot['htmlModel']);
    });
  }
  for (final q in draftFixture['quantities'] as List) {
    test('Jumlah HTML ${q['unit']}: ${q['input']}', () {
      expect(transactionSubtotal(q['input'] as String, q['price'] as num), q['subtotal']);
      final error = transactionQuantityError(transactionQuantity(q['input'] as String), q['unit'] as String);
      expect(error != null, q['rejected']);
      if (error != null) expect(error, q['toast']);
    });
  }
  final shots = draftFixture['shots'] as List;
  for (var i = 1; i < shots.length; i++) {
    final shot = shots[i] as Map;
    if (!'${shot['name']}'.startsWith('duration_')) continue;
    test('Ganti durasi persis HTML: ${shot['name']}', () {
      final before = shots[i - 1]['draft'] as Map;
      final after = shot['draft'] as Map;
      final got = transactionChangeDuration((before['cart'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(), (after['catalog'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(), after['duration'] as String);
      expect(got, after['cart']);
    });
  }

}
