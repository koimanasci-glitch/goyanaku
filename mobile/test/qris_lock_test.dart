// Kunci QRIS (keputusan Paduka 10 Okt 2026): nama merchant & NMID tampil, hapus QRIS, ganti hanya pemilik + konfirmasi password.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/qris.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/pages.dart';
import 'package:goyana_flutter/pure/qris_lock.dart';
import 'package:goyana_flutter/pure/server_sync.dart';

String _qris(String name) {
  final body = '00020101021126610014COM.GO-JEK.WWW01189360091434506469550210G4506469550303UMI'
      '51440014ID.CO.QRIS.WWW0215ID10200211817450303UMI520458125303360580'
      '2ID59${name.length.toString().padLeft(2, '0')}${name}6007JAKARTA6304';
  return body + crc16(body);
}

class _Server {
  String role = 'owner';
  final calls = <String>[];
  Future<ServerReply> send(String method, Uri url, Map<String, String> headers, String? body) async {
    calls.add('$method ${url.path} ${body ?? ''}');
    if (url.path == '/api/session') return ServerReply(200, jsonEncode({'token': 'tok', 'expires_at': '2099-01-01T00:00:00+00:00'}));
    if (url.path == '/api/me') {
      return ServerReply(200, jsonEncode({
        'user': {'id': 7, 'name': 'Rina', 'role': role, 'role_label': role, 'permissions': role == 'owner' ? ['*'] : ['orders.create']},
        'business': {'id': 1, 'name': 'Laundry', 'allow_debt': true},
        'access': {'package': 'Gold', 'read_only': false, 'outlet_limit': 3, 'cashier_device_limit': 3},
        'outlets': [{'id': 5, 'key': 'srv-5', 'name': 'Pusat', 'code': 'PUS', 'address': 'Jl', 'phone': '6281'}],
        'note': {'prefix': 'PUS', 'device': '1'},
      }));
    }
    if (url.path == '/api/qris/unlock') {
      final pw = (jsonDecode(body!) as Map)['password'];
      return pw == 'benar' ? ServerReply(200, jsonEncode({'until': '2099-01-01', 'minutes': 10})) : ServerReply(422, jsonEncode({'message': 'Password salah.'}));
    }
    return const ServerReply(204, '');
  }
}

class _Host implements PureHost {
  _Host(this.kv, this.business, this.settings, this.server);
  @override
  final AppSettings settings;
  @override
  Future<void> saveAll() => settings.save();
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
  DateTime get now => DateTime(2026, 10, 11, 10);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Host> _host(_Server server, {bool login = true}) async {
  final kv = MemoryKvStore({
    Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
    Keys.outlets: jsonEncode([{'id': 'srv-5', 'name': 'Pusat'}]),
    Keys.activeOutlet: jsonEncode('srv-5'),
    Keys.qrisText: _qris('LAUNDRY BERSIH'),
  });
  final sync = ServerSync(kv, send: server.send);
  await sync.load();
  if (login) {
    expect(await sync.setUrl('https://app.goyana.test/'), isNull);
    await sync.login('owner@laundry.test', 'PasswordAman123');
  }
  return _Host(kv, await Business.load(kv), await AppSettings.load(kv), sync);
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('NMID dan nama merchant terbaca dari QRIS', () {
    final q = _qris('LAUNDRY BERSIH');
    expect(qrisValid(q), isTrue);
    expect(qrisNmid(q), 'ID1020021181745');
    final items = qrisMerchantItems(q, hasImage: true);
    expect(items.single['t'], 'LAUNDRY BERSIH');
    expect(items.single['lines'], contains('NMID ID1020021181745'));
  });

  test('pemilik mengganti QRIS setelah konfirmasi password; QRIS bisa dihapus', () async {
    final server = _Server();
    final host = await _host(server);
    final page = QrisPage(host);
    page.opened();
    await _settle();
    page.input(1, _qris('LAUNDRY BARU'));
    page.button(1);
    await _settle();
    expect(host.sheets, {QrisUnlock.sheet});
    expect(host.settings.qrisText, _qris('LAUNDRY BERSIH'), reason: 'belum berubah sebelum konfirmasi');
    page.sheetEvent(QrisUnlock.sheet, 'input', 0, 'salah');
    page.sheetEvent(QrisUnlock.sheet, 'button', 0, null);
    await _settle();
    expect(host.toasts.last, 'Password salah.');
    page.sheetEvent(QrisUnlock.sheet, 'input', 0, 'benar');
    page.sheetEvent(QrisUnlock.sheet, 'button', 0, null);
    await _settle();
    expect(host.sheets, isEmpty);
    expect(host.settings.qrisText, _qris('LAUNDRY BARU'));
    expect(host.toasts, contains('Perhatian: merchant QRIS berubah dari LAUNDRY BERSIH ke LAUNDRY BARU'));

    page.button(5);
    expect(host.sheets, {'qris-del'});
    page.sheetEvent('qris-del', 'button', 0, null);
    await _settle();
    expect([host.settings.qrisText, host.toasts.last], ['', 'QRIS dihapus']);
  });

  test('akun staf tidak bisa mengganti QRIS', () async {
    final server = _Server()..role = 'kasir';
    final host = await _host(server);
    final page = QrisPage(host);
    page.input(1, _qris('ORANG LAIN'));
    page.button(1);
    await _settle();
    expect(host.toasts.last, 'QRIS hanya bisa diganti pemilik usaha.');
    expect(host.settings.qrisText, _qris('LAUNDRY BERSIH'));
  });
}
