// Logika murni Dart dibandingkan dengan aplikasi HTML (fixtures/core/snapshot.json diambil dari HTML).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/models.dart';
import 'package:goyana_flutter/core/money.dart';
import 'package:goyana_flutter/core/qris.dart';
import 'package:goyana_flutter/core/receipt.dart';
import 'package:goyana_flutter/core/store.dart';

Map<String, dynamic> _snap() => jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;

Future<Business> _load() async {
  final s = _snap();
  final kv = MemoryKvStore({
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
  });
  return Business.load(kv);
}

void main() {
  test('format rupiah sama dengan toLocaleString id-ID', () {
    expect(rp(14000), 'Rp14.000');
    expect(rpSpaced(1250000), 'Rp 1.250.000');
    expect(rp(0), 'Rp0');
    expect(parseRupiah('Rp 14.000'), 14000);
    expect(parseQty('1,3'), 1.3);
    expect(qtyText(1.5), '1,5');
    expect(qtyText(2), '2');
  });

  test('hitung total identik dengan api115.calc di HTML', () {
    for (final c in (_snap()['calc'] as List).cast<Map<String, dynamic>>()) {
      final input = c['in'] as Map<String, dynamic>, out = c['out'] as Map<String, dynamic>;
      final items = (input['items'] as List).map((e) => OrderItem(name: 'x', unit: 'kg', price: (e['price'] as num).round(), qty: (e['qty'] as num).toDouble())).toList();
      final t = calcTotals(items, input['discKey'] as String, (input['ongkir'] as num).round());
      expect([t.sub, t.disc, t.total], [out['sub'], out['disc'], out['total']], reason: jsonEncode(input));
    }
  });

  test('data HTML lama terbaca: pesanan, pelanggan, layanan, outlet', () async {
    final b = await _load();
    expect(b.orders, hasLength(1));
    final o = b.orders.first;
    expect(o.id, 'GY-261003-0133');
    expect(o.name, 'Budi Native');
    expect(o.status, 'antrian');
    expect(o.total, 14000);
    expect(o.paymentLabel, 'Belum Bayar');
    expect(o.items.single.name, 'Cuci Baju');
    expect(b.customers.single.phone, '081200000001');
    expect(b.services.map((s) => s.name), contains('Cuci Baju'));
    expect(b.services.firstWhere((s) => s.name == 'Cuci Baju').priceFor('Express'), 10500);
    expect(b.outlets.single.name, 'Uji');
    expect(b.activeOutlet, startsWith('outlet180-'));
  });

  test('pesanan baru, status, pembayaran, batal — disimpan dengan format HTML', () async {
    final b = await _load();
    final now = DateTime(2026, 10, 3, 9, 30);
    final o = b.createOrder(
      customer: 'Sari', phone: '081200000002', dur: 'Express',
      items: [OrderItem(name: 'Cuci Baju', icon: 'Kiloan', unit: 'kg', price: 10500, qty: 2)],
      discKey: 'p10', payMethod: 'DP / Uang Muka', dpMethod: 'QRIS', payAmount: 5000, now: now,
    );
    expect(o.id, 'GY-261003-0134', reason: 'nomor urut melanjutkan nomor terbesar');
    expect(o.total, 18900);
    expect(o.paid, 5000);
    expect(o.paymentLabel, 'DP Rp5.000');
    expect(o.due, DateTime(2026, 10, 4, 9, 30));
    expect(o.fields[3], ['Masuk · baru saja', 'Estimasi · 04/10/2026 · 09:30']);
    expect(o.dataset['method177'], 'QRIS');
    expect(o.dataset['disc'], '2100');
    expect(b.customerByName('Sari')?.phone, '081200000002');
    expect(b.orders.first.id, o.id, reason: 'pesanan baru di atas');

    expect(b.advance(o, now: now), 'cuci');
    o.status = 'setrika';
    expect(b.advance(o, now: now), 'siap', reason: 'tahap proses langsung ke siap seperti HTML');
    expect(b.advance(o, now: now), 'diambil');
    expect(b.advance(o, now: now), isNull);

    expect(b.pay(o, method: 'Tunai', amount: 50000, now: now), isNull);
    expect(o.paid, 18900, reason: 'tidak melebihi sisa tagihan');
    expect(o.paymentLabel, 'Lunas');
    expect(o.payments.map((p) => p['a']), [5000, 13900]);
    expect((b.kas['sales'] as List).where((s) => s['id'] == o.id).map((s) => s['a']), [5000, 13900]);

    final o2 = b.createOrder(customer: 'Budi Native', dur: 'Reguler', items: [OrderItem(name: 'Sprei', unit: 'pcs', price: 15000, qty: 1)], now: now);
    expect(b.cancel(o2, reason: '', now: now), isNotNull);
    expect(b.cancel(o2, reason: 'Salah input pesanan', now: now), isNull);
    expect(o2.status, 'batal');
    expect(b.today(now).inCount, 2, reason: 'pesanan lama hari ini + Sari; yang batal tidak dihitung');

    // Simpan → muat ulang: tetap sama (format sama dengan HTML).
    await b.save();
    final again = await Business.load(b.store);
    expect(again.orders.map((e) => e.id), [o2.id, o.id, 'GY-261003-0133']);
    expect(again.orderById(o.id)!.paid, 18900);
    expect(again.orderById(o2.id)!.status, 'batal');
  });

  test('pelanggan: nama & HP wajib, tidak dobel', () async {
    final b = await _load();
    expect(b.saveCustomer(Customer(name: 'Tono', phone: '')), isNotNull);
    expect(b.saveCustomer(Customer(name: 'Tono', phone: '0812')), isNull);
    expect(b.saveCustomer(Customer(name: 'tono', phone: '0813')), isNotNull);
    expect(b.saveCustomer(Customer(name: 'Tono', phone: '0813'), originalName: 'Tono'), isNull);
    expect(b.customerByName('Tono')!.phone, '0813');
  });

  test('QRIS dinamis identik dengan HTML (CRC16 & tag 54)', () {
    final q = jsonDecode(File('test/fixtures/core/qris.json').readAsStringSync()) as Map<String, dynamic>;
    final st = q['static'] as String;
    expect(qrisValid(st), isTrue);
    expect(qrisValid(st.substring(0, st.length - 1) + (st.endsWith('0') ? '1' : '0')), isFalse);
    expect(qrisDynamic(st, 14000), q['dyn14000']);
    expect(qrisDynamic(st, 23625.4), q['dyn23625']);
    expect(qrisValid(qrisDynamic(st, 14000)), isTrue);
    expect(qrisMerchant(st).name, 'TEST LAUNDRY');
  });

  test('struk 58 mm: lebar 32 kolom, total & status benar', () async {
    final b = await _load();
    final o = b.orders.first;
    final text = receiptText(o, const ReceiptSettings(header: 'Laundry Uji', address: 'Jl. Melati No. 5 Jakarta Timur'));
    for (final l in text.split('\n')) {
      expect(l.length, lessThanOrEqualTo(32), reason: l);
    }
    expect(text, contains('GY-261003-0133'));
    expect(text, contains('TOTAL'));
    expect(text, contains('Rp14.000'));
    expect(text, contains('BELUM BAYAR'));
  });
}
