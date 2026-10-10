// Pengaturan → Kelola Usaha (keputusan Paduka 10 Oktober 2026): semua fitur cabang & kontrol dikumpulkan di satu halaman,
// supaya tampilan utama (Beranda, Tambah Transaksi, Pesanan, menu bawah) tidak berubah. Empat kelompok:
// Cabang & Tim · Monitor & Laporan · Kontrol · Operasional. Isinya membuka halaman yang sudah ada.

import 'pages.dart';

class KelolaUsahaPage extends PurePage {
  KelolaUsahaPage(super.host);

  @override
  String get title => 'KELOLA USAHA';

  /// [judul, keterangan, ikon, halaman tujuan]
  static const groups = <(String, List<(String, String, String, String)>)>[
    ('Cabang & Tim', [
      ('Outlet & Cabang', 'Profil, zona waktu, tambah cabang', '🏪', 'outlets'),
      ('Tim', 'Kasir, pegawai, kurir & kepala cabang per cabang', '👥', 'tim'),
      ('Hak Akses Kasir', 'Fitur yang boleh dipakai kasir, per cabang', '🔑', 'cashier'),
      ('Hak Akses Pegawai', 'Yang boleh dilihat & dicatat pegawai, per cabang', '🔐', 'aksespegawai'),
      ('Tugas Kurir', 'Antar-jemput dan setoran tunai kurir', '🛵', 'couriers'),
    ]),
    ('Monitor & Laporan', [
      ('Monitor Cabang', 'Omset, antrian, kas, dan peringatan tiap cabang', '📡', 'superbilling'),
      ('Laporan', 'Per cabang atau semua cabang', '📊', 'reports'),
    ]),
    ('Kontrol', [
      ('Koreksi Transaksi', 'Perubahan setelah diproses/dibayar, per kasir', '⚠️', 'koreksi'),
      ('Audit Aktivitas', 'Riwayat kejadian semua HP & cabang', '🛡️', 'audit'),
      ('Ralat & PIN Admin', 'Ralat pembayaran/pengeluaran, PIN Admin', '✎', 'ralat139'),
    ]),
    ('Operasional', [
      ('Stok & Bahan', 'Stok per cabang, cek stok, kirim ke cabang', '🧴', 'stock'),
      ('Reminder Pekerjaan', 'Deadline, telat, stok menipis, belum bayar', '⏰', 'reminder'),
    ]),
  ];

  @override
  List<Map<String, dynamic>> items() {
    final out = <Map<String, dynamic>>[
      {'type': 'hint', 't': 'Semua pengaturan cabang, tim, dan kontrol usaha ada di sini.'},
    ];
    var i = 0;
    for (final (name, list) in groups) {
      out.add({'type': 'title', 't': name});
      for (final (t, s, ic, _) in list) {
        out.add({'type': 'card', 't': t, 's': s, 'svg': '', 'ic': ic, 'badge': '', 'meta': '', 'on': false, 'i': i++});
      }
    }
    return out;
  }

  /// Halaman tujuan kartu ke-[i].
  static String? target(int i) {
    var k = 0;
    for (final (_, list) in groups) {
      for (final e in list) {
        if (k++ == i) return e.$4;
      }
    }
    return null;
  }

  @override
  void button(int i) {
    final to = target(i);
    if (to != null) host.go(to);
  }
}
