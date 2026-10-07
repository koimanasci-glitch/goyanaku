// Beranda Laporan Dart (A8): ringkasan, KPI, cari & daftar 39 laporan dihitung langsung dari database Dart.
import '../logic/reports_a8.dart';
import '../logic/reports_catalog.dart';
import '../native/reports_page.dart';

const _cats = [
  ('keu', 'Keuangan', '💰', '#FFF4E5'),
  ('trx', 'Transaksi', '🧾', '#EAF2FD'),
  ('plg', 'Pelanggan', '👥', '#F3EFFF'),
  ('peg', 'Pegawai', '🧑‍🔧', '#E9F7EF'),
  ('stk', 'Stok & Bahan', '📦', '#FFF0F1'),
  ('ops', 'Operasional', '⏱️', '#EEF4FF'),
  ('exp', 'Export Data', '📤', '#F1F2F5'),
];

/// Id kategori sesuai urutan chip (setelah "Semua").
const reportCategoryIds = ['keu', 'trx', 'plg', 'peg', 'stk', 'ops', 'exp'];

/// Laporan yang bisa dibuka sebagai halaman detail Dart (selain tautan ke halaman lain).
bool reportHasDetail(String id) => reportIdsA8.contains(id) || id == 'hpp182' || id == 'labaop182';

/// Laporan tambahan v182 (HPP Bahan Terpakai, Laba Operasional) yang butuh data stok; diisi oleh shell.
Object? Function(String id, RepCtx ctx, RepRange r)? reportExtra;

/// Data satu laporan: laporan v182 dari [reportExtra], selebihnya logika A8.
Object? reportAny(String id, RepCtx ctx, RepRange r) => (id == 'hpp182' || id == 'labaop182') ? reportExtra?.call(id, ctx, r) : reportA8(id, ctx, r);

/// Id laporan pada urutan tampil (sesuai bagian & saringan) — indeks `rpOpen(i)` merujuk ke daftar ini.
List<String> reportVisibleIds({String cat = 'all', String query = ''}) {
  final q = query.toLowerCase();
  final out = <String>[];
  for (final c in _cats) {
    for (final e in reportCatalogA8) {
      if (e.$2 != c.$1) continue;
      if (cat != 'all' && e.$2 != cat) continue;
      if (q.isNotEmpty && !('${e.$3} ${e.$5} ${c.$2}').toLowerCase().contains(q)) continue;
      out.add(e.$1);
    }
  }
  return out;
}

ReportsModel reportsHubA8(RepCtx ctx, {required String periodKey, DateTime? from, DateTime? to, String cat = 'all', String query = '', String outlet = ''}) {
  final r = ctx.range(periodKey, from: from, to: to);
  final o = ctx.ords(r), pvOrd = ctx.ords(ctx.prev(r));
  num sum<T>(Iterable<T> a, num Function(T) f) => a.fold<num>(0, (s, x) => s + f(x));
  final v = sum(o, (x) => x.total), pv = sum(pvOrd, (x) => x.total);
  final exps = ctx.exps(r);
  final e = sum(exps, (x) => x.a);
  final m = reportA8('metode', ctx, r) as Map;
  final inc = sum(o.where((x) => x.isPaid), (x) => x.received) + sum(ctx.incs(r), (x) => x.a);
  final piut = sum(ctx.orders.where((x) => x.owed > 0 && x.st != 'batal'), (x) => x.owed);
  final nb = ctx.first.values.where((t) => !t.isBefore(r.s) && t.isBefore(r.e)).length;
  final label = periodLabelA8(periodKey, r);
  final trend = pv != 0 ? ' · ${(((v - pv) / pv * 100).round() >= 0 ? '▲ ' : '▼ ')}${((v - pv) / pv * 100).round().abs()}% vs sebelumnya' : '';
  final methods = [
    for (final k in (m['k'] as List).take(4)) RpTile(title: '${(k as List)[0]}', value: shA8(_amount(ctx, r, '${k[0]}'))),
  ];
  final visible = reportVisibleIds(cat: cat, query: query);
  var idx = 0;
  final sections = <RpSection>[];
  for (final c in _cats) {
    final items = <RpTile>[];
    for (final id in visible) {
      final ent = reportCatalogA8.firstWhere((x) => x.$1 == id);
      if (ent.$2 != c.$1) continue;
      items.add(RpTile(index: idx++, icon: ent.$4, bg: c.$4, title: ent.$3, sub: ent.$5, value: _preview(ctx, r, id)));
    }
    if (items.isNotEmpty) sections.add(RpSection('${c.$3} ${c.$2}', items));
  }
  return ReportsModel(
    title: 'Laporan',
    outlet: outlet,
    periods: [for (final p in reportPeriodsA8) RpChip(p.$2, on: p.$1 == periodKey)],
    heroLabel: 'Omzet · $label',
    heroBig: rpA8(v),
    heroSub: '${o.length} pesanan · rata-rata ${rpA8(o.isNotEmpty ? v / o.length : 0)}$trend',
    methods: methods,
    kpis: [
      RpTile(index: 0, icon: '↘', bg: '#FFF0F1', title: 'Pengeluaran', sub: '${exps.length} catatan', value: shA8(e)),
      RpTile(index: 1, icon: '＝', bg: '#EAF7E4', title: 'Laba bersih', sub: inc != 0 ? '${((inc - e) / inc * 100).round()}% margin' : '', value: shA8(inc - e)),
      RpTile(index: 2, icon: '⏳', bg: '#FFF6DF', title: 'Belum dibayar', sub: 'piutang berjalan', value: shA8(piut)),
      RpTile(index: 3, icon: '＋', bg: '#F3EFFF', title: 'Pelanggan baru', sub: label, value: '$nb orang'),
    ],
    quick: const [
      RpTile(index: 0, icon: '＋', bg: '#EAF7E4', title: 'Kas Masuk'),
      RpTile(index: 1, icon: '−', bg: '#FFF0F1', title: 'Pengeluaran'),
      RpTile(index: 2, icon: '✓', bg: '#EAF2FD', title: 'Tutup Kasir'),
      RpTile(index: 3, icon: '✎', bg: '#F3EFFF', title: 'Ralat'),
    ],
    search: query,
    placeholder: 'Cari laporan… (mis. piutang, pegawai, stok)',
    cats: [
      RpChip('Semua', on: cat == 'all'),
      for (final c in _cats) RpChip('${c.$3} ${c.$2}', on: cat == c.$1),
    ],
    sections: sections,
    empty: sections.isEmpty ? 'Tidak ada laporan yang cocok' : '',
  );
}

num _amount(RepCtx ctx, RepRange r, String method) {
  final m = reportA8('metode', ctx, r) as Map;
  for (final row in (m['rows'] as List)) {
    final l = row as List;
    if (l[0] == method) {
      final t = '${l[2]}'.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(t) ?? 0;
    }
  }
  return 0;
}

String _preview(RepCtx ctx, RepRange r, String id) {
  if (id.startsWith('x-') || id == 'ralat' || id == 'tutup') return '';
  try {
    final o = reportAny(id, ctx, r);
    if (o is! Map || o['pv'] == null) return '';
    final pv = o['pv'];
    if (pv is num) return o['unit'] == null ? shA8(pv) : '$pv ${o['unit']}';
    return '$pv';
  } catch (_) {
    return '';
  }
}

/// Kategori kartu detail laporan (nama kategori dari id).
String reportCategoryName(String id) {
  final e = reportCatalogA8.firstWhere((x) => x.$1 == id);
  return _cats.firstWhere((c) => c.$1 == e.$2).$2;
}
