// Mode Murni ↔ server GOYANA: pemetaan data, masuk, dan putaran sinkronisasi (tanpa jaringan sungguhan).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/server_sync.dart';

Map<String, dynamic> _card(String id, String st, {String outlet = 'out-1', String created = '2026-10-08T03:00:00.000Z'}) => {
      'dataset': {'st': st, 'outlet180': outlet, 'created177': created},
      'fields': [
        ['Reguler'],
        [id],
        ['Siti'],
      ],
      'total': 14000,
    };

MemoryKvStore _phone() => MemoryKvStore({
      Keys.business: jsonEncode({
        'orders': [_card('GY-1', 'antrian')],
        'details': {
          'GY-1': {'id': 'GY-1', 'name': 'Siti', 'paid': 0},
        },
        'customers': [
          {'name': 'Siti', 'phone': '0812-3456-7890'},
          {'name': 'Tanpa Nomor', 'phone': ''},
        ],
        'deposits178': <String, dynamic>{},
        'kas': {'start': 0, 'sales': <dynamic>[], 'ins': <dynamic>[], 'outs': <dynamic>[], 'kasir': 'Rina'},
      }),
      Keys.services: jsonEncode([
        {'key': 'cuci setrika', 'name': 'Cuci Setrika', 'prices': {'Reguler': 7000}},
      ]),
      Keys.outlets: jsonEncode([
        {'id': 'out-1', 'name': 'Outlet Lama', 'address': 'Jl. A', 'phone': '0811'},
      ]),
      Keys.activeOutlet: jsonEncode('out-1'),
      'goyana-couriers181': jsonEncode([
        {'id': 'kur-1', 'name': 'Budi', 'outlets': ['out-1']},
      ]),
      'goyana-pickup202': jsonEncode([
        {'id': 'jp-1', 'name': 'Siti', 'status': 'baru', 'outlet': 'out-1'},
      ]),
      Keys.qrisText: '00020101021126',
    });

/// Server tiruan: mencatat permintaan dan menjawab sesuai jalur.
class _Server {
  final List<Map<String, dynamic>> calls = [];
  int rev = 0;
  List<Map<String, dynamic>> pullRecords = [];
  Map<String, dynamic> Function(Map<String, dynamic> change)? onChange;
  int status = 200;
  String role = 'owner';
  List<String>? perms;
  String noteDevice = '1';
  int outletLimit = 3;
  List<String> googleClients = ['client-goyana.apps.googleusercontent.com'];
  String sessionExpires = '';
  List<Map<String, dynamic>> outlets = [
    {'id': 5, 'key': 'srv-5', 'name': 'Pusat', 'code': 'PUS', 'address': 'Jl. Server', 'phone': '6281'},
  ];

  Future<ServerReply> send(String method, Uri url, Map<String, String> headers, String? body) async {
    final data = body == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(body) as Map);
    calls.add({'method': method, 'path': url.path, 'query': url.query, 'auth': headers['Authorization'] ?? '', 'body': data});
    if (status != 200) return ServerReply(status, jsonEncode({'message': 'Ditolak'}));
    if (url.path == '/api/session/options') {
      return ServerReply(200, jsonEncode({
        'google': {'client_ids': googleClients},
        'pin_length': 6,
      }));
    }
    if (url.path == '/api/session' || url.path == '/api/session/pin' || url.path == '/api/session/google') {
      return ServerReply(200, jsonEncode({'token': 'tok-1', 'expires_at': '2099-01-01T00:00:00+00:00'}));
    }
    if (url.path == '/api/me') {
      return ServerReply(200, jsonEncode({
        'user': {'id': 7, 'name': 'Rina', 'role': role, 'role_label': role == 'owner' ? 'Owner' : 'Kasir', 'permissions': perms ?? (role == 'owner' ? ['*'] : ['orders.create'])},
        'business': {'id': 1, 'name': 'Laundry Bekasi', 'allow_debt': true},
        'access': {'package': 'Silver', 'read_only': false, 'outlet_limit': 3, 'cashier_device_limit': 3},
        'outlets': outlets,
        'note': {'prefix': 'PUS', 'device': noteDevice},
        if (sessionExpires.isNotEmpty) 'session': {'expires_at': sessionExpires},
      }));
    }
    if (url.path == '/api/outlets' && method == 'POST') {
      if (outlets.length >= outletLimit) {
        return ServerReply(422, jsonEncode({
          'message': 'Data tidak valid',
          'errors': {
            'name': ['Paket Silver maksimal 1 pusat + 2 cabang. Upgrade paket untuk menambah cabang.'],
          },
        }));
      }
      final id = 5 + outlets.length;
      final made = <String, dynamic>{'id': id, 'key': 'srv-$id', 'name': data['name'], 'code': 'CB$id', 'address': data['address'], 'phone': data['phone']};
      outlets.add(made);
      return ServerReply(201, jsonEncode({'outlet': made}));
    }
    if (url.path == '/api/devices/shared') {
      return ServerReply(201, jsonEncode({
        'id': 1, 'device_secret': 'rahasia-hp',
        'outlet': {'id': 5, 'name': 'Pusat'},
      }));
    }
    if (url.path == '/api/devices/roster') {
      return ServerReply(200, jsonEncode({
        'outlet': {'id': 5, 'name': 'Pusat'},
        'staff': [
          {'id': 9, 'name': 'Siti', 'role': 'kasir', 'role_label': 'Kasir'},
        ],
      }));
    }
    if (url.path == '/api/devices/claim') {
      return ServerReply(200, jsonEncode({'slot': 2, 'note': {'prefix': 'PUS', 'device': '2'}}));
    }
    if (url.path == '/api/sync/pull') {
      final out = pullRecords;
      pullRecords = [];
      return ServerReply(200, jsonEncode({'records': out, 'cursor': rev, 'more': false, 'read_only': false}));
    }
    if (url.path == '/api/sync/push') {
      final results = <Map<String, dynamic>>[];
      for (final c in data['changes'] as List) {
        final change = Map<String, dynamic>.from(c as Map);
        final custom = onChange?.call(change);
        if (custom != null) {
          results.add(custom);
        } else {
          rev++;
          results.add({'status': 'applied', 'rev': rev, 'op_id': change['op_id']});
        }
      }
      return ServerReply(200, jsonEncode({'results': results}));
    }
    return const ServerReply(204, '');
  }

  List<Map<String, dynamic>> pushed() => [
        for (final c in calls)
          if (c['path'] == '/api/sync/push')
            for (final x in (c['body'] as Map)['changes'] as List) Map<String, dynamic>.from(x as Map),
      ];
}

Future<ServerSync> _connected(MemoryKvStore kv, _Server server, {String account = 'Owner@Laundry.test', String secret = 'PasswordAman123'}) async {
  final sync = ServerSync(kv, send: server.send, clock: () => DateTime(2026, 10, 8, 14, 5));
  await sync.load();
  expect(await sync.setUrl('https://app.goyana.test/'), isNull);
  await sync.login(account, secret);
  return sync;
}

void main() {
  test('data HP dipetakan ke koleksi server dengan kunci yang sama seperti aplikasi HTML', () async {
    final local = await extractLocal(_phone());
    expect(local.keys.toSet(), {
      'orders|GY-1', 'customers|phone:6281234567890', 'customers|name:tanpa nomor', 'services|cuci setrika',
      'couriers|kur-1', 'pickups|jp-1', 'settings|goyana-qris-text',
    });
    expect(local['orders|GY-1']!.outlet, 'out-1');
    final order = local['orders|GY-1']!.data as Map;
    expect((order['detail'] as Map)['name'], 'Siti');
    expect(local['settings|goyana-qris-text']!.data, '00020101021126');
    // Laci kas kosong dan outlet yang belum punya id server tidak dikirim.
    expect(local.keys.any((k) => k.startsWith('kas|') || k.startsWith('outlet_profiles|')), isFalse);
    expect(fingerprintOf(local['orders|GY-1']!), fingerprintOf((await extractLocal(_phone()))['orders|GY-1']!));
    expect(shortHash('abc'), '${0x1a47e90b.toRadixString(36)}:3');
  });

  test('data dari server digabung ke HP: tambah, ubah, hapus', () async {
    final kv = _phone();
    await applyRemote(kv, [
      {'collection': 'orders', 'key': 'GY-2', 'data': {'card': _card('GY-2', 'cuci', created: '2026-10-08T05:00:00.000Z'), 'detail': {'id': 'GY-2', 'name': 'Andi'}}, 'deleted': false, 'rev': 9},
      {'collection': 'orders', 'key': 'GY-1', 'data': {'card': _card('GY-1', 'siap'), 'detail': {'id': 'GY-1', 'name': 'Siti', 'paid': 14000}}, 'deleted': false, 'rev': 10},
      {'collection': 'customers', 'key': 'name:tanpa nomor', 'data': null, 'deleted': true, 'rev': 11},
      {'collection': 'services', 'key': 'karpet', 'data': {'key': 'karpet', 'name': 'Karpet'}, 'deleted': false, 'rev': 12},
      {'collection': 'pickups', 'key': 'jp-1', 'data': {'id': 'jp-1', 'status': 'ditugaskan', 'outlet': 'out-1'}, 'deleted': false, 'rev': 13},
      {'collection': 'settings', 'key': 'goyana-qris-text', 'data': 'BARU', 'deleted': false, 'rev': 14},
      {'collection': 'tidak-dikenal', 'key': 'x', 'data': {'a': 1}, 'deleted': false, 'rev': 15},
    ]);
    final b = jsonDecode(kv.data[Keys.business]!) as Map;
    // Pesanan terbaru di atas, seperti aplikasi HTML.
    expect([for (final o in b['orders'] as List) orderIdOf(o)], ['GY-2', 'GY-1']);
    expect((((b['orders'] as List)[1] as Map)['dataset'] as Map)['st'], 'siap');
    expect(((b['details'] as Map)['GY-1'] as Map)['paid'], 14000);
    expect([for (final c in b['customers'] as List) (c as Map)['name']], ['Siti']);
    expect([for (final s in jsonDecode(kv.data[Keys.services]!) as List) (s as Map)['key']], ['cuci setrika', 'karpet']);
    expect(((jsonDecode(kv.data['goyana-pickup202']!) as List).single as Map)['status'], 'ditugaskan');
    expect(kv.data[Keys.qrisText], 'BARU');
  });

  test('pemilik masuk dengan email: outlet lama di HP memakai id server di semua data', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    expect(server.calls[0]['path'], '/api/session');
    expect((server.calls[0]['body'] as Map)['email'], 'owner@laundry.test');
    expect(((server.calls[0]['body'] as Map)['device_id'] as String).length, greaterThanOrEqualTo(8));
    expect(server.calls[1]['auth'], 'Bearer tok-1');
    expect(sync.loggedIn, isTrue);
    expect(sync.role, 'owner');
    expect(sync.can('reports.view'), isTrue);
    expect(sync.note['prefix'], 'PUS');
    expect(jsonDecode(kv.data[Keys.activeOutlet]!), 'srv-5');
    expect(((jsonDecode(kv.data[Keys.outlets]!) as List).single as Map)['id'], 'srv-5');
    final local = await extractLocal(kv);
    expect(local['orders|GY-1']!.outlet, 'srv-5');
    expect(local['pickups|jp-1']!.outlet, 'srv-5');
    expect(((local['couriers|kur-1']!.data as Map)['outlets'] as List).single, 'srv-5');
    expect(local.containsKey('outlet_profiles|srv-5'), isTrue);
    // Sesi tersimpan: aplikasi yang dibuka ulang tetap masuk.
    final again = ServerSync(kv, send: server.send);
    await again.load();
    expect(again.loggedIn, isTrue);
    expect(again.url, 'https://app.goyana.test');
  });

  test('kasir, pegawai, kurir masuk dengan nomor HP dan PIN', () async {
    final kv = _phone(), server = _Server()..role = 'kasir';
    final sync = await _connected(kv, server, account: '0812-3456-7890', secret: '482915');
    expect(server.calls[0]['path'], '/api/session/pin');
    expect(server.calls[0]['body'], containsPair('phone', '6281234567890'));
    expect(server.calls[0]['body'], containsPair('pin', '482915'));
    expect(sync.role, 'kasir');
    expect(sync.can('orders.create'), isTrue);
    expect(sync.can('reports.view'), isFalse);
    await expectLater(sync.login('0812', '482915'), throwsA(isA<ServerFailure>()));
    await expectLater(sync.login('081234567890', 'bukan-angka'), throwsA(isA<ServerFailure>()));
    await expectLater(sync.login('', 'x'), throwsA(isA<ServerFailure>()));
  });

  test('putaran sinkronisasi: kirim sekali, tidak bolak-balik, lalu kirim perubahan berikutnya saja', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    await sync.cycle();
    expect(sync.status.phase, 'ok');
    expect(sync.status.pending, 0);
    final first = server.pushed();
    expect(first.map((c) => '${c['collection']}|${c['key']}').toSet(), (await extractLocal(kv)).keys.toSet());
    expect(first.every((c) => c['base_rev'] == 0 && '${c['op_id']}'.length >= 8), isTrue);
    expect(first.firstWhere((c) => c['collection'] == 'orders')['outlet'], 'srv-5');
    await sync.cycle();
    expect(server.pushed().length, first.length);

    final b = jsonDecode(kv.data[Keys.business]!) as Map;
    (((b['orders'] as List)[0] as Map)['dataset'] as Map)['st'] = 'cuci';
    kv.data[Keys.business] = jsonEncode(b);
    await sync.cycle();
    final later = server.pushed().sublist(first.length);
    expect(later.length, 1);
    expect([later.single['collection'], later.single['key']], ['orders', 'GY-1']);
    expect(later.single['base_rev'], greaterThan(0));
    expect(sync.card()!['line'], 'Online · semua data tersinkron · 14.05');
    expect(sync.card()!['who'], 'Rina · Owner · Laundry Bekasi');
    expect(sync.card()!.containsKey('url'), isFalse);
    expect(sync.card()!['now'], 'Sinkronkan sekarang');
  });

  test('data dari HP lain ditampung lalu diterapkan, tanpa dikirim balik', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    await sync.cycle();
    final sent = server.pushed().length;
    server.rev = 50;
    server.pullRecords = [
      {'collection': 'orders', 'key': 'GY-9', 'outlet': 'srv-5', 'data': {'card': _card('GY-9', 'antrian', outlet: 'srv-5'), 'detail': {'id': 'GY-9', 'name': 'HP Lain'}}, 'deleted': false, 'rev': 50},
    ];
    await sync.cycle();
    expect(await sync.inboxCount(), 1);
    expect((await extractLocal(kv)).containsKey('orders|GY-9'), isFalse);
    expect(await sync.applyInbox(), 1);
    expect((await extractLocal(kv)).containsKey('orders|GY-9'), isTrue);
    expect(await sync.inboxCount(), 0);
    await sync.cycle();
    expect(server.pushed().length, sent);
    expect(sync.status.pending, 0);
  });

  test('kiriman yang tidak diterima server: HP mengambil versi server dan pesannya tampil', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    await sync.cycle();
    final b = jsonDecode(kv.data[Keys.business]!) as Map;
    (((b['orders'] as List)[0] as Map)['dataset'] as Map)['st'] = 'siap';
    kv.data[Keys.business] = jsonEncode(b);
    server.onChange = (c) => {
          'status': 'conflict', 'op_id': c['op_id'], 'message': 'Hanya kasir atau owner yang menandai Siap Ambil.',
          'record': {'collection': 'orders', 'key': 'GY-1', 'outlet': 'srv-5', 'data': {'card': _card('GY-1', 'packing', outlet: 'srv-5'), 'detail': {'id': 'GY-1', 'name': 'Siti', 'paid': 0}}, 'deleted': false, 'rev': 77},
        };
    await sync.cycle();
    expect(sync.status.rejected, 'Hanya kasir atau owner yang menandai Siap Ambil.');
    expect(await sync.applyInbox(), 1);
    final order = (await extractLocal(kv))['orders|GY-1']!.data as Map;
    expect(((order['card'] as Map)['dataset'] as Map)['st'], 'packing');
    server.onChange = null;
    final before = server.pushed().length;
    await sync.cycle();
    expect(server.pushed().length, before);

    // Ditolak (mis. HP kasir ke-3): perubahan tetap menunggu dan dicoba lagi dengan op_id yang sama.
    final b2 = jsonDecode(kv.data[Keys.business]!) as Map;
    (b2['customers'] as List).add({'name': 'Baru', 'phone': '0899-0000-1111'});
    kv.data[Keys.business] = jsonEncode(b2);
    server.onChange = (c) => {'status': 'rejected', 'op_id': c['op_id'], 'message': 'Maksimal 2 perangkat kasir per outlet.'};
    await sync.cycle();
    expect(sync.status.pending, 1);
    expect(sync.card()!['line'], '1 data menunggu sinkronisasi · Maksimal 2 perangkat kasir per outlet.');
    final firstTry = server.pushed().last['op_id'];
    await sync.cycle();
    expect(server.pushed().last['op_id'], firstTry);
  });

  test('tanpa internet data menunggu; sesi yang dicabut server mengeluarkan akun', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    final offline = ServerSync(kv, send: (m, u, h, b) => throw const FormatException('putus'));
    await offline.load();
    await offline.cycle();
    expect(offline.status.phase, 'offline');
    expect(offline.status.pending, greaterThan(0));
    expect(offline.card()!['line'], startsWith('Offline · '));

    server.status = 401;
    await sync.cycle();
    expect(sync.loggedIn, isFalse);
    expect(sync.status.phase, 'error');
    expect(kv.data.containsKey(serverAuthKey), isFalse);
    expect(sync.card()!['line'], 'Belum masuk · data hanya di HP ini');
    expect(sync.card()!['save'], 'Simpan & masuk');
    expect((sync.card()!['url'] as Map)['v'], 'https://app.goyana.test');
  });

  test('keluar akun: sesi dihapus, data di HP tetap; alamat server tidak valid ditolak', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    await sync.logout();
    expect(server.calls.last['method'], 'DELETE');
    expect(sync.loggedIn, isFalse);
    expect((await extractLocal(kv)).containsKey('orders|GY-1'), isTrue);
    final fresh = ServerSync(MemoryKvStore());
    await fresh.load();
    expect(fresh.card(), isNull);
    expect(await fresh.setUrl('app.goyana.id'), isNotNull);
    expect(await fresh.setUrl('https://app.goyana.id'), isNull);
  });

  test('nomor nota memakai kode cabang dan kode HP setelah masuk ke server', () async {
    final kv = _phone(), server = _Server();
    final sync = await _connected(kv, server);
    // Slot HP kasir belum didapat: kode sementara dari id perangkat, tetap unik per HP.
    expect(sync.noteCode('srv-5')![0], 'PUS');
    expect(sync.noteCode('srv-5')![1], startsWith('X'));
    expect(sync.noteCode('srv-99'), isNull);
    await sync.claimSlot('srv-5');
    expect(sync.noteCode('srv-5'), ['PUS', '2']);
    final b = await Business.load(kv);
    final at = DateTime(2026, 10, 8, 9);
    expect(b.nextOrderId(at), 'GY-261008-0133');
    serverNoteCode = sync.noteCode;
    addTearDown(() => serverNoteCode = null);
    expect(b.nextOrderId(at), 'PUS-261008-2-0133');

    // HP kurir memakai kode kurirnya dan tidak mengambil slot HP kasir.
    final kurir = _Server()
      ..role = 'kurir'
      ..perms = ['courier.tasks']
      ..noteDevice = 'K7';
    final ksync = await _connected(_phone(), kurir, account: '081234567890', secret: '482915');
    expect(ksync.noteCode('srv-5'), ['PUS', 'K7']);
    await ksync.claimSlot('srv-5');
    expect(kurir.calls.any((c) => c['path'] == '/api/devices/claim'), isFalse);
  });

  test('setelan usaha ikut tersinkron; setelan milik HP tidak pernah dikirim', () async {
    final kv = _phone(), server = _Server();
    kv.data[pureSettingsKey] = jsonEncode({
      'discounts': [
        {'id': 1, 'name': 'Diskon 10%'},
      ],
      'tpl': {
        'cashier': {
          'tg': {'3': false},
        },
      },
      'adminPin': 'PIN-ADMIN-RAHASIA', 'printer': 'AA:BB:CC', 'pinLock': true,
      'employees': [
        {'name': 'Rina', 'pin': 'PIN-PEGAWAI-RAHASIA'},
      ],
    });
    kv.data[Keys.perfumes] = jsonEncode([
      ['Lavender', 'rgb(1, 2, 3)'],
    ]);
    final sync = await _connected(kv, server);
    await sync.cycle();
    final sent = <String, Object?>{
      for (final c in server.pushed())
        if (c['collection'] == 'settings') '${c['key']}': c['data'],
    };
    expect(sent.keys.toSet(), {'goyana-qris-text', 'goyana-perfumes178', sharedSettingsRecord});
    final shared = jsonDecode(sent[sharedSettingsRecord] as String) as Map;
    expect(shared.keys.toSet(), {'discounts', 'tpl'});
    final all = sent.values.join('|');
    expect(all.contains('RAHASIA') || all.contains('AA:BB:CC'), isFalse);

    // HP kasir menerima setelan pemilik (izin kasir, diskon, parfum); setelan HP-nya sendiri tidak tersentuh.
    final other = MemoryKvStore({
      pureSettingsKey: jsonEncode({'printer': 'DD:EE:FF', 'adminPin': '1111', 'discounts': <dynamic>[], 'expenseCats': ['Lama']}),
    });
    await applyRemote(other, [
      {'collection': 'settings', 'key': sharedSettingsRecord, 'data': sent[sharedSettingsRecord], 'deleted': false, 'rev': 3},
      {'collection': 'settings', 'key': 'goyana-perfumes178', 'data': sent['goyana-perfumes178'], 'deleted': false, 'rev': 4},
    ]);
    final now = jsonDecode(other.data[pureSettingsKey]!) as Map;
    expect([now['printer'], now['adminPin'], now.containsKey('expenseCats')], ['DD:EE:FF', '1111', false]);
    expect((((now['tpl'] as Map)['cashier'] as Map)['tg'] as Map)['3'], false);
    expect(((now['discounts'] as List).single as Map)['name'], 'Diskon 10%');
    expect(other.data[Keys.perfumes], kv.data[Keys.perfumes]);
  });

  test('cabang yang ditambah owner di HP didaftarkan ke server; pesanannya ikut memakai id server', () async {
    final kv = _phone(), server = _Server()..outletLimit = 2;
    final sync = await _connected(kv, server);
    void addBranch(String id, String name) {
      final outs = jsonDecode(kv.data[Keys.outlets]!) as List;
      outs.add({'id': id, 'name': name, 'address': 'Jl. B', 'phone': '0822', 'logo': ''});
      kv.data[Keys.outlets] = jsonEncode(outs);
    }

    List<Object?> ids() => [for (final o in jsonDecode(kv.data[Keys.outlets]!) as List) (o as Map)['id']];
    int posts() => server.calls.where((c) => c['path'] == '/api/outlets').length;
    addBranch('outlet180-9', 'Cabang Bekasi');
    final b = jsonDecode(kv.data[Keys.business]!) as Map;
    (b['orders'] as List).add(_card('GY-2', 'antrian', outlet: 'outlet180-9'));
    (b['details'] as Map)['GY-2'] = {'id': 'GY-2', 'name': 'Siti', 'paid': 0};
    kv.data[Keys.business] = jsonEncode(b);

    expect(await sync.uploadLocalOutlets(), isTrue);
    expect(server.calls.where((c) => c['path'] == '/api/outlets').single['body'], {'name': 'Cabang Bekasi', 'address': 'Jl. B', 'phone': '0822'});
    expect(ids(), ['srv-5', 'srv-6']);
    expect((await extractLocal(kv))['orders|GY-2']!.outlet, 'srv-6');
    expect(sync.noteCode('srv-6')![0], 'CB6');
    // Sudah terdaftar: tidak dikirim dua kali.
    expect(await sync.uploadLocalOutlets(), isFalse);
    expect(posts(), 1);
    // Batas cabang paket ditegakkan server: cabang tetap ada di HP dan alasannya tampil.
    addBranch('outlet180-10', 'Cabang Ketiga');
    expect(await sync.uploadLocalOutlets(), isFalse);
    expect(ids(), ['srv-5', 'srv-6', 'outlet180-10']);
    expect(sync.status.outletNote, startsWith('Cabang Ketiga belum terdaftar di server: Paket Silver maksimal'));
    expect(sync.card()!['line'], sync.status.outletNote);
    // Akun selain owner tidak pernah mendaftarkan cabang.
    final kasirKv = _phone(), kasirServer = _Server()..role = 'kasir';
    final kasir = await _connected(kasirKv, kasirServer, account: '081234567890', secret: '482915');
    final outs = jsonDecode(kasirKv.data[Keys.outlets]!) as List;
    outs.add({'id': 'outlet180-9', 'name': 'Cabang Liar'});
    kasirKv.data[Keys.outlets] = jsonEncode(outs);
    expect(await kasir.uploadLocalOutlets(), isFalse);
    expect(kasirServer.calls.where((c) => c['path'] == '/api/outlets'), isEmpty);
  });

  test('akun pegawai memajukan satu tahap menurut alur layanan, berakhir di Selesai Proses', () async {
    final kv = MemoryKvStore({
      Keys.business: jsonEncode({
        'orders': [_card('GY-1', 'antrian'), _card('GY-2', 'setrika')],
        'details': {
          'GY-1': {
            'id': 'GY-1', 'name': 'Siti', 'paid': 0,
            'items': [
              {'n': 'Cuci Setrika', 'unit': 'kg', 'price': 7000, 'qty': 2},
            ],
          },
          'GY-2': {
            'id': 'GY-2', 'name': 'Siti', 'paid': 0,
            'items': [
              {'n': 'Karpet', 'unit': 'm', 'price': 15000, 'qty': 3},
            ],
          },
        },
        'customers': <dynamic>[],
        'deposits178': <String, dynamic>{},
        'kas': {'start': 0, 'sales': <dynamic>[], 'ins': <dynamic>[], 'outs': <dynamic>[], 'kasir': 'Rina'},
      }),
      Keys.services: jsonEncode([
        {'key': 'cuci setrika', 'name': 'Cuci Setrika', 'prices': {'Reguler': 7000}},
        {'key': 'karpet', 'name': 'Karpet', 'prices': {'Reguler': 15000}, 'proc': ['Cuci', 'Kering', 'Packing']},
      ]),
    });
    final b = await Business.load(kv);
    final at = DateTime(2026, 10, 8, 9);
    final baju = b.orderById('GY-1')!, karpet = b.orderById('GY-2')!;
    expect(b.stagesFor(baju), ['cuci', 'kering', 'setrika', 'packing']);
    expect(b.stagesFor(karpet), ['cuci', 'kering', 'packing']);
    final seen = <String?>[];
    for (var k = 0; k < 6; k++) {
      seen.add(b.advanceStage(baju, now: at, by: 'Pegawai'));
    }
    expect(seen, ['cuci', 'kering', 'setrika', 'packing', 'selesaiproses', null]);
    expect(baju.history.last, containsPair('by', 'Pegawai'));
    // Karpet yang berada di tahap di luar alurnya (kasir selalu memulai dari Cuci) tetap bisa dilanjutkan.
    expect(b.advanceStage(karpet, now: at, by: 'Pegawai'), 'packing');
    // Kasir atau owner yang menandai Siap Ambil.
    expect(b.advance(baju, now: at, by: 'Kasir'), 'siap');
    expect(b.nextStage(baju), isNull);
  });

  test('data CRM tersinkron per kunci; kasir hanya mengirim voucher terpakai, poin tertukar, dan pengingat', () async {
    Map<String, dynamic> crm({bool used = false, int redeemed = 20, int per = 10000}) => {
          'rem': {'on': true, 'days': [3, 7]},
          'pt': {'on': true, 'per': per},
          'redeemed': {'Siti': redeemed},
          'vouchers': [
            {'code': 'HEMAT10', 'name': 'Hemat', 'type': 'p', 'val': 10, 'used': used},
          ],
          'reminded': {
            'GY-1': [3],
          },
        };
    final kv = _phone()..data['goyana-crm203'] = jsonEncode(crm());
    final local = await extractLocal(kv);
    expect(local.keys.where((k) => k.startsWith('crm|')).toSet(), {'crm|rules', 'crm|voucher:HEMAT10', 'crm|redeemed:Siti', 'crm|reminded:GY-1'});
    expect(local['crm|redeemed:Siti']!.data, {'v': 20});

    // Dari server: aturan berubah, voucher terpakai, voucher baru, poin bertambah, pengingat dihapus.
    await applyRemote(kv, [
      {'collection': 'crm', 'key': 'rules', 'data': {'rem': {'on': false}, 'pt': {'on': true, 'per': 5000}}},
      {'collection': 'crm', 'key': 'voucher:HEMAT10', 'data': {'code': 'HEMAT10', 'name': 'Hemat', 'type': 'p', 'val': 10, 'used': true}},
      {'collection': 'crm', 'key': 'voucher:BARU', 'data': {'code': 'BARU', 'name': 'Baru', 'type': 'n', 'val': 5000, 'used': false}},
      {'collection': 'crm', 'key': 'redeemed:Siti', 'data': {'v': 30}},
      {'collection': 'crm', 'key': 'reminded:GY-1', 'deleted': true},
    ]);
    final merged = jsonDecode(kv.data['goyana-crm203']!) as Map;
    expect((merged['pt'] as Map)['per'], 5000);
    expect([for (final v in merged['vouchers'] as List) '${(v as Map)['code']}:${v['used']}'], ['HEMAT10:true', 'BARU:false']);
    expect(merged['redeemed'], {'Siti': 30});
    expect(merged['reminded'], isEmpty);

    // HP kasir: aturan yang diubah di HP-nya tidak dikirim; voucher terpakai dan poin tertukar dikirim.
    final kasirKv = _phone()..data['goyana-crm203'] = jsonEncode(crm());
    final server = _Server()
      ..role = 'kasir'
      ..perms = ['orders.create', 'payments.receive'];
    final sync = await _connected(kasirKv, server, account: '081234567890', secret: '482915');
    await sync.cycle();
    server.calls.clear();
    kasirKv.data['goyana-crm203'] = jsonEncode(crm(used: true, redeemed: 30, per: 1));
    await sync.cycle();
    expect(server.pushed().map((c) => c['key']).toSet(), {'voucher:HEMAT10', 'redeemed:Siti'});
  });

  test('HP outlet dipakai bergantian: owner mengikat HP, pegawai memilih nama lalu PIN', () async {
    final kv = _phone(), server = _Server();
    final owner = await _connected(kv, server);
    expect(owner.sharedBound, isFalse);
    await owner.bindShared('srv-5', ' HP Kasir Pusat ');
    expect(server.calls.last['body'], containsPair('label', 'HP Kasir Pusat'));
    expect([owner.sharedBound, owner.sharedOutletName], [true, 'Pusat']);
    await expectLater(owner.bindShared('outlet-lokal', 'x'), throwsA(isA<ServerFailure>()));
    await owner.logout();

    // Aplikasi dibuka lagi: ikatan tersimpan di HP ini; pegawai memilih nama, kunci rahasia HP ikut dikirim.
    server.role = 'kasir';
    final sync = ServerSync(kv, send: server.send);
    await sync.load();
    expect([sync.sharedBound, sync.loggedIn], [true, false]);
    final names = await sync.roster();
    expect(names.single['name'], 'Siti');
    await sync.loginShared(names.single['id'], '482915', 'Siti');
    final login = server.calls.lastWhere((c) => c['path'] == '/api/session/pin')['body'] as Map;
    expect([login['user_id'], login['pin'], login['device_secret']], [9, '482915', 'rahasia-hp']);
    expect(sync.role, 'kasir');
    // Kasir tidak bisa mengikat HP; ikatan bisa dilepas dari HP ini.
    await expectLater(sync.bindShared('srv-5', 'x'), throwsA(isA<ServerFailure>()));
    await sync.unbindShared();
    expect(sync.sharedBound, isFalse);
    expect(await sync.roster(), isEmpty);
  });

  test('masuk dengan Google: tanda masuk dikirim ke server, sesi diperpanjang tiap aplikasi dibuka', () async {
    final kv = _phone(), server = _Server();
    final sync = ServerSync(kv, send: server.send, clock: () => DateTime.utc(2026, 10, 8));
    await sync.load();
    await sync.setUrl('https://app.goyana.test');
    expect(await sync.googleClientIds(), ['client-goyana.apps.googleusercontent.com']);
    await expectLater(sync.loginGoogle(''), throwsA(isA<ServerFailure>()));
    await sync.loginGoogle('tanda-dari-google');
    final sent = server.calls.lastWhere((c) => c['path'] == '/api/session/google')['body'] as Map;
    expect(sent['id_token'], 'tanda-dari-google');
    expect('${sent['device_id']}'.length, greaterThanOrEqualTo(8));
    expect([sync.loggedIn, sync.role], [true, 'owner']);
    expect(jsonDecode(kv.data[Keys.activeOutlet]!), 'srv-5');

    // Server memperpanjang sesi saat profil diambil; masa baru disimpan di HP sehingga aplikasi tetap masuk.
    server.sessionExpires = '2027-01-06T00:00:00+00:00';
    await sync.refreshProfile();
    expect((jsonDecode(kv.data[serverAuthKey]!) as Map)['expires_at'], '2027-01-06T00:00:00+00:00');
    final later = ServerSync(kv, send: server.send, clock: () => DateTime.utc(2026, 12, 20));
    await later.load();
    expect(later.loggedIn, isTrue);
    final tooLate = ServerSync(kv, send: server.send, clock: () => DateTime.utc(2027, 2, 1));
    await tooLate.load();
    expect(tooLate.loggedIn, isFalse);

    // APK uji: alamat server yang diisi sendiri bisa dilepas, aplikasi kembali tanpa akun.
    await sync.clearUrl();
    expect([sync.url, kv.data.containsKey(serverUrlKey)], ['', false]);
  });

  test('HP pegawai tidak mengirim data yang bukan haknya', () async {
    final kv = _phone(), server = _Server()..role = 'kasir';
    final sync = await _connected(kv, server, account: '081234567890', secret: '482915');
    await sync.cycle();
    expect(server.pushed().map((c) => c['collection']).toSet(), {'orders', 'customers'});
    expect(sync.status.pending, 0);
    expect(sync.card()!['line'], startsWith('Online · semua data tersinkron'));
  });

  test('paket dari server menentukan fitur yang terbuka', () {
    final now = DateTime(2026, 10, 8);
    final access = PlanAccess()..trialUntil = now.add(const Duration(days: 30));
    expect(access.rank(now), 1);
    access.serverPlan = 'GOLD';
    expect([access.rank(now), access.has('ai', now), access.has('blast', now), access.outletLimit(now)], [3, true, false, 4]);
    access.serverPlan = '';
    expect([access.rank(now), access.has('employees', now)], [0, false]);
    access.serverPlan = 'BASIC';
    // Keputusan 10 Okt 2026: stok/opname/transfer semua paket; Hubungkan WhatsApp mulai Silver.
    expect([access.has('employees', now), access.has('stock', now), access.has('transfer', now), access.has('wa', now)], [true, true, true, false]);
    access.serverPlan = null;
    expect(access.rank(now), 1);
  });
}
