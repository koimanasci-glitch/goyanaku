// Tampilan akun kurir (Mode Murni): hanya Jemput, Antar, dan Setoran.
// Server hanya mengirim tugas milik kurir ini ke HP-nya, dan menegakkan haknya (menjemput, menimbang dengan harga daftar,
// mengantar, menerima pembayaran di lokasi). Tunai yang ia terima tercatat "dipegang kurir" sampai disetor ke kasir outletnya.

import '../core/models.dart' show Order;
import '../core/money.dart';
import 'pages.dart';
import 'pickup_pages.dart' show loadPickups, pickupWhen;
import 'server_sync.dart' show ServerFailure;
import 'views.dart' show mapsLink;

class CourierHomePage extends PurePage {
  CourierHomePage(super.host);

  /// 0 Jemput, 1 Antar, 2 Setoran.
  int tab = 0;
  Map<String, dynamic>? _cash;
  String _cashNote = '';
  int _requests = 0;

  @override
  String get title => 'TUGAS KURIR';
  @override
  String get back => 'kurirhome';
  @override
  int get navActive => 0;

  String get _me => '${host.server.user['courier_key'] ?? ''}';
  String get _myName {
    final n = '${host.server.user['name'] ?? ''}';
    return n.isEmpty ? 'Kurir' : n;
  }

  /// Transaksi yang baru dibuat di HP ini belum diberi nama kurir oleh server, jadi yang kosong ikut dihitung.
  bool _mine(Order o) {
    final c = '${o.dataset['courier181'] ?? ''}';
    return c.isEmpty || _me.isEmpty || c == _me;
  }

  List<Order> get pickups => [for (final o in host.business.orders) if (o.status == 'jemput' && _mine(o)) o];
  List<Order> get deliveries => [
        for (final o in host.business.orders)
          if ((((o.status == 'siap' || o.status == 'telat') && o.antar) || o.status == 'diantar') && _mine(o)) o,
      ];

  @override
  void opened() {
    loadPickups(host).then((v) {
      _requests = v.where((r) => r['status'] != 'selesai' && r['status'] != 'batal').length;
      host.refresh();
    });
    _loadCash();
  }

  Future<void> _loadCash() async {
    try {
      _cash = await host.server.api('GET', '/courier/cash');
      _cashNote = '';
    } on ServerFailure catch (e) {
      _cashNote = e.offline ? 'Butuh internet untuk melihat catatan setoran.' : e.message;
    }
    host.refresh();
  }

  /// Database pelanggan tidak dikirim ke HP kurir; alamat dan lokasi tugasnya disertakan server di rincian pesanan.
  String _address(Order o) {
    final own = '${o.detail['address'] ?? ''}'.trim();
    final a = own.isNotEmpty ? own : (host.business.customerByName(o.name)?.address ?? '');
    return a.isEmpty ? 'Alamat belum diisi' : a;
  }

  String _maps(Order o) {
    final known = mapsLink(host.business.customerByName(o.name));
    if (known.isNotEmpty) return known;
    final m = '${o.detail['maps'] ?? ''}'.trim();
    if (m.startsWith('http')) return m;
    final q = m.isNotEmpty ? m : '${o.detail['address'] ?? ''}'.trim();
    return q.isEmpty ? '' : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}';
  }

  Map<String, dynamic> _buttons(int k, Order o, String next, {bool pay = false, bool open = false}) => {
        'type': 'buttons',
        'options': [
          {'t': 'Navigasi', 'on': false, 'i': 1000 + 10 * k},
          {'t': 'WhatsApp', 'on': false, 'i': 1001 + 10 * k},
          if (open) {'t': 'Buka Nota', 'on': false, 'i': 1004 + 10 * k},
          if (pay) {'t': 'Bayar', 'on': false, 'i': 1002 + 10 * k},
          {'t': next, 'on': true, 'i': 1003 + 10 * k},
        ],
      };

  @override
  List<Map<String, dynamic>> items() {
    final jemput = pickups, antar = deliveries;
    final out = <Map<String, dynamic>>[
      {
        'type': 'buttons',
        'options': [
          {'t': 'Jemput (${jemput.length})', 'svg': '', 'file': '', 'after': false, 'on': tab == 0, 'i': 0},
          {'t': 'Antar (${antar.length})', 'svg': '', 'file': '', 'after': false, 'on': tab == 1, 'i': 1},
          {'t': 'Setoran', 'svg': '', 'file': '', 'after': false, 'on': tab == 2, 'i': 2},
        ],
      },
    ];
    if (tab == 0) {
      out.add({'type': 'button', 't': '+ Transaksi di Lokasi', 'primary': true, 'file': '', 'after': false, 'i': 3});
      if (_requests > 0) out.add(card('Permintaan jemput', '$_requests permintaan menunggu · buka untuk berangkat', '📍', 4));
      if (jemput.isEmpty) out.add({'type': 'hint', 't': 'Tidak ada cucian yang harus dijemput.'});
      for (var k = 0; k < jemput.length; k++) {
        final o = jemput[k];
        out
          ..add({'type': 'title', 't': '📍 ${o.name}'})
          ..add({'type': 'hint', 't': '${pickupWhen(o, host.now)} · ${_address(o)}${o.note.isEmpty || o.note == '-' ? '' : ' · ${o.note}'}'})
          ..add(_buttons(k, o, o.items.isEmpty ? 'Timbang & Jemput' : 'Sudah Dijemput', open: true));
      }
      out.add({'type': 'hint', 't': 'Timbang di lokasi lewat Buka Nota → Edit. Harga mengikuti daftar harga, tanpa diskon. Kasir mengecek timbangan lagi di outlet.'});
    } else if (tab == 1) {
      if (antar.isEmpty) out.add({'type': 'hint', 't': 'Tidak ada cucian yang harus diantar.'});
      for (var k = 0; k < antar.length; k++) {
        final o = antar[k];
        final going = o.status == 'diantar';
        out
          ..add({'type': 'title', 't': '${going ? '🚚 Sedang diantar' : '📦 Siap diantar'} · ${o.name}'})
          ..add({'type': 'hint', 't': '${o.id} · ${_address(o)} · ${o.remaining > 0 ? 'Tagih ${rp(o.remaining)}' : 'Lunas'}'})
          ..add(_buttons(k, o, going ? 'Sudah Diterima' : 'Mulai Antar', pay: o.remaining > 0));
      }
    } else {
      final cash = _cash;
      final held = _int(cash?['held']), notes = _int(cash?['notes']);
      out.add({
        'type': 'hero', 't': 'Tunai yang Anda pegang', 'v': rp(held),
        's': held > 0 ? '$notes nota · setorkan ke kasir outlet Anda' : 'Tidak ada tunai yang harus disetor',
      });
      if (_cashNote.isNotEmpty) out.add({'type': 'hint', 't': _cashNote});
      out.add({'type': 'button', 't': 'Muat Ulang', 'primary': false, 'file': '', 'after': false, 'i': 5});
      final history = [...(cash?['history'] as List? ?? const []).whereType<Map>()];
      if (history.isNotEmpty) out.add({'type': 'title', 't': 'Riwayat'});
      for (final h in history) {
        final deposit = h['type'] == 'deposit';
        final diff = deposit && h['expected'] != null ? _int(h['amount']) - _int(h['expected']) : 0;
        out.add({
          'type': 'entry',
          't': deposit ? 'Setor ke kasir' : 'Terima tunai · ${h['note_no'] ?? ''}',
          'lines': [
            _time(h['at']),
            if (diff != 0) 'Selisih ${diff < 0 ? '-' : '+'}${rp(diff.abs())} dari catatan ${rp(_int(h['expected']))}',
          ],
          'badge': '', 'avatar': deposit ? '✓' : '💵', 'svg': '', 'color': '', 'amount': rp(_int(h['amount'])), 'btns': <dynamic>[],
        });
      }
      out.add({'type': 'hint', 't': 'Tunai dari pelanggan tercatat atas nama Anda sampai kasir menerima setorannya.'});
    }
    return out;
  }

  @override
  void button(int i) {
    if (i >= 0 && i <= 2) {
      tab = i;
      if (i == 2) _loadCash();
      return host.refresh();
    }
    if (i == 3) return host.go('addorder');
    if (i == 4) return host.go('jemput202');
    if (i == 5) {
      _loadCash();
      return;
    }
    if (i < 1000) return;
    final list = tab == 0 ? pickups : deliveries;
    final k = (i - 1000) ~/ 10, act = (i - 1000) % 10;
    if (tab == 2 || k >= list.length) return;
    final o = list[k];
    switch (act) {
      case 0:
        final m = _maps(o);
        if (m.isEmpty) return host.toast('Lokasi belum tersedia');
        host.device.invokeMethod('App.openUrl', {'url': m}).catchError((_) => null);
      case 1:
        final p = waNumber(o.phone.isNotEmpty ? o.phone : (host.business.customerByName(o.name)?.phone ?? ''));
        if (p.isEmpty) return host.toast('Nomor WA belum ada');
        host.device.invokeMethod('App.openUrl', {'url': 'https://wa.me/$p'}).catchError((_) => null);
      case 2:
        host.payOrder(o.id);
      case 4:
        host.openOrder(o.id);
      default:
        final st = o.status;
        // Penjemputan tanpa layanan: timbang di lokasi dulu (Isi Layanan & Berat), lalu masuk Antrian.
        if (st == 'jemput' && o.items.isEmpty) return host.weighOrder(o.id);
        // Serah terima yang belum lunas: tampilkan Pembayaran dulu (bisa "Hutang Dulu" bila usaha mengizinkan).
        if (o.remaining > 0 && st == 'diantar') return host.advanceOrder(o.id, by: _myName);
        host.business.advance(o, now: host.now, by: _myName);
        host.saveAll();
        host.toast(st == 'jemput' ? 'Sudah dijemput · masuk Antrian outlet' : (st == 'diantar' ? 'Sudah diterima pelanggan · selesai' : 'Pengantaran dimulai'));
        host.refresh();
    }
  }
}

int _int(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;

String _time(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}.${two(t.minute)}';
}
