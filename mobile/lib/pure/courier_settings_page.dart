// Pengaturan Kurir (keputusan Paduka 9 Oktober 2026): satu tempat untuk kurir dan akun masuknya.
// Setiap kurir adalah akun di server (nomor HP + PIN, satu outlet tugas), jadi menu ini terbuka setelah pemilik masuk ke akun GOYANA.
// Server yang membuat data kurirnya (dipakai saat menunjuk kurir di tugas antar-jemput) dan menegakkan haknya.

import '../core/models.dart' show Outlet;
import '../core/stock.dart' show Couriers;
import 'pages.dart';
import 'server_sync.dart' show ServerFailure, ServerSync;

class CourierSettingsPage extends PurePage {
  CourierSettingsPage(super.host);

  static const _form = 'kurir-form';

  List<Map<String, dynamic>> team = [];
  /// Nama kurir lama di HP ini yang belum punya akun.
  List<Map<String, dynamic>> legacy = [];
  String _note = '';
  bool _sending = false;

  int? _id;
  String _name = '', _phone = '', _pin = '', _link = '';
  int _outlet = 0;
  /// Hak kurir (diatur pemilik per kurir; bawaan semua boleh). Ditegakkan server saat sinkron.
  Map<String, bool> _can = {for (final k in limitKeys) k: true};
  static const limitKeys = ['weigh', 'create', 'pay'];
  static const limitLabels = {
    'weigh': ('Boleh menimbang di lokasi', 'Mati: kurir hanya menandai sudah dijemput, timbangan diisi kasir di outlet.'),
    'create': ('Boleh buat transaksi di lokasi', 'Pelanggan datang langsung ke kurir tanpa penjemputan terjadwal.'),
    'pay': ('Boleh terima pembayaran', 'Mati: pelanggan membayar di outlet; kurir tidak memegang uang.'),
  };

  @override
  String get title => 'PENGATURAN KURIR';

  /// Dibuka dari Buat Penjemputan (belum ada kurir): kembali ke halaman itu setelah akun kurir dibuat atau saat Kembali.
  static String returnTo = '';
  @override
  String get back => returnTo.isNotEmpty ? returnTo : 'settings';

  bool get _owner => host.server.isOwner;
  List<Outlet> get _outlets => [for (final o in host.business.outlets) if (ServerSync.outletNumber(o.id) != null) o];
  List<Map<String, dynamic>> get _couriers => [for (final m in team) if ('${m['role']}' == 'kurir') m];
  String _outletName(Object? id) => host.business.outlets.where((o) => o.id == 'srv-$id').firstOrNull?.name ?? 'Outlet belum dipilih';

  static const howTo = [
    {'type': 'title', 't': 'Cara masuk kurir'},
    {'type': 'hint', 't': '1. Pasang aplikasi GOYANA di HP kurir.'},
    {'type': 'hint', 't': '2. Di layar masuk, isi nomor HP kurir yang didaftarkan di sini.'},
    {'type': 'hint', 't': '3. Isi PIN 6 angka yang Anda berikan.'},
    {'type': 'hint', 't': '4. Aplikasi langsung menampilkan Jemput, Antar, dan Setoran. Menu lain tidak terbuka untuk kurir.'},
    {'type': 'hint', 't': 'Lupa PIN: ketuk Edit pada kurir itu, lalu isi PIN baru. PIN yang terkunci karena salah berkali-kali terbuka lagi setelah diganti.'},
  ];

  @override
  void opened() {
    _reset();
    if (_owner) _load();
  }

  void _reset() {
    _id = null;
    _name = _phone = _pin = _link = '';
    _outlet = 0;
    _can = {for (final k in limitKeys) k: true};
  }

  /// Hak yang dimatikan untuk satu kurir, untuk ditampilkan di daftar.
  static String offList(Object? limits) {
    final m = limits is Map ? limits : const {};
    final off = [for (final k in limitKeys) if (m[k] == false) {'weigh': 'timbang', 'create': 'transaksi di lokasi', 'pay': 'terima uang'}[k]!];
    return off.isEmpty ? '' : 'Tidak boleh: ${off.join(', ')}';
  }

  Future<void> _load() async {
    _note = team.isEmpty ? 'Memuat daftar kurir…' : '';
    host.refresh();
    try {
      final j = await host.server.api('GET', '/team');
      team = [for (final m in (j['team'] as List? ?? const []).whereType<Map>()) Map<String, dynamic>.from(m)];
      _note = '';
      final linked = {for (final m in team) '${m['courier_key'] ?? ''}'};
      final local = await Couriers.load(host.kv);
      legacy = [for (final k in local.list) if (k['deleted'] != true && k['active'] != false && !linked.contains('${k['id']}')) k];
    } on ServerFailure catch (e) {
      _note = e.offline ? 'Butuh internet untuk memuat daftar kurir.' : e.message;
    }
    host.refresh();
  }

  @override
  List<Map<String, dynamic>> items() {
    if (!_owner) {
      final staff = host.server.loggedIn;
      return [
        {'type': 'title', 't': staff ? 'Hanya untuk pemilik' : 'Masuk ke akun GOYANA dulu'},
        {
          'type': 'hint',
          't': staff
              ? 'Kurir dan PIN-nya diatur pemilik usaha dari akunnya.'
              : 'Setiap kurir punya akun sendiri untuk masuk di HP-nya, dan akun itu disimpan di server GOYANA. Masuk dulu sebagai pemilik untuk menambah kurir.',
        },
        if (!staff) {'type': 'button', 't': 'Masuk ke Akun GOYANA', 'primary': true, 'file': '', 'after': false, 'i': 900},
        ...howTo,
      ];
    }
    final list = _couriers;
    return [
      {'type': 'hint', 't': 'Kurir yang ditambahkan di sini langsung punya akun untuk masuk di HP-nya dan bisa ditunjuk pada tugas antar-jemput.'},
      {'type': 'button', 't': '+ Tambah Kurir', 'primary': true, 'file': '', 'after': false, 'i': 0},
      if (_note.isNotEmpty) {'type': 'hint', 't': _note},
      if (_note.isEmpty && list.isEmpty) ...[
        {'type': 'title', 't': 'Belum ada kurir'},
        {'type': 'hint', 't': 'Ketuk Tambah Kurir, lalu isi nama, nomor HP, PIN, dan outlet tugasnya.'},
      ],
      for (var k = 0; k < list.length; k++)
        {
          'type': 'entry', 't': '${list[k]['name']}',
          'lines': [
            '${list[k]['phone'] ?? ''} · ${_outletName(list[k]['outlet_id'])}',
            list[k]['active'] == false ? 'Nonaktif · tidak bisa masuk' : (list[k]['pin_locked'] == true ? 'PIN terkunci · ganti PIN lewat Edit' : 'Aktif'),
            if (offList(list[k]['courier_limits']).isNotEmpty) offList(list[k]['courier_limits']),
          ],
          'badge': '', 'avatar': '${list[k]['name']}'.isEmpty ? 'K' : '${list[k]['name']}'[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '',
          'btns': [
            {'t': 'Edit', 'on': false, 'i': 1000 + 10 * k},
            {'t': list[k]['active'] == false ? 'Aktifkan' : 'Nonaktifkan', 'on': false, 'i': 1001 + 10 * k},
          ],
        },
      if (legacy.isNotEmpty) ...[
        {'type': 'title', 't': 'Kurir lama tanpa akun'},
        {'type': 'hint', 't': 'Nama-nama ini tersimpan sebelum ada akun. Buatkan akun supaya kurirnya bisa masuk; riwayat tugasnya ikut tersambung.'},
        for (var k = 0; k < legacy.length; k++)
          {
            'type': 'entry', 't': '${legacy[k]['name']}', 'lines': ['${legacy[k]['phone'] ?? ''} · belum bisa masuk'],
            'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
            'btns': [{'t': 'Buat Akun', 'on': true, 'i': 5000 + k}],
          },
      ],
      ...howTo,
    ];
  }

  @override
  void button(int i) {
    if (i == 900) return host.go('outlets');
    if (!_owner || _sending) return;
    if (i == 0) {
      _reset();
      return host.openPageSheet(_form);
    }
    if (i >= 5000) {
      if (i - 5000 >= legacy.length) return;
      final k = legacy[i - 5000];
      _reset();
      _name = '${k['name'] ?? ''}';
      _phone = '${k['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9+]'), '');
      _link = '${k['id'] ?? ''}';
      return host.openPageSheet(_form);
    }
    if (i < 1000) return;
    final list = _couriers, k = (i - 1000) ~/ 10;
    if (k >= list.length) return;
    final m = list[k];
    if ((i - 1000) % 10 == 1) {
      _toggle(m);
      return;
    }
    final outs = _outlets;
    _reset();
    _id = int.tryParse('${m['id']}');
    _name = '${m['name'] ?? ''}';
    _phone = '${m['phone'] ?? ''}';
    final at = outs.indexWhere((o) => o.id == 'srv-${m['outlet_id']}');
    _outlet = at < 0 ? 0 : at;
    final lim = m['courier_limits'] is Map ? m['courier_limits'] as Map : const {};
    _can = {for (final k in limitKeys) k: lim[k] != false};
    host.openPageSheet(_form);
  }

  Future<void> _toggle(Map<String, dynamic> m) async {
    final off = m['active'] != false;
    await _send(() => host.server.api('POST', '/team/${m['id']}/${off ? 'deactivate' : 'activate'}'), off ? 'Kurir dinonaktifkan' : 'Kurir aktif lagi');
  }

  /// Kirim satu perubahan ke server lalu muat ulang daftar; true bila berhasil.
  Future<bool> _send(Future<Object?> Function() work, String ok) async {
    if (_sending) return false;
    _sending = true;
    try {
      await work();
      host.toast(ok);
      await _load();
      return true;
    } on ServerFailure catch (e) {
      host.toast(e.offline ? 'Butuh internet untuk mengubah data kurir' : e.message);
      return false;
    } finally {
      _sending = false;
    }
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id != _form) return null;
    Map<String, dynamic> inp(String v, String ph, int i, {bool numeric = false, bool secret = false}) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': numeric, 'decimal': false, 'ro': false, 'secret': secret, 'email': false, 'i': i};
    final outs = _outlets;
    return [
      {'type': 'title', 't': _id == null ? 'Tambah Kurir' : 'Edit Kurir', 's': ''},
      {'type': 'label', 't': 'Nama kurir'},
      inp(_name, 'Contoh: Dodi', 0),
      {'type': 'label', 't': 'Nomor HP (untuk masuk)'},
      inp(_phone, '08xxxxxxxxxx', 1, numeric: true),
      {'type': 'label', 't': 'Bertugas di outlet'},
      if (outs.isEmpty) {'type': 'hint', 't': 'Belum ada outlet di server. Sinkronkan dulu di Pengaturan Outlet.'},
      if (outs.isNotEmpty) {'type': 'select', 'options': [for (final o in outs) o.name], 'index': _outlet.clamp(0, outs.length - 1), 'i': 2},
      {'type': 'label', 't': 'PIN 6 angka'},
      inp(_pin, _id == null ? 'PIN untuk kurir masuk' : 'Kosongkan jika tidak diganti', 3, numeric: true, secret: true),
      {'type': 'hint', 't': 'Kurir masuk di HP-nya dengan nomor HP dan PIN ini. Berikan PIN langsung kepada kurirnya.'},
      {'type': 'label', 't': 'Hak akses kurir'},
      for (var k = 0; k < limitKeys.length; k++)
        {'type': 'toggle', 't': limitLabels[limitKeys[k]]!.$1, 's': limitLabels[limitKeys[k]]!.$2, 'on': _can[limitKeys[k]] != false, 'i': 10 + k},
      {'type': 'button', 't': 'Simpan', 'primary': true, 'file': '', 'after': false, 'i': 0},
      {'type': 'button', 't': 'Batal', 'primary': false, 'file': '', 'after': false, 'i': 1},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id != _form) return;
    if (kind == 'input') {
      final v = '${value ?? ''}';
      switch (index) {
        case 0:
          _name = v;
        case 1:
          _phone = v;
        case 2:
          _outlet = value is int ? value : int.tryParse(v) ?? 0;
          host.refresh();
        case 3:
          _pin = v;
      }
      return;
    }
    if (kind == 'toggle') {
      final k = index - 10;
      if (k >= 0 && k < limitKeys.length) _can[limitKeys[k]] = _can[limitKeys[k]] == false;
      return host.refresh();
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet(_form);
    final outs = _outlets, id0 = _id;
    final name = _name.trim(), phone = _phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (name.isEmpty) return host.toast('Isi nama kurir');
    if (!RegExp(r'^\+?\d{9,15}$').hasMatch(phone)) return host.toast('Periksa nomor HP');
    if (outs.isEmpty) return host.toast('Belum ada outlet di server. Sinkronkan dulu.');
    if ((id0 == null || _pin.isNotEmpty) && !RegExp(r'^\d{6}$').hasMatch(_pin)) return host.toast('PIN harus 6 angka');
    final body = <String, dynamic>{
      'name': name, 'phone': phone, 'role': 'kurir',
      'outlet_id': ServerSync.outletNumber(outs[_outlet.clamp(0, outs.length - 1)].id),
      if (_link.isNotEmpty) 'courier_key': _link,
      'courier_limits': {for (final k in limitKeys) k: _can[k] != false},
    };
    final pin = _pin;
    _send(() async {
      if (id0 == null) {
        await host.server.api('POST', '/team', {...body, 'pin': pin});
      } else {
        await host.server.api('PATCH', '/team/$id0', body);
        if (pin.isNotEmpty) await host.server.api('POST', '/team/$id0/pin', {'pin': pin});
      }
      return null;
    }, id0 == null ? 'Akun kurir dibuat' : 'Data kurir tersimpan').then((done) {
      if (done) {
        _reset();
        host.closePageSheet(_form);
        if (id0 == null && returnTo.isNotEmpty) {
          final to = returnTo;
          returnTo = '';
          host.go(to);
        }
      }
    });
  }
}
