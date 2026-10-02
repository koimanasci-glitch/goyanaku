// Renders native Flutter pages to PNG so they can be compared with the HTML design.
// CI: flutter test --tags screens --update-goldens (pushes test/screens/*.png to branch ci-screens).
@Tags(['screens'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
