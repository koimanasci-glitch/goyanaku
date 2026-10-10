// Pengaturan → Hak Akses Pegawai (keputusan Paduka 10 Oktober 2026): sakelar per cabang untuk pegawai produksi.
// Tersimpan di setelan usaha bersama (tpl.pegawai) dan ditegakkan server (App\Support\StaffRights):
// nomor HP & nilai pesanan hanya dikirim ke HP pegawai bila diizinkan; catatan stok pegawai ditolak bila dimatikan.

import 'pages.dart';

class StaffRightsPage extends PurePage {
  StaffRightsPage(super.host);

  /// [judul, keterangan, bawaan] — urutan = indeks yang dibaca server (phone 0, price 1, stock 2).
  static const rights = [
    ('Lihat nomor HP pelanggan', 'Untuk menghubungi pelanggan dari HP pegawai', false),
    ('Lihat nilai pesanan (Rp)', 'Harga, total, dan pembayaran tampil di HP pegawai', false),
    ('Catat bahan dipakai', 'Pegawai mencatat pemakaian stok bahan di cabangnya', true),
  ];

  String outlet = '';

  @override
  String get title => 'HAK AKSES PEGAWAI';

  @override
  void opened() => outlet = '';

  Map<String, dynamic> get _cfg {
    final tpl = host.settings.raw.putIfAbsent('tpl', () => <String, dynamic>{}) as Map;
    return (tpl.putIfAbsent('pegawai', () => <String, dynamic>{}) as Map).cast<String, dynamic>();
  }

  Map<String, dynamic> _bag(String key) => (_cfg.putIfAbsent(key, () => <String, dynamic>{}) as Map).cast<String, dynamic>();
  Map<String, dynamic> _outletBag(String id) => (_bag('tgOutlet').putIfAbsent(id, () => <String, dynamic>{}) as Map).cast<String, dynamic>();

  bool value(int i) {
    if (outlet.isNotEmpty) {
      final v = (_bag('tgOutlet')[outlet] as Map?)?['$i'];
      if (v is bool) return v;
    }
    final v = _bag('tg')['$i'];
    return v is bool ? v : rights[i].$3;
  }

  @override
  List<Map<String, dynamic>> items() {
    final outs = host.business.outlets;
    final name = outs.where((o) => o.id == outlet).firstOrNull?.name ?? '';
    return [
      {'type': 'hint', 't': 'Pegawai memajukan tahap cucian (cuci, kering, setrika, packing). Atur apa saja yang boleh mereka lihat dan catat.'},
      if (outs.length > 1) ...[
        {'type': 'buttons', 'options': [
          {'t': 'Semua Cabang', 'on': outlet.isEmpty, 'i': 700},
          for (var n = 0; n < outs.length; n++) {'t': outs[n].name, 'on': outlet == outs[n].id, 'i': 701 + n},
        ]},
        {'type': 'hint', 't': outlet.isEmpty ? 'Setelan umum: dipakai cabang yang belum diatur sendiri.' : 'Setelan khusus $name. Yang belum diubah mengikuti setelan umum.'},
      ],
      for (var i = 0; i < rights.length; i++) {'type': 'toggle', 't': rights[i].$1, 's': rights[i].$2, 'on': value(i), 'i': i},
      {'type': 'hint', 't': host.server.loggedIn
          ? 'Berlaku untuk akun pegawai yang masuk ke GOYANA. Perubahan tampil di HP pegawai saat data pesanan berikutnya terkirim.'
          : 'Berlaku setelah usaha tersambung ke akun GOYANA dan pegawai masuk dengan akunnya sendiri.'},
    ];
  }

  @override
  void toggle(int i) {
    if (i < 0 || i >= rights.length) return;
    (outlet.isEmpty ? _bag('tg') : _outletBag(outlet))['$i'] = !value(i);
    host.saveAll();
    host.refresh();
  }

  @override
  void button(int i) {
    final outs = host.business.outlets;
    if (i == 700) outlet = '';
    if (i > 700 && i <= 700 + outs.length) outlet = outs[i - 701].id;
    host.refresh();
  }
}
