// Antar Jemput (keputusan Paduka 9 Oktober 2026): penjemputan = pesanan berstatus Penjemputan ('jemput') tanpa berat.
// Jadi tugasnya ikut tampil di tab Penjemputan (Pesanan), Tugas Kurir HP kurir yang ditunjuk, dan pantauan server.
// Berat & layanan ditimbang di lokasi lewat tombol Buat Pesanan; setelah disimpan pesanan masuk Antrian.
// Data lama `goyana-pickup202` (daftar terpisah, versi sebelumnya) tidak dipakai lagi; kuncinya tetap untuk HP kurir lama.
import 'dart:convert';

import '../core/models.dart' show Customer, Order;
import '../core/money.dart';
import '../core/stock.dart' show Couriers;
import 'courier_settings_page.dart' show CourierSettingsPage;
import 'delivery.dart';
import 'pages.dart';
import 'views.dart';

const pickupKey = 'goyana-pickup202';
const pickupActiveKey = 'goyana-pickup202-active';

Future<List<Map<String, dynamic>>> loadPickups(PureHost host) async {
  try {
    final v = jsonDecode(await host.kv.get(pickupKey) ?? '[]');
    if (v is List) return [for (final e in v.whereType<Map>()) Map<String, dynamic>.from(e)];
  } catch (_) {}
  return [];
}

/// Pilihan jam jemput: kode, label tombol, label kartu.
const pickupSlots = [
  ['asap', 'Secepatnya', 'Secepatnya'],
  ['pagi', 'Pagi · 08–11', 'Pagi 08.00–11.00'],
  ['siang', 'Siang · 11–15', 'Siang 11.00–15.00'],
  ['sore', 'Sore · 15–18', 'Sore 15.00–18.00'],
];
const pickupDays = ['Hari ini', 'Besok', 'Lusa'];

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _dayLabel(DateTime day, DateTime now) {
  final a = DateTime(day.year, day.month, day.day), b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  if (diff == 2) return 'Lusa';
  return '${day.day} ${_monthShort[day.month - 1]}';
}

/// Jadwal jemput untuk kartu: "Hari ini, Pagi 08.00–11.00". Pesanan jemput dari Tambah Pesanan: "Dibuat hari ini, 09.12".
String pickupWhen(Order o, DateTime now) {
  final date = DateTime.tryParse('${o.dataset['jemputDate'] ?? ''}');
  final slot = pickupSlots.where((s) => s[0] == '${o.dataset['jemputSlot'] ?? ''}').firstOrNull;
  if (date != null && slot != null) return slot[0] == 'asap' ? 'Secepatnya' : '${_dayLabel(date, now)}, ${slot[2]}';
  final c = o.created?.toLocal();
  return c == null ? 'Jadwal belum diatur' : 'Dibuat ${_dayLabel(c, now).toLowerCase()}, ${_two(c.hour)}.${_two(c.minute)}';
}

/// Nama orang yang memakai HP ini (untuk "Saya sendiri").
String pickupSelfName(PureHost host) {
  final n = host.server.loggedIn ? '${host.server.user['name'] ?? ''}'.trim() : '';
  return n.isNotEmpty ? n : 'Owner';
}

bool _courierMode(PureHost host) => host.server.loggedIn && host.server.role == 'kurir';

/// Kurir aktif yang boleh bertugas di outlet ini (aturan sama dengan Tugas Kurir).
List<Map<String, dynamic>> _couriersFor(List<Map<String, dynamic>> all, String outlet) => [
      for (final k in all)
        if (k['deleted'] != true && k['active'] != false &&
            ((k['outlets'] as List? ?? const []).isEmpty || outlet.isEmpty || (k['outlets'] as List).map((e) => '$e').contains(outlet)))
          k,
    ];

/// Penjemput pesanan ini: nama kurir, atau nama orang yang menjemput sendiri; '' = belum ada.
String pickupWho(Order o, List<Map<String, dynamic>> couriers) {
  final id = '${o.dataset['courier181'] ?? ''}';
  if (id.isNotEmpty) return '${couriers.where((k) => '${k['id']}' == id).firstOrNull?['name'] ?? 'Kurir'}';
  return '${o.dataset['jemputSelf'] ?? ''}';
}

/// Lembar Pilih Kurir (dipakai Buat Penjemputan dan menu ⋮ kartu). Indeks: 0.. kurir, 1000 Saya sendiri, 2000 Buat Akun Kurir, 999 Batal.
List<Map<String, dynamic>> _kurirSheet(PureHost host, List<Map<String, dynamic>> couriers, String chosenId, bool self) => [
      {'type': 'title', 't': 'Pilih Kurir', 's': ''},
      if (couriers.isEmpty) ...[
        {'type': 'hint', 't': 'Belum ada kurir. Buat akun kurir dulu supaya tugas jemput muncul di HP kurir, atau jemput sendiri.'},
        {'type': 'button', 't': '+ Buat Akun Kurir', 'primary': true, 'i': 2000},
      ],
      {'type': 'card', 't': 'Saya sendiri', 's': '${pickupSelfName(host)} · tugas muncul di Tugas Kurir HP ini', 'svg': '', 'ic': '🙋', 'badge': '', 'meta': '', 'on': self, 'i': 1000},
      for (var k = 0; k < couriers.length; k++)
        {'type': 'card', 't': '${couriers[k]['name']}', 's': '${couriers[k]['phone'] ?? ''}', 'svg': '', 'ic': '🛵', 'badge': '', 'meta': '', 'on': '${couriers[k]['id']}' == chosenId, 'i': k},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 999},
    ];

/// Daftar Antar Jemput (jemput202).
class PickupPage extends PurePage {
  PickupPage(super.host);
  List<Map<String, dynamic>> couriers = [];
  String filter = 'aktif';
  /// Pesanan pada kartu ke-k dari [items] terakhir.
  final List<String> _rows = [];
  String _menuId = '';
  @override
  String get title => 'ANTAR JEMPUT';
  @override
  String get back => _courierMode(host) ? 'kurirhome' : 'home';
  @override
  int get navActive => 0;

  @override
  void opened() {
    Couriers.load(host.kv).then((v) {
      couriers = v.list;
      host.refresh();
    });
  }

  String get _outlet => host.business.activeOutlet;
  bool _here(Order o) => _outlet.isEmpty || o.outlet.isEmpty || o.outlet == _outlet;
  String get _me => '${host.server.user['courier_key'] ?? ''}';
  bool _mine(Order o) {
    if (!_courierMode(host)) return true;
    final c = '${o.dataset['courier181'] ?? ''}';
    return c.isEmpty || _me.isEmpty || c == _me;
  }

  List<Order> get _active => [for (final o in host.business.orders) if (o.status == 'jemput' && _here(o) && _mine(o)) o]
    ..sort((a, b) => '${a.dataset['jemputDate'] ?? ''}${_slotRank(a)}'.compareTo('${b.dataset['jemputDate'] ?? ''}${_slotRank(b)}'));
  List<Order> get _done => [
        for (final o in host.business.orders)
          if (_here(o) && _mine(o) && o.status != 'jemput' && (o.dataset['picked'] == '1' || (o.dataset['jemput202'] == '1' && o.isCancelled))) o,
      ].take(30).toList();
  int _slotRank(Order o) => pickupSlots.indexWhere((s) => s[0] == '${o.dataset['jemputSlot'] ?? ''}').clamp(0, 9);

  Order? _order(String id) => host.business.orderById(id);

  @override
  List<Map<String, dynamic>> items() {
    _rows.clear();
    final active = _active, done = _done, courier = _courierMode(host);
    final rows = filter == 'aktif' ? active : done;
    final out = <Map<String, dynamic>>[
      if (!courier) {'type': 'button', 't': '+ Buat Penjemputan', 'primary': false, 'file': '', 'after': false, 'i': 0},
      {'type': 'buttons', 'options': [
        {'t': 'Aktif (${active.length})', 'svg': '', 'file': '', 'after': false, 'on': filter == 'aktif', 'i': 1},
        {'t': 'Selesai', 'svg': '', 'file': '', 'after': false, 'on': filter == 'selesai', 'i': 2},
      ]},
      if (rows.isEmpty) {'type': 'hint', 't': filter == 'aktif' ? (courier ? 'Tidak ada cucian yang harus dijemput.' : 'Belum ada penjemputan aktif. Tekan + Buat Penjemputan.') : 'Belum ada penjemputan selesai.'},
    ];
    for (final o in rows) {
      final k = _rows.length;
      _rows.add(o.id);
      final c = host.business.customerByName(o.name);
      final who = pickupWho(o, couriers);
      final address = '${o.detail['address'] ?? ''}'.trim().isNotEmpty ? '${o.detail['address']}'.trim() : (c?.address ?? '');
      final live = o.status == 'jemput';
      out.add({
        'type': 'pickup', 't': o.name, 'svg': c?.gender == 'female' ? custAvatarFemale : custAvatarMale,
        'when': live ? pickupWhen(o, host.now) : '${o.id} · ${o.items.isEmpty ? 'tanpa layanan' : rp(o.total)}',
        'addr': address.isEmpty ? 'Alamat belum diisi' : address,
        'who': who.isEmpty ? 'Kurir: belum dipilih' : (o.dataset['jemputSelf'] != null && '${o.dataset['courier181'] ?? ''}'.isEmpty ? 'Dijemput: $who' : 'Kurir: $who'),
        'badge': !live ? (o.isCancelled ? 'Dibatalkan' : 'Sudah dijemput') : (who.isEmpty ? 'Menunggu Kurir' : 'Ditugaskan'),
        'tone': !live ? (o.isCancelled ? 'grey' : 'green') : (who.isEmpty ? 'grey' : 'orange'),
        'note': o.note == '-' ? '' : o.note,
        'menu': live && !courier ? 100 + 10 * k + 3 : -1,
        'btns': live
            ? [
                {'t': 'Navigasi', 'kind': 'nav', 'i': 100 + 10 * k},
                {'t': 'Buat Pesanan', 'kind': 'order', 'i': 100 + 10 * k + 1},
                {'t': 'WhatsApp', 'kind': 'wa', 'i': 100 + 10 * k + 2},
              ]
            : [
                {'t': 'Buka Nota', 'kind': 'order', 'i': 100 + 10 * k + 4},
              ],
      });
    }
    return out;
  }

  void _open(String url) => host.device.invokeMethod('App.openUrl', {'url': url}).catchError((_) => null);

  String _maps(Order o) {
    final known = mapsLink(host.business.customerByName(o.name));
    if (known.isNotEmpty) return known;
    final m = '${o.detail['maps'] ?? ''}'.trim();
    if (m.startsWith('http')) return m;
    final q = m.isNotEmpty ? m : '${o.detail['address'] ?? ''}'.trim();
    return q.isEmpty ? '' : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}';
  }

  @override
  void button(int i) {
    if (i == 0) return host.go('jemputnew202');
    if (i == 1 || i == 2) {
      filter = i == 1 ? 'aktif' : 'selesai';
      return host.refresh();
    }
    if (i < 100) return;
    final k = (i - 100) ~/ 10, act = (i - 100) % 10;
    if (k >= _rows.length) return;
    final o = _order(_rows[k]);
    if (o == null) return;
    switch (act) {
      case 0:
        final u = _maps(o);
        return u.isEmpty ? host.toast('Alamat belum diisi') : _open(u);
      case 1:
        if (o.status != 'jemput') return host.openOrder(o.id);
        return host.weighOrder(o.id);
      case 2:
        final p = waNumber(o.phone.isNotEmpty ? o.phone : (host.business.customerByName(o.name)?.phone ?? ''));
        return p.isEmpty ? host.toast('Nomor WhatsApp belum ada') : _open('https://wa.me/$p');
      case 3:
        _menuId = o.id;
        return host.openPageSheet('jmenu');
      case 4:
        return host.openOrder(o.id);
    }
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    final o = _order(_menuId);
    if (o == null) return null;
    if (id == 'jmenu') {
      return [
        {'type': 'title', 't': o.name, 's': pickupWhen(o, host.now)},
        {'type': 'button', 't': 'Ganti Kurir', 'primary': false, 'i': 1},
        {'type': 'button', 't': 'Buka Rincian Pesanan', 'primary': false, 'i': 3},
        {'type': 'button', 't': 'Batalkan Penjemputan', 'primary': false, 'i': 2},
        {'type': 'button', 't': 'Tutup', 'primary': true, 'i': 0},
      ];
    }
    if (id == 'jkurir') {
      return _kurirSheet(host, _couriersFor(couriers, o.outlet.isNotEmpty ? o.outlet : _outlet), '${o.dataset['courier181'] ?? ''}',
          '${o.dataset['courier181'] ?? ''}'.isEmpty && '${o.dataset['jemputSelf'] ?? ''}'.isNotEmpty);
    }
    return null;
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (kind != 'button') return;
    final o = _order(_menuId);
    host.closePageSheet(id);
    if (o == null) return;
    if (id == 'jmenu') {
      if (index == 1) return host.openPageSheet('jkurir');
      if (index == 3) return host.openOrder(o.id);
      if (index == 2) {
        if (!host.kasirCan(3)) return host.toast('Kasir tidak diizinkan membatalkan pesanan');
        host.openFormSheet(FormSheetDef('Batalkan penjemputan?', const [], 'Batalkan', (_) {
          final err = host.business.cancel(o, reason: 'Penjemputan dibatalkan', now: host.now, by: pickupSelfName(host));
          if (err != null) {
            host.toast(err);
            return false;
          }
          host.saveAll();
          host.toast('Penjemputan dibatalkan');
          host.refresh();
          return true;
        }, sub: '${o.name} · ${pickupWhen(o, host.now)}', danger: true));
      }
      return;
    }
    if (id != 'jkurir') return;
    final list = _couriersFor(couriers, o.outlet.isNotEmpty ? o.outlet : _outlet);
    if (index == 2000) {
      CourierSettingsPage.returnTo = 'jemput202';
      return host.go('kurirsetting');
    }
    if (index == 1000) {
      o.dataset['courier181'] = '';
      o.dataset['jemputSelf'] = pickupSelfName(host);
    } else if (index >= 0 && index < list.length) {
      o.dataset['courier181'] = '${list[index]['id']}';
      o.dataset.remove('jemputSelf');
    } else {
      return;
    }
    host.saveAll();
    host.toast('Penjemput: ${pickupWho(o, couriers)}');
    host.refresh();
  }
}

/// Buat Penjemputan (jemputnew202): pelanggan, hari, jam (Secepatnya/Pagi/Siang/Sore), kurir, alamat, catatan.
class PickupNewPage extends PurePage {
  PickupNewPage(super.host);
  String customer = '', address = '', note = '', query = '';
  int day = 0, slot = 0;
  /// Penjemput: id kurir, atau [self] = jemput sendiri.
  String kurir = '';
  bool self = false;
  List<Map<String, dynamic>> couriers = [];
  int _known = -1;

  /// True sekali: kembali dari Tambah Pelanggan / Pengaturan Kurir, isian jangan dikosongkan.
  bool keep = false;
  @override
  String get title => 'BUAT PENJEMPUTAN';
  @override
  String get back => 'jemput202';
  @override
  int get navActive => 0;
  @override
  void opened() {
    CourierSettingsPage.returnTo = '';
    Couriers.load(host.kv).then((v) {
      final live = _couriersFor(v.list, host.business.activeOutlet);
      // Kembali dari Pengaturan Kurir dengan kurir baru: langsung terpilih.
      if (_known >= 0 && live.length > _known && kurir.isEmpty && !self) kurir = '${live.last['id']}';
      _known = -1;
      couriers = v.list;
      host.refresh();
    });
    if (keep) {
      keep = false;
      return;
    }
    customer = address = note = query = kurir = '';
    self = false;
    day = slot = 0;
  }

  List<Map<String, dynamic>> get _live => _couriersFor(couriers, host.business.activeOutlet);
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

  String get _kurirLabel {
    if (self) return 'Saya sendiri (${pickupSelfName(host)})';
    final k = _live.where((x) => '${x['id']}' == kurir).firstOrNull;
    return k == null ? 'Pilih kurir' : '${k['name']}';
  }

  @override
  List<Map<String, dynamic>> items() {
    final c = _cust;
    return [
      {'type': 'title', 't': 'Pelanggan'},
      if (c == null)
        {'type': 'button', 't': 'Pilih Pelanggan', 'primary': true, 'file': '', 'after': false, 'i': 10}
      else
        {'type': 'row', 't': c.name, 's': [c.phone, if (c.address.isNotEmpty) c.address].join(' · '), 'btn': 'Ganti', 'svg': c.gender == 'female' ? custAvatarFemale : custAvatarMale, 'i': 10},
      {'type': 'button', 't': '+ Tambah Pelanggan Baru', 'primary': false, 'file': '', 'after': false, 'i': 11},
      {'type': 'title', 't': 'Jadwal Penjemputan'},
      {'type': 'buttons', 'cols': 3, 'options': [for (var k = 0; k < pickupDays.length; k++) {'t': pickupDays[k], 'on': day == k, 'i': 21 + k}]},
      {'type': 'buttons', 'cols': 2, 'options': [for (var k = 0; k < pickupSlots.length; k++) {'t': pickupSlots[k][1], 'on': slot == k, 'i': 30 + k}]},
      {'type': 'title', 't': 'Pilih Kurir'},
      {'type': 'row', 't': _kurirLabel, 's': self || kurir.isNotEmpty ? 'Tugas muncul di Tugas Kurir' : 'Bisa dipilih nanti lewat ⋮ di kartu', 'btn': 'Pilih', 'svg': '', 'i': 12},
      if (c != null) ...[
        {'type': 'title', 't': 'Alamat Penjemputan'},
        _input(2, address, 'Alamat penjemputan', false),
        {'type': 'hint', 't': mapsLink(c).isEmpty ? 'Titik lokasi belum ditandai · bisa ditambah lewat Edit Pelanggan.' : '📍 Titik lokasi pelanggan tersimpan · bisa langsung Navigasi.'},
      ],
      {'type': 'title', 't': 'Catatan (opsional)'},
      _input(7, note, 'Contoh: rumah warna biru, pagar hitam', true),
      {'type': 'button', 't': 'Buat Penjemputan', 'primary': true, 'file': '', 'after': false, 'i': 0},
    ];
  }

  Map<String, dynamic> _input(int i, String v, String ph, bool multi) =>
      {'type': 'input', 'v': v, 'ph': ph, 'multiline': multi, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};

  @override
  void input(int i, Object value) {
    if (i == 2) address = '$value';
    if (i == 7) note = '$value';
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id == 'jkurir') return _kurirSheet(host, _live, kurir, self);
    if (id != 'pickcust') return null;
    final list = _found;
    return [
      {'type': 'title', 't': 'Pilih Pelanggan', 's': ''},
      {'type': 'input', 'v': query, 'ph': 'Cari nama atau nomor', 'i': 0},
      {'type': 'button', 't': '+ Tambah Pelanggan Baru', 'primary': false, 'i': 1001},
      if (list.isEmpty) {'type': 'hint', 't': host.business.customers.isEmpty ? 'Belum ada pelanggan. Tambahkan dulu.' : 'Pelanggan tidak ditemukan. Tambahkan sebagai pelanggan baru.'},
      for (var k = 0; k < list.length; k++)
        {'type': 'card', 't': list[k].name, 's': [list[k].phone, if (list[k].address.isNotEmpty) list[k].address].join(' · '), 'svg': list[k].gender == 'female' ? custAvatarFemale : custAvatarMale, 'ic': '', 'badge': '', 'meta': '', 'on': list[k].name == customer, 'i': k},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1000},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id == 'jkurir') {
      if (kind != 'button') return;
      host.closePageSheet(id);
      if (index == 2000) {
        keep = true;
        _known = _live.length;
        CourierSettingsPage.returnTo = 'jemputnew202';
        return host.go('kurirsetting');
      }
      final list = _live;
      if (index == 1000) {
        self = true;
        kurir = '';
      } else if (index >= 0 && index < list.length) {
        self = false;
        kurir = '${list[index]['id']}';
      }
      return host.refresh();
    }
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
  void button(int i) {
    if (i == 10) {
      query = '';
      return host.openPageSheet('pickcust');
    }
    if (i == 11) return host.addCustomerFor('jemputnew202');
    if (i == 12) return host.openPageSheet('jkurir');
    if (i >= 21 && i < 21 + pickupDays.length) {
      day = i - 21;
      if (day > 0 && slot == 0) slot = 1; // Secepatnya hanya untuk hari ini
      return host.refresh();
    }
    if (i >= 30 && i < 30 + pickupSlots.length) {
      slot = i - 30;
      if (slot == 0) day = 0;
      return host.refresh();
    }
    if (i != 0) return;
    final c = _cust;
    if (c == null) return host.toast('Pilih pelanggan dulu');
    final addr = address.trim(), maps = c.maps.trim();
    if (addr.isEmpty && maps.isEmpty) return host.toast('Isi alamat penjemputan');
    final b = host.business, now = host.now, by = pickupSelfName(host);
    final hand = handoverOptions(host.settings.raw).contains('Jemput & Antar') ? 'Jemput & Antar' : 'Jemput';
    final outlet = b.activeOutlet.isNotEmpty ? b.activeOutlet : (b.outlets.isEmpty ? '' : b.outlets.first.id);
    final o = b.createOrder(
      customer: c.name, phone: c.phone, dur: 'Reguler', items: const [], ongkir: transportFee(hand, transportCfg(outlet)),
      note: note.trim(), handover: hand, payMethod: 'Bayar Nanti', kasir: by, now: now,
    );
    o.dataset
      ..['jemput202'] = '1'
      ..['jemputDate'] = _ymd(now.add(Duration(days: day)))
      ..['jemputSlot'] = pickupSlots[slot][0];
    if (self) o.dataset['jemputSelf'] = by;
    if (!self && kurir.isNotEmpty) o.dataset['courier181'] = kurir;
    o.detail['address'] = addr;
    if (maps.isNotEmpty) o.detail['maps'] = maps;
    host.saveAll();
    keep = false;
    opened();
    host.go('jemput202');
    host.toast(self || kurir.isNotEmpty ? 'Penjemputan dibuat · masuk Tugas Kurir' : 'Penjemputan dibuat · pilih kurir lewat ⋮');
  }
}
