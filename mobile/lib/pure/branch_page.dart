// Halaman satu cabang (Tahap 2, 10 Oktober 2026): Pengaturan › Outlet › Kelola.
// Isi: daftar cek "Siap buka" (panduan cabang baru), profil & zona waktu, tim per tugas, hak akses cabang,
// HP kasir terdaftar, stok cabang, dan nonaktifkan/aktifkan cabang. Data tim, HP, dan status dari server (khusus pemilik).

import '../core/stock.dart';
import 'pages.dart';
import 'server_sync.dart' show ServerFailure, ServerSync;
import 'staff_rights_page.dart';
import 'team_page.dart';

class BranchPage extends PurePage {
  BranchPage(super.host);

  /// Outlet yang dibuka (id lokal, atau `srv-N` bila sudah di server).
  static String outletId = '';

  List<Map<String, dynamic>> team = [], devices = [], shared = [];
  Map<String, dynamic>? info;
  int devLimit = 0;
  String _note = '';
  StockBook? _stock;
  bool _busy = false;

  @override
  String get title => 'KELOLA CABANG';
  @override
  String get back => 'outlets';

  int? get _n => ServerSync.outletNumber(outletId);

  @override
  void opened() {
    team = devices = shared = [];
    info = null;
    _note = '';
    StockBook.load(host.kv).then((s) {
      _stock = s;
      host.refresh();
    });
    if (host.server.isOwner && _n != null) _load();
  }

  Future<void> _load() async {
    _note = 'Memuat data cabang…';
    host.refresh();
    try {
      final r = await Future.wait([host.server.api('GET', '/team'), host.server.api('GET', '/devices'), host.server.api('GET', '/outlets')]);
      final n = _n;
      team = [for (final m in (r[0]['team'] as List? ?? const []).whereType<Map>()) if (m['outlet_id'] == n) Map<String, dynamic>.from(m)];
      devices = [for (final d in (r[1]['cashier'] as List? ?? const []).whereType<Map>()) if (d['outlet_id'] == n) Map<String, dynamic>.from(d)];
      shared = [for (final d in (r[1]['shared'] as List? ?? const []).whereType<Map>()) if (d['outlet_id'] == n) Map<String, dynamic>.from(d)];
      devLimit = (r[1]['limit_per_outlet'] as num?)?.toInt() ?? 0;
      info = (r[2]['outlets'] as List? ?? const []).whereType<Map>().where((o) => o['id'] == n).map((o) => Map<String, dynamic>.from(o)).firstOrNull;
      _note = '';
    } on ServerFailure catch (e) {
      _note = e.offline ? 'Butuh internet untuk memuat data cabang.' : e.message;
    }
    host.refresh();
  }

  int _count(String role) => team.where((m) => '${m['role']}' == role && m['active'] != false).length;

  Map<String, dynamic> _step(bool done, String t, String s, int i, String action) => {
        'type': 'entry', 't': '${done ? '✅' : '⬜'} $t', 'lines': [s], 'badge': '', 'avatar': '', 'svg': '', 'color': '', 'amount': '',
        'btns': done || action.isEmpty ? <dynamic>[] : [{'t': action, 'on': false, 'i': i}],
      };

  @override
  List<Map<String, dynamic>> items() {
    final o = host.business.outlets.where((x) => x.id == outletId).firstOrNull;
    if (o == null) return [{'type': 'hint', 't': 'Outlet tidak ditemukan.'}];
    final owner = host.server.isOwner, online = owner && _n != null;
    final tz = '${o.raw['tz'] ?? ''}';
    final profil = o.name.trim().isNotEmpty && o.address.trim().isNotEmpty && o.phone.trim().isNotEmpty;
    final paired = devices.where((d) => d['paired'] == true).length + shared.length;
    final s = _stock;
    final its = s?.items ?? const [];
    final low = s == null ? 0 : its.where((e) => s.balance('${e['id']}', outletId) <= ((e['min'] as num?) ?? 0)).length;
    final active = info?['active'] != false;
    final steps = [
      _step(profil, 'Profil cabang', profil ? '${o.address} · WA ${o.phone}' : 'Isi nama, alamat, dan nomor WA cabang', 10, 'Lengkapi'),
      _step(tz.isNotEmpty, 'Zona waktu', tz.isNotEmpty ? tz : 'Pilih WIB / WITA / WIT', 10, 'Pilih'),
      if (online) _step(_count('kasir') > 0, 'Kasir cabang', _count('kasir') > 0 ? '${_count('kasir')} kasir' : 'Tambahkan minimal 1 kasir', 11, '+ Kasir'),
      if (online) _step(paired > 0, 'HP kasir', paired > 0 ? '$paired HP sudah masuk' : 'Kasir masuk di HP-nya dengan nomor HP + PIN', 0, ''),
      _step(host.business.services.isNotEmpty, 'Daftar harga', host.business.services.isNotEmpty ? '${host.business.services.length} layanan' : 'Isi layanan & harga di Pengaturan › Layanan', 12, 'Atur'),
    ];
    final ready = steps.every((e) => '${e['t']}'.startsWith('✅'));
    return [
      {'type': 'title', 't': o.name},
      if (!active) {'type': 'hint', 't': '⛔ Cabang ini nonaktif: tidak menerima transaksi baru. Riwayatnya tetap ada.'},
      {'type': 'title', 't': ready ? 'Siap buka ✅' : 'Siap buka'},
      ...steps,
      if (!owner) {'type': 'hint', 't': 'Tim, HP kasir, dan status cabang tampil setelah masuk ke akun GOYANA sebagai pemilik.'},
      if (owner && _n == null) {'type': 'hint', 't': 'Cabang ini belum tersimpan di server. Tunggu sinkron (butuh internet), lalu buka lagi.'},
      if (_note.isNotEmpty) {'type': 'hint', 't': _note},
      {'type': 'button', 't': 'Edit Profil & Zona Waktu', 'primary': false, 'file': '', 'after': false, 'i': 10},
      if (online) ...[
        {'type': 'title', 't': 'Tim'},
        {'type': 'hint', 't': [for (final r in TeamPage.roles) '${r[1]} ${_count(r[0])}'].join(' · ')},
        {'type': 'button', 't': 'Kelola Tim Cabang Ini', 'primary': false, 'file': '', 'after': false, 'i': 11},
        {'type': 'title', 't': 'Hak akses cabang ini'},
        {'type': 'buttons', 'cols': 2, 'options': [{'t': 'Hak Akses Kasir', 'on': false, 'i': 13}, {'t': 'Hak Akses Pegawai', 'on': false, 'i': 14}]},
        {'type': 'title', 't': 'HP kasir'},
        {'type': 'hint', 't': '${devices.length} dari $devLimit slot HP kasir terpakai${shared.isEmpty ? '' : ' · ${shared.length} HP outlet bersama'}.'},
        for (var k = 0; k < devices.length; k++)
          {
            'type': 'entry', 't': '${devices[k]['label'] ?? 'HP ${devices[k]['slot']}'}',
            'lines': ['Slot ${devices[k]['slot']} · ${devices[k]['paired'] == true ? 'terhubung' : 'menunggu HP masuk'}${_seen(devices[k]['last_seen_at'])}'],
            'badge': '', 'avatar': '📱', 'svg': '', 'color': '', 'amount': '', 'btns': [{'t': 'Cabut', 'on': false, 'i': 100 + k}],
          },
        for (final d in shared)
          {'type': 'entry', 't': '${d['label']}', 'lines': ['HP outlet bersama${_seen(d['last_seen_at'])}'], 'badge': '', 'avatar': '👥', 'svg': '', 'color': '', 'amount': '', 'btns': <dynamic>[]},
      ],
      {'type': 'title', 't': 'Stok cabang'},
      {'type': 'hint', 't': its.isEmpty ? 'Belum ada bahan.' : '${its.length} bahan · $low menipis di cabang ini'},
      if (outletId == host.business.activeOutlet) {'type': 'button', 't': 'Buka Stok', 'primary': false, 'file': '', 'after': false, 'i': 15},
      if (online && info != null) ...[
        {'type': 'title', 't': 'Status cabang'},
        {'type': 'button', 't': active ? 'Nonaktifkan Cabang' : 'Aktifkan Cabang', 'primary': false, 'file': '', 'after': false, 'i': 16},
      ],
    ];
  }

  String _seen(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return ' · aktif ${two(t.day)}/${two(t.month)} ${two(t.hour)}.${two(t.minute)}';
  }

  @override
  void button(int i) {
    switch (i) {
      case 10:
        OutletEditPage.editId = outletId;
        return host.go('outletedit');
      case 11:
        TeamPage.presetOutlet = outletId;
        return host.go('tim');
      case 12:
        return host.go('services');
      case 13:
        CashierPage.presetOutlet = outletId;
        return host.go('cashier');
      case 14:
        StaffRightsPage.presetOutlet = outletId;
        return host.go('aksespegawai');
      case 15:
        return host.go('stock');
      case 16:
        _toggleActive();
        return;
    }
    if (i >= 100 && i - 100 < devices.length) _revoke(devices[i - 100]);
  }

  Future<void> _toggleActive() async {
    final n = _n;
    if (n == null || _busy) return;
    final active = info?['active'] != false;
    _busy = true;
    try {
      await host.server.api('POST', '/outlets/$n/${active ? 'deactivate' : 'activate'}');
      host.toast(active ? 'Cabang dinonaktifkan' : 'Cabang aktif lagi');
      await _load();
    } on ServerFailure catch (e) {
      host.toast(e.offline ? 'Butuh internet' : e.message);
    } finally {
      _busy = false;
    }
  }

  Future<void> _revoke(Map<String, dynamic> d) async {
    if (_busy) return;
    _busy = true;
    try {
      await host.server.api('DELETE', '/devices/cashier/${d['id']}');
      host.toast('HP dicabut · slot bisa dipakai HP lain');
      await _load();
    } on ServerFailure catch (e) {
      host.toast(e.offline ? 'Butuh internet' : e.message);
    } finally {
      _busy = false;
    }
  }
}
