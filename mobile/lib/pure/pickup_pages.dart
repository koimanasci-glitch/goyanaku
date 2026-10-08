// Antar Jemput (v202): permintaan jemput tanpa berat; berat & item ditimbang di lokasi lewat Tambah Transaksi.
// Data di `goyana-pickup202` (sama dengan Hibrida).
import 'dart:convert';

import '../core/models.dart' show Customer;
import '../core/money.dart';
import '../core/stock.dart' show Couriers;
import 'pages.dart';
import 'views.dart';

const pickupKey = 'goyana-pickup202';
const pickupActiveKey = 'goyana-pickup202-active';
const _status = {'baru': 'Menunggu kurir', 'ditugaskan': 'Ditugaskan', 'sampai': 'Sudah sampai', 'selesai': 'Selesai', 'batal': 'Dibatalkan'};
const pickupWhen = ['Secepatnya', 'Hari ini · pagi', 'Hari ini · siang', 'Hari ini · sore', 'Besok · pagi', 'Besok · siang', 'Besok · sore'];

Future<List<Map<String, dynamic>>> loadPickups(PureHost host) async {
  try {
    final v = jsonDecode(await host.kv.get(pickupKey) ?? '[]');
    if (v is List) return [for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)];
  } catch (_) {}
  return [];
}

String _wa(Object? p) => waNumber(p);

String _map(Map r) {
  final m = '${r['maps'] ?? ''}'.trim();
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(m)) return m;
  final q = m.isNotEmpty ? m : '${r['address'] ?? ''}';
  return q.isEmpty ? '' : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}';
}

String _when(Map r) => [r['when'], r['whenNote']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · ');

/// Daftar Antar Jemput (jemput202).
class PickupPage extends PurePage {
  PickupPage(super.host);
  List<Map<String, dynamic>> list = [];
  List<Map<String, dynamic>> couriers = [];
  String filter = 'aktif';
  /// Peta indeks tombol/pilihan dari [items] terakhir → aksi.
  final Map<int, (String id, String action)> _btn = {};
  final Map<int, String> _sel = {};
  @override
  String get title => 'ANTAR JEMPUT';
  @override
  String get back => 'home';
  @override
  int get navActive => 0;

  @override
  void opened() {
    Future.wait([loadPickups(host), Couriers.load(host.kv)]).then((v) {
      list = v[0] as List<Map<String, dynamic>>;
      couriers = (v[1] as Couriers).list;
      host.refresh();
    });
  }

  Future<void> _save() => host.kv.set(pickupKey, jsonEncode(list));
  bool _done(Map r) => r['status'] == 'selesai' || r['status'] == 'batal';
  List<Map<String, dynamic>> get _liveCouriers => [for (final c in couriers) if (c['deleted'] != true && c['active'] != false) c];

  @override
  List<Map<String, dynamic>> items() {
    _btn.clear();
    _sel.clear();
    final o = host.business.activeOutlet, cs = _liveCouriers;
    final rows = list.where((r) => o.isEmpty || '${r['outlet'] ?? ''}'.isEmpty || r['outlet'] == o).where((r) => filter == 'aktif' ? !_done(r) : _done(r)).toList()
      ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    var nb = 3, ns = 0;
    final out = <Map<String, dynamic>>[
      {'type': 'button', 't': '+ Buat Penjemputan', 'primary': false, 'file': '', 'after': false, 'i': 0},
      {'type': 'buttons', 'options': [
        {'t': 'Aktif', 'svg': '', 'file': '', 'after': false, 'on': filter == 'aktif', 'i': 1},
        {'t': 'Selesai', 'svg': '', 'file': '', 'after': false, 'on': filter == 'selesai', 'i': 2},
      ]},
      if (rows.isEmpty) {'type': 'hint', 't': filter == 'aktif' ? 'Belum ada penjemputan aktif. Tekan + Buat Penjemputan.' : 'Belum ada penjemputan selesai.'},
    ];
    for (final r in rows) {
      final st = '${r['status']}', id = '${r['id']}';
      final k = couriers.where((c) => c['id'] == r['courierId']).firstOrNull;
      out.addAll([
        {'type': 'title', 't': '${st == 'sampai' ? '📍 ' : (st == 'selesai' ? '✅ ' : (st == 'batal' ? '✖ ' : '🛵 '))}${r['name']}'},
        {'type': 'hint', 't': '${_when(r)} · ${_status[st] ?? st}'},
        {'type': 'hint', 't': '${r['address'] ?? ''}'.isEmpty ? 'Alamat belum diisi' : '${r['address']}'},
        if ('${r['service'] ?? ''}'.isNotEmpty) {'type': 'hint', 't': 'Layanan: ${r['service']}'},
        if ('${r['note'] ?? ''}'.isNotEmpty) {'type': 'hint', 't': 'Catatan: ${r['note']}'},
        if (k != null) {'type': 'hint', 't': 'Kurir: ${k['name']}'},
        if ('${r['orderId'] ?? ''}'.isNotEmpty) {'type': 'hint', 't': 'Transaksi: ${r['orderId']}'},
      ]);
      if (st == 'baru' || st == 'ditugaskan') {
        _sel[ns] = id;
        out.add({'type': 'select', 'options': ['Pilih kurir', for (final c in cs) '${c['name']}'], 'index': cs.indexWhere((c) => c['id'] == r['courierId']) + 1, 'i': ns++});
      }
      if (!_done(r)) {
        final acts = <List<String>>[
          ['map', 'Navigasi'],
          if ('${r['phone'] ?? ''}'.isNotEmpty) ['wa', 'WhatsApp'],
          if (st == 'baru' || st == 'ditugaskan') ['assign', 'Tugaskan'],
          if (st == 'ditugaskan' && k != null && '${k['phone'] ?? ''}'.isNotEmpty) ['send', 'Kirim ke Kurir'],
          ['arrive', st == 'sampai' ? 'Lanjut Transaksi' : 'Sampai Lokasi'],
          ['cancel', 'Batalkan'],
        ];
        out.add({'type': 'buttons', 'options': [
          for (final a in acts)
            () {
              _btn[nb] = (id, a[0]);
              return {'t': a[1], 'svg': '', 'file': '', 'after': false, 'on': false, 'i': nb++};
            }(),
        ]});
      }
    }
    return out;
  }

  @override
  void input(int i, Object value) {
    final id = _sel[i], cs = _liveCouriers;
    final r = list.where((x) => x['id'] == id).firstOrNull;
    if (r == null || value is! int) return;
    r['courierId'] = value <= 0 || value > cs.length ? '' : cs[value - 1]['id'];
    _save();
    host.refresh();
  }

  void _open(String url) => host.device.invokeMethod('App.openUrl', {'url': url}).catchError((_) => null);

  @override
  void button(int i) {
    if (i == 0) return host.go('jemputnew202');
    if (i == 1 || i == 2) {
      filter = i == 1 ? 'aktif' : 'selesai';
      return host.refresh();
    }
    final hit = _btn[i];
    if (hit == null) return;
    final r = list.where((x) => x['id'] == hit.$1).firstOrNull;
    if (r == null) return;
    final ms = host.now.millisecondsSinceEpoch;
    switch (hit.$2) {
      case 'map':
        final u = _map(r);
        return u.isEmpty ? host.toast('Alamat belum diisi') : _open(u);
      case 'wa':
        final p = _wa(r['phone']);
        return p.isEmpty ? host.toast('Nomor WhatsApp belum ada') : _open('https://wa.me/$p');
      case 'assign':
        final id = '${r['courierId'] ?? ''}';
        if (id.isEmpty) return host.toast('Pilih kurir dulu');
        r
          ..['status'] = 'ditugaskan'
          ..['ditugaskanAt'] = ms;
        _save();
        final k = couriers.where((c) => c['id'] == id).firstOrNull;
        host.toast('Ditugaskan ke ${k?['name'] ?? 'kurir'}${'${k?['phone'] ?? ''}'.isNotEmpty ? ' · tekan Kirim ke Kurir untuk mengabari lewat WhatsApp' : ''}');
        return host.refresh();
      case 'send':
        final k = couriers.where((c) => c['id'] == r['courierId']).firstOrNull;
        final p = _wa(k?['phone']);
        if (p.isEmpty) return host.toast('Nomor WhatsApp kurir belum ada');
        final text = [
          'Jemput cucian', 'Pelanggan: ${r['name']}${'${r['phone'] ?? ''}'.isEmpty ? '' : ' (${r['phone']})'}', 'Alamat: ${'${r['address'] ?? ''}'.isEmpty ? '-' : r['address']}',
          'Maps: ${_map(r).isEmpty ? '-' : _map(r)}', 'Waktu: ${_when(r).isEmpty ? '-' : _when(r)}',
          if ('${r['service'] ?? ''}'.isNotEmpty) 'Layanan: ${r['service']}', if ('${r['note'] ?? ''}'.isNotEmpty) 'Catatan: ${r['note']}',
          'Timbang di lokasi, lalu isi berat di aplikasi.',
        ].join('\n');
        return _open('https://wa.me/$p?text=${Uri.encodeComponent('$text\n\nSalam, ${k?['name'] ?? ''}')}');
      case 'arrive':
        if (r['status'] != 'sampai') {
          r
            ..['status'] = 'sampai'
            ..['sampaiAt'] = ms;
          _save();
        }
        host.kv.set(pickupActiveKey, jsonEncode(r['id']));
        return host.startOrderFor('${r['name']}');
      default:
        r
          ..['status'] = 'batal'
          ..['batalAt'] = ms;
        _save();
        host.toast('Penjemputan dibatalkan');
        host.refresh();
    }
  }
}

/// Penjemputan Baru (jemputnew202). Revisi Koiman: pelanggan dipilih dari daftar / Tambah Pelanggan (tidak diketik ulang)
/// dan waktu jemput diatur lewat pilihan hari + jam.
class PickupNewPage extends PurePage {
  PickupNewPage(super.host);
  static const days = ['Secepatnya', 'Hari ini', 'Besok', 'Lusa'];
  static final times = [for (var h = 7; h <= 21; h++) for (final m in const ['00', '30']) if (!(h == 21 && m == '30')) '${h.toString().padLeft(2, '0')}.$m'];
  String customer = '', address = '', service = '', note = '', query = '';
  int day = 0, time = 4; // 09.00

  /// True sekali: kembali dari Tambah Pelanggan, isian jangan dikosongkan.
  bool keep = false;
  @override
  String get title => 'PENJEMPUTAN BARU';
  @override
  String get back => 'jemput202';
  @override
  int get navActive => 0;
  @override
  void opened() {
    if (keep) {
      keep = false;
      return;
    }
    customer = address = service = note = query = '';
    day = 0;
    time = 4;
  }

  Customer? get _cust => customer.isEmpty ? null : host.business.customerByName(customer);

  /// Pilih pelanggan: alamat penjemputan mengikuti alamat pelanggan (masih bisa diubah).
  void pick(String name) {
    final c = host.business.customerByName(name);
    if (c == null) return;
    customer = c.name;
    address = c.address;
  }

  List<Customer> get _found {
    final q = query.trim().toLowerCase();
    return [for (final c in host.business.customers) if (q.isEmpty || '${c.name} ${c.phone}'.toLowerCase().contains(q)) c].take(50).toList();
  }

  @override
  List<Map<String, dynamic>> items() {
    Map<String, dynamic> inp(int i, String v, String ph) =>
        {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};
    final c = _cust;
    return [
      {'type': 'hint', 't': 'Berat dan item tidak diisi di sini. Kurir menimbangnya di lokasi, lalu transaksi dibuat saat tombol Sampai Lokasi ditekan.'},
      {'type': 'title', 't': 'Pelanggan'},
      if (c == null) ...[
        {'type': 'button', 't': 'Pilih dari Daftar Pelanggan', 'primary': true, 'file': '', 'after': false, 'i': 10},
        {'type': 'button', 't': '+ Tambah Pelanggan Baru', 'primary': false, 'file': '', 'after': false, 'i': 11},
      ] else ...[
        {'type': 'row', 't': c.name, 's': c.phone, 'btn': 'Ganti', 'svg': c.gender == 'female' ? custAvatarFemale : custAvatarMale, 'i': 10},
        {'type': 'label', 't': 'Alamat penjemputan'},
        inp(2, address, 'Alamat penjemputan'),
        {'type': 'hint', 't': mapsLink(c).isEmpty ? 'Titik lokasi belum ditandai · bisa ditambah lewat Edit Pelanggan.' : '📍 Titik lokasi pelanggan tersimpan · kurir bisa langsung Navigasi.'},
      ],
      {'type': 'title', 't': 'Atur Jam Jemput'},
      {'type': 'buttons', 'cols': 4, 'options': [for (var k = 0; k < days.length; k++) {'t': days[k], 'on': day == k, 'i': 20 + k}]},
      if (day > 0) ...[
        {'type': 'label', 't': 'Jam jemput'},
        {'type': 'select', 'options': times, 'index': time, 'i': 5},
      ] else
        {'type': 'hint', 't': 'Kurir menjemput secepatnya. Pilih hari untuk menentukan jam.'},
      {'type': 'title', 't': 'Lainnya (opsional)'},
      inp(6, service, 'Layanan yang diinginkan'),
      inp(7, note, 'Catatan untuk kurir'),
      {'type': 'button', 't': 'Buat Penjemputan', 'primary': true, 'file': '', 'after': false, 'i': 0},
    ];
  }

  @override
  void input(int i, Object value) {
    if (i == 5) {
      time = value is int ? value.clamp(0, times.length - 1).toInt() : time;
      return host.refresh();
    }
    if (i == 2) address = '$value';
    if (i == 6) service = '$value';
    if (i == 7) note = '$value';
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id != 'pickcust') return null;
    final list = _found;
    return [
      {'type': 'title', 't': 'Pilih Pelanggan', 's': ''},
      {'type': 'input', 'v': query, 'ph': 'Cari nama / no HP', 'i': 0},
      if (list.isEmpty) {'type': 'hint', 't': host.business.customers.isEmpty ? 'Belum ada pelanggan. Tambahkan dulu.' : 'Pelanggan tidak ditemukan.'},
      for (var k = 0; k < list.length; k++)
        {'type': 'card', 't': list[k].name, 's': [list[k].phone, if (list[k].address.isNotEmpty) list[k].address].join(' · '), 'svg': list[k].gender == 'female' ? custAvatarFemale : custAvatarMale, 'ic': '', 'badge': '', 'meta': '', 'on': false, 'i': k},
      {'type': 'button', 't': '+ Tambah Pelanggan Baru', 'primary': true, 'i': 1001},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1000},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id != 'pickcust') return;
    if (kind == 'input') {
      query = '${value ?? ''}';
      return host.refresh();
    }
    if (kind != 'button') return;
    final list = _found;
    host.closePageSheet('pickcust');
    if (index == 1001) return host.addCustomerFor('jemputnew202');
    if (index >= 0 && index < list.length) pick(list[index].name);
    host.refresh();
  }

  @override
  void button(int i) async {
    if (i == 10) {
      query = '';
      return host.openPageSheet('pickcust');
    }
    if (i == 11) return host.addCustomerFor('jemputnew202');
    if (i >= 20 && i < 20 + days.length) {
      day = i - 20;
      return host.refresh();
    }
    final c = _cust;
    if (c == null) return host.toast('Pilih pelanggan dulu');
    final addr = address.trim(), maps = c.maps.trim();
    if (addr.isEmpty && maps.isEmpty) return host.toast('Isi alamat penjemputan');
    final ms = host.now.millisecondsSinceEpoch;
    final list = await loadPickups(host);
    list.add({
      'id': 'jm${ms.toRadixString(36)}', 'name': c.name, 'phone': c.phone, 'address': addr, 'maps': maps, 'when': days[day], 'whenNote': day > 0 ? 'jam ${times[time]}' : '',
      'service': service.trim(), 'note': note.trim(), 'status': 'baru', 'createdAt': ms, 'outlet': host.business.activeOutlet,
    });
    await host.kv.set(pickupKey, jsonEncode(list));
    opened();
    host.go('jemput202');
    host.toast('Penjemputan dibuat');
  }
}
