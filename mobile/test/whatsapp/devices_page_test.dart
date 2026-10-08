import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/whatsapp/device_store.dart';
import 'package:goyana_flutter/whatsapp/devices_page.dart';
import 'package:goyana_flutter/whatsapp/automation_tile.dart';

class MemoryStorage implements WaStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    values[key] = value;
    return true;
  }
}

void main() {
  testWidgets('offline create form uses real sole outlet and persists draft', (
    t,
  ) async {
    final store = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'local-business',
      outlets: const [WaOutlet(key: 'real-outlet', name: 'Pusat')],
    );
    await t.pumpWidget(MaterialApp(home: WhatsAppDevicesPage(store: store)));
    await t.pumpAndSettle();
    await t.tap(find.text('Tambah Perangkat'));
    await t.pumpAndSettle();
    expect(find.text('Pusat'), findsWidgets);
    await t.enterText(find.byType(TextFormField).at(0), 'Nomor Pusat');
    await t.enterText(find.byType(TextFormField).at(1), '081234567890');
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    expect(store.devices.single.outletKey, 'real-outlet');
    expect(find.text('Draf di perangkat ini'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'automation can disable expired entitlement but cannot enable it',
    (t) async {
      bool? changed;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaStatusAutomationTile(
              value: true,
              allowed: false,
              busy: false,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      await t.tap(find.byType(Checkbox));
      expect(changed, false);
      changed = null;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaStatusAutomationTile(
              value: false,
              allowed: false,
              busy: false,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      await t.tap(find.byType(Checkbox));
      expect(changed, isNull);
    },
  );
}
