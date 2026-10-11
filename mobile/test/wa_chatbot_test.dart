// Chatbot WhatsApp di server (11 Okt 2026): Media per cabang, Balasan Cepat, sakelar Otomatis/AI, pengetahuan, dan Promo,
// dengan server tiruan (tanpa jaringan dan tanpa CHATKU sungguhan).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/pages.dart';
import 'package:goyana_flutter/pure/server_sync.dart';
import 'package:goyana_flutter/pure/wa_chatbot.dart';
import 'package:goyana_flutter/pure/wa_link.dart';
import 'package:goyana_flutter/pure/wa_pages.dart';

class _Server {
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};
  final media = <Map<String, dynamic>>[];
  final replies = <Map<String, dynamic>>[];
  final blasts = <Map<String, dynamic>>[];
  Map<String, dynamic> settings = {
    'quick_enabled': true, 'ai_enabled': false, 'ai_name': 'Asisten Laundry', 'ai_instructions': 'Ramah', 'knowledge': '', 'ai_prices': true, 'ai_status': true,
    'takeover_minutes': 30, 'auto_nota': false, 'auto_ready': false, 'auto_late': false, 'late_days': 3, 'quiet_from': '21:00', 'quiet_until': '07:00', 'version': 0,
  };
  int paused = 2;

  ServerReply _json(int status, Object body) => ServerReply(status, jsonEncode(body));

  Future<ServerReply> send(String method, Uri url, Map<String, String> headers, String? body) async {
    final data = body == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(body) as Map);
    final path = url.path;
    calls.add('$method $path${url.hasQuery ? '?${url.query}' : ''}');
    bodies['$method $path'] = data;
    if (path == '/api/session') return _json(200, {'token': 'tok-1', 'expires_at': '2099-01-01T00:00:00+00:00'});
    if (path == '/api/me') {
      return _json(200, {
        'user': {'id': 7, 'name': 'Rina', 'role': 'owner', 'role_label': 'owner', 'permissions': ['*']},
        'business': {'id': 1, 'name': 'Laundry Bekasi', 'allow_debt': true},
        'access': {'package': 'Platinum', 'read_only': false, 'outlet_limit': 3, 'cashier_device_limit': 3},
        'outlets': [
          {'id': 5, 'key': 'srv-5', 'name': 'Pusat', 'code': 'PUS', 'address': 'Jl. Server', 'phone': '6281'},
          {'id': 6, 'key': 'srv-6', 'name': 'Bekasi', 'code': 'BKS', 'address': 'Jl. Dua', 'phone': '6282'},
        ],
        'note': {'prefix': 'PUS', 'device': '1'},
      });
    }
    if (path == '/api/whatsapp/devices') {
      return _json(200, {
        'devices': [
          {'id': '11111111-1111-4111-8111-111111111111', 'outlet_id': 5, 'name': 'WA Pusat', 'phone': '6281200000001', 'status': 'connected', 'reply_status': true, 'reply_services': false, 'version': 1},
        ],
        'quota': {'limit': 1, 'used': 1, 'status_allowed': true, 'services_allowed': true},
      });
    }
    if (path == '/api/whatsapp/chatbot/5' && method == 'GET') {
      return _json(200, {'outlet_id': 5, 'settings': settings, 'features': {'quick': true, 'ai': true, 'messages': true, 'blast': true}, 'ai_balance': 75000,
        'replies': replies, 'media': media, 'media_limit': 10, 'paused': paused});
    }
    if (path == '/api/whatsapp/chatbot/5' && method == 'PUT') {
      if (data['version'] != settings['version']) return _json(409, {'message': 'Pengaturan sudah diubah dari HP lain. Muat ulang.'});
      settings = {...settings, ...data..remove('version'), 'version': (settings['version'] as int) + 1};
      return _json(200, {'settings': settings});
    }
    if (path == '/api/whatsapp/chatbot/5/replies') {
      final r = {...data, 'position': 0};
      replies.removeWhere((x) => x['id'] == r['id']);
      replies.add(r);
      return _json(201, r);
    }
    if (path.startsWith('/api/whatsapp/chatbot/replies/')) {
      replies.removeWhere((x) => x['id'] == path.split('/').last);
      return const ServerReply(204, '');
    }
    if (path == '/api/whatsapp/chatbot/5/media') {
      if (media.length >= 10) return _json(422, {'message': 'Media cabang ini sudah 10.'});
      final m = {'id': 'm${media.length + 1}', 'outlet_id': 5, 'name': data['name'], 'kind': '${data['data']}'.startsWith('data:application/pdf') ? 'pdf' : 'image',
        'mime': 'image/jpeg', 'bytes': 2048, 'version': 1, 'preview_url': 'https://app.goyana.test/wa/media/m1?v=1&signature=x'};
      media.add(m);
      return _json(201, m);
    }
    if (path.startsWith('/api/whatsapp/media/')) {
      final parts = path.split('/');
      final id = parts[4];
      if (method == 'DELETE') {
        media.removeWhere((m) => m['id'] == id);
        return const ServerReply(204, '');
      }
      if (parts.length == 6 && parts[5] == 'copy') return _json(201, {'id': 'copy', 'outlet_id': data['outlet_id']});
      final m = media.firstWhere((x) => x['id'] == id)..['name'] = data['name'];
      return _json(200, m);
    }
    if (path == '/api/whatsapp/blasts/audience') return _json(200, {'count': url.queryParameters['audience'] == 'all' ? 40 : 12, 'max': 5000});
    if (path == '/api/whatsapp/blasts' && method == 'GET') return _json(200, {'blasts': blasts, 'allowed': true});
    if (path == '/api/whatsapp/blasts' && method == 'POST') {
      final b = {'id': 'b1', 'name': data['name'], 'status': 'running', 'total': 12, 'sent': 0, 'failed': 0, 'skipped': 0};
      blasts.insert(0, b);
      return _json(201, b);
    }
    if (path == '/api/whatsapp/blasts/b1/cancel') return _json(200, {...blasts.first, 'status': 'cancelled'});
    if (path == '/api/whatsapp/chatbot/5/resume') {
      paused = 0;
      return _json(200, {'resumed': 2});
    }
    return const ServerReply(204, '');
  }
}

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
  final went = <String>[];
  @override
  void toast(String text) => toasts.add(text);
  @override
  void refresh() {}
  @override
  void openPageSheet(String id) => sheets.add(id);
  @override
  void closePageSheet(String id) => sheets.remove(id);
  @override
  void go(String page) => went.add(page);
  @override
  DateTime get now => DateTime(2026, 10, 11, 10);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Host> _host(_Server server, {bool login = true}) async {
  final kv = MemoryKvStore({
    Keys.business: jsonEncode({'orders': <dynamic>[], 'details': <String, dynamic>{}, 'customers': <dynamic>[]}),
    Keys.outlets: jsonEncode([
      {'id': 'srv-5', 'name': 'Pusat', 'address': 'Jl. A', 'phone': '0811'},
      {'id': 'srv-6', 'name': 'Bekasi', 'address': 'Jl. B', 'phone': '0812'},
    ]),
    Keys.activeOutlet: jsonEncode('srv-5'),
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

List<Map<String, dynamic>> _entries(List<Map<String, dynamic>> items) => [for (final it in items) if (it['type'] == 'entry') it];

void main() {
  setUp(() => planAccess.testPlan = 'PLATINUM');
  tearDown(() => planAccess.testPlan = null);

  test('Media: tambah foto & PDF, ganti nama, salin ke cabang lain, hapus — semua ke server cabang aktif', () async {
    final server = _Server();
    final host = await _host(server);
    final pages = whatsappPages(host);
    final page = pages['wamedia']! as WaMediaPage;
    page.opened();
    await _settle();
    expect(page.items().firstWhere((e) => e['type'] == 'title')['s'], '0/10');

    page.file('wa-media', 'daftar_harga.png', 'image/png', base64Encode(List<int>.filled(300, 1)));
    expect(host.sheets, {'wam-add'});
    expect(page.sheetItems('wam-add')!.firstWhere((e) => e['type'] == 'input')['v'], 'daftar harga');
    page.sheetEvent('wam-add', 'input', 0, 'Daftar harga kiloan');
    page.sheetEvent('wam-add', 'button', 0, null);
    await _settle();
    expect(host.toasts.last, 'Media tersimpan');
    expect(server.bodies['POST /api/whatsapp/chatbot/5/media']!['data'], startsWith('data:image/png;base64,'));
    expect(_entries(page.items()).single['t'], 'Daftar harga kiloan');

    // PDF terlalu besar ditolak sebelum dikirim.
    page.file('wa-media', 'besar.pdf', 'application/pdf', 'A' * (3 * 1024 * 1024));
    expect(host.toasts.last, 'PDF maksimal 2 MB.');

    page.button(1001);
    page.sheetEvent('wam-rename', 'input', 0, 'Harga terbaru');
    page.sheetEvent('wam-rename', 'button', 0, null);
    await _settle();
    expect(_entries(page.items()).single['t'], 'Harga terbaru');

    page.button(1000);
    expect(page.sheetItems('wam-view')!.firstWhere((e) => e['type'] == 'image')['src'], startsWith('https://'));
    page.sheetEvent('wam-view', 'button', 0, null);

    page.button(1002);
    expect(page.sheetItems('wam-copy')!.firstWhere((e) => e['type'] == 'select')['options'], ['Bekasi']);
    page.sheetEvent('wam-copy', 'button', 0, null);
    await _settle();
    expect(server.bodies['POST /api/whatsapp/media/m1/copy'], {'outlet_id': 6});
    expect(host.toasts.last, 'Disalin ke Bekasi');

    page.button(1003);
    page.sheetEvent('wam-del', 'button', 0, null);
    await _settle();
    expect([host.toasts.last, server.media], ['Media dihapus', isEmpty]);
  });

  test('tanpa akun pemilik: Media tidak bisa dipakai dan tidak memanggil server', () async {
    final server = _Server();
    final host = await _host(server, login: false);
    final page = WaMediaPage(host, ChatbotServer(host));
    page.opened();
    await _settle();
    expect(page.items().single['t'], contains('Masuk dengan akun pemilik'));
    page.file('wa-media', 'a.png', 'image/png', 'AAAA');
    expect(host.sheets, isEmpty);
    expect(server.calls.where((c) => c.contains('/whatsapp/')), isEmpty);
  });

  test('Balas Cepat tersimpan di server dengan lampiran dari Media; sakelar Otomatis/AI dan pengetahuan ke server', () async {
    final server = _Server();
    server.media.add({'id': 'm1', 'outlet_id': 5, 'name': 'Brosur', 'kind': 'image', 'mime': 'image/jpeg', 'bytes': 1000, 'version': 1, 'preview_url': 'https://x'});
    final host = await _host(server);
    final pages = whatsappPages(host);
    final triggers = pages['triggers191']! as TriggersPage;
    triggers.opened();
    await _settle();
    triggers.button(0);
    triggers.input(0, 'Promo');
    triggers.input(1, 'promo, diskon');
    triggers.input(3, 'Diskon 20% Kak!');
    triggers.input(4, 1);
    triggers.button(1);
    await _settle();
    final sent = server.bodies['POST /api/whatsapp/chatbot/5/replies']!;
    expect([sent['keys'], sent['mode'], sent['media_id'], sent['reply']], ['promo, diskon', 'contains', 'm1', 'Diskon 20% Kak!']);
    expect((_entries(triggers.items()).single['lines'] as List).last, '📎 Brosur');
    triggers.button(3); // hapus
    await _settle();
    expect(server.replies, isEmpty);

    final hub = pages['whatsappbot']! as WaHubPage;
    hub.opened();
    await _settle();
    hub.button(901);
    hub.toggle(1);
    await _settle();
    expect(server.settings['auto_ready'], isTrue);
    expect(hub.toggleValue(1), isTrue);

    hub.button(902);
    expect(_entries(hub.items()).first['t'], '2 chat sedang ditangani admin');
    hub.button(21);
    await _settle();
    expect(server.paused, 0);
    hub.button(20);
    hub.sheetEvent('wa-kb', 'input', 0, 'Area antar');
    hub.sheetEvent('wa-kb', 'input', 1, 'Gratis 3 km');
    hub.sheetEvent('wa-kb', 'button', 0, null);
    await _settle();
    expect(server.settings['knowledge'], 'Tanya: Area antar\nJawab: Gratis 3 km');
    expect(hub.kb.single['a'], 'Gratis 3 km');

    hub.button(904);
    hub.button(22);
    expect(host.went.last, 'wamedia');
  });

  test('Promo dikirim lewat server dari nomor cabang aktif, butuh persetujuan, bisa dibatalkan', () async {
    final server = _Server();
    final host = await _host(server);
    final pages = whatsappPages(host);
    final blast = pages['blast191']! as BlastPage;
    blast.opened();
    await _settle();
    expect(blast.items().any((e) => '${e['t']}'.contains('Perkiraan penerima: 12')), isTrue);
    blast.input(0, 'Promo Oktober');
    blast.input(1, 'Halo {nama}, diskon!');
    blast.button(0);
    expect(host.toasts.last, 'Pastikan penerima sudah setuju menerima promo.');
    blast.toggle(0);
    blast.input(3, 1);
    await _settle();
    blast.button(0);
    await _settle();
    final body = server.bodies['POST /api/whatsapp/blasts']!;
    expect([body['device_id'], body['audience'], body['name']], ['11111111-1111-4111-8111-111111111111', 'all', 'Promo Oktober']);
    expect(host.toasts.last, 'Promo dikirim bergilir');
    blast.button(1000);
    await _settle();
    expect(server.calls, contains('POST /api/whatsapp/blasts/b1/cancel'));
  });

  test('Promo butuh paket Platinum', () async {
    planAccess.testPlan = 'GOLD';
    final host = await _host(_Server());
    final blast = whatsappPages(host)['blast191']! as BlastPage;
    blast.opened();
    await _settle();
    blast.button(0);
    expect(host.toasts.last, planAccess.lockedText('blast'));
  });

  test('WaLink tetap dipakai halaman perangkat', () async {
    final host = await _host(_Server());
    expect(WaLink(host).staffOnly, isFalse);
  });
}
