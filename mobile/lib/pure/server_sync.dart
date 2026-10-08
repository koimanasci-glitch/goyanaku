// Mode Murni tersambung ke server GOYANA (Laravel): masuk, lalu sinkronisasi dua arah.
//
// Protokolnya sama dengan aplikasi HTML (goyana-sync-core.js + goyana-v197-sync.js):
// - Data tetap disimpan di HP dengan kunci yang sama; berkas ini hanya memetakannya ke koleksi server.
// - Setiap perubahan dikirim dengan op_id (aman diulang) dan revisi server terakhir yang dikenal (base_rev).
// - Data dari server ditampung dulu ("inbox") dan baru diterapkan saat pengguna tidak sedang mengisi sesuatu.
// Owner masuk dengan email + password; kasir, pegawai, dan kurir dengan nomor HP + PIN (keputusan 8 Okt 2026).
// Status dan sesi memakai kunci sendiri (goyana-psync-*), terpisah dari mesin sinkron HTML.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/store.dart';

/// Alamat server bawaan saat APK dibangun (flutter build --dart-define=GOYANA_API_URL=https://…). Kosong = diisi di Pengaturan.
const serverDefaultUrl = String.fromEnvironment('GOYANA_API_URL');
const serverUrlKey = 'goyana-api-url';
const serverDeviceKey = 'goyana-sync-device';
const serverAuthKey = 'goyana-psync-auth';
const serverStateKey = 'goyana-psync-state';
const serverInboxKey = 'goyana-psync-inbox';
const serverOutboxKey = 'goyana-psync-outbox';

const _stockKey = 'goyana-stock181';
const _couriersKey = 'goyana-couriers181';
const _pickupsKey = 'goyana-pickup202';
const _transportKey = 'goyana-transport183';

/// Bagian stok di penyimpanan lokal untuk tiap koleksi server.
const _stockParts = {
  'stock_items': 'items',
  'stock_ledger': 'ledger',
  'stock_suppliers': 'suppliers',
  'stock_purchases': 'purchases',
  'stock_recipes': 'recipes',
};

/// Setelan yang disimpan sebagai teks apa adanya (bukan JSON).
const _settingKeys = [_transportKey, Keys.qrisText, Keys.qrisImage];

/// Kunci penyimpanan yang isinya ikut disinkronkan: perubahan padanya memicu sinkronisasi.
const serverWatchedKeys = [Keys.business, Keys.services, _stockKey, _couriersKey, Keys.outlets, _pickupsKey, _transportKey, Keys.qrisText, Keys.qrisImage];

class ServerFailure implements Exception {
  const ServerFailure(this.message, {this.offline = false});
  final String message;

  /// Server tidak terjangkau (tanpa internet), bukan ditolak.
  final bool offline;
  @override
  String toString() => message;
}

class ServerReply {
  const ServerReply(this.status, this.body);
  final int status;
  final String body;
}

/// Pengirim permintaan; diganti di tes.
typedef ServerSend = Future<ServerReply> Function(String method, Uri url, Map<String, String> headers, String? body);

Future<ServerReply> _httpSend(String method, Uri url, Map<String, String> headers, String? body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.openUrl(method, url);
    request.followRedirects = false;
    for (final e in headers.entries) {
      request.headers.set(e.key, e.value);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return ServerReply(response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

/// Satu data lokal yang dipetakan ke server.
class LocalRecord {
  const LocalRecord(this.outlet, this.data);
  final String? outlet;
  final Object? data;
}

Object? _decode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

String _text(Object? v) => v == null ? '' : '$v';

Map<String, dynamic> _asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _asList(Object? v) => v is List ? List<dynamic>.from(v) : <dynamic>[];

/// JSON dengan kunci terurut, supaya data yang sama selalu memberi sidik yang sama.
String canonJson(Object? v) {
  if (v is Map) {
    final keys = [for (final k in v.keys) '$k']..sort();
    return '{${[for (final k in keys) '${jsonEncode(k)}:${canonJson(v[k])}'].join(',')}}';
  }
  if (v is List) return '[${[for (final x in v) canonJson(x)].join(',')}]';
  return jsonEncode(v);
}

/// Sidik pendek (FNV-1a 32-bit), sama bentuknya dengan aplikasi HTML.
String shortHash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xffffffff;
  }
  return '${h.toRadixString(36)}:${s.length}';
}

String fingerprintOf(LocalRecord rec) => shortHash(canonJson({'o': rec.outlet, 'd': rec.data}));

/// Nomor HP sebagai angka saja berawalan 62.
String normalizePhone(Object? phone) {
  var n = _text(phone).replaceAll(RegExp(r'\D'), '');
  if (n.startsWith('0')) n = '62${n.substring(1)}';
  return n;
}

String customerKeyOf(Map<dynamic, dynamic> c) {
  final p = normalizePhone(c['phone']);
  return p.isNotEmpty ? 'phone:$p' : 'name:${_text(c['name']).trim().toLowerCase()}';
}

String orderIdOf(Object? card) {
  if (card is! Map) return '';
  final fields = card['fields'];
  if (fields is! List || fields.length < 2) return '';
  final second = fields[1];
  if (second is! List || second.isEmpty) return '';
  return _text(second[0]).trim();
}

String _idOf(Object? x) {
  if (x is Map) {
    final id = _text(x['id']).isNotEmpty ? _text(x['id']) : _text(x['key']);
    if (id.isNotEmpty) return id;
  }
  return shortHash(canonJson(x));
}

bool _notEmptyList(Object? v) => v is List && v.isNotEmpty;

bool _hasCash(Map<String, dynamic> kas) {
  final start = kas['start'];
  final started = start is num ? start != 0 : _text(start).isNotEmpty && _text(start) != '0';
  return _notEmptyList(kas['sales']) || _notEmptyList(kas['ins']) || _notEmptyList(kas['outs']) || started;
}

/// Data lokal sekarang sebagai peta "koleksi|kunci" ke isinya.
Future<Map<String, LocalRecord>> extractLocal(KvStore kv) async {
  final out = <String, LocalRecord>{};
  void put(String collection, String key, Object? outlet, Object? data) {
    if (key.isEmpty) return;
    final o = _text(outlet);
    out['$collection|$key'] = LocalRecord(o.isEmpty ? null : o, data);
  }

  final b = _asMap(_decode(await kv.get(Keys.business)));
  final details = _asMap(b['details']);
  for (final r in _asList(b['orders'])) {
    final id = orderIdOf(r);
    if (id.isEmpty || r is! Map) continue;
    final dataset = r['dataset'];
    put('orders', id, dataset is Map ? dataset['outlet180'] : null, {'card': r, 'detail': details[id]});
  }
  for (final c in _asList(b['customers'])) {
    if (c is Map && _text(c['name']).isNotEmpty) put('customers', customerKeyOf(c), null, c);
  }
  final deposits = _asMap(b['deposits178']);
  for (final e in deposits.entries) {
    put('deposits', e.key, null, e.value);
  }
  final active = _text(_decode(await kv.get(Keys.activeOutlet)));
  final kas = b['kas'];
  if (kas is Map) {
    final k = _asMap(kas);
    if (_hasCash(k)) put('kas', '$active|${_text(k['kasir'])}', active, k);
  }
  for (final s in _asList(_decode(await kv.get(Keys.services)))) {
    if (s is Map && _text(s['key']).isNotEmpty) put('services', _text(s['key']), null, s);
  }
  for (final c in _asList(_decode(await kv.get(_couriersKey)))) {
    put('couriers', _idOf(c), null, c);
  }
  final stock = _decode(await kv.get(_stockKey));
  if (stock is Map) {
    for (final part in _stockParts.entries) {
      for (final x in _asList(stock[part.value])) {
        put(part.key, _idOf(x), null, x);
      }
    }
  }
  for (final o in _asList(_decode(await kv.get(Keys.outlets)))) {
    if (o is Map && RegExp(r'^srv-\d+$').hasMatch(_text(o['id']))) put('outlet_profiles', _text(o['id']), null, o);
  }
  for (final p in _asList(_decode(await kv.get(_pickupsKey)))) {
    if (p is Map && _text(p['id']).isNotEmpty) put('pickups', _text(p['id']), p['outlet'], p);
  }
  for (final k in _settingKeys) {
    final v = await kv.get(k);
    if (v != null && v.isNotEmpty) put('settings', k, null, v);
  }
  return out;
}

void _upsert(List<dynamic> list, String key, String Function(Object? x) keyOf, Object? value, bool deleted) {
  final i = list.indexWhere((x) => keyOf(x) == key);
  if (deleted) {
    if (i >= 0) list.removeAt(i);
    return;
  }
  if (value == null) return;
  if (i >= 0) {
    list[i] = value;
  } else {
    list.add(value);
  }
}

String _createdOf(Object? card) {
  if (card is! Map) return '';
  final dataset = card['dataset'];
  return dataset is Map ? _text(dataset['created177']) : '';
}

/// Gabungkan data dari server ke penyimpanan lokal (deleted = hapus). Mengembalikan jumlah yang diterapkan.
Future<int> applyRemote(KvStore kv, List<Map<String, dynamic>> records) async {
  if (records.isEmpty) return 0;
  final b = _asMap(_decode(await kv.get(Keys.business)));
  final orders = _asList(b['orders']);
  final customers = _asList(b['customers']);
  final details = _asMap(b['details']);
  final deposits = _asMap(b['deposits178']);
  final active = _text(_decode(await kv.get(Keys.activeOutlet)));
  var businessChanged = false;
  List<dynamic>? services, couriers, outlets, pickups;
  Map<String, dynamic>? stock;

  for (final r in records) {
    final collection = _text(r['collection']), key = _text(r['key']);
    final deleted = r['deleted'] == true;
    final data = r['data'];
    switch (collection) {
      case 'orders':
        _upsert(orders, key, orderIdOf, data is Map ? data['card'] : null, deleted);
        if (deleted) {
          details.remove(key);
        } else if (data is Map && data['detail'] != null) {
          details[key] = data['detail'];
        }
        businessChanged = true;
      case 'customers':
        _upsert(customers, key, (x) => x is Map ? customerKeyOf(x) : '', data, deleted);
        businessChanged = true;
      case 'deposits':
        if (deleted) {
          deposits.remove(key);
        } else {
          deposits[key] = data;
        }
        businessChanged = true;
      case 'kas':
        // Hanya laci kas milik HP ini yang dipulihkan (mis. setelah pasang ulang); laci lain tetap di server.
        final kas = _asMap(b['kas']);
        final mine = '$active|${_text(kas['kasir']).isNotEmpty ? _text(kas['kasir']) : (data is Map ? _text(data['kasir']) : '')}';
        final empty = !(_notEmptyList(kas['sales']) || _notEmptyList(kas['ins']) || _notEmptyList(kas['outs']));
        if (!deleted && key == mine && empty && data is Map) {
          b['kas'] = data;
          businessChanged = true;
        }
      case 'services':
        services ??= _asList(_decode(await kv.get(Keys.services)));
        _upsert(services, key, (x) => x is Map ? _text(x['key']) : '', data, deleted);
      case 'couriers':
        couriers ??= _asList(_decode(await kv.get(_couriersKey)));
        _upsert(couriers, key, _idOf, data, deleted);
      case 'outlet_profiles':
        outlets ??= _asList(_decode(await kv.get(Keys.outlets)));
        _upsert(outlets, key, (x) => x is Map ? _text(x['id']) : '', data, deleted);
      case 'pickups':
        pickups ??= _asList(_decode(await kv.get(_pickupsKey)));
        _upsert(pickups, key, (x) => x is Map ? _text(x['id']) : '', data, deleted);
      case 'settings':
        if (_settingKeys.contains(key)) {
          if (deleted) {
            await kv.remove(key);
          } else if (data is String) {
            await kv.set(key, data);
          }
        }
      default:
        final part = _stockParts[collection];
        if (part != null) {
          stock ??= _asMap(_decode(await kv.get(_stockKey)));
          final list = _asList(stock[part]);
          _upsert(list, key, _idOf, data, deleted);
          stock[part] = list;
        }
    }
  }
  if (businessChanged) {
    orders.removeWhere((x) => x == null);
    orders.sort((x, y) => _createdOf(y).compareTo(_createdOf(x)));
    b['orders'] = orders;
    b['customers'] = customers;
    b['details'] = details;
    b['deposits178'] = deposits;
    await kv.set(Keys.business, jsonEncode(b));
  }
  if (services != null) await kv.set(Keys.services, jsonEncode(services));
  if (couriers != null) await kv.set(_couriersKey, jsonEncode(couriers));
  if (outlets != null) await kv.set(Keys.outlets, jsonEncode(outlets));
  if (pickups != null) await kv.set(_pickupsKey, jsonEncode(pickups));
  if (stock != null) await kv.set(_stockKey, jsonEncode(stock));
  return records.length;
}

Object? _replaceDeep(Object? v, String from, String to) {
  if (v == from) return to;
  if (v is List) return [for (final x in v) _replaceDeep(x, from, to)];
  if (v is Map) {
    return <String, dynamic>{for (final e in v.entries) ('${e.key}' == from ? to : '${e.key}'): _replaceDeep(e.value, from, to)};
  }
  return v;
}

/// Outlet lokal memakai id server ("srv-" + nomor). Outlet lama di HP ini dipetakan ke outlet server pertama yang belum ada.
/// Mengembalikan true bila penyimpanan berubah.
Future<bool> mapServerOutlets(KvStore kv, List<dynamic> serverOutlets, String role) async {
  var local = _asList(_decode(await kv.get(Keys.outlets)));
  var changed = false;
  final allowed = <String>[];
  for (final s in serverOutlets) {
    if (s is! Map) continue;
    final id = 'srv-${_text(s['id'])}';
    allowed.add(id);
    if (local.any((o) => o is Map && _text(o['id']) == id)) continue;
    final legacy = local.where((o) => o is Map && !RegExp(r'^srv-\d+$').hasMatch(_text(o['id']))).firstOrNull;
    if (legacy is Map) {
      final old = _text(legacy['id']);
      for (final k in [...serverWatchedKeys, Keys.activeOutlet]) {
        // Teks QRIS disimpan apa adanya (bukan JSON) dan tidak memuat id outlet.
        if (k == Keys.qrisText || k == Keys.qrisImage) continue;
        final raw = await kv.get(k);
        final v = _decode(raw);
        if (v == null) continue;
        final next = jsonEncode(_replaceDeep(v, old, id));
        if (next != raw) await kv.set(k, next);
      }
      local = _asList(_decode(await kv.get(Keys.outlets)));
      for (final o in local) {
        if (o is Map && _text(o['id']) == id && _text(o['name']).isEmpty) o['name'] = _text(s['name']);
      }
    } else {
      local.add({'id': id, 'name': _text(s['name']), 'address': _text(s['address']), 'phone': _text(s['phone']), 'logo': ''});
    }
    changed = true;
  }
  if (changed) await kv.set(Keys.outlets, jsonEncode(local));
  final active = _text(_decode(await kv.get(Keys.activeOutlet)));
  if (allowed.isNotEmpty && (role != 'owner' || !allowed.contains(active))) {
    if (active != allowed.first && (role != 'owner' || !active.startsWith('srv-'))) {
      await kv.set(Keys.activeOutlet, jsonEncode(allowed.first));
      changed = true;
    }
  }
  return changed;
}

String _uuid() {
  final r = Random.secure();
  return [for (var i = 0; i < 16; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// Keadaan untuk kartu "Sinkronisasi server" di Pengaturan.
class ServerStatus {
  /// idle | syncing | ok | offline | error
  String phase = 'idle';
  int pending = 0;
  DateTime? last;
  String error = '';
  String rejected = '';
  bool readOnly = false;
}

class ServerSync {
  ServerSync(this.kv, {ServerSend? send, this.onChanged, DateTime Function()? clock})
      : _send = send ?? _httpSend,
        _clock = clock ?? DateTime.now;

  final KvStore kv;
  final ServerSend _send;
  final DateTime Function() _clock;

  /// Dipanggil setiap status berubah (untuk menggambar ulang kartu).
  final void Function()? onChanged;

  final ServerStatus status = ServerStatus();
  String _url = '';
  Map<String, dynamic>? _auth;
  Future<void>? _running;

  /// Alamat server tanpa garis miring di akhir; kosong = belum diatur.
  String get url => _url;

  bool get loggedIn => _auth != null;
  Map<String, dynamic> get user => _asMap(_auth?['user']);
  Map<String, dynamic> get businessInfo => _asMap(_auth?['business']);
  Map<String, dynamic> get access => _asMap(_auth?['access']);
  Map<String, dynamic> get note => _asMap(_auth?['note']);
  String get role => _text(user['role']);

  /// Izin peran dari server (mis. orders.create); owner memuat "*".
  bool can(String permission) {
    final list = _asList(user['permissions']);
    return list.contains('*') || list.contains(permission);
  }

  Future<void> load() async {
    final saved = _text(await kv.get(serverUrlKey)).trim();
    _url = (saved.isNotEmpty ? saved : serverDefaultUrl).replaceAll(RegExp(r'/+$'), '');
    final a = _asMap(_decode(await kv.get(serverAuthKey)));
    final expires = DateTime.tryParse(_text(a['expires_at']));
    _auth = _text(a['token']).isNotEmpty && (expires == null || expires.isAfter(_clock())) ? a : null;
    status.pending = loggedIn ? (await _pending()).length : 0;
  }

  /// Simpan alamat server. Mengembalikan pesan salah, atau null bila diterima.
  Future<String?> setUrl(String value) async {
    final v = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(v);
    if (uri == null || uri.host.isEmpty || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return 'Isi alamat server, contoh https://app.goyana.id';
    }
    _url = v;
    await kv.set(serverUrlKey, v);
    onChanged?.call();
    return null;
  }

  Future<String> deviceId() async {
    var d = _text(await kv.get(serverDeviceKey));
    if (d.length < 8) {
      d = _uuid();
      await kv.set(serverDeviceKey, d);
    }
    return d;
  }

  Future<Map<String, dynamic>> _request(String method, String path, [Map<String, dynamic>? body]) async {
    if (_url.isEmpty) throw const ServerFailure('Alamat server belum diisi.');
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _text(_auth?['token']);
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    ServerReply reply;
    try {
      reply = await _send(method, Uri.parse('$_url/api$path'), headers, body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 40));
    } on ServerFailure {
      rethrow;
    } catch (_) {
      throw const ServerFailure('Tidak dapat terhubung ke server.', offline: true);
    }
    final json = _asMap(_decode(reply.body));
    if (reply.status == 401) {
      _auth = null;
      await kv.remove(serverAuthKey);
      throw const ServerFailure('Sesi berakhir. Masuk lagi.');
    }
    if (reply.status == 429) throw const ServerFailure('Terlalu banyak percobaan. Tunggu sebentar.');
    if (reply.status < 200 || reply.status >= 300) {
      final errors = _asMap(json['errors']);
      final first = errors.isEmpty ? null : errors.values.first;
      final detail = first is List && first.isNotEmpty ? _text(first.first) : _text(json['message']);
      throw ServerFailure(detail.isNotEmpty ? detail : 'Server menolak (${reply.status})');
    }
    return json;
  }

  /// Masuk dengan email + password (owner) atau nomor HP + PIN (kasir, pegawai, kurir).
  /// Mengembalikan true bila data outlet di HP berubah dan perlu dimuat ulang.
  Future<bool> login(String account, String secret) async {
    final id = account.trim();
    if (id.isEmpty) throw const ServerFailure('Isi email atau nomor HP');
    if (secret.isEmpty) throw const ServerFailure('Isi password atau PIN');
    final device = await deviceId();
    Map<String, dynamic> session;
    if (id.contains('@')) {
      session = await _request('POST', '/session', {'email': id.toLowerCase(), 'password': secret, 'device_id': device});
    } else {
      final phone = normalizePhone(id);
      if (phone.length < 10) throw const ServerFailure('Periksa nomor HP');
      if (!RegExp(r'^\d+$').hasMatch(secret)) throw const ServerFailure('PIN berupa angka');
      session = await _request('POST', '/session/pin', {'phone': phone, 'pin': secret, 'device_id': device});
    }
    final token = _text(session['token']);
    if (token.isEmpty) throw const ServerFailure('Server tidak memberikan sesi yang valid.');
    _auth = {'token': token, 'expires_at': _text(session['expires_at']), 'account': id};
    await kv.set(serverAuthKey, jsonEncode(_auth));
    return refreshProfile();
  }

  /// Ambil profil, paket, dan outlet akun ini, lalu petakan outlet ke id server.
  Future<bool> refreshProfile() async {
    final device = await deviceId();
    final me = await _request('GET', '/me?device_id=${Uri.encodeQueryComponent(device)}');
    final a = _auth;
    if (a == null) return false;
    for (final k in const ['user', 'business', 'access', 'outlets', 'note', 'rules']) {
      a[k] = me[k];
    }
    await kv.set(serverAuthKey, jsonEncode(a));
    final changed = await mapServerOutlets(kv, _asList(me['outlets']), _text(_asMap(me['user'])['role']));
    onChanged?.call();
    return changed;
  }

  Future<void> logout() async {
    if (loggedIn && _url.isNotEmpty) {
      try {
        await _request('DELETE', '/session');
      } catch (_) {}
    }
    _auth = null;
    await kv.remove(serverAuthKey);
    status
      ..phase = 'idle'
      ..pending = 0
      ..error = ''
      ..rejected = '';
    onChanged?.call();
  }

  Future<Map<String, dynamic>> _state() async {
    final s = _asMap(_decode(await kv.get(serverStateKey)));
    if (s['recs'] is! Map) return {'cursor': 0, 'recs': <String, dynamic>{}};
    s['recs'] = _asMap(s['recs']);
    return s;
  }

  Future<List<Map<String, dynamic>>> _inbox() async => [for (final r in _asList(_decode(await kv.get(serverInboxKey)))) if (r is Map) Map<String, dynamic>.from(r)];

  /// Jumlah data dari server yang menunggu diterapkan.
  Future<int> inboxCount() async => (await _inbox()).length;

  Future<List<Map<String, dynamic>>> _pending() async {
    final now = await extractLocal(kv), st = await _state();
    final recs = _asMap(st['recs']);
    final staged = {for (final r in await _inbox()) '${r['collection']}|${r['key']}'};
    final list = <Map<String, dynamic>>[];
    for (final e in now.entries) {
      final h = fingerprintOf(e.value), known = recs[e.key];
      if (staged.contains(e.key) || (known is Map && known['h'] == h)) continue;
      final i = e.key.indexOf('|');
      list.add({
        'ck': e.key, 'h': h, 'collection': e.key.substring(0, i), 'key': e.key.substring(i + 1), 'outlet': e.value.outlet,
        'data': e.value.data, 'deleted': false, 'base_rev': known is Map ? (known['rev'] ?? 0) : 0,
      });
    }
    for (final e in recs.entries) {
      final known = e.value;
      if (known is! Map || known['h'] == null || staged.contains(e.key) || now.containsKey(e.key)) continue;
      final i = e.key.indexOf('|');
      list.add({
        'ck': e.key, 'h': null, 'collection': e.key.substring(0, i), 'key': e.key.substring(i + 1), 'outlet': null,
        'data': null, 'deleted': true, 'base_rev': known['rev'] ?? 0,
      });
    }
    return list;
  }

  Future<void> _stage(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final byKey = <String, Map<String, dynamic>>{};
    for (final r in [...await _inbox(), ...records]) {
      byKey['${r['collection']}|${r['key']}'] = r;
    }
    await kv.set(serverInboxKey, jsonEncode(byKey.values.toList()));
  }

  Future<void> _pull() async {
    var cursor = (_asMap(await _state())['cursor'] as num?)?.toInt() ?? 0;
    while (true) {
      final j = await _request('GET', '/sync/pull?cursor=$cursor');
      final st = await _state();
      final recs = _asMap(st['recs']);
      final got = <Map<String, dynamic>>[];
      for (final r in _asList(j['records'])) {
        if (r is! Map) continue;
        final known = recs['${r['collection']}|${r['key']}'];
        final rev = (r['rev'] as num?)?.toInt() ?? 0;
        if (known is! Map || ((known['rev'] as num?)?.toInt() ?? 0) < rev) got.add(Map<String, dynamic>.from(r));
      }
      status.readOnly = j['read_only'] == true;
      await _stage(got);
      cursor = (j['cursor'] as num?)?.toInt() ?? cursor;
      st['cursor'] = cursor;
      st['recs'] = recs;
      await kv.set(serverStateKey, jsonEncode(st));
      if (j['more'] != true) return;
    }
  }

  Future<void> _push() async {
    final changes = await _pending();
    status.pending = changes.length;
    if (changes.isEmpty) {
      status.rejected = '';
      return;
    }
    if (status.readOnly) {
      status.rejected = 'Paket berakhir: perubahan di HP ini belum terkirim.';
      return;
    }
    final outbox = _asMap(_decode(await kv.get(serverOutboxKey)));
    for (final c in changes) {
      final prev = outbox[c['ck']];
      c['op_id'] = prev is Map && prev['h'] == c['h'] ? _text(prev['op']) : _uuid();
      outbox['${c['ck']}'] = {'h': c['h'], 'op': c['op_id']};
    }
    await kv.set(serverOutboxKey, jsonEncode(outbox));
    final device = await deviceId();
    var rejected = '';
    for (var i = 0; i < changes.length; i += 100) {
      final batch = changes.sublist(i, i + 100 > changes.length ? changes.length : i + 100);
      final j = await _request('POST', '/sync/push', {
        'device_id': device,
        'changes': [
          for (final c in batch)
            {'op_id': c['op_id'], 'collection': c['collection'], 'key': c['key'], 'outlet': c['outlet'], 'data': c['data'], 'deleted': c['deleted'], 'base_rev': c['base_rev']},
        ],
      });
      final st = await _state();
      final recs = _asMap(st['recs']);
      final ob = _asMap(_decode(await kv.get(serverOutboxKey)));
      final conflicts = <Map<String, dynamic>>[];
      final results = _asList(j['results']);
      for (var k = 0; k < results.length && k < batch.length; k++) {
        final res = results[k], c = batch[k];
        if (res is! Map) continue;
        if (res['status'] == 'applied') {
          recs['${c['ck']}'] = {'rev': res['rev'], 'h': c['h']};
          ob.remove(c['ck']);
        } else if (res['status'] == 'conflict') {
          // Server memakai versinya (bentrok, atau kiriman tidak sesuai hak peran): HP mengambil versi server.
          if (res['record'] is Map) conflicts.add(Map<String, dynamic>.from(res['record'] as Map));
          if (_text(res['message']).isNotEmpty) rejected = _text(res['message']);
          ob.remove(c['ck']);
        } else {
          rejected = _text(res['message']).isNotEmpty ? _text(res['message']) : 'Sebagian data ditolak server';
        }
      }
      st['recs'] = recs;
      await kv.set(serverStateKey, jsonEncode(st));
      await kv.set(serverOutboxKey, jsonEncode(ob));
      await _stage(conflicts);
    }
    status.rejected = rejected;
    status.pending = (await _pending()).length;
  }

  /// Terapkan data dari server yang sudah ditampung. Panggil saat pengguna tidak sedang mengisi sesuatu,
  /// lalu muat ulang data di layar. Mengembalikan jumlah yang diterapkan.
  Future<int> applyInbox() async {
    final inbox = await _inbox();
    if (inbox.isEmpty) return 0;
    await applyRemote(kv, inbox);
    final st = await _state();
    final recs = _asMap(st['recs']);
    final now = await extractLocal(kv);
    for (final r in inbox) {
      final ck = '${r['collection']}|${r['key']}';
      final local = now[ck];
      recs[ck] = {'rev': r['rev'], 'h': r['deleted'] == true || local == null ? null : fingerprintOf(local)};
    }
    st['recs'] = recs;
    await kv.set(serverStateKey, jsonEncode(st));
    await kv.remove(serverInboxKey);
    status.pending = (await _pending()).length;
    onChanged?.call();
    return inbox.length;
  }

  /// Satu putaran: tarik lalu kirim. Aman dipanggil berulang; putaran yang sedang jalan dipakai bersama.
  Future<void> cycle() {
    final running = _running;
    if (running != null) return running;
    final next = _cycle().whenComplete(() => _running = null);
    _running = next;
    return next;
  }

  Future<void> _cycle() async {
    if (_url.isEmpty || !loggedIn) return;
    status.phase = 'syncing';
    onChanged?.call();
    try {
      await _pull();
      await _push();
      status
        ..phase = 'ok'
        ..error = ''
        ..last = _clock();
    } on ServerFailure catch (e) {
      status
        ..phase = e.offline ? 'offline' : 'error'
        ..error = e.message;
      try {
        status.pending = loggedIn ? (await _pending()).length : 0;
      } catch (_) {}
    } catch (_) {
      status
        ..phase = 'error'
        ..error = 'Data di HP tidak terbaca';
    }
    onChanged?.call();
  }

  /// Isi kartu "Sinkronisasi server" (teks dan warna sama dengan aplikasi HTML). null = belum ada alamat server.
  Map<String, dynamic>? card() {
    if (_url.isEmpty) return null;
    String line, dot;
    if (!loggedIn) {
      line = 'Belum masuk · data hanya di HP ini';
      dot = 'rgb(232, 162, 58)';
    } else if (status.phase == 'offline') {
      line = 'Offline · ${status.pending} data menunggu sinkronisasi';
      dot = 'rgb(232, 162, 58)';
    } else if (status.phase == 'error') {
      line = 'Sinkronisasi bermasalah · ${status.error}';
      dot = 'rgb(232, 73, 63)';
    } else if (status.phase == 'syncing') {
      line = 'Menyinkronkan…';
      dot = 'rgb(30, 123, 224)';
    } else if (status.pending > 0) {
      line = '${status.pending} data menunggu sinkronisasi${status.rejected.isEmpty ? '' : ' · ${status.rejected}'}';
      dot = 'rgb(232, 162, 58)';
    } else {
      final t = status.last;
      final at = t == null ? '' : ' · ${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
      line = 'Online · semua data tersinkron$at';
      dot = 'rgb(27, 166, 114)';
    }
    final u = user, b = businessInfo;
    final who = loggedIn && u.isNotEmpty ? '${_text(u['name'])} · ${_text(u['role_label'])}${b.isEmpty ? '' : ' · ${_text(b['name'])}'}' : '';
    return {
      'dot': dot, 't': 'Sinkronisasi server', 'line': line, 'who': who,
      if (!loggedIn) 'url': {'v': _url, 'ph': 'https://app.goyana.id'},
      'save': loggedIn ? '' : 'Simpan & masuk',
      'now': loggedIn ? 'Sinkronkan sekarang' : '',
    };
  }
}
