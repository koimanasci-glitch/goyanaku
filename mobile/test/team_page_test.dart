// Tim gabungan (10 Okt 2026): anggota per cabang, kuota per paket, tambah langsung terisi tugas & cabang.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/pages.dart';
import 'package:goyana_flutter/pure/server_sync.dart';
import 'package:goyana_flutter/pure/team_page.dart';

class _Server {
  final posted = <Map<String, dynamic>>[];
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
    return const ServerReply(204, '');
  }
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
}
