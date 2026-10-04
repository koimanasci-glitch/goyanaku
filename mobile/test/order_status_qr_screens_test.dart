@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/order_detail_page.dart';
import 'package:goyana_flutter/native/order_status_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Actions implements OrderDetailActions {
  final buttons = <int>[];
  @override
  void scan() {}
  @override
  void odButton(int index) => buttons.add(index);
  @override
  void odTap(int index) {}
  @override
  void odClose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });
  test('QR status memakai ID pesanan, tidak memiliki ID contoh cadangan', () {
    expect(orderStatusId({'sub': 'GY-261005-0133 · Reguler'}), 'GY-261005-0133');
    for (final model in <Map<String, dynamic>>[{}, {'sub': null}, {'sub': 42}, {'sub': ''}, {'sub': '../pesanan-lain'}, {'sub': '<script>'}]) {
      expect(orderStatusId(model), isNull);
    }
    expect(orderStatusUrl('GY-261005-0133'), 'https://goyana.id/s/GY-261005-0133');
  });
  for (final width in [320, 390]) {
    testWidgets('Tombol QR dan popup pesanan aktif $width', (tester) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = Map<String, dynamic>.from(jsonDecode(File('test/fixtures/order_detail_od.json').readAsStringSync()) as Map);
      final actions = _Actions();
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
        home: Builder(builder: (context) => RepaintBoundary(key: const Key('screen'),
          child: NativeOrderDetail(model: model, actions: actions, topInset: 31,
            onQrStatus: () => showModalBottomSheet<void>(context: context, isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => NativeOrderStatusQr(orderId: orderStatusId(model)!,
                customerName: '${(model['customer'] as Map)['name']}', onClose: () => Navigator.pop(context))),
          )))));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/order_detail_with_qr_$width.png'));
      await tester.tap(find.text('KIRIM NOTA WA'));
      expect(actions.buttons, [(model['actions'] as List).firstWhere((a) => a['green'] == true)['b']]);
      await tester.tap(find.byKey(const Key('order-detail-status-qr')));
      await tester.pumpAndSettle();
      final qr = tester.widget<QrImageView>(find.byKey(const Key('order-status-qr-image')));
      expect(qr.data, 'https://goyana.id/s/GY-261003-0133');
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(NativeOrderStatusQr), matchesGoldenFile('screens/order_status_qr_native_$width.png'));
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(NativeOrderStatusQr), findsNothing);
    });
  }
}
