// Renders native Flutter pages to PNG so they can be compared with the HTML design.
// CI: flutter test --tags screens --update-goldens (pushes test/screens/*.png to branch ci-screens).
@Tags(['screens'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/addorder_page.dart';
import 'package:goyana_flutter/native/home_page.dart';
import 'package:goyana_flutter/native/orders_page.dart';

class _NoActions implements HomeActions {
  @override
  void scan() {}
  @override
  void slide(int index) {}
  @override
  void tile(int index) {}
  @override
  void manageOutlet() {}
  @override
  void qr() {}
  @override
  void monthly() {}
  @override
  void helpChat() {}
  @override
  void nav(String pageId) {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

class _NoOrderActions implements OrdersActions {
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void autoSettings() {}
  @override
  void addOrder() {}
  @override
  void search(String text) {}
  @override
  void tab(int index) {}
  @override
  void openCard(int index) {}
  @override
  void cardAction(int index) {}
}

Map<String, dynamic> _card(int i, String id, String name, String status, String sbg, String sc, String action, {String? auto, List<String> chips = const [], String gender = 'male', String pay = 'Belum Bayar'}) => {
      'i': i, 'id': id, 'name': name, 'amount': 'Rp14.000', 'gender': gender,
      'dur': {'t': 'Reguler', 'bg': 'rgb(241, 242, 245)', 'c': 'rgb(91, 95, 110)'},
      'status': {'t': status, 'bg': sbg, 'c': sc},
      'pay': pay == 'Lunas'
          ? {'t': 'Lunas', 'bg': 'rgb(232, 247, 238)', 'c': 'rgb(31, 150, 90)'}
          : {'t': pay, 'bg': 'rgb(255, 240, 241)', 'c': 'rgb(216, 50, 63)'},
      'auto': auto == null ? null : {'t': auto, 'bg': 'rgb(238, 244, 255)', 'c': 'rgb(43, 106, 166)'},
      'chips': [for (final c in chips) {'t': c, 'bg': 'rgb(241, 242, 245)', 'c': 'rgb(91, 95, 110)'}],
      'action': {'t': action, 'bg': 'rgb(232, 73, 63)', 'c': 'rgb(255, 255, 255)'},
      'lines': <String>[],
    };

final _orders = OrdersModel.fromJson({
  'title': 'Pesanan', 'auto': {'t': 'Otomatis', 'on': true}, 'search': '', 'placeholder': 'Cari nama / ID / no HP',
  'tabs': [
    {'t': 'Penjemputan', 'n': '0', 'on': false}, {'t': 'Antrian', 'n': '3', 'on': true}, {'t': 'Proses', 'n': '1', 'on': false},
    {'t': 'Siap Ambil', 'n': '0', 'on': false}, {'t': 'Diantar', 'n': '0', 'on': false},
  ],
  'cards': [
    _card(0, 'GY-261002-0135', 'Andi Wijaya', 'Antrian', 'rgb(255, 240, 241)', 'rgb(232, 73, 63)', 'Proses', auto: '⏱ 1j'),
    _card(1, 'GY-261002-0134', 'Sari Dewi', 'Proses', 'rgb(238, 244, 255)', 'rgb(43, 106, 166)', 'Tandai Siap ›', chips: ['Antar'], gender: 'female'),
    _card(2, 'GY-261002-0133', 'Budi Santoso Pratama Wijayakusuma', 'Antrian', 'rgb(255, 240, 241)', 'rgb(232, 73, 63)', 'Proses', auto: '⏱ 1j', pay: 'Lunas'),
  ],
});

class _NoAddActions implements AddOrderActions {
  @override
  void scan() {}
  @override
  void aoBack() {}
  @override
  void aoSearchCustomer(String text) {}
  @override
  void aoAddCustomer() {}
  @override
  void aoPickCustomer(int index) {}
  @override
  void aoDuration(int index) {}
  @override
  void aoSearchService(String text) {}
  @override
  void aoCategory(int index) {}
  @override
  void aoService(int index) {}
  @override
  void aoNext() {}
}

const _avatar = '<svg viewBox="0 0 64 64"><path d="M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54" fill="#5C97F8"/><circle cx="32" cy="26" r="11" fill="#FFD6B3"/><path d="M21 24.5c0-8.5 4.5-13.5 11-13.5 6.6 0 11 5 11 13.5v2.1H21v-2.1z" fill="#26384D"/><circle cx="28" cy="26" r="1.3" fill="#26384D"/><circle cx="36" cy="26" r="1.3" fill="#26384D"/><path d="M29 31c1.6 1.6 4.4 1.6 6 0" stroke="#D58A78" stroke-width="1.7" fill="none" stroke-linecap="round"/></svg>';
const _basket = '<svg viewBox="0 0 48 48"><rect x="12" y="7" width="24" height="6" rx="2.5" fill="#E8493F"/><rect x="10" y="11.5" width="28" height="6" rx="2.5" fill="#ffc857"/><path d="M7 19h34l-3.6 20.5A3 3 0 0 1 34.4 42H13.6a3 3 0 0 1-3-2.5z" fill="#3b82c4"/><rect x="5" y="17" width="38" height="5" rx="2.5" fill="#2b6aa6"/></svg>';
const _bed = '<svg viewBox="0 0 48 48"><rect x="4" y="16" width="4" height="26" rx="1.5" fill="#c68a55"/><rect x="40" y="24" width="4" height="18" rx="1.5" fill="#c68a55"/><rect x="8" y="26" width="32" height="10" rx="2" fill="#ffffff"/><path d="M18 24h20a2 2 0 0 1 2 2v10H18z" fill="#5aa9e6"/><rect x="4" y="36" width="40" height="3" fill="#9c6a3c"/></svg>';

final _addCustomer = AddOrderModel.fromJson({
  'title': 'Pilih Pelanggan', 'step': 'Langkah 1 dari 5', 'stage': 'customer', 'search': {'v': '', 'ph': 'Cari nama / no handphone'}, 'add': 'Tambah Pelanggan',
  'people': [
    {'i': 0, 'name': 'Sari Dewi', 'avatar': _avatar, 'lines': ['☎ 081200000002', '⌖ Jakarta'], 'btn': 'Pilih'},
    {'i': 1, 'name': 'Budi Santoso Pratama Wijayakusuma', 'avatar': _avatar, 'lines': ['☎ 081200000001', '⌖ Jl. Raya Bekasi No. 12, Jakarta Timur'], 'btn': 'Pilih'},
  ],
});

final _addServices = AddOrderModel.fromJson({
  'title': 'Tambahkan Layanan', 'step': 'Langkah 2 dari 5', 'stage': 'services', 'search': {'v': '', 'ph': 'Cari layanan Express'},
  'customer': {'name': 'Sari Dewi', 'sub': 'Express · 24 Jam', 'avatar': _avatar},
  'durations': [{'t': 'Reguler', 's': '72 Jam', 'on': false}, {'t': 'Express', 's': '24 Jam', 'on': true}, {'t': 'Kilat', 's': '6 Jam', 'on': false}],
  'cats': [{'t': 'Semua', 'on': true, 'svg': ''}, {'t': 'Kiloan', 'on': false, 'svg': _basket}, {'t': 'Satuan', 'on': false, 'svg': _bed}, {'t': 'Meteran', 'on': false, 'svg': _bed}],
  'items': [
    {'h': 1, 'svg': _basket, 't': 'Kiloan · Express', 's': 'Cuci ››› Kering ››› Setrika'},
    {'i': 0, 'svg': _basket, 't': 'Cuci Baju', 's': 'Rp 10.500 / kg · 24 Jam', 'btn': '3 kg', 'on': true},
    {'i': 1, 'svg': _basket, 't': 'Setrika', 's': 'Rp 7.500 / kg · 24 Jam', 'btn': 'Pilih', 'on': false},
    {'h': 1, 'svg': _bed, 't': 'Satuan · Express', 's': 'Cuci ››› Kering ››› Packing'},
    {'i': 2, 'svg': _bed, 't': 'Sprei', 's': 'Rp 22.500 / pcs · 24 Jam', 'btn': 'Pilih', 'on': false},
  ],
  'footer': {'name': 'Sari Dewi', 'sum': '3 kg · 0 pcs · 0 m', 'label': 'Total Layanan', 'total': 'Rp 31.500', 'btn': 'LANJUT ›'},
});

void main() {
  setUpAll(_loadFonts);

  for (final width in [320.0, 390.0, 412.0]) {
    testWidgets('Beranda native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeHome(model: const HomeModel(badge: '3'), actions: _NoActions(), topInset: 0),
        ),
      ));
      // flutter_svg decodes asynchronously.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/home_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('Pesanan native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeOrders(model: _orders, actions: _NoOrderActions(), topInset: 0),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/orders_${width.toInt()}.png'));
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final entry in {'addorder_customer': _addCustomer, 'addorder_services': _addServices}.entries) {
      testWidgets('Tambah Transaksi ${entry.key} at $width px', (tester) async {
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('screen'),
            child: NativeAddOrder(model: entry.value, actions: _NoAddActions(), topInset: 0),
          ),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/${entry.key}_${width.toInt()}.png'));
      });
    }
  }
}
