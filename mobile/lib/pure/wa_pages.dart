// WhatsApp & Chatbot (v191/v195): pengaturan tersimpan per outlet di `goyana-chat191:<idOutlet>` (sama dengan Hibrida).
// Pengiriman WhatsApp dan AI sungguhan menunggu server — sama seperti di HTML.
import 'dart:convert';

import '../core/money.dart';
import 'access.dart';
import 'pages.dart';

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
  TriggersPage(super.host);
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
  List<Map<String, dynamic>> get rules => (st['rules'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  @override
  void opened() {
    form = false;
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
    return [
      {'type': 'hint', 't': _serverNote},
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
        {'type': 'label', 't': 'Gambar balasan / promo'},
        {'type': 'button', 't': 'Pilih Gambar', 'primary': false, 'file': 'rule-image191', 'i': -1},
        if (image.isNotEmpty) pickedImageItem(image),
        {'type': 'toggle', 't': 'Aktif', 's': '', 'on': enabled, 'i': 0},
        {'type': 'buttons', 'options': [
          {'t': 'Simpan', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 1},
          {'t': 'Batal', 'svg': '', 'file': '', 'after': false, 'on': false, 'i': 2},
        ]},
      ],
      if (r.isEmpty) {'type': 'hint', 't': 'Belum ada balasan. Tambahkan kata pemicu dan jawabannya.'},
      for (var k = 0; k < r.length; k++)
        {
          'type': 'entry', 't': '${r[k]['name']}', 'lines': ['${r[k]['keys']} · ${r[k]['mode'] == 'exact' ? 'Pesan sama persis' : 'Mengandung kata/frasa'}', '${r[k]['reply']}'],
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
    host.refresh();
  }

  @override
  void input(int i, Object value) {
    if (i == 2) {
      mode = value is int ? value : 0;
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

/// Pengaturan Chatbot AI (ai191): tersimpan di state chat outlet; jawaban AI sungguhan menunggu server.
class AiPage extends TemplatePage {
  // ignore: use_super_parameters
  AiPage(PureHost host) : super(host, 'ai191', backTo: 'whatsappbot');
  Map<String, dynamic> st = {};
  Map<String, dynamic> get ai => ((st['ai'] ??= <String, dynamic>{}) as Map).cast<String, dynamic>();
  static const _in = ['name', 'instructions', 'knowledge'];
  static const _tg = ['enabled', 'prices', 'status'];

  @override
  void opened() {
    loadChat(host).then((v) {
      st = v;
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
        'antrian': 'Antrian', 'cuci': 'Sedang dicuci', 'kering': 'Sedang dikeringkan', 'setrika': 'Sedang disetrika', 'packing': 'Dalam proses', 'siap': 'Siap diambil',
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
    return 'Pertanyaan ini membutuhkan koneksi AI. Pengetahuan tambahan sudah tersimpan, tetapi layanan AI belum terhubung.';
  }

  @override
  void button(int i) async {
    if (i == 2) {
      _answer = answer(_test[5] ?? '', _test[4] ?? '');
      return host.refresh();
    }
    if (!_gate(host, 'ai')) return;
    if (!await saveChat(host, st)) return host.toast('Penyimpanan penuh. Kurangi ukuran gambar.');
    host.toast('Pengaturan AI tersimpan');
    host.refresh();
  }
}

/// Halaman WhatsApp lain yang susunannya tetap (dari tangkapan HTML).
Map<String, PurePage> whatsappPages(PureHost host) => {
      'whatsappbot': TemplatePage(host, 'whatsappbot', onButton: (p, i) {
        const go = ['triggers191', 'ai191', 'blast191', 'wadevices195', 'quickreply'];
        const need = ['quick', 'ai', 'blast', '', 'quick'];
        if (i < 0 || i >= go.length) return;
        if (need[i].isNotEmpty && !_gate(host, need[i])) return;
        host.go(go[i]);
      }),
      'triggers191': TriggersPage(host),
      'ai191': AiPage(host),
      'blast191': TemplatePage(host, 'blast191', backTo: 'whatsappbot', onButton: (p, i) {
        if (i < 0) return;
        if (!_gate(host, 'blast')) return;
        host.toast('Isi promo, pilih penerima dan konfirmasi persetujuan.');
      }),
      'quickreply': TemplatePage(host, 'quickreply', backTo: 'whatsappbot', onButton: (p, i) {
        if (_gate(host, 'quick')) host.go('triggers191');
      }),
      'automation': AutomationPage(host),
      'wadevices195': TemplatePage(host, 'wadevices195', onButton: (p, i) {
        if (host.business.outlets.isEmpty) return host.toast('Tambahkan pusat atau cabang di Pengaturan Outlet terlebih dahulu.');
        host.toast('Menautkan WhatsApp memerlukan layanan WhatsApp GOYANA (server belum aktif).');
      }),
    };
