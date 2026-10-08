// A8 Laporan — kelompok Keuangan (10), Transaksi (7), Pelanggan (6), Pegawai (4), Stok (4), Operasional (4), Export (4).
// Menyalin hitungan mesin HTML (goyana-v170-reports-script) apa adanya; HTML tetap pembanding (paritas).
// Waktu dipakai sebagai "jam dinding" (UTC yang sudah digeser zona perangkat) agar hasil sama di tiap mesin uji.
import 'dart:math' as math;

import '../core/models.dart' show Order, durationHours;

const reportIdsA8 = [
  // Keuangan
  'omzet', 'arus', 'ptrx', 'metode', 'lain', 'keluar', 'piutang', 'diskon', 'bulat', 'laba',
  // Transaksi
  'semua', 'layanan', 'durasi', 'status', 'batal', 'telat', 'antar',
  // Pelanggan
  'tumbuh', 'toppl', 'lamabaru', 'poin', 'pasif', 'kasbon',
  // Pegawai
  'kinerja', 'presensi', 'komisi', 'kurir',
  // Stok & Bahan
  'stok', 'pakai', 'beli', 'nilai',
  // Operasional
  'jam', 'hari', 'waktu', 'kapasitas',
  // Export (baris tabel CSV)
  'x-keu', 'x-trx', 'x-plg', 'x-peg',
];
const _day = Duration.millisecondsPerDay;
const _bl = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _hr = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
const _stn = {
  'antrian': ['Antrian', 'b'], 'proses': ['Proses', 'b'], 'siap': ['Siap Ambil', 'g'],
  'telat': ['Telat Ambil', 'r'], 'diambil': ['Selesai', ''], 'batal': ['Batal', 'r'],
};

num _num(Object? v) {
  if (v is num) return v.isNaN ? 0 : v;
  final p = num.tryParse('${v ?? ''}'.trim());
  return p == null || p.isNaN ? 0 : p;
}

/// Math.round milik JavaScript: pecahan .5 naik (ke arah +tak hingga).
int jsRound(num x) => (x + 0.5).floor();
Object _norm(num n) => n == n.truncate() && n.abs() < 9e15 ? n.toInt() : n;
String _group(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
String rpA8(num n) => '${n < 0 ? '−' : ''}Rp${_group(jsRound(n.abs()))}';
String _pad(int n) => n < 10 ? '0$n' : '$n';
String _esc(Object? t) => '${t ?? ''}'.replaceAllMapped(RegExp('[&<>"\']'),
    (m) => const {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[m[0]]!);
String _dmy(DateTime d) => '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
String _dm(DateTime d) => '${d.day} ${_bl[d.month - 1]}';
int _jsDay(DateTime d) => d.weekday % 7;
DateTime _d0(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

class RepOrder {
  RepOrder(this.raw)
      : id = '${raw['id'] ?? ''}',
        c = '${raw['c'] ?? ''}',
        m = '${raw['m'] ?? ''}',
        st = '${raw['st'] ?? ''}',
        total = _num(raw['total']),
        paid = _num(raw['paid']),
        disc = _num(raw['disc']),
        rd = _num(raw['rd']),
        ong = _num(raw['ong']),
        kg = _num(raw['kg']),
        dur = '${raw['dur'] ?? ''}',
        antar = raw['antar'] == true,
        pts = _num(raw['pts']),
        items = [
          for (final it in (raw['items'] as List? ?? const []).whereType<Map>())
            (n: '${it['n'] ?? ''}', u: '${it['u'] ?? ''}', q: _num(it['q']), t: _num(it['t']))
        ],
        payments = [
          for (final p in (raw['payments178'] as List? ?? const []).whereType<Map>()) (m: '${p['m'] ?? ''}', a: _num(p['a']))
        ];
  final Map raw;
  final String id, c, m, st, dur;
  final bool antar;
  final List<({String n, String u, num q, num t})> items;
  final num total, paid, disc, rd, ong, kg, pts;
  String get staff => '${raw['staff'] ?? ''}';
  final List<({String m, num a})> payments;
  late DateTime t;
  DateTime? done, due;

  num get received => m == 'Batal' ? 0 : math.max(0, math.min(total, paid));
  num get cashReceived {
    if (m == 'Batal') return 0;
    if (payments.isNotEmpty) return payments.where((p) => p.m != 'Deposit').fold<num>(0, (s, p) => s + p.a);
    return m == 'Deposit' ? 0 : received;
  }

  num get owed => math.max(0, total - received);
  bool get isPaid => received > 0;
}

class RepMoney {
  RepMoney(this.t, this.a, this.cat, this.note, {this.deposit = false});
  final DateTime t;
  final num a;
  final String cat, note;
  final bool deposit;
}

class RepRange {
  RepRange(this.s, this.e) : days = math.max(1, jsRound((e.millisecondsSinceEpoch - s.millisecondsSinceEpoch) / _day));
  final DateTime s, e;
  final int days;
}

class RepAtt {
  RepAtt(this.d, this.s, this.inAt, this.outAt);
  final DateTime d, inAt, outAt;
  final String s;
}

class RepStock {
  RepStock(this.n, this.now, this.min, this.u, this.per, this.buy);
  final String n, u;
  final num now, min, per, buy;
}

class RepCtx {
  RepCtx({
    required this.now,
    required this.t0,
    required this.orders,
    required this.exp,
    required this.inc,
    required this.first,
    this.tzMs = 0,
    this.att = const [],
    this.stock = const [],
    this.staff = const ['Rina', 'Dewi', 'Andi'],
  });
  /// Selisih zona perangkat (ms) yang dipakai untuk mengubah waktu epoch menjadi jam dinding.
  final int tzMs;
  DateTime wallOf(Object? v) =>
      _ms((v is num ? v.toInt() : DateTime.parse('$v').millisecondsSinceEpoch) + tzMs);
  final List<RepAtt> att;
  final List<RepStock> stock;
  final List<String> staff;
  final DateTime now, t0;
  final List<RepOrder> orders;
  final List<RepMoney> exp, inc;
  final Map<String, DateTime> first;

  /// [state] = keluaran `__goyanaReportsA8()` (waktu dalam ms epoch + `tz` menit).
  factory RepCtx.fromJson(Map state) {
    final tz = _num(state['tz']).toInt() * 60000;
    DateTime w(Object? v) => _ms((v is num ? v.toInt() : DateTime.parse('$v').millisecondsSinceEpoch) + tz);
    final orders = [
      for (final o in (state['ord'] as List).whereType<Map>()) RepOrder(o)
        ..t = w(o['t'])
        ..done = o['done'] == null ? null : w(o['done'])
        ..due = o['due'] == null ? null : w(o['due'])
    ];
    final first = <String, DateTime>{};
    for (final o in orders) {
      final f = first[o.c];
      if (f == null || f.isAfter(o.t)) first[o.c] = o.t;
    }
    return RepCtx(
      att: [
        for (final x in (state['att'] as List? ?? const []).whereType<Map>()) RepAtt(w(x['d']), '${x['s']}', w(x['in']), w(x['out']))
      ],
      stock: [
        for (final x in (state['stock'] as List? ?? const []).whereType<Map>())
          RepStock('${x['n']}', _num(x['now']), _num(x['min']), '${x['u'] ?? ''}', _num(x['per']), _num(x['buy']))
      ],
      staff: [for (final x in (state['staff'] as List? ?? const ['Rina', 'Dewi', 'Andi'])) '$x'],
      tzMs: tz,
      now: w(state['now']),
      t0: w(state['t0']),
      orders: orders,
      first: first,
      exp: [for (final x in (state['exp'] as List).whereType<Map>()) RepMoney(w(x['t']), _num(x['a']), '${x['cat'] ?? 'Lain-Lain'}', '${x['note'] ?? ''}')],
      inc: [
        for (final x in (state['inc'] as List).whereType<Map>())
          RepMoney(w(x['t']), _num(x['a']), '', '${x['note'] ?? ''}', deposit: x['deposit178'] == true)
      ],
    );
  }

  RepRange range(String key, {DateTime? from, DateTime? to}) {
    var e = t0.add(const Duration(milliseconds: _day));
    late DateTime s;
    switch (key) {
      case 'today':
        s = t0;
      case '7':
        s = t0.subtract(const Duration(milliseconds: 6 * _day));
      case '30':
        s = t0.subtract(const Duration(milliseconds: 29 * _day));
      case 'month':
        s = DateTime.utc(t0.year, t0.month, 1);
      case 'last':
        s = DateTime.utc(t0.year, t0.month - 1, 1);
        e = DateTime.utc(t0.year, t0.month, 1);
      default:
        s = from ?? t0.subtract(const Duration(milliseconds: 29 * _day));
        e = (to ?? t0).add(const Duration(milliseconds: _day));
    }
    return RepRange(s, e);
  }

  RepRange prev(RepRange r) {
    final len = r.e.millisecondsSinceEpoch - r.s.millisecondsSinceEpoch;
    return RepRange(_ms(r.s.millisecondsSinceEpoch - len), r.s);
  }

  bool _in(DateTime t, RepRange r) => !t.isBefore(r.s) && t.isBefore(r.e);
  List<RepOrder> ords(RepRange r, {bool all = false}) => [for (final o in orders) if (_in(o.t, r) && (all || o.st != 'batal')) o];
  List<RepMoney> exps(RepRange r) => [for (final x in exp) if (_in(x.t, r)) x];
  List<RepMoney> incs(RepRange r) => [for (final x in inc) if (!x.deposit && _in(x.t, r)) x];
  List<RepMoney> cashIncs(RepRange r) => [for (final x in inc) if (_in(x.t, r)) x];
}

num _sum<T>(Iterable<T> a, num Function(T) f) => a.fold<num>(0, (s, x) => s + f(x));

String _trend(num cur, num prev) {
  if (prev == 0) return '';
  final p = jsRound((cur - prev) / prev * 100);
  return '${p >= 0 ? '▲ ' : '▼ '}${p.abs()}% vs sebelumnya';
}

List<List<Object>> _buckets(RepRange r, List<({DateTime t, num v})> list) {
  if (r.days <= 1) {
    final keys = <int>[for (var h = 7; h <= 21; h++) h];
    final map = <int, num>{for (final h in keys) h: 0};
    for (final x in list) {
      final h = x.t.hour;
      if (map[h] == null) {
        map[h] = 0;
        keys.add(h);
      }
      map[h] = map[h]! + x.v;
    }
    keys.sort();
    return [for (final h in keys) [_pad(h), map[h]!, 'Jam ${_pad(h)}.00']];
  }
  final step = r.days > 45 ? 7 : 1;
  final keys = <int>[];
  final map = <int, num>{};
  for (var t = r.s.millisecondsSinceEpoch; t < r.e.millisecondsSinceEpoch; t += step * _day) {
    keys.add(t);
    map[t] = 0;
  }
  for (final x in list) {
    final t = _d0(x.t).millisecondsSinceEpoch;
    int? k;
    for (final kk in keys) {
      if (kk <= t) k = kk;
    }
    if (k != null) map[k] = map[k]! + x.v;
  }
  return [
    for (final k in keys)
      () {
        final d = _ms(k);
        return <Object>[
          step > 1 ? _dm(d) : (r.days <= 7 ? _hr[_jsDay(d)] : '${d.day}'),
          map[k]!,
          step > 1 ? 'Minggu ${_dm(d)}' : '${_hr[_jsDay(d)]}, ${_dm(d)} ${d.year}',
        ];
      }()
  ];
}

List<({DateTime t, num v})> _tv<T>(Iterable<T> a, DateTime Function(T) t, num Function(T) v) =>
    [for (final x in a) (t: t(x), v: v(x))];

List<List<Object>> _methodRows(RepCtx c, RepRange r) {
  final entries = <({String m, num a})>[];
  for (final o in c.ords(r)) {
    entries.addAll(o.payments.isNotEmpty ? o.payments : [(m: o.m, a: o.received)]);
  }
  return [
    for (final m in const ['Tunai', 'QRIS', 'Transfer', 'Deposit'])
      () {
        final a = entries.where((x) => x.m == m && x.a > 0).toList();
        return <Object>[m, a.length, _sum(a, (x) => x.a)];
      }()
  ];
}

List<T> _sortedDesc<T>(List<T> a, num Function(T) key) {
  final idx = List<int>.generate(a.length, (i) => i);
  idx.sort((x, y) {
    final c = key(a[y]).compareTo(key(a[x]));
    return c != 0 ? c : x.compareTo(y);
  });
  return [for (final i in idx) a[i]];
}

List<Object> _kpi(String a, String b, String c, [String? tone]) => [a, b, c, ?tone];

/// toLocaleString('id-ID'): titik ribuan, koma desimal (maks. 3 angka di belakang koma).
String _idNum(num n) {
  final neg = n < 0;
  var s = n.abs().toStringAsFixed(3);
  var parts = s.split('.');
  var frac = parts[1].replaceFirst(RegExp(r'0+$'), '');
  final out = _group(int.parse(parts[0])) + (frac.isEmpty ? '' : ',$frac');
  return neg ? '-$out' : out;
}

Object _jsonNum(Object? v) => v is num ? _norm(v) : v!;

/// Hasil satu laporan (keluaran `REP170[i].f(range)` di HTML; untuk export `exp(range)` = daftar baris), atau null bila belum dipindah.
Object? reportA8(String id, RepCtx c, RepRange r) {
  switch (id) {
    case 'omzet':
      {
        final o = c.ords(r), pv = c.ords(c.prev(r));
        final v = _sum(o, (x) => x.total), pvv = _sum(pv, (x) => x.total);
        final money = _buckets(r, _tv(o, (x) => x.t, (x) => x.total));
        final cnt = _buckets(r, _tv(o, (x) => x.t, (_) => 1));
        return {
          'k': [
            _kpi('Omzet', rpA8(v), _trend(v, pvv), 'w'),
            _kpi('Transaksi', '${o.length} order', ''),
            _kpi('Rata-rata / order', rpA8(o.isNotEmpty ? v / o.length : 0), ''),
            _kpi('Total berat', '${jsRound(_sum(o, (x) => x.kg))} kg', ''),
          ],
          'ch': {'t': 'bar', 'd': _chart(money), 'money': 1, 'title': 'Omzet per ${r.days <= 1 ? 'jam' : r.days > 45 ? 'minggu' : 'hari'}'},
          'cols': ['Tanggal', 'Order', 'Omzet'],
          'rows': [for (var i = 0; i < cnt.length; i++) [cnt[i][2], _jsonNum(cnt[i][1]), rpA8(money[i][1] as num)]],
          'pv': _norm(v),
        };
      }
    case 'arus':
      {
        final o = c.ords(r).where((x) => x.cashReceived > 0).toList(), i = c.cashIncs(r), e = c.exps(r);
        final mi = _sum(o, (x) => x.cashReceived) + _sum(i, (x) => x.a), mo = _sum(e, (x) => x.a);
        final rows = <({DateTime t, String kind, String note, num a})>[
          for (final x in o) (t: x.t, kind: 'Masuk', note: 'Pembayaran ${x.id} · ${x.m}', a: x.cashReceived),
          for (final x in i) (t: x.t, kind: 'Masuk', note: x.note, a: x.a),
          for (final x in e) (t: x.t, kind: 'Keluar', note: '${x.cat} · ${x.note}', a: -x.a),
        ];
        final idx = List<int>.generate(rows.length, (n) => n)
          ..sort((a, b) {
            final cmp = rows[b].t.compareTo(rows[a].t);
            return cmp != 0 ? cmp : a.compareTo(b);
          });
        return {
          'k': [
            _kpi('Saldo bersih', rpA8(mi - mo), 'Masuk − keluar', 'w'),
            _kpi('Uang masuk', rpA8(mi), '', 'g'),
            _kpi('Uang keluar', rpA8(mo), '', 'r'),
            _kpi('Mutasi', '${rows.length} catatan', ''),
          ],
          'ch': {'t': 'hb', 'd': [['Masuk', _norm(mi)], ['Keluar', _norm(mo)]], 'money': 1, 'title': 'Perbandingan'},
          'cols': ['Waktu', 'Keterangan', 'Nominal'],
          'rows': [
            for (final n in idx)
              [
                '${_dmy(rows[n].t)}<small>${_pad(rows[n].t.hour)}:${_pad(rows[n].t.minute)}</small>',
                '${_esc(rows[n].note)}<small><span class="tag ${rows[n].a >= 0 ? 'g' : 'r'}">${rows[n].kind}</span></small>',
                rpA8(rows[n].a),
              ]
          ],
          'raw': 1,
          'pv': _norm(mi - mo),
        };
      }
    case 'ptrx':
      {
        final all = c.ords(r), o = all.where((x) => x.isPaid).toList();
        final v = _sum(o, (x) => x.received);
        return {
          'k': [
            _kpi('Pendapatan diterima', rpA8(v), '${o.length} pembayaran', 'w'),
            _kpi('Belum dibayar', rpA8(_sum(all.where((x) => x.owed > 0), (x) => x.owed)), '', 'r'),
          ],
          'ch': {'t': 'bar', 'd': _chart(_buckets(r, _tv(o, (x) => x.t, (x) => x.received))), 'money': 1, 'title': 'Pendapatan'},
          'cols': ['Order', 'Pelanggan', 'Nominal'],
          'rows': [
            for (final x in o.reversed) ['${x.id}<small>${_dmy(x.t)}</small>', '${_esc(x.c)}<small>${x.m}</small>', rpA8(x.received)]
          ],
          'raw': 1,
          'pv': _norm(v),
        };
      }
    case 'metode':
      {
        final m = _methodRows(c, r);
        final t = _sum(m, (x) => x[2] as num);
        return {
          'k': [
            for (final x in m) _kpi(x[0] as String, rpA8(x[2] as num), '${x[1]} trx · ${t != 0 ? jsRound((x[2] as num) / t * 100) : 0}%'),
            _kpi('Total', rpA8(t), '', ''),
          ],
          'ch': {'t': 'hb', 'd': [for (final x in m) [x[0], _jsonNum(x[2])]], 'money': 1, 'title': 'Porsi metode'},
          'cols': ['Metode', 'Trx', 'Nominal'],
          'rows': [for (final x in m) [x[0], x[1], rpA8(x[2] as num)]],
          'pv': _norm(t),
        };
      }
    case 'lain':
      {
        final i = c.incs(r);
        return {
          'k': [_kpi('Pendapatan lain', rpA8(_sum(i, (x) => x.a)), '${i.length} catatan', 'w')],
          'cols': ['Tanggal', 'Keterangan', 'Nominal'],
          'rows': [for (final x in i.reversed) [_dmy(x.t), _esc(x.note), rpA8(x.a)]],
          'raw': 1,
          'pv': _norm(_sum(i, (x) => x.a)),
          'empty': 'Belum ada pendapatan lain. Catat lewat Kas Masuk.',
        };
      }
    case 'keluar':
      {
        final e = c.exps(r);
        final cat = <String, num>{};
        for (final x in e) {
          cat[x.cat] = (cat[x.cat] ?? 0) + x.a;
        }
        final cs = _sortedDesc(cat.entries.toList(), (x) => x.value);
        final v = _sum(e, (x) => x.a), pv = _sum(c.exps(c.prev(r)), (x) => x.a);
        return {
          'k': [
            _kpi('Total pengeluaran', rpA8(v), _trend(v, pv), 'w'),
            _kpi('Kategori terbesar', cs.isNotEmpty ? cs.first.key : '-', cs.isNotEmpty ? rpA8(cs.first.value) : ''),
          ],
          'ch': {'t': 'hb', 'd': [for (final x in cs) [x.key, _norm(x.value)]], 'money': 1, 'title': 'Per kategori'},
          'cols': ['Tanggal', 'Keterangan', 'Nominal'],
          'rows': [for (final x in e.reversed) [_dmy(x.t), '${_esc(x.cat)}<small>${_esc(x.note)}</small>', rpA8(x.a)]],
          'raw': 1,
          'pv': _norm(v),
        };
      }
    case 'piutang':
      {
        final o = [for (final x in c.orders) if (x.owed > 0 && x.st != 'batal' && x.t.isBefore(r.e)) x];
        return {
          'k': [
            _kpi('Total piutang', rpA8(_sum(o, (x) => x.owed)), '${o.length} pesanan', 'w'),
            _kpi('Paling lama', o.isNotEmpty ? '${jsRound((c.now.millisecondsSinceEpoch - o.first.t.millisecondsSinceEpoch) / _day)} hari' : '-', ''),
          ],
          'cols': ['Order', 'Pelanggan', 'Tagihan'],
          'rows': [
            for (final x in o)
              [
                '${x.id}<small>${_dmy(x.t)}</small>',
                '${_esc(x.c)}<small><span class="tag ${(_stn[x.st] ?? const ['', ''])[1]}">${(_stn[x.st] ?? [x.st])[0]}</span></small>',
                rpA8(x.owed),
              ]
          ],
          'raw': 1,
          'pv': _norm(_sum(o, (x) => x.owed)),
          'empty': 'Semua pesanan sudah dibayar 👍',
        };
      }
    case 'diskon':
      {
        final o = c.ords(r).where((x) => x.disc > 0).toList();
        return {
          'k': [
            _kpi('Total diskon', rpA8(_sum(o, (x) => x.disc)), '${o.length} pesanan', 'w'),
            _kpi('Rata-rata', rpA8(o.isNotEmpty ? _sum(o, (x) => x.disc) / o.length : 0), 'per pesanan'),
          ],
          'cols': ['Order', 'Pelanggan', 'Diskon'],
          'rows': [for (final x in o.reversed) ['${x.id}<small>${_dmy(x.t)}</small>', _esc(x.c), rpA8(x.disc)]],
          'raw': 1,
          'pv': _norm(_sum(o, (x) => x.disc)),
        };
      }
    case 'bulat':
      {
        final o = c.ords(r).where((x) => x.rd != 0).toList();
        return {
          'k': [_kpi('Total pembulatan', rpA8(_sum(o, (x) => x.rd)), '${o.length} pesanan', 'w')],
          'cols': ['Order', 'Asli', 'Selisih'],
          'rows': [for (final x in o.reversed) [x.id, rpA8(x.total - x.rd), rpA8(x.rd)]],
          'pv': _norm(_sum(o, (x) => x.rd)),
        };
      }
    case 'laba':
      {
        final o = c.ords(r).where((x) => x.isPaid).toList();
        final other = _sum(c.incs(r), (x) => x.a);
        final inc = _sum(o, (x) => x.received) + other;
        final e = c.exps(r);
        final cat = <String, num>{};
        for (final x in e) {
          cat[x.cat] = (cat[x.cat] ?? 0) + x.a;
        }
        final ex = _sum(e, (x) => x.a), l = inc - ex;
        return {
          'k': [
            _kpi('Laba bersih', rpA8(l), inc != 0 ? 'Margin ${jsRound(l / inc * 100)}%' : '', 'w'),
            _kpi('Pendapatan', rpA8(inc), '', 'g'),
            _kpi('Pengeluaran', rpA8(ex), '', 'r'),
          ],
          'cols': ['Pos', '', 'Nominal'],
          'rows': [
            ['<b>Pendapatan laundry</b>', '', rpA8(_sum(o, (x) => x.received))],
            ['Pendapatan lain', '', rpA8(other)],
            for (final k in cat.entries) ['Beban ${k.key}', '', rpA8(-k.value)],
            ['<b>Laba bersih</b>', '', '<b>${rpA8(l)}</b>'],
          ],
          'raw': 1,
          'pv': _norm(l),
        };
      }
    case 'semua':
      {
        final o = c.ords(r, all: true).reversed.toList();
        return {
          'k': [
            _kpi('Pesanan', '${o.length}', '', 'w'),
            _kpi('Selesai', '${o.where((x) => x.st == 'diambil').length}', ''),
            _kpi('Dalam proses', '${o.where((x) => RegExp('antrian|proses|siap|telat').hasMatch(x.st)).length}', ''),
          ],
          'cols': ['Order', 'Pelanggan', 'Total'],
          'rows': [
            for (final x in o)
              [
                '${x.id}<small>${_dmy(x.t)} · ${x.dur}</small>',
                '${_esc(x.c)}<small><span class="tag ${_stn[x.st]![1]}">${_stn[x.st]![0]}</span> ${x.m}</small>',
                rpA8(x.total),
              ]
          ],
          'raw': 1,
          'pv': o.length,
          'unit': 'order',
        };
      }
    case 'layanan':
      {
        final m = <String, ({String n, String u, num q, int c, num v})>{};
        for (final o in c.ords(r)) {
          for (final it in o.items) {
            final x = m[it.n];
            m[it.n] = (n: it.n, u: x?.u ?? it.u, q: (x?.q ?? 0) + it.q, c: (x?.c ?? 0) + 1, v: (x?.v ?? 0) + it.t);
          }
        }
        final a = _sortedDesc(m.values.toList(), (x) => x.v);
        return {
          'k': [
            _kpi('Layanan terlaris', a.isNotEmpty ? a.first.n : '-', a.isNotEmpty ? rpA8(a.first.v) : '', 'w'),
            _kpi('Jenis layanan', '${a.length}', ''),
          ],
          'ch': {'t': 'hb', 'd': [for (final x in a.take(6)) [x.n, _norm(x.v)]], 'money': 1, 'title': 'Pendapatan per layanan'},
          'cols': ['Layanan', 'Jumlah', 'Pendapatan'],
          'rows': [for (final x in a) ['${_esc(x.n)}<small>${x.c} order</small>', '${_idNum(jsRound(x.q * 10) / 10)} ${x.u}', rpA8(x.v)]],
          'raw': 1,
          'pv': a.isNotEmpty ? a.first.n : '-',
          'txt': 1,
        };
      }
    case 'durasi':
      {
        final o = c.ords(r);
        final a = [
          for (final d in const ['Reguler', 'Express', 'Kilat'])
            () {
              final x = o.where((y) => y.dur == d).toList();
              return <Object>[d, x.length, _sum(x, (y) => y.total)];
            }()
        ];
        return {
          'k': [for (final x in a) [x[0], '${x[1]} order', rpA8(x[2] as num)]],
          'ch': {'t': 'hb', 'd': [for (final x in a) [x[0], _jsonNum(x[2])]], 'money': 1, 'title': 'Omzet per durasi'},
          'cols': ['Durasi', 'Order', 'Omzet'],
          'rows': [for (final x in a) [x[0], x[1], rpA8(x[2] as num)]],
          'pv': '${a[1][1]} express',
          'txt': 1,
        };
      }
    case 'status':
      {
        final o = c.ords(r, all: true);
        final a = [
          for (final k in const ['antrian', 'proses', 'siap', 'telat', 'diambil', 'batal']) [_stn[k]![0], o.where((x) => x.st == k).length]
        ];
        return {
          'k': [for (final x in a.take(4)) [x[0], '${x[1]}', '']],
          'ch': {'t': 'hb', 'd': a, 'title': 'Jumlah per status'},
          'cols': ['Status', 'Jumlah', ''],
          'rows': [for (final x in a) [x[0], x[1], '']],
          'pv': '${a[3][1]} telat',
          'txt': 1,
        };
      }
    case 'batal':
      {
        final o = c.ords(r, all: true).where((x) => x.st == 'batal').toList();
        const why = ['Pelanggan batal', 'Salah input', 'Barang tidak jadi dicuci'];
        return {
          'k': [_kpi('Dibatalkan', '${o.length} order', rpA8(_sum(o, (x) => x.total)), 'w')],
          'cols': ['Order', 'Pelanggan', 'Nilai'],
          'rows': [
            for (final x in o.reversed)
              [
                '${x.id}<small>${_dmy(x.t)}</small>',
                '${_esc(x.c)}<small>${why[x.id.codeUnitAt(x.id.length - 1) % 3]}</small>',
                rpA8(x.total),
              ]
          ],
          'raw': 1,
          'pv': o.length,
          'unit': 'order',
          'empty': 'Tidak ada pesanan batal 👍',
        };
      }
    case 'telat':
      {
        final o = [for (final x in c.orders) if (x.st == 'telat') x];
        String lama(RepOrder x) => x.done == null
            ? 'NaN hari'
            : '${jsRound((c.now.millisecondsSinceEpoch - x.done!.millisecondsSinceEpoch) / _day)} hari';
        return {
          'k': [_kpi('Telat ambil', '${o.length} order', rpA8(_sum(o, (x) => x.total)), 'w')],
          'cols': ['Order', 'Pelanggan', 'Lama'],
          'rows': [for (final x in o) ['${x.id}<small>${rpA8(x.total)}</small>', _esc(x.c), lama(x)]],
          'raw': 1,
          'pv': o.length,
          'unit': 'order',
          'empty': 'Tidak ada cucian telat ambil',
        };
      }
    case 'antar':
      {
        final o = c.ords(r).where((x) => x.antar).toList();
        return {
          'k': [_kpi('Pesanan antar', '${o.length}', '${rpA8(_sum(o, (x) => x.ong))} ongkir', 'w')],
          'cols': ['Order', 'Pelanggan', 'Ongkir'],
          'rows': [for (final x in o.reversed) ['${x.id}<small>${_dmy(x.t)}</small>', _esc(x.c), rpA8(x.ong)]],
          'raw': 1,
          'pv': o.length,
          'unit': 'antar',
        };
      }
    case 'tumbuh':
      {
        final list = [for (final e in c.first.entries) if (c._in(e.value, r)) (t: e.value, c: e.key)];
        final byTime = List<int>.generate(list.length, (i) => i)
          ..sort((a, b) {
            final cmp = list[b].t.compareTo(list[a].t);
            return cmp != 0 ? cmp : a.compareTo(b);
          });
        return {
          'k': [_kpi('Pelanggan baru', '${list.length}', '', 'w'), _kpi('Total pelanggan', '${c.first.length}', '')],
          'ch': {'t': 'bar', 'd': _chart(_buckets(r, _tv(list, (x) => x.t, (_) => 1))), 'title': 'Pelanggan baru'},
          'cols': ['Pelanggan', 'Order pertama', ''],
          'rows': [for (final i in byTime) [_esc(list[i].c), _dmy(list[i].t), '']],
          'raw': 1,
          'pv': list.length,
          'unit': 'baru',
          'empty': 'Belum ada pelanggan baru di periode ini',
        };
      }
    case 'toppl':
      {
        // Patch v181 mengganti laporan ini: urut total belanja (bukan sisa tagihan), tanpa grafik & medali.
        final m = <String, ({String c, int n, num v})>{};
        for (final o in c.ords(r)) {
          final x = m[o.c];
          m[o.c] = (c: o.c, n: (x?.n ?? 0) + 1, v: (x?.v ?? 0) + o.total);
        }
        final a = _sortedDesc(m.values.toList(), (x) => x.v);
        return {
          'k': [
            _kpi('Pelanggan teratas', a.isNotEmpty ? a.first.c : '-', a.isNotEmpty ? rpA8(a.first.v) : '', 'w'),
            _kpi('Pelanggan aktif', '${a.length}', ''),
          ],
          'cols': ['Pelanggan', 'Order', 'Belanja'],
          'rows': [for (final x in a) [_esc(x.c), x.n, rpA8(x.v)]],
          'raw': 1,
          'pv': a.isNotEmpty ? a.first.c : '-',
          'txt': 1,
        };
      }
    case 'lamabaru':
      {
        final o = c.ords(r);
        var nw = 0, od = 0;
        num vn = 0, vo = 0;
        for (final x in o) {
          final f = c.first[x.c]!;
          if (c._in(f, r) && f.millisecondsSinceEpoch == x.t.millisecondsSinceEpoch) {
            nw++;
            vn += x.total;
          } else {
            od++;
            vo += x.total;
          }
        }
        return {
          'k': [_kpi('Order langganan', '$od', rpA8(vo), 'w'), _kpi('Order pelanggan baru', '$nw', rpA8(vn))],
          'ch': {'t': 'hb', 'd': [['Langganan', od], ['Baru', nw]], 'title': 'Jumlah order'},
          'cols': ['Tipe', 'Order', 'Omzet'],
          'rows': [['Langganan', od, rpA8(vo)], ['Baru', nw, rpA8(vn)]],
          'pv': '${o.isNotEmpty ? jsRound(od / o.length * 100) : 0}% kembali',
          'txt': 1,
        };
      }
    case 'poin':
      {
        final m = <String, num>{};
        for (final o in c.ords(r).where((x) => x.isPaid)) {
          m[o.c] = (m[o.c] ?? 0) + o.pts;
        }
        final a = _sortedDesc(m.entries.toList(), (x) => x.value);
        final total = _sum(a, (x) => x.value);
        return {
          'k': [_kpi('Poin diberikan', '${_norm(total)} poin', '1 poin / Rp10.000', 'w'), _kpi('Penerima', '${a.length} pelanggan', '')],
          'cols': ['Pelanggan', 'Poin', ''],
          'rows': [for (final x in a) [_esc(x.key), '${_norm(x.value)} ⭐', '']],
          'raw': 1,
          'pv': '${_norm(total)} poin',
          'txt': 1,
        };
      }
    case 'pasif':
      {
        final last = <String, DateTime>{};
        for (final o in c.orders) {
          final l = last[o.c];
          if (l == null || l.isBefore(o.t)) last[o.c] = o.t;
        }
        final a = [
          for (final e in last.entries)
            if (c.now.millisecondsSinceEpoch - e.value.millisecondsSinceEpoch > 30 * _day) e
        ];
        final idx = List<int>.generate(a.length, (i) => i)
          ..sort((x, y) {
            final cmp = a[x].value.compareTo(a[y].value);
            return cmp != 0 ? cmp : x.compareTo(y);
          });
        return {
          'k': [_kpi('Tidak aktif', '${a.length} pelanggan', '> 30 hari tanpa order', 'w')],
          'cols': ['Pelanggan', 'Order terakhir', 'Lama'],
          'rows': [
            for (final i in idx)
              [_esc(a[i].key), _dmy(a[i].value), '${jsRound((c.now.millisecondsSinceEpoch - a[i].value.millisecondsSinceEpoch) / _day)} hari']
          ],
          'raw': 1,
          'pv': a.length,
          'unit': 'orang',
          'empty': 'Semua pelanggan masih aktif 👍',
          'note': 'Kirim voucher lewat menu CRM Pelanggan untuk mengajak mereka kembali.',
        };
      }
    case 'kasbon':
      {
        final m = <String, ({String c, int n, num v})>{};
        for (final o in c.orders.where((x) => x.owed > 0 && x.st != 'batal')) {
          final x = m[o.c];
          m[o.c] = (c: o.c, n: (x?.n ?? 0) + 1, v: (x?.v ?? 0) + o.owed);
        }
        final a = _sortedDesc(m.values.toList(), (x) => x.v);
        return {
          'k': [_kpi('Total kasbon', rpA8(_sum(a, (x) => x.v)), '${a.length} pelanggan', 'w')],
          'cols': ['Pelanggan', 'Order', 'Tagihan'],
          'rows': [for (final x in a) [_esc(x.c), x.n, rpA8(x.v)]],
          'raw': 1,
          'pv': _norm(_sum(a, (x) => x.v)),
          'empty': 'Tidak ada kasbon',
        };
      }
    case 'kinerja':
      {
        final o = c.ords(r);
        final a = [
          for (final st in c.staff)
            () {
              final x = o.where((y) => y.staff == st).toList();
              return <Object>[st, x.length, jsRound(_sum(x, (y) => y.kg)), _sum(x, (y) => y.total)];
            }()
        ];
        final top = _sortedDesc(a, (x) => x[1] as num);
        return {
          'k': [for (final x in a) [x[0], '${x[1]} order', '${x[2]} kg']],
          'ch': {'t': 'hb', 'd': [for (final x in a) [x[0], x[1]]], 'title': 'Order ditangani'},
          'cols': ['Pegawai', 'Order', 'Berat'],
          'rows': [for (final x in a) ['${x[0]}<small>${rpA8(x[3] as num)}</small>', x[1], '${x[2]} kg']],
          'raw': 1,
          'pv': top.first[0],
          'txt': 1,
        };
      }
    case 'presensi':
      {
        final a = [for (final x in c.att) if (c._in(x.d, r)) x];
        bool late(RepAtt y) => y.inAt.hour + y.inAt.minute / 60 > 7.5;
        final per = [
          for (final st in c.staff)
            () {
              final x = a.where((y) => y.s == st).toList();
              return <Object>[st, x.length, x.where(late).length];
            }()
        ];
        return {
          'k': [for (final x in per) [x[0], '${x[1]} hari hadir', '${x[2]}× terlambat']],
          'cols': ['Tanggal', 'Pegawai', 'Masuk – Pulang'],
          'rows': [
            for (final x in a.reversed)
              [
                _dmy(x.d),
                '${x.s}${late(x) ? ' <span class="tag y">telat</span>' : ''}',
                '${_pad(x.inAt.hour)}:${_pad(x.inAt.minute)} – ${_pad(x.outAt.hour)}:${_pad(x.outAt.minute)}',
              ]
          ],
          'raw': 1,
          'pv': '${per.first[1]} hari',
          'txt': 1,
          'note': 'Jam masuk normal 07.30. Presensi dicatat saat pegawai login di aplikasi.',
        };
      }
    case 'komisi':
      {
        final o = c.ords(r);
        const g = {'Rina': 2300000, 'Dewi': 2100000, 'Andi': 1900000};
        final a = [
          for (final st in c.staff)
            () {
              final kg = jsRound(_sum(o.where((y) => y.staff == st), (y) => y.kg));
              return <Object>[st, kg, kg * 300, g[st] ?? 0];
            }()
        ];
        final total = _sum(a, (x) => x[2] as num);
        return {
          'k': [
            _kpi('Total komisi', rpA8(total), 'Rp300 per kg', 'w'),
            for (final x in a) [x[0], rpA8(x[2] as num), '${x[1]} kg'],
          ],
          'cols': ['Pegawai', 'Komisi', 'Gaji pokok'],
          'rows': [for (final x in a) ['${x[0]}<small>${x[1]} kg</small>', rpA8(x[2] as num), rpA8(x[3] as num)]],
          'raw': 1,
          'pv': _norm(total),
        };
      }
    case 'kurir':
      {
        final o = c.ords(r).where((x) => x.antar).toList();
        return {
          'k': [_kpi('Budi (Kurir)', '${o.length} antar', '${rpA8(_sum(o, (x) => x.ong))} ongkir', 'w')],
          'cols': ['Order', 'Pelanggan', 'Ongkir'],
          'rows': [for (final x in o.reversed) ['${x.id}<small>${_dmy(x.t)}</small>', _esc(x.c), rpA8(x.ong)]],
          'raw': 1,
          'pv': o.length,
          'unit': 'antar',
        };
      }
    case 'stok':
      {
        final low = c.stock.where((s) => s.now <= s.min).toList();
        return {
          'k': [_kpi('Hampir habis', '${low.length} bahan', low.isEmpty ? 'Aman' : low.map((s) => s.n).join(', '), 'w')],
          'cols': ['Bahan', 'Sisa', 'Status'],
          'rows': [
            for (final s in c.stock)
              [s.n, '${_norm(s.now)} ${s.u}', s.now <= s.min ? '<span class="tag r">Beli lagi</span>' : '<span class="tag g">Aman</span>']
          ],
          'raw': 1,
          'pv': low.isNotEmpty ? '${low.length} habis' : 'Aman',
          'txt': 1,
          'go2': 'inventory',
        };
      }
    case 'pakai':
      {
        final kg = _sum(c.ords(r), (x) => x.kg);
        return {
          'k': [_kpi('Cucian diproses', '${jsRound(kg)} kg', '', 'w')],
          'cols': ['Bahan', 'Terpakai', 'Biaya'],
          'rows': [
            for (final s in c.stock) [s.n, '${_idNum(jsRound(kg * s.per * 10) / 10)} ${s.u}', rpA8(kg * s.per * s.buy)]
          ],
          'pv': '${jsRound(kg)} kg',
          'txt': 1,
          'note': 'Dihitung dari takaran rata-rata per kg. Ubah takaran di menu Stok Bahan.',
        };
      }
    case 'beli':
      {
        final e = c.exps(r).where((x) => x.cat == 'Bahan Baku').toList();
        return {
          'k': [_kpi('Total belanja', rpA8(_sum(e, (x) => x.a)), '${e.length} kali', 'w')],
          'ch': {'t': 'bar', 'd': _chart(_buckets(r, _tv(e, (x) => x.t, (x) => x.a))), 'money': 1, 'title': 'Belanja bahan'},
          'cols': ['Tanggal', 'Item', 'Nominal'],
          'rows': [for (final x in e.reversed) [_dmy(x.t), _esc(x.note), rpA8(x.a)]],
          'raw': 1,
          'pv': _norm(_sum(e, (x) => x.a)),
        };
      }
    case 'nilai':
      {
        final a = [for (final s in c.stock) <Object>[s.n, '${_norm(s.now)} ${s.u}', s.now * s.buy]];
        final total = _sum(a, (x) => x[2] as num);
        return {
          'k': [_kpi('Nilai persediaan', rpA8(total), 'Harga beli terakhir', 'w')],
          'cols': ['Bahan', 'Stok', 'Nilai'],
          'rows': [for (final x in a) [x[0], x[1], rpA8(x[2] as num)]],
          'pv': _norm(total),
        };
      }
    case 'jam':
      {
        final o = c.ords(r);
        final m = <int, int>{for (var h = 7; h <= 21; h++) h: 0};
        for (final x in o) {
          m[x.t.hour] = (m[x.t.hour] ?? 0) + 1;
        }
        final a = [for (final h in (m.keys.toList()..sort())) <Object>[_pad(h), m[h]!]];
        final top = _sortedDesc(a, (x) => x[1] as num).first;
        return {
          'k': [_kpi('Paling ramai', '${top[0]}.00', '${top[1]} order', 'w')],
          'ch': {'t': 'bar', 'd': a, 'title': 'Order per jam'},
          'cols': ['Jam', 'Order', ''],
          'rows': [for (final x in a) ['${x[0]}.00 – ${x[0]}.59', x[1], '']],
          'pv': '${top[0]}.00',
          'txt': 1,
        };
      }
    case 'hari':
      {
        final o = c.ords(r);
        final m = List<int>.filled(7, 0);
        final v = List<num>.filled(7, 0);
        for (final x in o) {
          m[_jsDay(x.t)]++;
          v[_jsDay(x.t)] += x.total;
        }
        final a = [for (final i in const [1, 2, 3, 4, 5, 6, 0]) <Object>[_hr[i], m[i], v[i]]];
        final top = _sortedDesc(a, (x) => x[1] as num).first;
        return {
          'k': [_kpi('Hari teramai', top[0] as String, '${top[1]} order', 'w')],
          'ch': {'t': 'bar', 'd': [for (final x in a) [x[0], x[1]]], 'title': 'Order per hari'},
          'cols': ['Hari', 'Order', 'Omzet'],
          'rows': [for (final x in a) [x[0], x[1], rpA8(x[2] as num)]],
          'pv': top[0],
          'txt': 1,
        };
      }
    case 'waktu':
      {
        final o = c.ords(r).where((x) => x.st == 'diambil' || x.st == 'siap' || x.st == 'telat').toList();
        bool onTime(RepOrder x) => x.done != null && x.due != null && !x.done!.isAfter(x.due!);
        bool late(RepOrder x) => x.done != null && x.due != null && x.done!.isAfter(x.due!);
        final on = o.where(onTime).toList();
        final pct = o.isNotEmpty ? jsRound(on.length / o.length * 100) : 0;
        return {
          'k': [
            _kpi('Tepat waktu', '$pct%', '${on.length} dari ${o.length} pesanan', 'w'),
            _kpi('Terlambat', '${o.length - on.length} pesanan', '', 'r'),
          ],
          'cols': ['Order', 'Estimasi', 'Selesai'],
          'rows': [
            for (final x in o.where(late).toList().reversed)
              [
                '${x.id}<small>${x.dur}</small>',
                '${_dmy(x.due!)}<small>${_pad(x.due!.hour)}:${_pad(x.due!.minute)}</small>',
                '<span class="tag r">+${math.max(1, jsRound((x.done!.millisecondsSinceEpoch - x.due!.millisecondsSinceEpoch) / 36e5))} jam</span>',
              ]
          ],
          'raw': 1,
          'pv': '$pct% tepat',
          'txt': 1,
        };
      }
    case 'kapasitas':
      {
        final o = c.ords(r);
        final b = [for (final x in _buckets(r, _tv(o, (x) => x.t, (x) => x.kg))) <Object>[x[0], jsRound(x[1] as num), x[2]]];
        final mx = b.fold<int>(0, (s, x) => math.max(s, x[1] as int));
        final kg = jsRound(_sum(o, (x) => x.kg));
        return {
          'k': [_kpi('Total berat', '$kg kg', '', 'w'), _kpi('Tertinggi', '$mx kg', mx > 60 ? 'Melebihi kapasitas' : 'Masih aman')],
          'ch': {'t': 'bar', 'd': b, 'title': 'Kg per ${r.days <= 1 ? 'jam' : r.days > 45 ? 'minggu' : 'hari'}'},
          'cols': ['Periode', 'Berat', ''],
          'rows': [for (final x in b) [x[2], '${x[1]} kg', (x[1] as int) > 60 ? '<span class="tag r">Penuh</span>' : '']],
          'raw': 1,
          'pv': '$kg kg',
          'txt': 1,
        };
      }
    case 'x-keu':
      {
        final o = c.ords(r).where((x) => x.isPaid);
        return <Object>[
          ['Tanggal', 'Jenis', 'Keterangan', 'Metode', 'Nominal'],
          for (final x in o) [_dmy(x.t), 'Masuk', 'Pembayaran ${x.id}', x.m, _norm(x.total)],
          for (final x in c.incs(r)) [_dmy(x.t), 'Masuk', x.note, 'Tunai', _norm(x.a)],
          for (final x in c.exps(r)) [_dmy(x.t), 'Keluar', '${x.cat} - ${x.note}', 'Tunai', _norm(-x.a)],
        ];
      }
    case 'x-trx':
      return <Object>[
        ['Order', 'Tanggal', 'Pelanggan', 'Layanan', 'Berat/Qty', 'Durasi', 'Diskon', 'Total', 'Bayar', 'Status', 'Pegawai'],
        for (final x in c.ords(r, all: true))
          [
            x.id,
            _dmy(x.t),
            x.c,
            x.items.map((i) => i.n).join(' + '),
            x.items.map((i) => '${_norm(i.q)} ${i.u}').join(' + '),
            x.dur,
            _norm(x.disc),
            _norm(x.total),
            x.m,
            _stn[x.st]![0],
            x.staff,
          ],
      ];
    case 'x-plg':
      {
        final m = <String, ({int n, num v, DateTime last})>{};
        for (final o in c.orders) {
          final x = m[o.c];
          m[o.c] = (n: (x?.n ?? 0) + 1, v: (x?.v ?? 0) + o.total, last: x == null || o.t.isAfter(x.last) ? o.t : x.last);
        }
        return <Object>[
          ['Pelanggan', 'Total Order', 'Total Belanja', 'Order Pertama', 'Order Terakhir'],
          for (final e in m.entries) [e.key, e.value.n, _norm(e.value.v), _dmy(c.first[e.key]!), _dmy(e.value.last)],
        ];
      }
    case 'x-peg':
      {
        final o = c.ords(r);
        return <Object>[
          ['Pegawai', 'Order', 'Berat (kg)', 'Omzet', 'Komisi', 'Hari Hadir'],
          for (final st in c.staff)
            () {
              final x = o.where((y) => y.staff == st).toList();
              final kg = jsRound(_sum(x, (y) => y.kg));
              return <Object>[st, x.length, kg, _norm(_sum(x, (y) => y.total)), kg * 300, c.att.where((a) => a.s == st && c._in(a.d, r)).length];
            }(),
        ];
      }
  }
  return null;
}

List<List<Object>> _chart(List<List<Object>> b) => [for (final x in b) [x[0], _jsonNum(x[1]), x[2]]];

/// Singkatan uang untuk grafik (sh() di HTML): Rp1,5jt, Rp250rb, Rp2,1M.
String shA8(num n) {
  final a = n.abs(), s = n < 0 ? '−' : '';
  if (a >= 1e9) return '${s}Rp${(a / 1e9).toStringAsFixed(1).replaceAll('.', ',')}M';
  if (a >= 1e6) {
    final t = (a / 1e6).toStringAsFixed(a >= 1e7 ? 1 : 2).replaceAll('.', ',').replaceFirst(RegExp(r',?0+$'), '');
    return '${s}Rp${t}jt';
  }
  if (a >= 1e3) return '${s}Rp${jsRound(a / 1e3)}rb';
  return rpA8(n);
}

const reportPeriodsA8 = [
  ('today', 'Hari ini'), ('7', '7 hari'), ('30', '30 hari'), ('month', 'Bulan ini'), ('last', 'Bulan lalu'), ('custom', 'Pilih tanggal'),
];

/// Label periode seperti plabel() di HTML.
String periodLabelA8(String key, RepRange r) {
  if (key == 'custom') return '${_dmy(r.s)} – ${_dmy(r.e.subtract(const Duration(milliseconds: _day)))}';
  return reportPeriodsA8.firstWhere((p) => p.$1 == key, orElse: () => ('', key)).$2;
}

/// Susun data laporan langsung dari database Dart (`goyana-business177`), meniru `reports()` di HTML
/// (goyana-local-transactions177). Hasilnya berbentuk sama dengan keluaran `__goyanaReportsA8`.
Map<String, Object?> reportStateFromBusiness(Map<String, dynamic> business, {required DateTime now, int? tzMinutes}) {
  final tz = tzMinutes ?? now.timeZoneOffset.inMinutes;
  final details = business['details'] is Map ? Map<String, dynamic>.from(business['details'] as Map) : <String, dynamic>{};
  String idOf(Map c) {
    final f = c['fields'];
    return f is List && f.length > 1 && f[1] is List && (f[1] as List).isNotEmpty ? '${(f[1] as List).first}'.trim() : '';
  }

  final ord = <Map<String, Object?>>[];
  for (final c in (business['orders'] as List? ?? const []).whereType<Map>()) {
    final card = Map<String, dynamic>.from(c);
    final id = idOf(card);
    final d = details[id] is Map ? Map<String, dynamic>.from(details[id] as Map) : <String, dynamic>{};
    final o = Order(card, d);
    final created = o.created ?? now;
    final total = o.total;
    final paid = math.min(total, o.paid);
    final st = o.status;
    final items = o.items;
    final disc = _num(o.dataset['disc']);
    final dur = o.dur;
    final due = o.due ?? created.add(Duration(hours: durationHours(dur)));
    ord.add({
      'id': id, 't': created.millisecondsSinceEpoch, 'c': o.name, 'f': false,
      'items': [for (final it in items) {'n': it.name, 'u': it.unit, 'q': it.qty, 'p': it.price, 't': (it.qty * it.price).round()}],
      'kg': items.fold<num>(0, (s, it) => s + (it.unit == 'kg' ? it.qty : 0)),
      'sub': total + disc, 'disc': disc, 'ong': o.ongkir, 'rd': 0, 'total': total, 'paid': paid,
      'm': st == 'batal' ? 'Batal' : (paid > 0 ? o.method : 'Belum'),
      'payments178': o.payments,
      'st': const {'cuci', 'kering', 'setrika', 'packing', 'selesaiproses'}.contains(st) ? 'proses' : st,
      'staff': '', 'antar': o.antar, 'dur': dur,
      'due': due.millisecondsSinceEpoch,
      'done': (o.due ?? created).millisecondsSinceEpoch,
      'pts': paid ~/ 10000,
    });
  }
  final kas = business['kas'] is Map ? business['kas'] as Map : const {};
  int at(Object? v) => (DateTime.tryParse('${v ?? ''}') ?? now).millisecondsSinceEpoch;
  final t0 = DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + tz * 60000, isUtc: true);
  final midnight = DateTime.utc(t0.year, t0.month, t0.day).millisecondsSinceEpoch - tz * 60000;
  return {
    'tz': tz, 'now': now.millisecondsSinceEpoch, 't0': midnight, 'ord': ord,
    'exp': [
      for (final x in (kas['outs'] as List? ?? const []).whereType<Map>())
        {'t': at(x['at']), 'a': _num(x['a']), 'cat': (x['t'] == null || '${x['t']}'.isEmpty) ? 'Lain-Lain' : '${x['t']}', 'note': '${x['t'] ?? ''}'}
    ],
    'inc': [
      for (final x in (kas['ins'] as List? ?? const []).whereType<Map>()) {'t': at(x['at']), 'a': _num(x['a']), 'note': '${x['t'] ?? ''}', 'deposit178': x['deposit178'] == true}
    ],
    'att': const [], 'stock': const [], 'staff': const ['Rina', 'Dewi', 'Andi'],
  };
}

String _stripHtml(Object? v) => '${v ?? ''}'
    .replaceAll('<small>', ' · ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .trim();

/// Isi CSV (pemisah ';', seperti csv170 di HTML) dari hasil laporan atau baris export.
String reportCsvA8(Object data) {
  late final List<List<Object?>> lines;
  if (data is List) {
    lines = [for (final r in data) (r as List).cast<Object?>()];
  } else {
    final o = data as Map;
    lines = [(o['cols'] as List).cast<Object?>(), for (final r in (o['rows'] as List)) (r as List).cast<Object?>()];
  }
  String cell(Object? v) {
    final s = _stripHtml(v);
    return RegExp(r'[",;\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return lines.map((r) => r.map(cell).join(';')).join('\n');
}

/// Teks kiriman WhatsApp (share170 di HTML).
String reportShareTextA8(String title, String period, Object data) {
  final b = StringBuffer('*LAPORAN ${title.toUpperCase()}*\nGOYANA Laundry · $period\n━━━━━━━━━━━━━━━━━━━━\n');
  if (data is Map) {
    for (final k in (data['k'] as List? ?? const [])) {
      final l = k as List;
      b.writeln('• ${l[0]}: *${l[1]}*${l.length > 2 && '${l[2]}'.isNotEmpty ? ' (${l[2]})' : ''}');
    }
    final rows = (data['rows'] as List? ?? const []);
    if (rows.isNotEmpty) {
      b.writeln('━━━━━━━━━━━━━━━━━━━━');
      b.write(rows.take(10).map((r) => (r as List).map(_stripHtml).where((x) => x.isNotEmpty).join(' | ')).join('\n'));
      if (rows.length > 10) b.write('\n… +${rows.length - 10} baris lagi');
    }
  } else {
    final rows = data as List;
    b.writeln('${rows.length - 1} baris data siap diexport');
    b.writeln('━━━━━━━━━━━━━━━━━━━━');
    b.write(rows.skip(1).take(10).map((r) => (r as List).map(_stripHtml).where((x) => x.isNotEmpty).join(' | ')).join('\n'));
    if (rows.length - 1 > 10) b.write('\n… +${rows.length - 11} baris lagi');
  }
  return b.toString();
}
