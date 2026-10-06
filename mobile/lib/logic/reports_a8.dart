// A8 Laporan — kelompok Keuangan (10) dan Transaksi (7).
// Menyalin hitungan mesin HTML (goyana-v170-reports-script) apa adanya; HTML tetap pembanding (paritas).
// Waktu dipakai sebagai "jam dinding" (UTC yang sudah digeser zona perangkat) agar hasil sama di tiap mesin uji.
import 'dart:math' as math;

const reportIdsA8 = [
  // Keuangan
  'omzet', 'arus', 'ptrx', 'metode', 'lain', 'keluar', 'piutang', 'diskon', 'bulat', 'laba',
  // Transaksi
  'semua', 'layanan', 'durasi', 'status', 'batal', 'telat', 'antar',
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
  final num total, paid, disc, rd, ong, kg;
  final List<({String m, num a})> payments;
  late DateTime t;
  DateTime? done;

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

class RepCtx {
  RepCtx({required this.now, required this.t0, required this.orders, required this.exp, required this.inc, required this.first});
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
    ];
    final first = <String, DateTime>{};
    for (final o in orders) {
      final f = first[o.c];
      if (f == null || f.isAfter(o.t)) first[o.c] = o.t;
    }
    return RepCtx(
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

/// Hasil satu laporan (struktur sama dengan keluaran `REP170[i].f(range)` di HTML), atau null bila belum dipindah.
Map<String, Object?>? reportA8(String id, RepCtx c, RepRange r) {
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
  }
  return null;
}

List<List<Object>> _chart(List<List<Object>> b) => [for (final x in b) [x[0], _jsonNum(x[1]), x[2]]];
