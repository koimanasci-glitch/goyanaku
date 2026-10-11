// Chatbot WhatsApp di server (keputusan Paduka 10 Okt 2026): pengaturan, Balasan Cepat, pengetahuan AI, Media, dan Promo/Blast
// tersimpan di server GOYANA per cabang, sehingga bot (lewat CHATKU) memakai isi yang sama dengan yang terlihat di HP.
// Mode server berlaku bila pemilik masuk akun dan cabang aktif sudah terdaftar di server; selain itu halaman tetap memakai
// penyimpanan HP seperti sebelumnya. Kunci CHATKU tidak pernah ada di aplikasi.


import '../whatsapp/device_store.dart' show WaFailure, newWaId;
import 'access.dart';
import 'pages.dart';
import 'server_sync.dart' show ServerFailure, ServerSync;
import 'wa_link.dart';

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? v) => [if (v is List) for (final e in v) if (e is Map) e.cast<String, dynamic>()];
int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? d;

String waRp(int v) {
  final s = v.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${v < 0 ? '-' : ''}Rp$s';
}

String waSize(int bytes) => bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

/// Data Chatbot cabang aktif dari server GOYANA (satu objek dipakai bersama semua halaman WhatsApp).
class ChatbotServer {
  ChatbotServer(this.host);
  final PureHost host;

  Map<String, dynamic> settings = {};
  Map<String, dynamic> features = {};
  List<Map<String, dynamic>> replies = [], media = [], blasts = [];
  int mediaLimit = 10, paused = 0, aiBalance = 0;
  bool loaded = false, busy = false;
  String note = '';
  int? _for;

  int? get outletId => ServerSync.outletNumber(host.business.activeOutlet);

  /// Pemilik sedang masuk akun dan cabang aktif sudah terdaftar di server.
  bool get available => host.server.loggedIn && host.server.isOwner && outletId != null;

  /// Data server cabang aktif sudah dimuat.
  bool get ready => available && loaded && _for == outletId;

  String get outletName {
    for (final o in host.business.outlets) {
      if (o.id == host.business.activeOutlet) return o.name.isEmpty ? 'Outlet' : o.name;
    }
    return 'Outlet';
  }

  /// Cabang lain yang sudah terdaftar di server (tujuan salin media).
  List<({int id, String name})> get otherOutlets => [
        for (final o in host.business.outlets)
          if (ServerSync.outletNumber(o.id) case final n? when n != outletId) (id: n, name: o.name.isEmpty ? 'Outlet' : o.name),
      ];

  Future<Map<String, dynamic>> _api(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      return await host.server.api(method, '/whatsapp$path', body);
    } on ServerFailure catch (e) {
      if (e.offline) throw const WaFailure('Butuh internet untuk mengatur Chatbot WhatsApp.');
      if (e.status == 404 && path.startsWith('/chatbot/')) throw const WaFailure('Layanan WhatsApp belum diaktifkan di server GOYANA.');
      throw WaFailure(e.message);
    }
  }

  /// Muat pengaturan, balasan cepat, dan media cabang aktif.
  Future<void> load({bool force = false}) async {
    final id = outletId;
    if (!available || id == null) {
      loaded = false;
      return;
    }
    if (!force && ready) return;
    try {
      final j = await _api('GET', '/chatbot/$id');
      settings = _map(j['settings']);
      features = _map(j['features']);
      replies = _maps(j['replies']);
      media = _maps(j['media']);
      mediaLimit = _int(j['media_limit'], 10);
      paused = _int(j['paused']);
      aiBalance = _int(j['ai_balance']);
      loaded = true;
      _for = id;
      note = '';
    } on WaFailure catch (e) {
      note = e.message;
    } catch (_) {
      note = 'Pengaturan Chatbot belum dapat dimuat.';
    }
    host.refresh();
  }

  /// Jalankan satu perubahan; gagal ditampilkan apa adanya, tidak pernah dianggap berhasil.
  Future<bool> run(Future<void> Function() work, {String ok = ''}) async {
    if (busy) {
      host.toast('Tunggu proses sebelumnya selesai.');
      return false;
    }
    busy = true;
    host.refresh();
    try {
      await work();
      if (ok.isNotEmpty) host.toast(ok);
      return true;
    } on WaFailure catch (e) {
      host.toast(e.message);
      return false;
    } catch (_) {
      host.toast('Belum berhasil. Periksa koneksi lalu coba lagi.');
      return false;
    } finally {
      busy = false;
      host.refresh();
    }
  }

  bool flag(String key) => settings[key] == true || settings[key] == 1;

  Future<void> save(Map<String, dynamic> changes) async {
    final j = await _api('PUT', '/chatbot/$outletId', {'version': _int(settings['version']), ...changes});
    settings = _map(j['settings']);
  }

  // ---------------------------------------------------------------- pengetahuan AI (teks di server)

  /// Pengetahuan disimpan sebagai teks "Tanya: …\nJawab: …" (dibaca AI apa adanya).
  List<Map<String, dynamic>> get knowledge {
    final text = '${settings['knowledge'] ?? ''}'.trim();
    if (text.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (final part in text.split(RegExp(r'\n\n(?=Tanya: )'))) {
      final m = RegExp(r'^Tanya: (.*?)\nJawab: ([\s\S]*)$').firstMatch(part.trim());
      out.add(m == null ? {'q': 'Catatan', 'a': part.trim()} : {'q': m.group(1)!.trim(), 'a': m.group(2)!.trim()});
    }
    return out;
  }

  Future<void> saveKnowledge(List<Map<String, dynamic>> list) =>
      save({'knowledge': [for (final e in list) 'Tanya: ${e['q']}\nJawab: ${e['a']}'].join('\n\n')});

  // ---------------------------------------------------------------- balasan cepat

  Future<void> saveReply(Map<String, dynamic> r) async {
    final j = await _api('POST', '/chatbot/$outletId/replies', r);
    final k = replies.indexWhere((x) => x['id'] == j['id']);
    k < 0 ? replies.add(j) : replies[k] = j;
  }

  Future<void> deleteReply(String id) async {
    await _api('DELETE', '/chatbot/replies/$id');
    replies.removeWhere((x) => x['id'] == id);
  }

  // ---------------------------------------------------------------- media

  Map<String, dynamic>? mediaById(Object? id) => media.where((m) => m['id'] == id).firstOrNull;

  Future<void> uploadMedia(String name, String mime, String base64) async {
    media.add(await _api('POST', '/chatbot/$outletId/media', {'name': name, 'data': 'data:$mime;base64,$base64'}));
  }

  Future<void> renameMedia(String id, String name) async {
    final j = await _api('PUT', '/media/$id', {'name': name});
    final k = media.indexWhere((m) => m['id'] == id);
    if (k >= 0) media[k] = j;
  }

  Future<void> deleteMedia(String id) async {
    await _api('DELETE', '/media/$id');
    media.removeWhere((m) => m['id'] == id);
    for (final r in replies) {
      if (r['media_id'] == id) r['media_id'] = null;
    }
  }

  Future<void> copyMedia(String id, int toOutlet) => _api('POST', '/media/$id/copy', {'outlet_id': toOutlet});

  /// Uji jawaban AI dengan bahan yang sama dengan bot sungguhan; biaya dipotong dari saldo AI laundry.
  Future<String> aiTest(String question, String phone) async {
    final j = await _api('POST', '/chatbot/$outletId/ai-test', {'question': question, if (phone.trim().isNotEmpty) 'phone': phone.trim()});
    aiBalance = _int(j['ai_balance'], aiBalance);
    final media = '${j['media'] ?? ''}';
    return [
      '${j['answer'] ?? ''}',
      if (media.isNotEmpty) '📎 Lampiran: $media',
      if (j['handover'] == true) '(Bot akan meneruskan ke admin)',
      'Biaya ${waRp(_int(j['cost']))} · saldo AI ${waRp(aiBalance)}',
    ].join('\n');
  }

  Future<void> resume() async {
    await _api('POST', '/chatbot/$outletId/resume');
    paused = 0;
  }

  // ---------------------------------------------------------------- promo (blast)

  Future<void> loadBlasts() async {
    blasts = _maps((await _api('GET', '/blasts?outlet_id=$outletId'))['blasts']);
  }

  Future<int> audience(bool all) async => _int((await _api('GET', '/blasts/audience?outlet_id=$outletId&audience=${all ? 'all' : 'outlet'}'))['count']);

  Future<void> createBlast(Map<String, dynamic> body) async {
    blasts.insert(0, await _api('POST', '/blasts', body));
  }

  Future<void> cancelBlast(String id) async {
    final j = await _api('POST', '/blasts/$id/cancel');
    final k = blasts.indexWhere((b) => b['id'] == id);
    if (k >= 0) blasts[k] = j;
  }
}

Map<String, dynamic> _in(int i, String v, String ph, {bool multi = false}) =>
    {'type': 'input', 'v': v, 'ph': ph, 'multiline': multi, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
Map<String, dynamic> _btn(String t, int i, {bool primary = false, String file = ''}) =>
    {'type': 'button', 't': t, 'primary': primary, 'file': file, 'after': false, 'i': i};

/// Media Chatbot per cabang (wamedia): foto/PDF untuk Balasan Cepat dan Promo, maks. 10 per cabang.
class WaMediaPage extends PurePage {
  WaMediaPage(super.host, this.cb);
  final ChatbotServer cb;
  static const _add = 'wam-add', _view = 'wam-view', _rename = 'wam-rename', _copy = 'wam-copy', _del = 'wam-del';

  String _name = '', _mime = '', _data = '';
  String? _target;
  int _copyTo = 0;

  @override
  String get title => 'MEDIA CHATBOT';
  @override
  String get back => 'whatsappbot';

  @override
  void opened() => cb.load(force: true);

  Map<String, dynamic>? get _m => cb.mediaById(_target);

  @override
  List<Map<String, dynamic>> items() {
    if (!cb.available) {
      return [
        {'type': 'hint', 't': 'Media disimpan di server per cabang. Masuk dengan akun pemilik dan pastikan cabang ini sudah terdaftar di server.'},
      ];
    }
    final list = cb.media, limit = cb.mediaLimit;
    return [
      if (!planAccess.has('quick', host.now)) {'type': 'hint', 't': planAccess.lockedText('quick')},
      if (cb.note.isNotEmpty) {'type': 'hint', 't': cb.note},
      {'type': 'title', 't': 'Media ${cb.outletName}', 's': '${list.length}/$limit'},
      {'type': 'hint', 't': 'Foto atau PDF untuk Balasan Cepat dan Promo. Foto otomatis dikecilkan (±300 KB), PDF maksimal 2 MB. Maksimal $limit per cabang.'},
      _btn(list.length >= limit ? 'Media penuh ($limit/$limit)' : '+ Tambah Media', -1, primary: true, file: 'wa-media'),
      if (cb.ready && list.isEmpty) {'type': 'hint', 't': 'Belum ada media. Tambahkan daftar harga, brosur promo, atau foto outlet.'},
      for (var k = 0; k < list.length; k++)
        {
          'type': 'entry', 't': '${list[k]['name']}',
          'lines': ['${list[k]['kind'] == 'pdf' ? 'PDF' : 'Foto'} · ${waSize(_int(list[k]['bytes']))}'],
          'badge': '', 'avatar': list[k]['kind'] == 'pdf' ? '📄' : '🖼', 'svg': '', 'color': '', 'amount': '',
          'btns': [
            {'t': 'Lihat', 'on': false, 'i': 1000 + 10 * k},
            {'t': 'Nama', 'on': false, 'i': 1001 + 10 * k},
            {'t': 'Salin', 'on': false, 'i': 1002 + 10 * k},
            {'t': 'Hapus', 'on': false, 'i': 1003 + 10 * k},
          ],
        },
    ];
  }

  @override
  void button(int i) {
    if (i < 1000) return;
    final k = (i - 1000) ~/ 10, act = (i - 1000) % 10;
    if (k >= cb.media.length) return;
    final m = cb.media[k];
    _target = '${m['id']}';
    switch (act) {
      case 0:
        host.openPageSheet(_view);
      case 1:
        _name = '${m['name']}';
        host.openPageSheet(_rename);
      case 2:
        if (cb.otherOutlets.isEmpty) return host.toast('Belum ada cabang lain yang terdaftar di server.');
        _copyTo = 0;
        host.openPageSheet(_copy);
      case 3:
        host.openPageSheet(_del);
    }
  }

  @override
  void file(String inputId, String name, String mime, String data) {
    if (inputId != 'wa-media') return;
    if (!cb.available) return host.toast('Masuk dengan akun pemilik untuk menyimpan media di server.');
    if (!planAccess.has('quick', host.now)) return host.toast(planAccess.lockedText('quick'));
    if (cb.media.length >= cb.mediaLimit) return host.toast('Media cabang ini sudah ${cb.mediaLimit}. Hapus yang tidak dipakai dulu.');
    final bytes = data.length * 3 ~/ 4;
    if (mime == 'application/pdf') {
      if (bytes > 2 * 1024 * 1024) return host.toast('PDF maksimal 2 MB.');
    } else if (!RegExp(r'^image/(png|jpeg|webp)$').hasMatch(mime)) {
      return host.toast('Pilih foto JPG/PNG/WebP atau PDF.');
    } else if (bytes > 8 * 1024 * 1024) {
      return host.toast('Foto maksimal 8 MB.');
    }
    final dot = name.lastIndexOf('.');
    _name = (dot > 0 ? name.substring(0, dot) : name).replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (_name.length > 80) _name = _name.substring(0, 80);
    _mime = mime;
    _data = data;
    host.openPageSheet(_add);
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id == _add) {
      return [
        {'type': 'title', 't': 'Simpan Media', 's': cb.outletName},
        if (_mime.startsWith('image/')) pickedImageItem('data:$_mime;base64,$_data') else {'type': 'hint', 't': '📄 Dokumen PDF · ${waSize(_data.length * 3 ~/ 4)}'},
        {'type': 'label', 't': 'Nama media'},
        _in(0, _name, 'Contoh: Daftar harga kiloan'),
        _btn(cb.busy ? 'Mengunggah…' : 'Simpan', 0, primary: true),
        _btn('Batal', 1),
      ];
    }
    final m = _m;
    if (m == null) return null;
    switch (id) {
      case _view:
        return [
          {'type': 'title', 't': '${m['name']}', 's': '${m['kind'] == 'pdf' ? 'PDF' : 'Foto'} · ${waSize(_int(m['bytes']))}'},
          if (m['kind'] == 'pdf') {'type': 'hint', 't': 'Dokumen PDF dikirim sebagai berkas ke pelanggan.'} else {'type': 'image', 'src': '${m['preview_url'] ?? ''}', 'svg': '', 'mark': '🖼', 't': '', 's': '', 'w': 260},
          _btn('Tutup', 0, primary: true),
        ];
      case _rename:
        return [
          {'type': 'title', 't': 'Ganti Nama Media', 's': ''},
          _in(0, _name, 'Nama media'),
          _btn('Simpan', 0, primary: true),
          _btn('Batal', 1),
        ];
      case _copy:
        final to = cb.otherOutlets;
        return [
          {'type': 'title', 't': 'Salin ke Cabang', 's': '${m['name']}'},
          {'type': 'hint', 't': 'Berkas disalin ke cabang tujuan (terpakai 1 dari ${cb.mediaLimit} slot media di sana). Hapus di satu cabang tidak menghapus salinannya.'},
          {'type': 'select', 'options': [for (final o in to) o.name], 'index': _copyTo.clamp(0, to.isEmpty ? 0 : to.length - 1), 'i': 0},
          _btn('Salin', 0, primary: true),
          _btn('Batal', 1),
        ];
      case _del:
        return [
          {'type': 'title', 't': 'Hapus media?', 's': '${m['name']}'},
          {'type': 'hint', 't': 'Berkas di server ikut terhapus. Balasan cepat yang memakai media ini tetap ada, tanpa lampiran.'},
          _btn('Hapus', 0, primary: true),
          _btn('Batal', 1),
        ];
    }
    return null;
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (kind == 'input') {
      if (id == _copy) {
        _copyTo = value is int ? value : int.tryParse('$value') ?? 0;
        host.refresh();
      } else {
        _name = '${value ?? ''}';
      }
      return;
    }
    if (kind != 'button') return;
    if (index != 0 || id == _view) return host.closePageSheet(id);
    final m = _m;
    switch (id) {
      case _add:
        final name = _name.trim();
        if (name.isEmpty) return host.toast('Isi nama media.');
        cb.run(() => cb.uploadMedia(name, _mime, _data), ok: 'Media tersimpan').then((done) {
          if (!done) return;
          _data = '';
          host.closePageSheet(_add);
        });
      case _rename:
        if (m == null) return;
        final name = _name.trim();
        if (name.isEmpty) return host.toast('Isi nama media.');
        cb.run(() => cb.renameMedia('${m['id']}', name), ok: 'Nama diganti').then((done) {
          if (done) host.closePageSheet(_rename);
        });
      case _copy:
        final to = cb.otherOutlets;
        if (m == null || to.isEmpty) return;
        final target = to[_copyTo.clamp(0, to.length - 1)];
        cb.run(() => cb.copyMedia('${m['id']}', target.id), ok: 'Disalin ke ${target.name}').then((done) {
          if (done) host.closePageSheet(_copy);
        });
      case _del:
        host.closePageSheet(_del);
        if (m != null) cb.run(() => cb.deleteMedia('${m['id']}'), ok: 'Media dihapus');
    }
  }
}

/// WhatsApp Blast / Promo (blast191). Mode server: dikirim bergilir oleh mesin WhatsApp (paket Platinum),
/// penerima diambil server dari data pelanggan tanpa yang membalas STOP. Tanpa server: draf seperti sebelumnya.
class BlastPage extends TemplatePage {
  // ignore: use_super_parameters
  BlastPage(PureHost host, this.cb, this.wa) : super(host, 'blast191', backTo: 'whatsappbot');
  final ChatbotServer cb;
  final WaLink wa;

  String _name = '', _body = '';
  int _media = 0;
  bool _all = false, _consent = false;
  int? _count;

  bool get _server => cb.available;

  @override
  void opened() {
    if (!_server) return super.opened();
    cb.load(force: true).then((_) async {
      try {
        await cb.loadBlasts();
        _count = await cb.audience(_all);
      } catch (_) {}
      host.refresh();
    });
    wa.sync();
  }

  /// Nomor WhatsApp cabang aktif yang sudah terhubung (pengirim promo).
  String? get _device {
    for (final d in wa.store.devices) {
      if (d.registered && d.status == 'connected' && d.serverOutletId == cb.outletId) return d.id;
    }
    return null;
  }

  static const _labels = {
    'creating': 'Disiapkan', 'queued': 'Antre', 'scheduled': 'Terjadwal', 'running': 'Mengirim', 'paused': 'Dijeda',
    'done': 'Selesai', 'completed': 'Selesai', 'cancelled': 'Dibatalkan', 'failed': 'Gagal',
  };

  @override
  List<Map<String, dynamic>> items() {
    if (!_server) return super.items();
    final media = cb.media;
    return [
      if (!planAccess.has('blast', host.now)) {'type': 'hint', 't': planAccess.lockedText('blast')},
      if (cb.note.isNotEmpty) {'type': 'hint', 't': cb.note},
      if (_device == null) {'type': 'hint', 't': 'Hubungkan dulu nomor WhatsApp ${cb.outletName} di tab Perangkat.'},
      {'type': 'title', 't': 'Promo baru', 's': cb.outletName},
      {'type': 'label', 't': 'Nama kampanye'},
      _in(0, _name, 'Contoh: Promo Oktober'),
      {'type': 'label', 't': 'Pesan promo (pakai {nama} untuk nama pelanggan)'},
      _in(1, _body, 'Halo Kak {nama}, ada diskon 20% untuk cuci bed cover minggu ini!', multi: true),
      {'type': 'label', 't': 'Lampiran dari Media'},
      {'type': 'select', 'options': ['Tanpa lampiran', for (final m in media) '${m['name']}'], 'index': _media.clamp(0, media.length), 'i': 2},
      {'type': 'label', 't': 'Penerima'},
      {'type': 'select', 'options': const ['Pelanggan cabang ini', 'Semua pelanggan usaha'], 'index': _all ? 1 : 0, 'i': 3},
      {'type': 'hint', 't': _count == null ? 'Menghitung penerima…' : 'Perkiraan penerima: $_count pelanggan bernomor WhatsApp (tanpa yang membalas STOP).'},
      {'type': 'hint', 't': 'Kalimat "Balas STOP bila tidak ingin menerima promo." ditambahkan otomatis. Dikirim bergilir pukul 08.00–20.00 supaya nomor aman.'},
      {'type': 'toggle', 't': 'Penerima sudah setuju menerima promo', 's': '', 'on': _consent, 'i': 0},
      _btn(cb.busy ? 'Mengirim…' : 'Kirim Promo', 0, primary: true),
      if (cb.blasts.isNotEmpty) {'type': 'title', 't': 'Riwayat promo'},
      for (var k = 0; k < cb.blasts.length; k++)
        {
          'type': 'entry', 't': '${cb.blasts[k]['name']}',
          'lines': [
            '${_labels[cb.blasts[k]['status']] ?? cb.blasts[k]['status']} · terkirim ${_int(cb.blasts[k]['sent'])}/${_int(cb.blasts[k]['total'])}'
                '${_int(cb.blasts[k]['failed']) > 0 ? ' · gagal ${_int(cb.blasts[k]['failed'])}' : ''}',
            if ('${cb.blasts[k]['reason'] ?? ''}'.isNotEmpty) '${cb.blasts[k]['reason']}',
          ],
          'badge': '', 'avatar': '📣', 'svg': '', 'color': '', 'amount': '',
          'btns': [
            if (const {'creating', 'queued', 'scheduled', 'running', 'paused'}.contains(cb.blasts[k]['status'])) {'t': 'Batalkan', 'on': false, 'i': 1000 + k},
          ],
        },
    ];
  }

  @override
  void input(int i, Object value) {
    if (!_server) return super.input(i, value);
    switch (i) {
      case 0:
        _name = '$value';
      case 1:
        _body = '$value';
      case 2:
        _media = value is int ? value : int.tryParse('$value') ?? 0;
        host.refresh();
      case 3:
        _all = (value is int ? value : int.tryParse('$value') ?? 0) == 1;
        _count = null;
        host.refresh();
        cb.audience(_all).then((n) {
          _count = n;
          host.refresh();
        }).catchError((_) {});
    }
  }

  @override
  void toggle(int i) {
    if (!_server) return super.toggle(i);
    _consent = !_consent;
    host.refresh();
  }

  @override
  void button(int i) {
    if (!_server) {
      if (i < 0) return;
      if (!planAccess.has('blast', host.now)) return host.toast(planAccess.lockedText('blast'));
      return host.toast('Masuk dengan akun pemilik untuk mengirim promo lewat server.');
    }
    if (i >= 1000) {
      final k = i - 1000;
      if (k < cb.blasts.length) cb.run(() => cb.cancelBlast('${cb.blasts[k]['id']}'), ok: 'Promo dibatalkan');
      return;
    }
    if (i != 0) return;
    if (!planAccess.has('blast', host.now)) return host.toast(planAccess.lockedText('blast'));
    final device = _device;
    if (device == null) return host.toast('Hubungkan dulu nomor WhatsApp cabang ini.');
    if (_name.trim().isEmpty || _body.trim().isEmpty) return host.toast('Isi nama kampanye dan pesan promo.');
    if (!_consent) return host.toast('Pastikan penerima sudah setuju menerima promo.');
    final String? media = _media > 0 && _media <= cb.media.length ? '${cb.media[_media - 1]['id']}' : null;
    cb.run(() => cb.createBlast({
          'device_id': device, 'name': _name.trim(), 'body': _body.trim(), 'media_id': ?media, 'audience': _all ? 'all' : 'outlet',
        }), ok: 'Promo dikirim bergilir').then((done) {
      if (!done) return;
      _name = '';
      _body = '';
      _media = 0;
      _consent = false;
    });
  }
}

/// Id baru untuk balasan cepat di server.
String newReplyId() => newWaId();
