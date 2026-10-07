// Ranking Pelanggan (HTML v138 #rk138): Transaksi Terbanyak / Belanja Terbesar, podium 3 besar,
// 10 teratas dengan batang, ringkasan. Angka dihitung dari pesanan asli (HTML memakai angka contoh).

import '../core/money.dart';
import 'pages.dart';

class RankPage extends PurePage {
  RankPage(super.host);
  bool spend = false;

  @override
  String get title => 'RANKING PELANGGAN';
  @override
  String get back => 'customers';
  @override
  int get navActive => 0;

  @override
  List<Map<String, dynamic>> items() {
    final b = host.business;
    final d = <List<Object>>[]; // [nama, order, belanja]
    for (final c in b.customers) {
      final mine = b.orders.where((o) => !o.isCancelled && o.name.trim().toLowerCase() == c.name.trim().toLowerCase());
      d.add([c.name, mine.length, mine.fold<int>(0, (a, o) => a + o.total)]);
    }
    final k = spend ? 2 : 1, alt = spend ? 1 : 2;
    d.sort((x, y) {
      final r = (y[k] as int).compareTo(x[k] as int);
      return r != 0 ? r : (y[alt] as int).compareTo(x[alt] as int);
    });
    final top = d.take(10).toList();
    final mx = top.isEmpty || (top.first[k] as int) == 0 ? 1 : top.first[k] as int;
    String val(List<Object> x) => spend ? rp(x[2] as int) : '${x[1]} transaksi';
    String sub(List<Object> x) => spend ? '${x[1]} transaksi' : rp(x[2] as int);
    final tot = d.fold<int>(0, (a, x) => a + (x[2] as int)), to = d.fold<int>(0, (a, x) => a + (x[1] as int));
    final share = top.fold<int>(0, (a, x) => a + (x[2] as int));
    const medal = ['🥇', '🥈', '🥉'];
    return [
      {'type': 'buttons', 'options': [{'t': 'Transaksi Terbanyak', 'on': !spend, 'i': 0}, {'t': 'Belanja Terbesar', 'on': spend, 'i': 1}]},
      if (top.isEmpty) {'type': 'hint', 't': 'Belum ada pelanggan.'},
      if (top.isNotEmpty)
        {'type': 'stats', 'cells': [
          // Podium: perak · emas · perunggu.
          for (final i in const [1, 0, 2])
            if (i < top.length) {'v': '${medal[i]} ${top[i][0]}', 't': val(top[i])},
        ]},
      if (top.isNotEmpty)
        {'type': 'hbars', 'bars': [
          for (var i = 0; i < top.length; i++)
            {'t': '${i < 3 ? medal[i] : '${i + 1}.'} ${top[i][0]} · ${sub(top[i])}', 'v': val(top[i]), 'w': ((top[i][k] as int) / mx).clamp(.04, 1)},
        ]},
      if (top.isNotEmpty) {'type': 'pair', 't': 'Top 10 = ${tot > 0 ? (share / tot * 100).round() : 0}% dari total belanja', 'v': '$to trx · ${rp(tot)}'},
    ];
  }

  @override
  void button(int i) {
    spend = i == 1;
    host.refresh();
  }
}
