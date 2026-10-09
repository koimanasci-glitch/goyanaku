// Perbaikan tutup kasir 10 Oktober 2026: pembatalan mengembalikan dana otomatis, setoran kurir = omset tunai.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/models.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/logic/cash.dart';

Future<Business> _load() async {
  final s = jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;
  final kv = MemoryKvStore({
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
  });
  final b = await Business.load(kv);
  b.kas
    ..['sales'] = <dynamic>[]
    ..['ins'] = <dynamic>[]
    ..['outs'] = <dynamic>[]
    ..['start'] = 100000;
  return b;
}

void main() {
  final now = DateTime(2026, 10, 10, 9);
  List<OrderItem> items() => [OrderItem(name: 'Sprei', unit: 'pcs', price: 20000, qty: 1)];

  test('batal pesanan lunas tunai: pengembalian dana jadi pengeluaran, laci seharusnya kembali ke modal', () async {
    final b = await _load();
    final o = b.createOrder(customer: 'Budi Native', dur: 'Reguler', items: items(), payMethod: 'Tunai', now: now);
    expect(cashSummaryA7(b.kas)['expect'], 120000);
    expect(b.cancel(o, reason: 'Salah input pesanan', now: now), isNull);
    final outs = (b.kas['outs'] as List).cast<Map>();
    expect([outs.single['t'], outs.single['a'], outs.single['n']], ['Pengembalian dana', 20000, o.id]);
    final c = cashSummaryA7(b.kas);
    expect(c['expect'], 100000, reason: 'uang yang dikembalikan sudah keluar dari laci');
    expect(o.detail['refunded'], 20000);
    expect(b.cancel(o, reason: 'lagi', now: now), isNotNull, reason: 'tidak bisa dibatalkan / dikembalikan dua kali');
    expect((b.kas['outs'] as List).length, 1);
  });

  test('batal pesanan QRIS dan deposit: non-tunai jadi pengeluaran non-tunai, deposit kembali ke saldo', () async {
    final b = await _load();
    final q = b.createOrder(customer: 'Budi Native', dur: 'Reguler', items: items(), payMethod: 'QRIS', now: now);
    b.cancel(q, reason: 'Batal', now: now);
    expect(((b.kas['outs'] as List).single as Map)['m'], 'Non-Tunai');
    expect(cashSummaryA7(b.kas)['expect'], 100000, reason: 'laci tunai tidak berubah');

    expect(b.topUpDeposit('Budi Native', 50000, method: 'Tunai', now: now), isNull);
    final d = b.createOrder(customer: 'Budi Native', dur: 'Reguler', items: items(), payMethod: 'Bayar Nanti', now: now);
    expect(b.pay(d, method: 'Deposit', amount: d.total, now: now), isNull);
    expect(b.depositOf('Budi Native'), 30000);
    b.cancel(d, reason: 'Batal', now: now);
    expect(b.depositOf('Budi Native'), 50000);
    expect((b.kas['outs'] as List).length, 1, reason: 'deposit tidak keluar dari kas');
  });

  test('bayar saldo deposit tercatat sekali; setoran kurir masuk omset tunai', () async {
    final b = await _load();
    b.topUpDeposit('Budi Native', 50000, method: 'Tunai', now: now);
    final d = b.createOrder(customer: 'Budi Native', dur: 'Reguler', items: items(), payMethod: 'Bayar Nanti', now: now);
    b.pay(d, method: 'Deposit', amount: d.total, now: now);
    expect(d.payments.length, 1);
    expect(cashSummaryA7(b.kas)['omset'], 20000);

    b.courierDeposit(amount: 35000, courier: 'Andi', now: now);
    final c = cashSummaryA7(b.kas);
    expect(c['t'], 35000);
    expect(c['omset'], 55000);
    expect(c['expect'], 100000 + 50000 + 35000);
  });
}
