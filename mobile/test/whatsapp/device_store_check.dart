// ignore_for_file: avoid_print
// Standalone Dart checks: no Flutter engine or network required.
import 'dart:convert';

import 'package:goyana_flutter/whatsapp/device_store.dart';

class MemoryStorage implements WaStorage {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    if (fail) return false;
    values[key] = value;
    return true;
  }
}

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> fails(Future<void> Function() f) async {
  try {
    await f();
  } on WaFailure {
    return;
  }
  throw StateError('Expected WaFailure');
}

Future<void> main() async {
  var passed = 0;
  Future<void> test(String name, Future<void> Function() f) async {
    await f();
    passed++;
    print('PASS $name');
  }

  const outlets = [WaOutlet(key: 'pusat-local', name: 'Pusat', serverId: 21)];
  final now = DateTime.utc(2026, 10, 8);
  await test('save offline, reload and normalize phone', () async {
    final storage = MemoryStorage();
    final a = WaDeviceStore(
      storage: storage,
      accountScope: 'a',
      outlets: outlets,
    );
    await a.save(
      name: 'Pusat',
      phone: '+62 812-3456-7890',
      outletKey: outlets.first.key,
    );
    final b = WaDeviceStore(
      storage: storage,
      accountScope: 'a',
      outlets: outlets,
    );
    await b.load();
    check(b.devices.single.phone == '6281234567890', 'phone');
    check(
      b.devices.single.status == 'draft' && !b.devices.single.registered,
      'offline not connected',
    );
  });
  await test(
    'storage failure keeps previous record and reports failure',
    () async {
      final s = MemoryStorage();
      final a = WaDeviceStore(storage: s, accountScope: 'a', outlets: outlets);
      await a.save(
        name: 'One',
        phone: '081234567890',
        outletKey: 'pusat-local',
      );
      s.fail = true;
      await fails(
        () => a.save(
          id: a.devices.single.id,
          name: 'Changed',
          phone: '081234567890',
          outletKey: 'pusat-local',
        ),
      );
      check(a.devices.single.name == 'One', 'not mutated on failed save');
    },
  );
  await test('account drafts are isolated', () async {
    final s = MemoryStorage();
    final a = WaDeviceStore(storage: s, accountScope: 'a', outlets: outlets);
    await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
    final b = WaDeviceStore(storage: s, accountScope: 'b', outlets: outlets);
    await b.load();
    check(b.devices.isEmpty, 'leaked account');
  });
  await test('reject duplicate normalized phones', () async {
    final a = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'a',
      outlets: outlets,
    );
    await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
    await fails(
      () => a.save(name: 'B', phone: '6281234567890', outletKey: 'pusat-local'),
    );
  });
  await test('never invent outlet Pusat or accept foreign outlet', () async {
    final a = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'a',
      outlets: [],
    );
    await fails(
      () => a.save(name: 'A', phone: '081234567890', outletKey: 'pusat'),
    );
  });
  await test('unsynced outlet cannot provision remote device', () async {
    var calls = 0;
    final a = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'a',
      outlets: const [WaOutlet(key: 'local', name: 'Pusat')],
      request: (m, p, b) async {
        calls++;
        return {};
      },
    );
    await a.save(name: 'A', phone: '081234567890', outletKey: 'local');
    await fails(() async {
      await a.pair(a.devices.single.id, 'qr');
    });
    check(calls == 0, 'remote used invented ID');
  });
  await test('slot refusal retains offline draft', () async {
    final a = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'a',
      outlets: outlets,
      request: (m, p, b) async => throw const WaFailure('Slot penuh'),
    );
    await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
    await fails(() async {
      await a.pair(a.devices.single.id, 'qr');
    });
    check(!a.devices.single.registered, 'draft lost');
  });
  await test(
    'provision succeeds but pairing fails: retry does not reprovision',
    () async {
      var provisions = 0;
      var pairingCalls = 0;
      final a = WaDeviceStore(
        storage: MemoryStorage(),
        accountScope: 'a',
        outlets: outlets,
        clock: () => now,
        request: (m, p, b) async {
          if (p.endsWith('/devices')) {
            provisions++;
            return {...b!, 'version': 1, 'status': 'disconnected'};
          }
          pairingCalls++;
          if (pairingCalls == 1) throw const WaFailure('Gateway down');
          return {
            'kind': 'qr',
            'value': 'REAL_PROVIDER_TEST_VALUE',
            'expires_at': now.add(const Duration(minutes: 1)).toIso8601String(),
          };
        },
      );
      await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
      final id = a.devices.single.id;
      await fails(() async {
        await a.pair(id, 'qr');
      });
      final p = await a.pair(id, 'qr');
      check(provisions == 1 && p.kind == 'qr', 'provision duplicated');
      check(a.devices.single.status != 'connected', 'false connection');
    },
  );
  await test('QR and pairing code expiry validation', () async {
    for (final kind in ['qr', 'code']) {
      final a = WaDeviceStore(
        storage: MemoryStorage(),
        accountScope: 'a',
        outlets: outlets,
        clock: () => now,
        request: (m, p, b) async => p.endsWith('/devices')
            ? {...b!, 'version': 1, 'status': 'disconnected'}
            : {
                'kind': kind,
                'value': 'test',
                'expires_at': now.toIso8601String(),
              },
      );
      await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
      await fails(() async {
        await a.pair(a.devices.single.id, kind);
      });
    }
  });
  await test('provider payload never saved in local storage', () async {
    final s = MemoryStorage();
    final a = WaDeviceStore(
      storage: s,
      accountScope: 'a',
      outlets: outlets,
      clock: () => now,
      request: (m, p, b) async => p.endsWith('/devices')
          ? {...b!, 'version': 1, 'status': 'disconnected'}
          : {
              'kind': 'code',
              'value': 'SECRET_PAIR_CODE',
              'expires_at': now
                  .add(const Duration(minutes: 1))
                  .toIso8601String(),
            },
    );
    await a.save(name: 'A', phone: '081234567890', outletKey: 'pusat-local');
    await a.pair(a.devices.single.id, 'code');
    check(
      !s.values.values.join().contains('SECRET_PAIR_CODE'),
      'pairing secret persisted',
    );
  });
  await test('cached connected state becomes unknown on reopen', () async {
    final s = MemoryStorage();
    s.values['goyana-wa-drafts-v1:a'] = jsonEncode([
      {
        'id': 'id',
        'name': 'A',
        'phone': '6281234567890',
        'outlet_key': 'pusat-local',
        'outlet_id': 21,
        'registered': true,
        'version': 1,
        'status': 'connected',
      },
    ]);
    final a = WaDeviceStore(storage: s, accountScope: 'a', outlets: outlets);
    await a.load();
    check(a.devices.single.status == 'unknown', 'stale connected');
  });
  await test('failed server deletion does not release local record', () async {
    final s = MemoryStorage();
    s.values['goyana-wa-drafts-v1:a'] = jsonEncode([
      {
        'id': 'id',
        'name': 'A',
        'phone': '6281234567890',
        'outlet_key': 'pusat-local',
        'outlet_id': 21,
        'registered': true,
        'version': 1,
      },
    ]);
    final a = WaDeviceStore(
      storage: s,
      accountScope: 'a',
      outlets: outlets,
      request: (m, p, b) async => throw const WaFailure('Server down'),
    );
    await a.load();
    await fails(() => a.remove('id'));
    check(a.devices.length == 1, 'lost record');
  });
  await test('invalid phone strings rejected', () async {
    for (final p in [
      '08123456789@group',
      'abc08123456789',
      '123',
      '+0000',
      '',
    ]) {
      await fails(() async {
        normalizeWaPhone(p);
      });
    }
  });
  await test('corrupt local storage cannot be silently overwritten', () async {
    final s = MemoryStorage();
    s.values['goyana-wa-drafts-v1:a'] = 'corrupt';
    final a = WaDeviceStore(storage: s, accountScope: 'a', outlets: outlets);
    await fails(a.load);
    await fails(
      () =>
          a.save(name: 'New', phone: '081234567890', outletKey: 'pusat-local'),
    );
    check(s.values[a.storageKey] == 'corrupt', 'corrupt data overwritten');
  });
  await test('refresh failure clears remembered package entitlement', () async {
    var online = true;
    final a = WaDeviceStore(
      storage: MemoryStorage(),
      accountScope: 'a',
      outlets: outlets,
      request: (m, p, b) async {
        if (!online) throw const WaFailure('Offline');
        return {
          'devices': [],
          'quota': {
            'limit': 1,
            'used': 0,
            'status_allowed': true,
            'services_allowed': false,
          },
        };
      },
    );
    await a.refresh();
    check(a.statusAllowed, 'initial entitlement');
    online = false;
    await fails(a.refresh);
    check(!a.statusAllowed && a.slotLimit == null, 'stale entitlement');
  });
  print('$passed checks passed');
}
