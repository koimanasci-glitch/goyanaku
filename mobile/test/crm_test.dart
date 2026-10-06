import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/logic/crm.dart';
import 'package:goyana_flutter/native/crm_page.dart';

final _now = DateTime.utc(2026, 10, 6, 3);

Map _business() => {
      'orders': [
        _order('GY-1', 'Ani', 'siap', 35000, 35000, '2026-10-01T03:00:00.000Z'),
        _order('GY-2', 'Ani', 'diambil', 120000, 120000, '2026-09-20T03:00:00.000Z'),
        _order('GY-3', 'Budi', 'batal', 50000, 50000, '2026-09-25T03:00:00.000Z'),
        _order('GY-4', 'Citra', 'telat', 28000, 0, '2026-08-01T03:00:00.000Z'),
        _order('GY-5', 'Ani', 'diambil', 10000, 10000, '2026-09-10T03:00:00.000Z'),
      ],
      'details': {
        'GY-1': {'phone': '081200000001', 'hist': [{'st': 'antrian', 'at': '2026-10-01T03:00:00.000Z'}, {'st': 'siap', 'at': '2026-10-02T03:00:00.000Z'}]},
      },
      'customers': [
        {'name': 'Ani', 'phone': '081200000001'},
        {'name': 'Budi', 'phone': '081200000002'},
        {'name': 'Citra', 'phone': ''},
      ],
    };

Map _order(String id, String name, String st, int total, int paid, String created) => {
      'dataset': {'st': st, 'paid177': '$paid', 'created177': created},
      'fields': [['Reguler'], [id], [name]],
      'total': total,
    };

void main() {
  test('Poin dihitung dari pesanan lunas (batal tidak dihitung) dan dikurangi penukaran', () {
    final st = CrmState();
    final d = crmFromBusiness(_business(), st, _now);
    expect(d.members, {'Ani': 3 + 12 + 1}); // 35rb→3, 120rb→12, 10rb→1
    st.redeemed['Ani'] = 5;
    expect(crmBalances(d, st)['Ani'], 11);
    st.redeemed['Ani'] = 99;
    expect(crmBalances(d, st)['Ani'], 0);
  });

  test('Pengingat: siap sejak riwayat Siap, tahapan, template', () {
    final st = CrmState();
    final d = crmFromBusiness(_business(), st, _now);
    expect(d.uncollected.map((u) => u.id), ['GY-1', 'GY-4']);
    final u = d.uncollected.first;
    expect(u.days, 4);
    expect(crmStage(st, u.days).$1, 'Perlu diingatkan');
    expect(crmStage(st, 3).$1, 'Perlu diingatkan');
    expect(crmStage(st, 2).$1, 'Baru siap');
    expect(crmStage(st, 14).$1, 'Peringatan terakhir');
    expect(crmStage(st, 30).$1, 'Lewat 30 hari');
    expect(crmReminderText(st, u, 'Gramapuri'), contains('Ani'));
    expect(crmReminderText(st, u, 'Gramapuri'), isNot(contains('⚠️')));
    expect(crmReminderText(st, d.uncollected.last, 'G'), contains('biaya simpan Rp1.000/hari'));
  });

  test('Segmen pelanggan', () {
    final d = crmFromBusiness(_business(), CrmState(), _now);
    expect(d.segments['all'], ['Ani', 'Budi', 'Citra']);
    expect(d.segments['setia'], ['Ani']);
    expect(d.segments['pasif'], ['Citra']);
    expect(d.segments['baru'], ['Ani']); // pesanan pertama Ani 10/9 = 26 hari lalu
  });

  test('Tukar poin membuat voucher nominal dan memotong poin; voucher unik', () {
    final st = CrmState(rewards: [CrmReward('Gratis setrika', 10, 15000)]);
    final d = crmFromBusiness(_business(), st, _now);
    final rnd = math.Random(1);
    expect(crmRedeem(st, crmBalances(d, st), 'Budi', st.rewards.first, rnd: rnd), isNull);
    final v = crmRedeem(st, crmBalances(d, st), 'Ani', st.rewards.first, rnd: rnd)!;
    expect(v.val, 15000);
    expect(crmBalances(d, st)['Ani'], 6);
    final n = crmCreateVouchers(st, name: 'Promo', type: 'p', val: 10, min: 0, until: '2026-10-31', who: ['A', 'B', 'C'], rnd: rnd);
    expect(n, 3);
    expect(st.vouchers.map((x) => x.code).toSet().length, 4);
    expect(st.vouchers.first.status(_now), 'Aktif');
    expect(CrmVoucher(code: 'x', name: 'n', type: 'p', val: 5, until: '2026-10-01', who: 'a').status(_now), 'Kedaluwarsa');
  });

  test('Data CRM tersimpan dan terbaca ulang utuh', () async {
    final kv = MemoryKvStore();
    final st = CrmState(remDays: [1, 5], rule: 'donate', rewards: [CrmReward('X', 3, 1000)])
      ..redeemed['Ani'] = 2
      ..reminded['GY-1'] = [4];
    crmCreateVouchers(st, name: 'V', type: 'n', val: 5000, min: 20000, until: '2026-12-01', who: ['Ani']);
    await CrmStore(kv).save(st);
    final back = await CrmStore(kv).load();
    expect(back.toJson(), st.toJson());
    expect(back.ruleText, contains('disumbangkan'));
    expect((await CrmStore(MemoryKvStore()).load()).remDays, [3, 7]);
  });

  group('halaman', () {
    setUpAll(() async {
      final loader = FontLoader('Poppins');
      for (final f in ['Regular', 'Medium', 'SemiBold']) {
        final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    });

    Future<(MemoryKvStore, List<String>)> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final kv = MemoryKvStore();
      kv.data['goyana-business177'] = _encode(_business());
      final urls = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: NativeCrm(store: kv, onBack: () {}, onNav: (_) {}, onScan: () {}, openUrl: urls.add, topInset: 0, now: () => _now),
      ));
      await tester.pumpAndSettle();
      return (kv, urls);
    }

    testWidgets('Pengingat: kirim lewat WA mencatat H+ dan membuka tautan', (tester) async {
      final (kv, urls) = await pump(tester);
      expect(find.text('2 pesanan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('crm-remind-GY-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crm-ok')));
      await tester.pumpAndSettle();
      expect(urls.single, startsWith('https://wa.me/6281200000001?text='));
      expect(kv.data[crmKey], contains('"GY-1":[4]'));
      expect(find.textContaining('Sudah diingatkan: H+4'), findsOneWidget);
    });

    testWidgets('Poin: tambah hadiah lalu tukar poin membuat voucher', (tester) async {
      final (kv, _) = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('crm-tab-pt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crm-rw-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('crm-f0')), 'Gratis setrika');
      await tester.enterText(find.byKey(const ValueKey('crm-f1')), '10');
      await tester.enterText(find.byKey(const ValueKey('crm-f2')), '15000');
      await tester.tap(find.byKey(const ValueKey('crm-ok')));
      await tester.pumpAndSettle();
      expect(find.text('Gratis setrika'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('crm-redeem-Ani')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crm-ok')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Poin ditukar · kode GY-'), findsOneWidget);
      expect(find.text('⭐ 6'), findsOneWidget);
      expect(kv.data[crmKey], contains('"redeemed":{"Ani":10}'));
    });

    testWidgets('Voucher: buat untuk semua pelanggan menghasilkan 3 kode unik', (tester) async {
      final (kv, _) = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('crm-tab-vc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crm-vc-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('crm-f0')), 'Promo Oktober');
      await tester.enterText(find.byKey(const ValueKey('crm-f2')), '10');
      await tester.tap(find.byKey(const ValueKey('crm-ok')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 kode unik dibuat'), findsOneWidget);
      expect('GY-'.allMatches(kv.data[crmKey]!).length, 3);
    });
  });
}

String _encode(Map m) => jsonEncode(m);
