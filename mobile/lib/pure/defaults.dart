// Data contoh bawaan (revisi Koiman): layanan/kategori dan kategori pengeluaran yang umum dipakai laundry,
// supaya aplikasi baru tidak kosong. Hanya diisi sekali dan tidak menimpa data yang sudah ada;
// semuanya bisa diedit / dihapus di Pengaturan.

import '../core/models.dart';

const _all = ['Cuci', 'Kering', 'Setrika', 'Packing'];

/// [nama, ikon, satuan, harga Reguler, alur proses].
const defaultServiceRows = <List<Object>>[
  ['Cuci Setrika', 'Kiloan', 'kg', 7000, _all],
  ['Cuci Kering', 'Cuci Kering', 'kg', 5000, ['Cuci', 'Kering', 'Packing']],
  ['Setrika Saja', 'Setrika', 'kg', 5000, ['Setrika', 'Packing']],
  ['Selimut', 'Selimut', 'pcs', 15000, _all],
  ['Bed Cover', 'Bed Cover', 'pcs', 25000, _all],
  ['Sprei', 'Sprei', 'pcs', 10000, _all],
  ['Boneka', 'Boneka', 'pcs', 15000, ['Cuci', 'Kering', 'Packing']],
  ['Jas', 'Jas', 'pcs', 25000, _all],
  ['Kemeja', 'Kemeja', 'pcs', 8000, _all],
  ['Gaun', 'Gaun', 'pcs', 25000, _all],
  ['Sepatu', 'Sepatu', 'pcs', 25000, ['Cuci', 'Kering', 'Packing']],
  ['Tas', 'Tas', 'pcs', 25000, ['Cuci', 'Kering', 'Packing']],
  ['Karpet', 'Karpet', 'm', 15000, ['Cuci', 'Kering', 'Packing']],
  ['Gorden', 'Gorden', 'm', 10000, _all],
];

/// Layanan contoh: Express = 1,5× (dibulatkan ke Rp500), Kilat = 2× harga Reguler.
List<Service> defaultServices() => [
      for (final r in defaultServiceRows)
        Service({
          'key': '${r[0]}'.toLowerCase(), 'name': r[0], 'unit': r[2], 'icon': r[1],
          'prices': {'Reguler': r[3], 'Express': ((r[3] as int) * 1.5 / 500).round() * 500, 'Kilat': (r[3] as int) * 2},
          'enabled': {'Reguler': true, 'Express': true, 'Kilat': true},
          'proc': List<String>.from(r[4] as List),
        }),
    ];

const defaultExpenseCats = [
  'Deterjen & Bahan Cuci', 'Parfum & Pewangi', 'Plastik & Kemasan', 'Listrik', 'Air', 'Gas', 'Gaji Karyawan', 'Sewa Tempat',
  'Perawatan Mesin', 'Bensin & Transport', 'Internet & Pulsa', 'Perlengkapan', 'Lain-lain',
];

/// Isi data contoh sekali saja. [services] & [settings] diubah di tempat.
/// Mengembalikan (layanan berubah, pengaturan berubah).
(bool, bool) seedDefaults(List<Service> services, Map<String, dynamic> settings) {
  final seed = settings.putIfAbsent('seed203', () => <String, dynamic>{}) as Map;
  var sv = false, st = false;
  if (seed['services'] != true) {
    seed['services'] = true;
    st = true;
    if (services.isEmpty) {
      services.addAll(defaultServices());
      sv = true;
    }
  }
  if (seed['expenseCats'] != true) {
    seed['expenseCats'] = true;
    st = true;
    final cats = settings.putIfAbsent('expenseCats', () => <dynamic>[]) as List;
    final have = {for (final c in cats) '$c'.trim().toLowerCase()};
    for (final c in defaultExpenseCats) {
      if (!have.contains(c.toLowerCase())) cats.add(c);
    }
  }
  return (sv, st);
}
