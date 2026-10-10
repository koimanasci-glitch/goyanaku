// Tim gabungan (10 Okt 2026): anggota per cabang, kuota per paket, tambah langsung terisi tugas & cabang.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/pages.dart';
import 'package:goyana_flutter/pure/server_sync.dart';
import 'package:goyana_flutter/pure/branch_page.dart';
import 'package:goyana_flutter/pure/team_page.dart';

class _Server {
  final posted = <Map<String, dynamic>>[];
  final queries = <String>[];
  final team = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Rina', 'role': 'kasir', 'outlet_id': 5, 'phone': '6281', 'active': true},
    {'id': 2, 'name': 'Sari', 'role': 'kasir', 'outlet_id': 5, 'phone': '6282', 'active': true},
    {'id': 3, 'name': 'Budi', 'role': 'kurir', 'outlet_id': 6, 'phone': '6283', 'active': true, 'courier_limits': {'weigh': true, 'create': true, 'pay': false}},
  ];
  ServerReply _json(int status, Object body) => ServerReply(status, jsonEncode(body));

  Future<ServerReply> send(String method, Uri url, Map<String, String> headers, String? body) async {
    final path = url.path;
    if (path == '/api/session') return _json(200, {'token': 'tok-1', 'expires_at': '2099-01-01T00:00:00+00:00'});
    if (path == '/api/me') {
      return _json(200, {
        'user': {'id': 9, 'name': 'Koko', 'role': 'owner', 'permissions': ['*']},
        'business': {'id': 1, 'name': 'Laundry'},
        'access': {'package': 'Basic', 'read_only': false, 'outlet_limit': 2, 'cashier_device_limit': 2},
        'outlets': [
          {'id': 5, 'key': 'srv-5', 'name': 'Pusat', 'code': 'PUS', 'address': 'A', 'phone': '6281'},
          {'id': 6, 'key': 'srv-6', 'name': 'Bekasi', 'code': 'BKS', 'address': 'B', 'phone': '6282'},
        ],
      });
    }
    if (path == '/api/team' && method == 'GET') {
      return _json(200, {'team': team, 'limits': {'kasir': 2, 'produksi': 2, 'kurir': 2, 'manager': 1}, 'package': 'Basic'});
    }
    if (path == '/api/team' && method == 'POST') {
      final d = Map<String, dynamic>.from(jsonDecode(body!) as Map);
      posted.add(d);
      team.add({...d, 'id': 10 + team.length, 'active': true});
      return _json(201, {'member': d});
    }
    if (path == '/api/devices') {
      return _json(200, {
        'limit_per_outlet': 2,
        'cashier': [
          for (final d in devices) d,
        ],
        'shared': <dynamic>[],
      });
    }
    if (path.startsWith('/api/devices/cashier/') && method == 'DELETE') {
      devices.removeWhere((d) => '${d['id']}' == path.split('/').last);
      return const ServerReply(204, '');
    }
    if (path == '/api/monitoring') {
      queries.add(url.query);
      final one = url.queryParameters['outlet_id'];
      final rows = [
        {'id': 5, 'name': 'Pusat', 'active': true, 'orders': 4, 'revenue': 120000, 'cash_in': 90000, 'unpaid': 1, 'debt': 30000, 'stages': {'cuci': 2}, 'in_process': 2, 'ready_uncollected': 1, 'late': 1, 'pending_weigh': 0},
        {'id': 6, 'name': 'Bekasi', 'active': true, 'orders': 1, 'revenue': 20000, 'cash_in': 20000, 'unpaid': 0, 'debt': 0, 'stages': <String, dynamic>{}, 'in_process': 0, 'ready_uncollected': 0, 'late': 0, 'pending_weigh': 0},
      ].where((o) => one == null || '${o['id']}' == one).toList();
      return _json(200, {
        'totals': {'revenue': 140000, 'in_process': 2, 'ready_uncollected': 1, 'late': 1},
        'outlets': rows,
        'money': {
          'cash_in_by_method': {'Tunai': 70000, 'QRIS': 20000},
          'courier_cash': [{'courier': 'Budi', 'outlet_id': 5, 'held': 25000, 'notes': 1}],
          'deposits': <dynamic>[],
          'cash_closes': [{'outlet_id': 5, 'cashier': 'Rina', 'at': '2026-10-10T03:00:00Z', 'deposited': 65000, 'difference': -5000, 'note': 'kurang'}],
        },
        'cashiers': [{'name': 'Rina', 'created': 3, 'marked_ready': 1, 'cancelled': 0, 'skipped': 0, 'moved_back': 0, 'received': 70000}],
        'production': <dynamic>[], 'couriers': <dynamic>[], 'alerts': <dynamic>[], 'devices': <dynamic>[],
        'pickups': [{'outlet_id': 5, 'order': 'GY-9', 'customer': 'Tono', 'courier': 'Budi', 'when': 'Secepatnya', 'address': 'Jl. Mawar'}],
      });
    }
    if (path == '/api/outlets') {
      return _json(200, {'outlets': [{'id': 5, 'name': 'Pusat', 'active': true}, {'id': 6, 'name': 'Bekasi', 'active': true}]});
    }
    return const ServerReply(204, '');
  }

  final devices = <Map<String, dynamic>>[
    {'id': 31, 'outlet_id': 5, 'label': 'HP Kasir 1', 'slot': 1, 'paired': true, 'last_seen_at': null},
  ];
}

class _Host implements PureHost {
  _Host(this.kv, this.business, this.settings, this.server);
  @override
  final AppSettings settings;
  @override
  final KvStore kv;
  @override
  final Business business;
  @override
  final ServerSync server;
  final toasts = <String>[];
  final sheets = <String>{};
  @override
  void toast(String text) => toasts.add(text);
  @override
  void refresh() {}
  @override
  void openPageSheet(String id) => sheets.add(id);
  @override
  void closePageSheet(String id) => sheets.remove(id);
  @override
  DateTime get now => DateTime(2026, 10, 10, 10);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('tim per cabang: kuota tampil, tambah terisi tugas & cabang, kuota penuh ditolak sebelum ke server', () async {
    final server = _Server();
    final kv = MemoryKvStore({
      Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
      Keys.outlets: jsonEncode([{'id': 'out-1', 'name': 'Pusat', 'address': 'A', 'phone': '0811'}]),
      Keys.activeOutlet: jsonEncode('out-1'),
    });
    final sync = ServerSync(kv, send: server.send);
    await sync.load();
    expect(await sync.setUrl('https://app.goyana.test/'), isNull);
    await sync.login('owner@laundry.test', 'PasswordAman123');
    final host = _Host(kv, await Business.load(kv), await AppSettings.load(kv), sync);
    expect(host.business.outlets.map((o) => o.id), containsAll(['srv-5', 'srv-6']));
    final page = TeamPage(host)..opened();
    await _settle();
    final items = page.items();
    final hints = [for (final it in items) if (it['type'] == 'hint') '${it['t']}'];
    expect(hints, contains('Kasir 2/2 · Pegawai 0/2 · Kurir 0/2 · Kepala Cabang 0/1'));
    expect(hints, contains('Kasir 0/2 · Pegawai 0/2 · Kurir 1/2 · Kepala Cabang 0/1'));
    final budi = items.firstWhere((e) => e['t'] == 'Budi');
    expect((budi['lines'] as List).last, 'Tidak boleh: terima uang');

    // Kasir Pusat sudah 2/2: ditolak tanpa membuka formulir.
    final pusat = host.business.outlets.indexWhere((o) => o.id == 'srv-5');
    final outs = [for (final o in host.business.outlets) if (o.id.startsWith('srv-')) o];
    final k = outs.indexWhere((o) => o.id == 'srv-5');
    expect(pusat, greaterThanOrEqualTo(0));
    page.button(1000 + k * 10 + 0);
    expect(host.toasts.last, 'Paket Basic: maksimal 2 Kasir per outlet. Upgrade paket atau beli tambahan akun.');
    expect(host.sheets, isEmpty);

    // + Pegawai di Bekasi: formulir terisi tugas & cabang, tersimpan ke server.
    final b = outs.indexWhere((o) => o.id == 'srv-6');
    page.button(1000 + b * 10 + 1);
    expect(host.sheets, contains('tim-form'));
    final form = page.sheetItems('tim-form')!;
    expect(form.first['t'], 'Tambah Pegawai');
    expect([for (final it in form) if (it['type'] == 'select') it['index']], [1, b]);
    page.sheetEvent('tim-form', 'input', 0, 'Dodi');
    page.sheetEvent('tim-form', 'input', 1, '0812-0000-1111');
    page.sheetEvent('tim-form', 'input', 4, '123');
    page.sheetEvent('tim-form', 'button', 0, null);
    expect(host.toasts.last, 'PIN harus 6 angka');
    page.sheetEvent('tim-form', 'input', 4, '482915');
    page.sheetEvent('tim-form', 'button', 0, null);
    await _settle();
    expect(server.posted.single, containsPair('role', 'produksi'));
    expect(server.posted.single, containsPair('outlet_id', 6));
    expect(host.toasts.last, 'Pegawai ditambahkan');
    expect(host.sheets, isEmpty);
  });

  test('halaman cabang: daftar cek siap buka, tim, HP kasir dan cabut HP', () async {
    final server = _Server();
    final kv = MemoryKvStore({
      Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
      Keys.outlets: jsonEncode([{'id': 'out-1', 'name': 'Pusat', 'address': 'Jl. A', 'phone': '0811', 'tz': 'WIB'}]),
      Keys.activeOutlet: jsonEncode('out-1'),
    });
    final sync = ServerSync(kv, send: server.send);
    await sync.load();
    expect(await sync.setUrl('https://app.goyana.test/'), isNull);
    await sync.login('owner@laundry.test', 'PasswordAman123');
    final host = _Host(kv, await Business.load(kv), await AppSettings.load(kv), sync);
    BranchPage.outletId = 'srv-6';
    final page = BranchPage(host)..opened();
    await _settle();
    var items = page.items();
    final titles = [for (final it in items) '${it['t']}'];
    expect(titles, contains('Siap buka'));
    expect(titles.where((t) => t.startsWith('⬜')), containsAll(['⬜ Zona waktu', '⬜ Kasir cabang', '⬜ HP kasir', '⬜ Daftar harga']));
    expect(items.any((e) => e['t'] == 'Kasir 0 · Pegawai 0 · Kurir 1 · Kepala Cabang 0'), isTrue);
    expect(items.any((e) => e['t'] == 'Jadikan Cabang Rumah HP Ini'), isTrue, reason: 'Bekasi bukan cabang rumah HP ini');

    // Pusat: 2 kasir, 1 HP terhubung; cabut HP.
    BranchPage.outletId = 'srv-5';
    page.opened();
    await _settle();
    items = page.items();
    expect(items.any((e) => e['t'] == '✅ Kasir cabang'), isTrue);
    expect(items.any((e) => e['t'] == '✅ HP kasir'), isTrue);
    expect(items.any((e) => e['t'] == '1 dari 2 slot HP kasir terpakai.'), isTrue);
    expect(items.any((e) => '${e['t']}'.startsWith('🏠 Cabang rumah HP ini')), isTrue);
    page.button(100);
    await _settle();
    expect(host.toasts.last, 'HP dicabut · slot bisa dipakai HP lain');
    expect(server.devices, isEmpty);
    // Kelola tim cabang ini: Tim terbuka dengan saringan cabang tersebut.
    expect(TeamPage.presetOutlet, '');
  });

  test('monitor cabang: kartu per cabang, pilihan waktu, dan tab satu cabang dari server', () async {
    final server = _Server();
    final kv = MemoryKvStore({
      Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
      Keys.outlets: jsonEncode([{'id': 'out-1', 'name': 'Pusat', 'address': 'A', 'phone': '0811'}]),
      Keys.activeOutlet: jsonEncode('out-1'),
    });
    final sync = ServerSync(kv, send: server.send);
    await sync.load();
    expect(await sync.setUrl('https://app.goyana.test/'), isNull);
    await sync.login('owner@laundry.test', 'PasswordAman123');
    final host = _Host(kv, await Business.load(kv), await AppSettings.load(kv), sync);
    MonitorPeriod.index = 0;

    // Semua cabang: kartu per cabang dengan tutup omset dan tunai kurir.
    final all = ManageBranchesPage(host)..opened();
    await _settle();
    expect(server.queries.last, 'from=2026-10-10&to=2026-10-10');
    var items = all.items();
    final pusat = items.firstWhere((e) => e['type'] == 'entry' && e['t'] == 'Pusat' && e['avatar'] == '🏪');
    expect(pusat['lines'], contains('Belum lunas 1 · tutup omset selisih -Rp5.000 · kurir pegang Rp25.000'));
    expect(pusat['badge'], '⚠');
    expect((pusat['btns'] as List).single['t'], 'Monitor');
    final bekasi = items.firstWhere((e) => e['type'] == 'entry' && e['t'] == 'Bekasi' && e['avatar'] == '🏪');
    expect(bekasi['lines'], contains('Belum lunas 0 · belum tutup omset'));

    // Ganti waktu: 7 hari.
    all.button(902);
    await _settle();
    expect(server.queries.last, 'from=2026-10-04&to=2026-10-10');
    items = all.items();
    expect(items.any((e) => e['t'] == 'Cabang · 7 hari'), isTrue);
    MonitorPeriod.index = 0;

    // Satu cabang: tab Ringkasan, Pesanan, Kas, Stok, Tim, Riwayat.
    BranchMonitorPage.outletId = 'srv-5';
    final one = BranchMonitorPage(host)..opened();
    await _settle();
    expect(server.queries.last, 'from=2026-10-10&to=2026-10-10&outlet_id=5');
    items = one.items();
    expect(items.firstWhere((e) => e['type'] == 'hero')['v'], 'Rp120.000');
    expect(items.any((e) => e['t'] == 'Tahap Cucian'), isTrue);
    one.button(951);
    items = one.items();
    expect(items.firstWhere((e) => e['t'] == 'Tono')['lines'], ['GY-9 · Jl. Mawar · Secepatnya · Budi']);
    one.button(952);
    items = one.items();
    expect(items.firstWhere((e) => e['t'] == 'Tunai')['amount'], 'Rp70.000');
    expect(items.firstWhere((e) => e['t'] == 'Rina')['avatar'], '⚠');
    expect(items.any((e) => e['t'] == 'Tunai dipegang kurir'), isTrue);
    one.button(953);
    expect(one.items().any((e) => e['t'] == 'Belum ada bahan.'), isTrue);
    one.button(954);
    items = one.items();
    expect(items.any((e) => e['t'] == 'Kasir Hari Ini'), isTrue);
    expect(items.any((e) => e['t'] == 'Tunai Dipegang Kurir'), isFalse, reason: 'tunai kurir ada di tab Kas');
    one.button(955);
    expect(one.items().any((e) => e['t'] == 'Belum ada riwayat aktivitas cabang ini di HP ini.'), isTrue);
  });
}
