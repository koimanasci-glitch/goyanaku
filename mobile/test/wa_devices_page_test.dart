// Hubungkan WhatsApp + Balas Status WhatsApp di Mode Murni, dengan server tiruan (tanpa jaringan dan tanpa Chatku sungguhan).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/pages.dart';
import 'package:goyana_flutter/pure/server_sync.dart';
import 'package:goyana_flutter/pure/wa_devices_page.dart';
import 'package:goyana_flutter/pure/wa_link.dart';

/// Server tiruan: sesi pemilik + API perangkat WhatsApp GOYANA. `gateway` = layanan Chatku tersambung atau belum.
class _Server {
  final calls = <String>[];
  final devices = <Map<String, dynamic>>[];
  String role = 'owner';
  bool enabled = true, gateway = true, statusAllowed = true;
  int limit = 1;
  String remoteStatus = 'pairing';
  String expires = '2099-01-01T00:00:00Z';

  ServerReply _json(int status, Object body) => ServerReply(status, jsonEncode(body));

  Future<ServerReply> send(String method, Uri url, Map<String, String> headers, String? body) async {
    final data = body == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(body) as Map);
    final path = url.path;
    calls.add('$method $path');
    if (path == '/api/session' || path == '/api/session/pin') return _json(200, {'token': 'tok-1', 'expires_at': '2099-01-01T00:00:00+00:00'});
    if (path == '/api/me') {
      return _json(200, {
        'user': {'id': 7, 'name': 'Rina', 'role': role, 'role_label': role, 'permissions': role == 'owner' ? ['*'] : ['orders.create']},
        'business': {'id': 1, 'name': 'Laundry Bekasi', 'allow_debt': true},
        'access': {'package': 'Silver', 'read_only': false, 'outlet_limit': 3, 'cashier_device_limit': 3},
        'outlets': [
          {'id': 5, 'key': 'srv-5', 'name': 'Pusat', 'code': 'PUS', 'address': 'Jl. Server', 'phone': '6281'},
        ],
        'note': {'prefix': 'PUS', 'device': '1'},
      });
    }
    if (!path.startsWith('/api/whatsapp/')) return const ServerReply(204, '');
    if (!enabled) return _json(404, {'message': 'Not Found'});
    final parts = path.substring('/api/whatsapp/'.length).split('/');
    if (parts.length == 1 && method == 'GET') {
      return _json(200, {
        'devices': devices,
        'quota': {'limit': limit, 'used': devices.length, 'status_allowed': statusAllowed, 'services_allowed': false},
      });
    }
    if (parts.length == 1 && method == 'POST') {
      if (devices.length >= limit) return _json(409, {'message': 'Slot WhatsApp penuh. Tambahkan slot berbayar.'});
      final d = <String, dynamic>{...data, 'status': 'disconnected', 'reply_status': false, 'reply_services': false, 'version': 1};
      devices.add(d);
      return _json(201, d);
    }
    final d = devices.where((x) => x['id'] == parts[1]).firstOrNull;
    if (d == null) return _json(404, {'message': 'Not Found'});
    if (parts.length == 2 && method == 'DELETE') {
      devices.remove(d);
      return const ServerReply(204, '');
    }
    if (parts.length == 2 && method == 'PUT') {
      d.addAll({'name': data['name'], 'phone': data['phone'], 'outlet_id': data['outlet_id'], 'version': (d['version'] as int) + 1});
      return _json(200, d);
    }
    switch (parts[2]) {
      case 'pairing':
        if (!gateway) return _json(503, {'message': 'Kontrak API Chatku belum dikonfigurasi.'});
        d['status'] = 'pairing';
        return _json(200, {'kind': data['method'], 'value': data['method'] == 'qr' ? 'QR-DARI-SERVER' : '1234-5678', 'expires_at': expires});
      case 'refresh':
        if (!gateway) return _json(503, {'message': 'Kontrak API Chatku belum dikonfigurasi.'});
        d['status'] = remoteStatus;
        return _json(200, d);
      case 'automation':
        if (data['reply_status'] == true && !statusAllowed) return _json(403, {'message': 'Balas status belum tersedia pada paket ini.'});
        d.addAll({'reply_status': data['reply_status'], 'reply_services': data['reply_services'], 'version': (d['version'] as int) + 1});
        return _json(200, d);
    }
    return _json(404, {'message': 'Not Found'});
  }
}

/// Host seperlunya: penyimpanan, usaha, sesi server, pesan singkat, dan popup halaman.
class _Host implements PureHost {
  _Host(this.kv, this.business, this.settings, this.server);
  @override
  final AppSettings settings;
  @override
  Future<void> saveAll() async {}
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MemoryKvStore _phone() => MemoryKvStore({
      Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
      Keys.outlets: jsonEncode([
        {'id': 'out-1', 'name': 'Pusat', 'address': 'Jl. A', 'phone': '0811'},
      ]),
      Keys.activeOutlet: jsonEncode('out-1'),
    });

Future<_Host> _host(_Server server, {bool login = true, String account = 'owner@laundry.test', String secret = 'PasswordAman123'}) async {
  final kv = _phone();
  final sync = ServerSync(kv, send: server.send);
  await sync.load();
  if (login) {
    expect(await sync.setUrl('https://app.goyana.test/'), isNull);
    await sync.login(account, secret);
  }
  return _Host(kv, await Business.load(kv), await AppSettings.load(kv), sync);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

List<Map<String, dynamic>> _entries(WaDevicesPage p) => [for (final it in p.items()) if (it['type'] == 'entry') it];
List<String> _hints(List<Map<String, dynamic>> items) => [for (final it in items) if (it['type'] == 'hint') '${it['t']}'];

Future<void> _add(WaDevicesPage page, {String name = 'WA Kasir', String phone = '0812-3456-7890'}) async {
  page.button(0);
  page.sheetEvent('wa195-form', 'input', 0, name);
  page.sheetEvent('wa195-form', 'input', 1, phone);
  page.sheetEvent('wa195-form', 'button', 0, null);
  await _settle();
}

void main() {
  test('pemilik: draf di HP, didaftarkan ke server saat dihubungkan, QR asli dari server, lalu status diperiksa', () async {
    final server = _Server();
    final host = await _host(server);
    final wa = WaLink(host);
    final page = WaDevicesPage(host, wa);
    page.opened();
    await _settle();
    expect(page.items().map((e) => e['t']), contains('Slot nomor WhatsApp: 0 dari 1 terpakai. Menambah cabang tidak menambah slot.'));
    expect(page.items().map((e) => e['t']), contains('Belum ada perangkat'));

    await _add(page);
    expect(host.toasts.last, 'Perangkat tersimpan');
    expect(host.sheets, isEmpty);
    final row = _entries(page).single;
    expect([row['t'], (row['lines'] as List).take(2).toList()], ['WA Kasir', ['+6281234567890 · Pusat', 'Draf di HP ini, belum dihubungkan']]);
    expect([for (final b in row['btns'] as List) (b as Map)['t']], ['Hubungkan', 'Edit', 'Hapus']);
    expect(server.devices, isEmpty, reason: 'draf belum memakai slot server');

    // Nomor yang sama dan nomor asal-asalan ditolak sebelum menyentuh server.
    await _add(page, name: 'Kembar');
    expect(host.toasts.last, 'Nomor sudah ada dalam daftar.');
    page.sheetEvent('wa195-form', 'input', 1, 'abc');
    page.sheetEvent('wa195-form', 'button', 0, null);
    await _settle();
    expect(host.toasts.last, 'Nomor WhatsApp tidak valid.');
    host.closePageSheet('wa195-form');

    page.button(1000);
    expect(host.sheets, {'wa195-pair'});
    var sheet = page.sheetItems('wa195-pair')!;
    expect(sheet.any((e) => e['type'] == 'qr'), isFalse, reason: 'tidak ada QR sebelum server memberikannya');
    expect(sheet.where((e) => e['type'] == 'button').map((e) => e['t']), ['Tampilkan QR', 'Tutup']);
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(server.devices.single['outlet_id'], 5);
    sheet = page.sheetItems('wa195-pair')!;
    expect(sheet.singleWhere((e) => e['type'] == 'qr')['data'], 'QR-DARI-SERVER');
    expect((_entries(page).single['lines'] as List)[1], 'Belum terhubung', reason: 'QR tampil belum berarti terhubung');

    // Kode WhatsApp: pilihan diganti, QR lama dibuang, kode diminta ulang ke server.
    page.sheetEvent('wa195-pair', 'button', 1, null);
    expect(page.sheetItems('wa195-pair')!.any((e) => e['type'] == 'qr'), isFalse);
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(page.sheetItems('wa195-pair')!.map((e) => e['t']), contains('1234-5678'));

    // Periksa Status: belum tertaut → tetap di popup; sudah tertaut → popup ditutup.
    page.sheetEvent('wa195-pair', 'button', 4, null);
    await _settle();
    expect(host.toasts.last, 'Belum terhubung. Selesaikan penautan di WhatsApp lalu periksa lagi.');
    server.remoteStatus = 'connected';
    page.sheetEvent('wa195-pair', 'button', 4, null);
    await _settle();
    expect([host.toasts.last, host.sheets], ['WhatsApp terhubung', <String>{}]);
    expect(((_entries(page).single['btns'] as List).first as Map)['t'], 'Cek Status');

    // Slot penuh: nomor kedua tetap draf, server menolak saat dihubungkan.
    await _add(page, name: 'WA Cabang', phone: '081200000002');
    page.button(1000 + 10 * page.wa.store.devices.indexWhere((d) => d.name == 'WA Cabang'));
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(host.toasts.last, 'Slot WhatsApp penuh. Tambahkan slot berbayar.');
    expect(server.devices.length, 1);

    // Hapus: sambungan server diputus dulu.
    page.button(1002 + 10 * page.wa.store.devices.indexWhere((d) => d.name == 'WA Kasir'));
    expect(host.sheets, contains('wa195-del'));
    page.sheetEvent('wa195-del', 'button', 0, null);
    await _settle();
    expect([host.toasts.last, server.devices], ['Perangkat dihapus', isEmpty]);
  });

  test('QR kedaluwarsa tidak ditampilkan; layanan WhatsApp yang belum tersambung dilaporkan apa adanya', () async {
    final server = _Server()..expires = '2000-01-01T00:00:00Z';
    final host = await _host(server);
    final page = WaDevicesPage(host, WaLink(host));
    page.opened();
    await _settle();
    await _add(page);
    page.button(1000);
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(host.toasts.last, 'QR atau kode tidak valid/kedaluwarsa. Minta ulang.');
    expect(page.sheetItems('wa195-pair')!.any((e) => e['type'] == 'qr'), isFalse);

    server.gateway = false;
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(host.toasts.last, 'Layanan WhatsApp belum tersambung ke server GOYANA. QR dan kode pemasangan tersedia setelah tersambung.');
    expect(page.sheetItems('wa195-pair')!.any((e) => e['type'] == 'qr'), isFalse);
  });

  test('server belum mengaktifkan WhatsApp: draf tetap bisa disimpan dan keterangannya jelas', () async {
    final server = _Server()..enabled = false;
    final host = await _host(server);
    final page = WaDevicesPage(host, WaLink(host));
    page.opened();
    await _settle();
    expect(_hints(page.items()), contains('Layanan WhatsApp belum diaktifkan di server GOYANA. Draf tetap tersimpan di HP ini.'));
    await _add(page);
    expect(_entries(page).single['t'], 'WA Kasir');
    // Dibuka lagi: draf masih ada.
    final again = WaDevicesPage(host, WaLink(host));
    again.opened();
    await _settle();
    expect(_entries(again).single['t'], 'WA Kasir');
  });

  test('tanpa akun server draf tersimpan di HP; karyawan tidak mengatur nomor WhatsApp usaha', () async {
    final offline = await _host(_Server(), login: false);
    final page = WaDevicesPage(offline, WaLink(offline));
    page.opened();
    await _settle();
    await _add(page);
    expect((_entries(page).single['lines'] as List).first, '+6281234567890 · Pusat');
    page.button(1000);
    page.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect(offline.toasts.last, 'Masuk ke akun GOYANA dulu untuk menautkan WhatsApp.');

    final server = _Server()..role = 'kasir';
    final staff = await _host(server, account: '081234567890', secret: '482915');
    final locked = WaDevicesPage(staff, WaLink(staff));
    locked.opened();
    await _settle();
    expect(locked.items().any((e) => e['type'] == 'button'), isFalse);
    expect(_hints(locked.items()), contains('Hanya pemilik usaha yang dapat mengatur nomor WhatsApp.'));
    locked.button(0);
    expect(staff.sheets, isEmpty);
    expect(server.calls.where((c) => c.contains('/api/whatsapp/')), isEmpty);
  });

  test('Otomasi: Balas Status WhatsApp per nomor terdaftar, hak paket diputuskan server', () async {
    final server = _Server();
    final host = await _host(server);
    final wa = WaLink(host);
    final devices = WaDevicesPage(host, wa);
    final page = AutomationPage(host, wa: wa);
    Map<String, dynamic> reply() => page.items().lastWhere((e) => e['type'] == 'toggle');

    page.opened();
    await _settle();
    expect([reply()['t'], reply()['s'], reply()['on'], reply()['i']], ['Balas Status WhatsApp', 'Otomatis menjawab pertanyaan status pesanan.', false, 3]);
    page.toggle(3);
    expect(host.toasts.last, 'Hubungkan nomor WhatsApp dulu di menu Hubungkan WhatsApp.');

    await _add(devices);
    devices.button(1000);
    devices.sheetEvent('wa195-pair', 'button', 3, null);
    await _settle();
    expect([reply()['s'], reply()['on'], reply()['i']], ['Otomatis menjawab pertanyaan status pesanan. WA Kasir · +6281234567890', false, 100]);
    page.toggle(100);
    await _settle();
    expect([reply()['on'], server.devices.single['reply_status'], host.toasts.last], [true, true, 'Balas Status WhatsApp aktif']);
    expect((_entries(devices).single['lines'] as List).last, 'Balas Status WhatsApp aktif');
    devices.sheetEvent('wa195-pair', 'button', 2, null);

    // Paket turun: yang sudah menyala tetap bisa dimatikan, tetapi tidak bisa dinyalakan lagi.
    server.statusAllowed = false;
    page.toggle(100);
    await _settle();
    expect(reply()['on'], false);
    page.toggle(100);
    await _settle();
    expect([reply()['on'], host.toasts.last], [false, 'Balas status belum tersedia pada paket ini.']);
  });
}
