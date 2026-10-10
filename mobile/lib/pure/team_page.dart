// Pengaturan → Tim (keputusan Paduka 10 Oktober 2026): kasir, pegawai, kurir, dan kepala cabang dikelola di satu tempat,
// dikelompokkan per cabang. "+ Tambah" langsung terisi tugas & cabangnya. Batas akun per outlet mengikuti paket
// (Basic 2 tiap tugas, naik +1 tiap paket; kepala cabang 1 per outlet) dan ditegakkan server (App\Support\Team).

import '../core/models.dart' show Outlet;
import 'courier_settings_page.dart' show CourierSettingsPage;
import 'pages.dart';
import 'server_sync.dart' show ServerFailure, ServerSync;

class TeamPage extends PurePage {
  TeamPage(super.host);

  static const _form = 'tim-form';
  /// [kunci server, nama tampil]
  static const roles = [['kasir', 'Kasir'], ['produksi', 'Pegawai'], ['kurir', 'Kurir'], ['manager', 'Kepala Cabang']];

  List<Map<String, dynamic>> team = [];
  Map<String, dynamic> limits = {};
  String package = '', _note = '';
  bool _sending = false;
  int _fOutlet = 0, _fRole = 0; // saringan: 0 = semua

  // Isian formulir
  int? _id;
  String _name = '', _phone = '', _pin = '';
  int _role = 0, _outlet = 0;
  Map<String, bool> _can = {for (final k in CourierSettingsPage.limitKeys) k: true};

  @override
  String get title => 'TIM';

  bool get _owner => host.server.isOwner;
  List<Outlet> get _outs => [for (final o in host.business.outlets) if (ServerSync.outletNumber(o.id) != null) o];
  String _roleName(Object? k) => roles.where((r) => r[0] == '$k').firstOrNull?[1] ?? '$k';
  int _limit(String role) => (limits[role] as num?)?.toInt() ?? (role == 'manager' ? 1 : 2);
  List<Map<String, dynamic>> _members(String outletKey, [String? role]) => [
        for (final m in team)
          if ('srv-${m['outlet_id']}' == outletKey && (role == null || '${m['role']}' == role)) m,
      ];
  int _used(String outletKey, String role) => _members(outletKey, role).where((m) => m['active'] != false).length;

  @override
  void opened() {
    _fOutlet = _fRole = 0;
    if (_owner) _load();
  }

  Future<void> _load() async {
    _note = team.isEmpty ? 'Memuat tim…' : '';
    host.refresh();
    try {
      final j = await host.server.api('GET', '/team');
      team = [for (final m in (j['team'] as List? ?? const []).whereType<Map>()) Map<String, dynamic>.from(m)];
      limits = j['limits'] is Map ? Map<String, dynamic>.from(j['limits'] as Map) : {};
      package = '${j['package'] ?? ''}';
      _note = '';
    } on ServerFailure catch (e) {
      _note = e.offline ? 'Butuh internet untuk memuat tim.' : e.message;
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
              ? 'Tim diatur pemilik usaha dari akunnya.'
              : 'Kasir, pegawai, dan kurir punya akun sendiri (nomor HP + PIN) yang disimpan di server GOYANA. Masuk dulu sebagai pemilik untuk mengatur tim.',
        },
        if (!staff) {'type': 'button', 't': 'Masuk ke Akun GOYANA', 'primary': true, 'file': '', 'after': false, 'i': 900},
        if (!staff) {'type': 'button', 't': 'Pegawai di HP ini (tanpa akun)', 'primary': false, 'file': '', 'after': false, 'i': 901},
      ];
    }
    final outs = _outs;
    final shown = [for (var k = 0; k < outs.length; k++) if (_fOutlet == 0 || _fOutlet == k + 1) k];
    final onlyRole = _fRole == 0 ? null : roles[_fRole - 1][0];
    final out = <Map<String, dynamic>>[
      {'type': 'hint', 't': 'Setiap orang punya akun sendiri (nomor HP + PIN) dan terikat ke satu cabang.${package.isEmpty ? '' : ' Paket $package: ${_limit('kasir')} kasir, ${_limit('produksi')} pegawai, ${_limit('kurir')} kurir, dan ${_limit('manager')} kepala cabang per outlet.'}'},
      if (outs.length > 1)
        {'type': 'buttons', 'options': [
          {'t': 'Semua Cabang', 'on': _fOutlet == 0, 'i': 20},
          for (var k = 0; k < outs.length; k++) {'t': outs[k].name, 'on': _fOutlet == k + 1, 'i': 21 + k},
        ]},
      {'type': 'buttons', 'options': [
        {'t': 'Semua', 'on': _fRole == 0, 'i': 60},
        for (var r = 0; r < roles.length; r++) {'t': roles[r][1], 'on': _fRole == r + 1, 'i': 61 + r},
      ]},
      if (_note.isNotEmpty) {'type': 'hint', 't': _note},
      if (outs.isEmpty && _note.isEmpty) {'type': 'hint', 't': 'Belum ada outlet di server. Sinkronkan dulu di Pengaturan Outlet.'},
    ];
    for (final k in shown) {
      final o = outs[k];
      out
        ..add({'type': 'title', 't': o.name})
        ..add({'type': 'hint', 't': [for (final r in roles) '${r[1]} ${_used(o.id, r[0])}/${_limit(r[0])}'].join(' · ')})
        ..add({'type': 'buttons', 'cols': 4, 'options': [
          for (var r = 0; r < roles.length; r++)
            if (onlyRole == null || onlyRole == roles[r][0]) {'t': '+ ${roles[r][1]}', 'on': false, 'i': 1000 + k * 10 + r},
        ]});
      final list = _members(o.id, onlyRole);
      if (list.isEmpty) out.add({'type': 'hint', 't': 'Belum ada ${onlyRole == null ? 'anggota tim' : _roleName(onlyRole).toLowerCase()} di cabang ini.'});
      for (final m in list) {
        final idx = team.indexOf(m);
        final off = CourierSettingsPage.offList(m['courier_limits']);
        out.add({
          'type': 'entry', 't': '${m['name']}',
          'lines': [
            '${_roleName(m['role'])} · ${m['phone'] ?? ''}',
            m['active'] == false ? 'Nonaktif · tidak bisa masuk' : (m['pin_locked'] == true ? 'PIN terkunci · ganti PIN lewat Edit' : 'Aktif'),
            if ('${m['role']}' == 'kurir' && off.isNotEmpty) off,
          ],
          'badge': '', 'avatar': '${m['name']}'.isEmpty ? '?' : '${m['name']}'[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '',
          'btns': [
            {'t': 'Edit', 'on': false, 'i': 5000 + idx * 10},
            {'t': m['active'] == false ? 'Aktifkan' : 'Nonaktifkan', 'on': false, 'i': 5001 + idx * 10},
          ],
        });
      }
    }
    out.add({'type': 'hint', 't': 'Cara masuk: pasang GOYANA di HP orang itu, lalu masuk dengan nomor HP dan PIN dari sini. Menu yang tampil mengikuti tugasnya.'});
    return out;
  }

  void _reset() {
    _id = null;
    _name = _phone = _pin = '';
    _role = _outlet = 0;
    _can = {for (final k in CourierSettingsPage.limitKeys) k: true};
  }

  @override
  void button(int i) {
    if (i == 900) return host.go('outlets');
    if (i == 901) return host.go('employees');
    if (!_owner || _sending) return;
    if (i >= 20 && i < 60) {
      _fOutlet = i - 20;
      return host.refresh();
    }
    if (i >= 60 && i < 60 + 1 + roles.length) {
      _fRole = i - 60;
      return host.refresh();
    }
    final outs = _outs;
    if (i >= 1000 && i < 5000) {
      final k = (i - 1000) ~/ 10, r = (i - 1000) % 10;
      if (k >= outs.length || r >= roles.length) return;
      final role = roles[r][0];
      if (_used(outs[k].id, role) >= _limit(role)) {
        return host.toast(role == 'manager'
            ? 'Setiap outlet hanya punya ${_limit(role)} Kepala Cabang'
            : 'Paket ${package.isEmpty ? 'ini' : package}: maksimal ${_limit(role)} ${roles[r][1]} per outlet. Upgrade paket atau beli tambahan akun.');
      }
      _reset();
      _role = r;
      _outlet = k;
      return host.openPageSheet(_form);
    }
    if (i >= 5000) {
      final idx = (i - 5000) ~/ 10;
      if (idx >= team.length) return;
      final m = team[idx];
      if ((i - 5000) % 10 == 1) {
        final off = m['active'] != false;
        _send(() => host.server.api('POST', '/team/${m['id']}/${off ? 'deactivate' : 'activate'}'), off ? '${m['name']} dinonaktifkan' : '${m['name']} aktif lagi');
        return;
      }
      _reset();
      _id = int.tryParse('${m['id']}');
      _name = '${m['name'] ?? ''}';
      _phone = '${m['phone'] ?? ''}';
      _role = roles.indexWhere((r) => r[0] == '${m['role']}').clamp(0, roles.length - 1);
      _outlet = outs.indexWhere((o) => o.id == 'srv-${m['outlet_id']}').clamp(0, outs.isEmpty ? 0 : outs.length - 1);
      final lim = m['courier_limits'] is Map ? m['courier_limits'] as Map : const {};
      _can = {for (final k in CourierSettingsPage.limitKeys) k: lim[k] != false};
      host.openPageSheet(_form);
    }
  }

  Future<bool> _send(Future<Object?> Function() work, String ok) async {
    if (_sending) return false;
    _sending = true;
    try {
      await work();
      host.toast(ok);
      await _load();
      return true;
    } on ServerFailure catch (e) {
      host.toast(e.offline ? 'Butuh internet untuk mengubah tim' : e.message);
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
    final outs = _outs, kurir = roles[_role][0] == 'kurir';
    return [
      {'type': 'title', 't': _id == null ? 'Tambah ${roles[_role][1]}' : 'Edit ${roles[_role][1]}', 's': ''},
      {'type': 'label', 't': 'Nama'},
      inp(_name, 'Contoh: Rina', 0),
      {'type': 'label', 't': 'Nomor HP (untuk masuk)'},
      inp(_phone, '08xxxxxxxxxx', 1, numeric: true),
      {'type': 'label', 't': 'Tugas'},
      {'type': 'select', 'options': [for (final r in roles) r[1]], 'index': _role, 'i': 2},
      {'type': 'label', 't': 'Cabang'},
      if (outs.isNotEmpty) {'type': 'select', 'options': [for (final o in outs) o.name], 'index': _outlet.clamp(0, outs.length - 1), 'i': 3},
      {'type': 'label', 't': 'PIN 6 angka'},
      inp(_pin, _id == null ? 'PIN untuk masuk' : 'Kosongkan jika tidak diganti', 4, numeric: true, secret: true),
      if (kurir) ...[
        {'type': 'label', 't': 'Hak akses kurir'},
        for (var k = 0; k < CourierSettingsPage.limitKeys.length; k++)
          {
            'type': 'toggle', 't': CourierSettingsPage.limitLabels[CourierSettingsPage.limitKeys[k]]!.$1,
            's': CourierSettingsPage.limitLabels[CourierSettingsPage.limitKeys[k]]!.$2, 'on': _can[CourierSettingsPage.limitKeys[k]] != false, 'i': 10 + k,
          },
      ],
      {'type': 'hint', 't': 'Berikan PIN langsung kepada orangnya. Ganti tugas membuat orang itu perlu masuk lagi.'},
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
          _role = (value is int ? value : int.tryParse(v) ?? 0).clamp(0, roles.length - 1);
          host.refresh();
        case 3:
          _outlet = value is int ? value : int.tryParse(v) ?? 0;
        case 4:
          _pin = v;
      }
      return;
    }
    if (kind == 'toggle') {
      final k = index - 10;
      if (k >= 0 && k < CourierSettingsPage.limitKeys.length) {
        final key = CourierSettingsPage.limitKeys[k];
        _can[key] = _can[key] == false;
      }
      return host.refresh();
    }
    if (kind != 'button') return;
    if (index == 1) return host.closePageSheet(_form);
    final outs = _outs, id0 = _id;
    final name = _name.trim(), phone = _phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (name.isEmpty) return host.toast('Isi nama');
    if (!RegExp(r'^\+?\d{9,15}$').hasMatch(phone)) return host.toast('Periksa nomor HP');
    if (outs.isEmpty) return host.toast('Belum ada outlet di server. Sinkronkan dulu.');
    if ((id0 == null || _pin.isNotEmpty) && !RegExp(r'^\d{6}$').hasMatch(_pin)) return host.toast('PIN harus 6 angka');
    final role = roles[_role][0];
    final body = <String, dynamic>{
      'name': name, 'phone': phone, 'role': role,
      'outlet_id': ServerSync.outletNumber(outs[_outlet.clamp(0, outs.length - 1)].id),
      if (role == 'kurir') 'courier_limits': {for (final k in CourierSettingsPage.limitKeys) k: _can[k] != false},
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
    }, id0 == null ? '${roles[_role][1]} ditambahkan' : 'Data tersimpan').then((done) {
      if (done) {
        _reset();
        host.closePageSheet(_form);
      }
    });
  }
}
