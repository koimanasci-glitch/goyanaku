import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/logic/order_detail.dart';
import 'package:goyana_flutter/logic/orders.dart';

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Map<String, String> _seed(Map<String, dynamic> value) => {
      for (final entry in value.entries) entry.key: '${entry.value}',
    };

int _unpaidCount(Map<String, dynamic> store) {
  final b = jsonDecode(store[Keys.business] as String) as Map<String, dynamic>;
  var n = 0;
  for (final raw in b['orders'] as List? ?? const []) {
    if (raw is! Map) continue;
    final ds = raw['dataset'] as Map? ?? const {};
    final cancelled = '${ds['st'] ?? ''}' == 'batal';
    final paid = raw['paid'] == true || '${raw['payment'] ?? ''}' == 'Lunas';
    if (!cancelled && !paid) n++;
  }
  return n;
}

Map<String, dynamic> _latestOrdersExpected(
    Map<String, dynamic> fixture, Map<String, dynamic> after) {
  final expected = _copy(fixture);
  final tabs = expected['tabs'] as List;
  if (!tabs.any((e) => e is Map && e['t'] == 'Belum Bayar')) {
    tabs.add({'t': 'Belum Bayar', 'n': _unpaidCount(after), 'on': false});
  }
  return expected;
}

Map<String, dynamic> _dirtyDetail(Map<String, dynamic> source) {
  final value = _copy(source);
  final od = value['od'] as Map<String, dynamic>;
  od['sub'] = 'SALAH';
  od['banner'] = {'bad': true};
  od['steps'] = <dynamic>[];
  od['edit'] = {'t': 'SALAH', 'b': -1};
  od['actions'] = <dynamic>[];
  od['total'] = {'bad': true};
  final rows = od['rows'] as List? ?? const [];
  for (final row in rows.whereType<Map>()) {
    if (row['k'] == 'Status') row['v'] = 'SALAH';
  }
  final items = value['items'] as List? ?? const [];
  for (final row in items.whereType<Map>()) {
    if (row['type'] == 'steps') row['steps'] = <dynamic>[];
    if (row['type'] == 'pair' && row['t'] == 'Status') row['v'] = 'SALAH';
    if (row['type'] == 'button') {
      row['t'] = 'SALAH';
      row['i'] = -1;
    }
    if (row['type'] == 'total') {
      row['v'] = 'SALAH';
      row['s'] = 'SALAH';
      row['i'] = -1;
    }
  }
  return value;
}

void main() {
  final fixture = jsonDecode(File('test/fixtures/parity/flows_a4_a5_a7.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final cases = (fixture['steps'] as List)
      .whereType<Map>()
      .where((e) => e['part'] == 'A4')
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  test('A4 fixture Claude berisi empat langkah', () {
    expect(cases.map((e) => e['name']).toList(), [
      'status_1_proses',
      'status_2_siap',
      'status_3_diambil',
      'batal_pelanggan',
    ]);
  });

  for (final c in cases) {
    test('A4 after sama persis HTML: ${c['name']}', () {
      final before = Map<String, dynamic>.from(c['before'] as Map);
      final after = Map<String, dynamic>.from(c['after'] as Map);
      final original = jsonEncode(before);
      final action = inferOrderDetailA4Action(before: before, after: after);
      expect(action, isNotNull, reason: 'Aksi fixture harus dikenali tanpa menebak');
      final got = applyOrderDetailA4(before: before, action: action!);
      expect(got, after);
      expect(jsonEncode(before), original, reason: 'Input before tidak boleh dimutasi');
    });

    test('A4 model orders & detail sama: ${c['name']}', () async {
      final before = Map<String, dynamic>.from(c['before'] as Map);
      final after = Map<String, dynamic>.from(c['after'] as Map);
      final action = inferOrderDetailA4Action(before: before, after: after)!;
      final got = applyOrderDetailA4(before: before, action: action);

      final business = await Business.load(MemoryKvStore(_seed(got)));
      final htmlOrders = Map<String, dynamic>.from(c['orders'] as Map);
      final tabs = htmlOrders['tabs'] as List;
      var selected = tabs.indexWhere((e) => e is Map && e['on'] == true);
      if (selected < 0) selected = 1;
      final dartOrders = ordersModel(
        business,
        tab: selected,
        search: '${htmlOrders['search'] ?? ''}',
        now: DateTime.parse(c['now'] as String),
      );
      expect(dartOrders, _latestOrdersExpected(htmlOrders, after));

      final dartDetail = orderDetailA4Model(
        store: got,
        orderId: action.orderId,
        presentation: _dirtyDetail(Map<String, dynamic>.from(c['detail'] as Map)),
      );
      expect(dartDetail, c['detail']);
    });
  }

  test('A4 keputusan Koko: belum bayar tetap boleh Diambil', () {
    final c = cases.firstWhere((e) => e['name'] == 'status_3_diambil');
    final before = Map<String, dynamic>.from(c['before'] as Map);
    final after = Map<String, dynamic>.from(c['after'] as Map);
    final action = inferOrderDetailA4Action(before: before, after: after)!;
    final got = applyOrderDetailA4(before: before, action: action);
    final b = jsonDecode(got[Keys.business] as String) as Map<String, dynamic>;
    final card = (b['orders'] as List).whereType<Map>().firstWhere((o) {
      final fields = o['fields'] as List;
      return (fields[1] as List).first == action.orderId;
    });
    final detail = (b['details'] as Map)[action.orderId] as Map;
    expect((card['dataset'] as Map)['st'], 'diambil');
    expect(card['payment'], 'Belum Bayar');
    expect(card['paid'], false);
    expect(detail['paid'], 0);
  });
}
