// Isolated WhatsApp module. No login, package catalog or outlet system duplicated here.
import 'dart:convert';
import 'dart:math';

abstract interface class WaStorage {
  Future<String?> read(String key);
  Future<bool> write(String key, String value);
}

/// Inject the authenticated transport from Goyana's existing session layer.
/// Paths belong to GOYANA Laravel, never Chatku. API keys never enter Flutter.
typedef WaRequest = Future<Map<String, dynamic>> Function(
  String method,
  String path,
  Map<String, dynamic>? body,
);

class WaFailure implements Exception {
  const WaFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class WaOutlet {
  const WaOutlet({required this.key, required this.name, this.serverId});
  final String key, name;
  final int? serverId;
}

class WaDevice {
  const WaDevice({
    required this.id,
    required this.name,
    required this.phone,
    required this.outletKey,
    this.serverOutletId,
    this.registered = false,
    this.status = 'draft',
    this.replyStatus = false,
    this.replyServices = false,
    this.version = 1,
  });
  final String id, name, phone, outletKey, status;
  final int? serverOutletId;
  final bool registered, replyStatus, replyServices;
  final int version;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'outlet_key': outletKey,
    'outlet_id': serverOutletId, 'registered': registered, 'version': version,
    // Cached connection state is deliberately never persisted as authoritative.
    'reply_status': replyStatus, 'reply_services': replyServices,
  };
  factory WaDevice.local(Map<String, dynamic> j) => WaDevice(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    outletKey: j['outlet_key'] as String,
    serverOutletId: j['outlet_id'] as int?,
    registered: j['registered'] == true,
    status: j['registered'] == true ? 'unknown' : 'draft',
    replyStatus: j['reply_status'] == true,
    replyServices: j['reply_services'] == true,
    version: (j['version'] as num?)?.toInt() ?? 1,
  );
  factory WaDevice.server(Map<String, dynamic> j, List<WaOutlet> outlets) {
    final outletId = (j['outlet_id'] as num).toInt();
    final matches = outlets.where((o) => o.serverId == outletId);
    // Unknown mapping stays explicit; it is never guessed as Pusat.
    return WaDevice(
      id: j['id'] as String,
      name: j['name'] as String,
      phone: j['phone'] as String,
      outletKey: matches.isEmpty ? '' : matches.first.key,
      serverOutletId: outletId,
      registered: true,
      status: j['status'] as String? ?? 'unknown',
      replyStatus: j['reply_status'] == true || j['reply_status'] == 1,
      replyServices: j['reply_services'] == true || j['reply_services'] == 1,
      version: (j['version'] as num).toInt(),
    );
  }
}

class WaPairing {
  WaPairing(Map<String, dynamic> json, String method, DateTime now)
    : kind = json['kind'] as String? ?? '',
      value = json['value'] as String? ?? '',
      expiresAt =
          DateTime.tryParse('${json['expires_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0) {
    if (kind != method ||
        !['qr', 'code'].contains(kind) ||
        value.isEmpty ||
        !expiresAt.isAfter(now)) {
      throw const WaFailure(
        'QR atau kode tidak valid/kedaluwarsa. Minta ulang.',
      );
    }
  }
  final String kind, value;
  final DateTime expiresAt;
}

String normalizeWaPhone(String value) {
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(value.trim()))
    throw const WaFailure('Nomor WhatsApp tidak valid.');
  var n = value.replaceAll(RegExp(r'\D'), '');
  if (n.startsWith('0')) {
    n = '62${n.substring(1)}';
  } else if (n.startsWith('8')) {
    n = '62$n';
  }
  if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(n))
    throw const WaFailure('Nomor WhatsApp tidak valid.');
  return n;
}

String newWaId() {
  final random = Random.secure();
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class WaDeviceStore {
  WaDeviceStore({
    required this.storage,
    required this.accountScope,
    required this.outlets,
    this.request,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    if (accountScope.trim().isEmpty)
      throw ArgumentError('A stable local business/account scope is required.');
  }
  final WaStorage storage;
  // Must be recreated on account change, including request/token callback.
  final String accountScope;
  final List<WaOutlet> outlets;
  final WaRequest? request;
  final DateTime Function() clock;
  final List<WaDevice> _devices = [];
  List<WaDevice> get devices => List.unmodifiable(_devices);
  int? slotLimit, slotsUsed;
  bool statusAllowed = false, servicesAllowed = false;
  String get storageKey => 'goyana-wa-drafts-v1:$accountScope';
  bool _busy = false;
  bool _storageReadable = true;

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    if (_busy) throw const WaFailure('Tunggu proses sebelumnya selesai.');
    _busy = true;
    try {
      return await work();
    } finally {
      _busy = false;
    }
  }

  Future<void> _persist(List<WaDevice> next) async {
    if (!_storageReadable)
      throw const WaFailure(
        'Draf lama tidak dapat dibaca. Pulihkan penyimpanan sebelum mengubah data.',
      );
    if (!await storage.write(
      storageKey,
      jsonEncode(next.map((d) => d.toJson()).toList()),
    )) {
      throw const WaFailure(
        'Penyimpanan lokal gagal. Muat ulang sebelum melanjutkan.',
      );
    }
    _devices
      ..clear()
      ..addAll(next);
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (request == null)
      throw const WaFailure(
        'Draf tersimpan. Hubungkan ke server Goyana untuk memasangkan WhatsApp.',
      );
    return request!(method, '/api/whatsapp/$path', data);
  }

  Future<void> load() => _exclusive(() async {
    final raw = await storage.read(storageKey);
    if (raw == null) return;
    try {
      final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = rows.map(WaDevice.local).toList();
      _storageReadable = true;
      _devices
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      _storageReadable = false;
      throw const WaFailure(
        'Draf perangkat tidak dapat dibaca. Data lama belum dihapus.',
      );
    }
  });
  Future<void> refresh() => _exclusive(() async {
    // Offline refresh invalidates remembered entitlements, never grants from a stale cache.
    slotLimit = null;
    slotsUsed = null;
    statusAllowed = false;
    servicesAllowed = false;
    final json = await _call('GET', 'devices');
    final server = (json['devices'] as List)
        .map(
          (e) => WaDevice.server(Map<String, dynamic>.from(e as Map), outlets),
        )
        .toList();
    final ids = server.map((d) => d.id).toSet();
    await _persist([
      ..._devices.where((d) => !d.registered && !ids.contains(d.id)),
      ...server,
    ]);
    final q = json['quota'] as Map;
    slotLimit = (q['limit'] as num).toInt();
    slotsUsed = (q['used'] as num).toInt();
    statusAllowed = q['status_allowed'] == true;
    servicesAllowed = q['services_allowed'] == true;
  });
  Future<void> save({
    String? id,
    required String name,
    required String phone,
    required String outletKey,
  }) => _exclusive(() async {
    final n = name.trim();
    if (n.isEmpty || n.length > 80)
      throw const WaFailure('Isi nama perangkat, maksimal 80 karakter.');
    final p = normalizeWaPhone(phone);
    final outlet = outlets.where((o) => o.key == outletKey).firstOrNull;
    if (outlet == null)
      throw const WaFailure('Pilih outlet yang sudah dibuat.');
    if (_devices.any((d) => d.phone == p && d.id != id))
      throw const WaFailure('Nomor sudah ada dalam daftar.');
    final old = _devices.where((d) => d.id == id).firstOrNull;
    if (id != null && old == null)
      throw const WaFailure('Perangkat tidak ditemukan.');
    var next = WaDevice(
      id: id ?? newWaId(),
      name: n,
      phone: p,
      outletKey: outletKey,
      serverOutletId: outlet.serverId,
    );
    if (old?.registered == true) {
      if (outlet.serverId == null)
        throw const WaFailure('Outlet belum tersinkron ke server.');
      final json = await _call('PUT', 'devices/${old!.id}', {
        'name': n,
        'phone': p,
        'outlet_id': outlet.serverId,
        'version': old.version,
      });
      next = WaDevice.server(json, outlets);
    }
    await _persist([..._devices.where((d) => d.id != id), next]);
  });
  Future<void> remove(String id) => _exclusive(() async {
    final d = _get(id);
    if (d.registered) await _call('DELETE', 'devices/$id');
    await _persist(_devices.where((d) => d.id != id).toList());
  });
  WaDevice _get(String id) =>
      _devices.where((d) => d.id == id).firstOrNull ??
      (throw const WaFailure('Perangkat tidak ditemukan.'));
  Future<WaPairing> pair(String id, String method) => _exclusive(() async {
    if (!['qr', 'code'].contains(method))
      throw const WaFailure('Pilih QR atau kode pemasangan.');
    var d = _get(id);
    if (!d.registered) {
      final outletId = outlets
          .where((o) => o.key == d.outletKey)
          .firstOrNull
          ?.serverId;
      if (outletId == null)
        throw const WaFailure('Outlet belum tersinkron. Simpan draf dahulu.');
      final json = await _call('POST', 'devices', {
        'id': d.id,
        'name': d.name,
        'phone': d.phone,
        'outlet_id': outletId,
      });
      d = WaDevice.server(json, outlets);
      await _persist([..._devices.where((x) => x.id != id), d]);
    }
    final p = await _call('POST', 'devices/$id/pairing', {'method': method});
    return WaPairing(p, method, clock());
  });
  Future<void> refreshDevice(String id) => _exclusive(() async {
    final d = _get(id);
    if (!d.registered) throw const WaFailure('Perangkat masih berupa draf.');
    final json = await _call('POST', 'devices/$id/refresh');
    await _persist([
      ..._devices.where((d) => d.id != id),
      WaDevice.server(json, outlets),
    ]);
  });
  Future<void> automation(
    String id, {
    required bool status,
    required bool services,
  }) => _exclusive(() async {
    final d = _get(id);
    if (!d.registered)
      throw const WaFailure('Hubungkan perangkat ke server terlebih dahulu.');
    final json = await _call('PUT', 'devices/$id/automation', {
      'reply_status': status,
      'reply_services': services,
    });
    await _persist([
      ..._devices.where((d) => d.id != id),
      WaDevice.server(json, outlets),
    ]);
  });
}
