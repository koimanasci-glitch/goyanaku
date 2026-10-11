// WhatsApp & Chatbot (v191/v195): pengaturan tersimpan per outlet di `goyana-chat191:<idOutlet>` (sama dengan Hibrida).
// Sejak 11 Okt 2026: bila pemilik masuk akun dan cabang terdaftar di server, Balasan Cepat, pengaturan Chatbot, pengetahuan AI,
// pesan otomatis, Media, dan Promo disimpan di server (wa_chatbot.dart) dan dipakai bot WhatsApp sungguhan.
import 'dart:convert';

import '../core/money.dart';
import '../whatsapp/device_store.dart' show WaFailure;
import 'access.dart';
import 'pages.dart';
import 'wa_chatbot.dart';
import 'wa_devices_page.dart';
import 'wa_link.dart';

String _chatKey(PureHost host) => 'goyana-chat191:${host.business.activeOutlet}';

Future<Map<String, dynamic>> loadChat(PureHost host) async {
  final st = <String, dynamic>{
    'rules': <dynamic>[],
    'ai': {'enabled': false, 'name': 'Asisten Laundry', 'instructions': 'Jawab dengan ramah dan singkat. Gunakan data aplikasi; jangan mengarang harga atau status.', 'knowledge': '', 'prices': true, 'status': true, 'image': ''},
    'campaigns': <dynamic>[],
    'chatImage': '',
  };
  try {
    final v = jsonDecode(await host.kv.get(_chatKey(host)) ?? '{}');
    if (v is Map) st.addAll(Map<String, dynamic>.from(v));
  } catch (_) {}
  if (st['rules'] is! List) st['rules'] = <dynamic>[];
  if (st['ai'] is! Map) st['ai'] = <String, dynamic>{};
  return st;
}

Future<bool> saveChat(PureHost host, Map<String, dynamic> st) => host.kv.set(_chatKey(host), jsonEncode(st));

const _serverNote = 'Pengaturan tersimpan di perangkat ini. Pengiriman WhatsApp dan AI belum terhubung ke server.';
bool _gate(PureHost host, String feature) {
  if (planAccess.has(feature, host.now)) return true;
  host.toast(planAccess.lockedText(feature));
  return false;
}

/// Balasan Cepat & Trigger (triggers191): daftar aturan + formulir di halaman.
class TriggersPage extends PurePage {
  TriggersPage(super.host, [this.cb]);
  final ChatbotServer? cb;
  bool get _server => cb?.available ?? false;
  int mediaIndex = 0;
  Map<String, dynamic> st = {'rules': <dynamic>[]};
  bool form = false;
  String? editing;
  String name = '', keys = '', reply = '';
  int mode = 0;
  bool enabled = true;
  @override
  String get title => 'BALASAN CEPAT & TRIGGER';
  @override
  String get back => 'whatsappbot';
  List<Map<String, dynamic>> get rules =>
      _server ? cb!.replies : (st['rules'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  @override
  void opened() {
    form = false;
    if (_server) cb!.load(force: true);
    loadChat(host).then((v) {
      st = v;
      host.refresh();
    });
  }

  @override
  List<Map<String, dynamic>> items() {
    Map<String, dynamic> inp(String v, int i, {bool multi = false}) =>
        {'type': 'input', 'v': v, 'ph': '', 'multiline': multi, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    final r = rules, base = form ? 3 : 1;
    final server = _server, media = server ? cb!.media : const <Map<String, dynamic>>[];
    final local = (st['rules'] as List).whereType<Map>().length;
    return [
      {'type': 'hint', 't': server ? 'Tersimpan di server untuk ${cb!.outletName} · langsung dipakai bot WhatsApp.' : _serverNote},
      if (server && cb!.note.isNotEmpty) {'type': 'hint', 't': cb!.note},
      {'type': 'button', 't': '＋ Tambah Balasan', 'primary': true, 'file': '', 'after': false, 'i': 0},
      if (form) ...[
        {'type': 'label', 't': 'Nama balasan'},
        inp(name, 0),
        {'type': 'label', 't': 'Kata pemicu (pisahkan dengan koma)'},
        inp(keys, 1),
        {'type': 'label', 't': 'Cara mencocokkan'},
        {'type': 'select', 'options': const ['Mengandung kata/frasa', 'Pesan sama persis'], 'index': mode, 'i': 2},
        {'type': 'label', 't': 'Isi balasan'},
        inp(reply, 3, multi: true),
        if (server) ...[
          {'type': 'label', 't': 'Lampiran dari Media (foto / PDF)'},
          {'type': 'select', 'options': ['Tanpa lampiran', for (final m in media) '${m['name']}'], 'index': mediaIndex.clamp(0, media.length), 'i': 4},
          if (media.isEmpty) {'type': 'hint', 't': 'Belum ada media. Tambahkan di WhatsApp & Chatbot › Media.'},
        ] else ...[
          {'type': 'label', 't': 'Gambar balasan / promo'},
          {'type': 'button', 't': 'Pilih Gambar', 'primary': false, 'file': 'rule-image191', 'i': -1},
          if (image.isNotEmpty) pickedImageItem(image),
        ],
        {'type': 'toggle', 't': 'Aktif', 's': '', 'on': enabled, 'i': 0},
        {'type': 'buttons', 'options': [
          {'t': 'Simpan', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1},
          {'t': 'Batal', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 2},
        ]},
      ],
      if (r.isEmpty) {'type': 'hint', 't': 'Belum ada balasan. Tambahkan kata pemicu dan jawabannya.'},
      if (server && r.isEmpty && local > 0) {'type': 'button', 't': 'Pindahkan $local balasan dari HP ke server', 'primary': false, 'file': '', 'after': false, 'i': 999},
      for (var k = 0; k < r.length; k++)
        {
          'type': 'entry', 't': '${r[k]['name']}',
          'lines': [
            '${r[k]['keys']} · ${r[k]['mode'] == 'exact' ? 'Pesan sama persis' : 'Mengandung kata/frasa'}',
            '${r[k]['reply']}',
            if (server)
              if (cb!.mediaById(r[k]['media_id']) case final m?) '📎 ${m['name']}',
          ],
          'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
          'btns': [
            {'t': 'Edit', 'on': false, 'i': base + 3 * k},
            {'t': r[k]['enabled'] == false ? 'Nonaktif' : 'Aktif', 'on': false, 'i': base + 3 * k + 1},
            {'t': 'Hapus', 'on': false, 'i': base + 3 * k + 2},
          ],
        },
    ];
  }

  void _form(Map<String, dynamic>? r) {
    form = true;
    editing = r == null ? null : '${r['id']}';
    name = '${r?['name'] ?? ''}';
    keys = '${r?['keys'] ?? ''}';
    reply = '${r?['reply'] ?? ''}';
    image = '${r?['image'] ?? ''}';
    mode = r?['mode'] == 'exact' ? 1 : 0;
    enabled = r?['enabled'] != false;
    final media = _server ? cb!.media : const <Map<String, dynamic>>[];
    final at = media.indexWhere((m) => m['id'] == r?['media_id']);
    mediaIndex = at < 0 ? 0 : at + 1;
    host.refresh();
  }

  @override
  void input(int i, Object value) {
    if (i == 2) {
      mode = value is int ? value : 0;
      return host.refresh();
    }
    if (i == 4) {
      mediaIndex = value is int ? value : int.tryParse('$value') ?? 0;
      return host.refresh();
    }
    if (i == 0) name = '$value';
    if (i == 1) keys = '$value';
    if (i == 3) reply = '$value';
  }

  @override
  void toggle(int i) {
    enabled = !enabled;
    host.refresh();
  }

  String image = '';
  @override
  void file(String inputId, String name, String mime, String data) {
    final err = pickedImageError(mime, data);
    if (err != null) return host.toast(err);
    image = 'data:$mime;base64,$data';
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 0) return _form(null);
    if (_server) return _triggersServer(this, i);
    final list = st['rules'] as List;
    if (form && i == 2) {
      form = false;
      return host.refresh();
    }
    if (form && i == 1) {
      if (!_gate(host, 'quick')) return;
      final ks = keys.split(',').map((x) => x.trim().toLowerCase()).where((x) => x.isNotEmpty).toList();
      if (name.trim().isEmpty || ks.isEmpty || reply.trim().isEmpty) return host.toast('Isi nama, pemicu dan teks atau gambar.');
      final entry = <String, dynamic>{'id': editing ?? host.now.microsecondsSinceEpoch.toRadixString(36), 'name': name.trim(), 'keys': ks.join(', '), 'reply': reply.trim(), 'image': image, 'mode': mode == 1 ? 'exact' : 'contains', 'enabled': enabled};
      final k = list.indexWhere((x) => x is Map && '${x['id']}' == entry['id']);
      k < 0 ? list.add(entry) : list[k] = entry;
      if (!await saveChat(host, st)) return host.toast('Penyimpanan penuh. Kurangi ukuran gambar.');
      form = false;
      host.toast('Balasan tersimpan');
      return host.refresh();
    }
    final base = form ? 3 : 1, k = (i - base) ~/ 3, r = rules;
    if (i < base || k >= r.length) return;
    switch ((i - base) % 3) {
      case 0:
        return _form(r[k]);
      case 1:
        if (!_gate(host, 'quick')) return;
        (list[k] as Map)['enabled'] = (list[k] as Map)['enabled'] == false;
      default:
        list.removeAt(k);
    }
    await saveChat(host, st);
    host.refresh();
  }
}

/// Balasan Cepat di server: simpan / aktif-nonaktif / hapus langsung ke server cabang aktif.
void _triggersServer(TriggersPage p, int i) {
  final host = p.host;
  final c = p.cb!;
  if (i == 999) {
    if (!_gate(host, 'quick')) return;
    final list = (p.st['rules'] as List).whereType<Map>().toList();
    c.run(() async {
      for (final x in list) {
        await c.saveReply({'id': newReplyId(), 'name': '${x['name']}', 'keys': '${x['keys']}', 'mode': x['mode'] == 'exact' ? 'exact' : 'contains',
          'reply': '${x['reply']}', 'enabled': x['enabled'] != false});
      }
    }, ok: 'Balasan dipindahkan ke server. Gambar dari HP tidak ikut — pilih ulang dari Media.');
    return;
  }
  if (p.form && i == 2) {
    p.form = false;
    return host.refresh();
  }
  if (p.form && i == 1) {
    if (!_gate(host, 'quick')) return;
    final ks = p.keys.split(',').map((x) => x.trim().toLowerCase()).where((x) => x.isNotEmpty).toList();
    final media = p.mediaIndex > 0 && p.mediaIndex <= c.media.length ? '${c.media[p.mediaIndex - 1]['id']}' : null;
    if (p.name.trim().isEmpty || ks.isEmpty || (p.reply.trim().isEmpty && media == null)) return host.toast('Isi nama, pemicu, dan teks atau lampiran.');
    c.run(() => c.saveReply({'id': p.editing ?? newReplyId(), 'name': p.name.trim(), 'keys': ks.join(', '), 'mode': p.mode == 1 ? 'exact' : 'contains',
          'reply': p.reply.trim(), 'media_id': media, 'enabled': p.enabled}), ok: 'Balasan tersimpan').then((done) {
      if (!done) return;
      p.form = false;
      host.refresh();
    });
    return;
  }
  final base = p.form ? 3 : 1, k = (i - base) ~/ 3, r = p.rules;
  if (i < base || k >= r.length) return;
  final x = r[k];
  switch ((i - base) % 3) {
    case 0:
      return p._form(x);
    case 1:
      if (!_gate(host, 'quick')) return;
      c.run(() => c.saveReply({...x, 'enabled': x['enabled'] == false}));
    default:
      c.run(() => c.deleteReply('${x['id']}'), ok: 'Balasan dihapus');
  }
}

/// Pengaturan Chatbot AI (ai191): tersimpan di state chat outlet; jawaban AI sungguhan menunggu server.
class AiPage extends TemplatePage {
  // ignore: use_super_parameters
  AiPage(PureHost host, [this.cb]) : super(host, 'ai191', backTo: 'whatsappbot');
  final ChatbotServer? cb;
  Map<String, dynamic> st = {};
  Map<String, dynamic> get ai => ((st['ai'] ??= <String, dynamic>{}) as Map).cast<String, dynamic>();
  static const _in = ['name', 'instructions', 'knowledge'];
  static const _tg = ['enabled', 'prices', 'status'];

  @override
  void opened() {
    loadChat(host).then((v) async {
      st = v;
      final c = cb;
      if (c != null && c.available) {
        // Mode server: isian diambil dari pengaturan Chatbot cabang aktif di server.
        await c.load(force: true);
        if (c.ready) {
          ai
            ..['enabled'] = c.flag('ai_enabled')
            ..['prices'] = c.flag('ai_prices')
            ..['status'] = c.flag('ai_status')
            ..['name'] = '${c.settings['ai_name'] ?? ''}'
            ..['instructions'] = '${c.settings['ai_instructions'] ?? ''}'
            ..['knowledge'] = '${c.settings['knowledge'] ?? ''}';
        }
      }
      host.refresh();
    });
  }

  /// Harga layanan aktif, sama dengan `prices()` di HTML.
  String get knowledge => [
        for (final s in host.business.services)
          for (final e in s.prices.entries)
            if (s.enabledFor(e.key) && e.value > 0) '${s.name} · ${e.key}: ${rp(e.value)}/${s.unit}',
      ].join(' ');

  @override
  String inputValue(int i) => i < 3 ? '${ai[_in[i]] ?? super.inputValue(i)}' : _test[i] ?? '';
  final Map<int, String> _test = {};
  @override
  void setInput(int i, String v) => i < 3 ? ai[_in[i]] = v : _test[i] = v;
  @override
  void input(int i, Object value) => setInput(i, '$value');
  @override
  bool toggleValue(int i) => ai[_tg[i.clamp(0, 2)]] is bool ? ai[_tg[i.clamp(0, 2)]] as bool : super.toggleValue(i);
  @override
  void toggle(int i) {
    ai[_tg[i.clamp(0, 2)]] = !toggleValue(i);
    host.refresh();
  }

  @override
  List<Map<String, dynamic>> items() {
    final out = super.items();
    final k = out.indexWhere((e) => e['t'] == 'Pengetahuan aplikasi');
    if (k >= 0 && k + 2 < out.length) out[k + 2]['t'] = knowledge;
    if (_answer.isNotEmpty) out.add({'type': 'hint', 't': _answer});
    return out;
  }

  String _answer = '';
  static String _phone(Object? p) => waNumber(p);

  /// Jawaban uji dari data aplikasi (HTML v191 answer()): status pesanan per nomor, atau daftar harga.
  String answer(String message, String sender) {
    if (!planAccess.has('ai', host.now)) return 'Fitur AI membutuhkan paket Gold.';
    if (!toggleValue(0)) return 'Chatbot AI belum diaktifkan.';
    final m = message.toLowerCase();
    if (RegExp('status|cucian|pesanan').hasMatch(m) && toggleValue(2)) {
      final p = _phone(sender);
      if (p.isEmpty) return 'Nomor WhatsApp pelanggan diperlukan untuk memeriksa pesanan.';
      const statuses = {
        'antrian': 'Antrian', 'cuci': 'Sedang dicuci', 'kering': 'Sedang dikeringkan', 'setrika': 'Sedang disetrika', 'packing': 'Dalam proses', 'selesaiproses': 'Dalam proses', 'siap': 'Siap diambil',
        'telat': 'Siap diambil', 'diantar': 'Sedang diantar', 'diambil': 'Sudah diambil', 'batal': 'Dibatalkan', 'jemput': 'Menunggu penjemputan',
      };
      final b = host.business;
      final found = [
        for (final o in b.orders)
          if ((b.activeOutlet.isEmpty || o.outlet == b.activeOutlet) && _phone(o.phone.isNotEmpty ? o.phone : b.customerByName(o.name)?.phone) == p)
            '${o.id}: ${statuses[o.status] ?? 'Status belum dikenali'}',
      ];
      return found.isEmpty ? 'Tidak ada pesanan untuk nomor ini pada outlet aktif.' : found.join('\n');
    }
    if (RegExp('harga|tarif|layanan').hasMatch(m) && toggleValue(1)) {
      final list = [
        for (final s in host.business.services)
          for (final e in s.prices.entries)
            if (s.enabledFor(e.key) && e.value > 0) '${s.name} · ${e.key}: ${rp(e.value)}/${s.unit}',
      ];
      return list.isEmpty ? 'Belum ada harga layanan aktif. Hubungi kasir.' : list.join('\n');
    }
    // Pengetahuan dari laundry (tanya-jawab pemilik): cocokkan kata penting topik dengan pertanyaan.
    for (final e in (ai['kb'] as List? ?? const []).whereType<Map>()) {
      final words = '${e['q'] ?? ''}'.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 3);
      if (words.isNotEmpty && words.any(m.contains)) return '${e['a'] ?? ''}';
    }
    return 'Pertanyaan ini membutuhkan koneksi AI. Pengetahuan tambahan sudah tersimpan, tetapi layanan AI belum terhubung.';
  }

  @override
  void button(int i) async {
    if (i == 2) {
      final c = cb;
      if (c != null && c.ready) {
        if (!_gate(host, 'ai')) return;
        final q = (_test[5] ?? '').trim();
        if (q.isEmpty) return host.toast('Tulis pertanyaan pelanggan untuk diuji.');
        _answer = 'Menunggu jawaban AI…';
        host.refresh();
        try {
          _answer = await c.aiTest(q, _test[4] ?? '');
        } on WaFailure catch (e) {
          _answer = e.message;
        } catch (_) {
          _answer = 'AI belum bisa dihubungi. Coba lagi sebentar.';
        }
        return host.refresh();
      }
      _answer = answer(_test[5] ?? '', _test[4] ?? '');
      return host.refresh();
    }
    if (!_gate(host, 'ai')) return;
    final c = cb;
    if (c != null && c.ready) {
      c.run(() => c.save({
            'ai_enabled': toggleValue(0), 'ai_prices': toggleValue(1), 'ai_status': toggleValue(2),
            'ai_name': '${ai['name'] ?? ''}'.trim(), 'ai_instructions': '${ai['instructions'] ?? ''}'.trim(), 'knowledge': '${ai['knowledge'] ?? ''}'.trim(),
          }), ok: 'Pengaturan AI tersimpan di server');
      return;
    }
    if (!await saveChat(host, st)) return host.toast('Penyimpanan penuh. Kurangi ukuran gambar.');
    host.toast('Pengaturan AI tersimpan');
    host.refresh();
  }
}

/// WhatsApp & Chatbot (permintaan Paduka 10 Oktober 2026): satu halaman dengan tab supaya tidak membingungkan.
/// Sakelar tetap disimpan di tempat yang sama (setelan `tpl.whatsappbot`), jadi fitur lain yang membacanya tidak berubah.
/// Tab Chatbot AI punya "Pengetahuan dari laundry": tanya-jawab yang ditulis pemilik untuk bahan balasan AI.
class WaHubPage extends TemplatePage {
  // ignore: use_super_parameters
  WaHubPage(PureHost host, this.wa, this.cb) : super(host, 'whatsappbot');
  final WaLink wa;
  final ChatbotServer cb;
  int tab = 0;
  Map<String, dynamic> st = {};
  static const _tabs = [['📱', 'Perangkat'], ['⚡', 'Otomatis'], ['🤖', 'Chatbot AI'], ['💬', 'Balas Cepat'], ['🖼', 'Media'], ['📣', 'Promo']];

  /// Sakelar yang disimpan di server bila mode server: nomor sakelar → kunci pengaturan server & fitur paket.
  static const _serverToggles = {
    0: ('auto_nota', 'messages'), 1: ('auto_ready', 'messages'), 2: ('auto_late', 'messages'),
    3: ('ai_enabled', 'ai'), 4: ('quick_enabled', 'quick'), 5: ('ai_status', 'ai'), 7: ('ai_prices', 'ai'),
  };

  @override
  bool toggleValue(int i) {
    final key = _serverToggles[i];
    if (cb.ready && key != null) return cb.flag(key.$1);
    return super.toggleValue(i);
  }

  @override
  void toggle(int i) {
    final key = _serverToggles[i];
    if (!cb.ready || key == null) return super.toggle(i);
    final on = !cb.flag(key.$1);
    if (on && !_gate(host, key.$2)) return;
    cb.run(() => cb.save({key.$1: on}));
  }
  static const _kbSheet = 'wa-kb';
  int? _kbEdit;
  String _kbQ = '', _kbA = '';

  @override
  void opened() {
    loadChat(host).then((v) {
      st = v;
      host.refresh();
    });
    wa.sync();
    cb.load(force: true);
  }

  Map<String, dynamic> get _ai => ((st['ai'] ??= <String, dynamic>{}) as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> get kb => cb.ready ? cb.knowledge : [for (final e in (_ai['kb'] as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];

  Map<String, dynamic> _tg(int i, String t, String s) => {'type': 'toggle', 't': t, 's': s, 'on': toggleValue(i), 'i': i};
  Map<String, dynamic> _btn(String t, int i, {bool primary = false, String file = ''}) =>
      {'type': 'button', 't': t, 'primary': primary, 'file': file, 'after': false, 'i': i};

  @override
  List<Map<String, dynamic>> items() {
    final out = <Map<String, dynamic>>[
      {'type': 'chips', 'options': [for (var k = 0; k < _tabs.length; k++) {'t': _tabs[k][1], 'ic': _tabs[k][0], 'on': tab == k, 'i': 900 + k}]},
    ];
    final server = cb.ready;
    if (cb.available && cb.note.isNotEmpty) out.add({'type': 'hint', 't': cb.note});
    switch (tab) {
      case 0:
        final devs = wa.store.devices;
        final on = devs.where((d) => d.status == 'connected').length;
        out
          ..add({'type': 'title', 't': 'Nomor WhatsApp outlet'})
          ..add({'type': 'hint', 't': 'Nomor ini yang mengirim pesan otomatis dan membalas chat pelanggan. Satu nomor untuk satu cabang.'})
          ..add({
            'type': 'entry', 't': devs.isEmpty ? 'Belum ada nomor WhatsApp' : '${devs.length} nomor · $on terhubung',
            'lines': [devs.isEmpty ? 'Tambahkan nomor lalu hubungkan lewat Scan QR atau Kode WhatsApp.' : devs.map((d) => '+${d.phone}').join(' · ')],
            'badge': on > 0 ? 'Terhubung' : '', 'avatar': '📱', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[],
          })
          ..add(_btn(devs.isEmpty ? '+ Tambah Nomor WhatsApp' : 'Kelola Perangkat WhatsApp', 3, primary: true));
        if (wa.note.isNotEmpty) out.add({'type': 'hint', 't': wa.note});
      case 1:
        out
          ..add({'type': 'title', 't': 'Pesan otomatis ke pelanggan'})
          ..add({'type': 'hint', 't': 'Dikirim dari nomor outlet. Hanya pesan penting, tidak ada pesan harian.'})
          ..add(_tg(0, 'Pesanan diterima', 'Konfirmasi + nota elektronik saat transaksi dibuat'))
          ..add(_tg(1, 'Siap ambil', 'Pelanggan dikabari begitu cucian Siap Ambil'))
          ..add(_tg(2, 'Pengingat telat ambil', 'Sekali, saat cucian ${server ? cb.settings['late_days'] ?? 3 : 7} hari belum diambil'));
        if (server) {
          out.add({'type': 'hint', 't': 'Tersimpan di server untuk ${cb.outletName}. Tidak dikirim pukul ${cb.settings['quiet_from'] ?? '21:00'}–${cb.settings['quiet_until'] ?? '07:00'}; '
              'pesanan diterima berisi link nota digital. Mulai paket Gold.'});
        }
      case 2:
        out
          ..add(_tg(3, 'Chatbot AI 24 jam', 'Membalas pertanyaan pelanggan dari nomor outlet'))
          ..add({'type': 'title', 't': 'Yang boleh dijawab dari data aplikasi'})
          ..add({'type': 'hint', 't': 'Bot hanya membaca data, tidak bisa mengubah transaksi.'})
          ..add(_tg(5, server ? 'Status cucian & tagihan' : 'Status cucian', 'Sesuai nomor WhatsApp pelanggan'));
        if (!server) {
          out
            ..add(_tg(6, 'Total tagihan', ''))
            ..add(_tg(7, 'Harga & layanan', 'Mengikuti daftar harga aktif'))
            ..add(_tg(8, 'Jam buka & alamat outlet', ''))
            ..add(_tg(9, 'Permintaan antar-jemput', ''))
            ..add(_tg(10, 'Teruskan ke admin (CS manusia)', 'Bila bot tidak yakin atau pelanggan minta bicara dengan orang'));
        } else {
          out
            ..add(_tg(7, 'Harga & layanan', 'Hanya dari daftar harga aktif; AI tidak mengarang harga'))
            ..add({'type': 'hint', 't': 'Jam buka, alamat, antar-jemput, dan teruskan ke admin selalu aktif. Saldo AI: ${waRp(cb.aiBalance)}.'});
          if (cb.paused > 0) {
            out.add({
              'type': 'entry', 't': '${cb.paused} chat sedang ditangani admin', 'lines': ['Bot diam setelah Anda membalas dari HP (atau #stop). Ketik #bot di chat untuk melanjutkan.'],
              'badge': '', 'avatar': '🙋', 'svg': '', 'color': '', 'amount': '', 'btns': [{'t': 'Lanjutkan bot', 'on': false, 'i': 21}],
            });
          }
        }
        out
          ..add({'type': 'title', 't': 'Pengetahuan dari laundry', 's': '${kb.length} catatan'})
          ..add({'type': 'hint', 't': 'Tulis info yang sering ditanyakan pelanggan (aturan, promo, area antar, cara bayar). AI memakai ini selain data aplikasi.'});
        final list = kb;
        for (var k = 0; k < list.length; k++) {
          out.add({
            'type': 'entry', 't': '${list[k]['q'] ?? ''}', 'lines': ['${list[k]['a'] ?? ''}'],
            'badge': '', 'avatar': '📝', 'svg': '', 'color': '', 'amount': '',
            'btns': [{'t': 'Edit', 'on': false, 'i': 1000 + 10 * k}, {'t': 'Hapus', 'on': false, 'i': 1001 + 10 * k}],
          });
        }
        out
          ..add(_btn('+ Tambah Pengetahuan', 20, primary: list.isEmpty))
          ..add(_btn('Pengaturan Chatbot AI ›', 1));
      case 3:
        out
          ..add(_tg(4, 'Balas cepat & trigger', 'Jawaban template berdasarkan kata kunci, tanpa AI'))
          ..add(_btn('Atur Balas Cepat & Trigger ›', 4, primary: true));
        if (server) {
          out
            ..add({'type': 'hint', 't': '${cb.replies.length} balasan tersimpan di server. Foto/PDF balasan dipilih dari Media.'})
            ..add(_btn('Kelola Media (${cb.media.length}/${cb.mediaLimit}) ›', 22));
        } else {
          out
            ..add({'type': 'label', 't': 'Gambar default balasan / promo'})
            ..add(_btn('Pilih Gambar', -1, file: 'chat-image191'))
            ..add({'type': 'hint', 't': 'Dipakai untuk balasan cepat tanpa gambar khusus. Maksimal 1 MB.'});
          final src = (((host.settings.raw['tpl'] as Map?)?['whatsappbot'] as Map?)?['img'] as Map?)?['chat-image191'];
          if (src is String && src.isNotEmpty) out.add(pickedImageItem(src));
        }
      case 4:
        out
          ..add({'type': 'title', 't': 'Media balasan', 's': server ? '${cb.media.length}/${cb.mediaLimit}' : ''})
          ..add({'type': 'hint', 't': 'Foto atau PDF (daftar harga, brosur, promo) per cabang, dipakai Balasan Cepat, Promo, dan Chatbot AI. Maksimal 10 per cabang.'});
        if (server) {
          for (final m in cb.media.take(5)) {
            out.add({'type': 'entry', 't': '${m['name']}', 'lines': ['${m['kind'] == 'pdf' ? 'PDF' : 'Foto'} · ${waSize((m['bytes'] as num?)?.toInt() ?? 0)}'],
              'badge': '', 'avatar': m['kind'] == 'pdf' ? '📄' : '🖼', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[], 'compact': true});
          }
        } else {
          out.add({'type': 'hint', 't': 'Media disimpan di server. Masuk dengan akun pemilik dan pastikan cabang ini sudah terdaftar di server.'});
        }
        out.add(_btn('Kelola Media ›', 22, primary: true));
      default:
        out
          ..add({'type': 'title', 't': 'WhatsApp Blast'})
          ..add({'type': 'hint', 't': 'Kirim promo ke pelanggan yang setuju dihubungi. Dikirim bergilir supaya nomor aman.'})
          ..add(_btn('Buka WhatsApp Blast ›', 2, primary: true));
    }
    if (!wa.store.devices.any((d) => d.status == 'connected') && tab != 0) {
      out.add({'type': 'hint', 't': 'WhatsApp belum terhubung · pesan baru terkirim setelah nomor outlet dihubungkan di tab Perangkat.'});
    }
    return out;
  }

  @override
  void button(int i) {
    if (i >= 900 && i < 900 + _tabs.length) {
      tab = i - 900;
      return host.refresh();
    }
    if (i == 20 || (i >= 1000 && (i - 1000) % 10 == 0)) {
      if (!_gate(host, 'ai')) return;
      final k = i == 20 ? null : (i - 1000) ~/ 10;
      _kbEdit = k;
      _kbQ = k == null ? '' : '${kb[k]['q'] ?? ''}';
      _kbA = k == null ? '' : '${kb[k]['a'] ?? ''}';
      return host.openPageSheet(_kbSheet);
    }
    if (i >= 1000 && (i - 1000) % 10 == 1) {
      final k = (i - 1000) ~/ 10, list = kb;
      if (k >= list.length) return;
      list.removeAt(k);
      if (cb.ready) {
        cb.run(() => cb.saveKnowledge(list), ok: 'Pengetahuan dihapus');
        return;
      }
      _ai['kb'] = list;
      saveChat(host, st);
      host.toast('Pengetahuan dihapus');
      return host.refresh();
    }
    if (i == 21) {
      cb.run(cb.resume, ok: 'Bot dilanjutkan untuk semua chat');
      return;
    }
    if (i == 22) return host.go('wamedia');
    const go = ['triggers191', 'ai191', 'blast191', 'wadevices195', 'quickreply'];
    const need = ['quick', 'ai', 'blast', 'wa', 'quick'];
    if (i < 0 || i >= go.length) return;
    if (need[i].isNotEmpty && !_gate(host, need[i])) return;
    host.go(go[i]);
  }

  Map<String, dynamic> _in(int i, String v, String ph, bool multi) =>
      {'type': 'input', 'v': v, 'ph': ph, 'multiline': multi, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};

  @override
  List<Map<String, dynamic>>? sheetItems(String id) => id != _kbSheet
      ? null
      : [
          {'type': 'title', 't': _kbEdit == null ? 'Tambah Pengetahuan' : 'Edit Pengetahuan', 's': ''},
          {'type': 'label', 't': 'Topik / pertanyaan pelanggan'},
          _in(0, _kbQ, 'Contoh: Area antar jemput', false),
          {'type': 'label', 't': 'Jawaban'},
          _in(1, _kbA, 'Contoh: Gratis antar jemput radius 3 km dari outlet, di luar itu Rp5.000.', true),
          {'type': 'button', 't': 'Simpan', 'primary': true, 'i': 0},
          {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1},
        ];

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id != _kbSheet) return;
    if (kind == 'input') {
      if (index == 0) _kbQ = '${value ?? ''}';
      if (index == 1) _kbA = '${value ?? ''}';
      return;
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet(_kbSheet);
    final q = _kbQ.trim(), a = _kbA.trim();
    if (q.isEmpty || a.isEmpty) return host.toast('Isi topik dan jawabannya');
    final list = kb, e = _kbEdit;
    if (e != null && e < list.length) {
      list[e] = {'q': q, 'a': a};
    } else {
      list.add({'q': q, 'a': a});
    }
    if (cb.ready) {
      cb.run(() => cb.saveKnowledge(list), ok: 'Pengetahuan tersimpan').then((ok) {
        if (ok) host.closePageSheet(_kbSheet);
      });
      return;
    }
    _ai['kb'] = list;
    saveChat(host, st).then((ok) {
      if (!ok) return host.toast('Penyimpanan penuh');
      host.closePageSheet(_kbSheet);
      host.toast('Pengetahuan tersimpan');
      host.refresh();
    });
  }
}

/// Halaman WhatsApp lain yang susunannya tetap (dari tangkapan HTML).
Map<String, PurePage> whatsappPages(PureHost host) {
  // Satu sumber data perangkat WhatsApp untuk halaman perangkat dan sakelar Balas Status di Otomasi.
  final wa = WaLink(host);
  // Satu sumber data Chatbot di server (cabang aktif) untuk hub, Balasan Cepat, Media, dan Promo.
  final cb = ChatbotServer(host);
  return {
      'whatsappbot': WaHubPage(host, wa, cb),
      'triggers191': TriggersPage(host, cb),
      'ai191': AiPage(host, cb),
      'blast191': BlastPage(host, cb, wa),
      'wamedia': WaMediaPage(host, cb),
      'quickreply': TemplatePage(host, 'quickreply', backTo: 'whatsappbot', onButton: (p, i) {
        if (_gate(host, 'quick')) host.go('triggers191');
      }),
      'automation': AutomationPage(host, wa: wa),
      'wadevices195': WaDevicesPage(host, wa),
    };
}
