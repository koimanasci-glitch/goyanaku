// Diskon (v127 di HTML): daftar diskon, aturan kasir, dan hitungan potongan per cakupan layanan.
import '../core/models.dart';
import '../core/money.dart';

const _bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const discScopes = ['Semua layanan', 'Kiloan', 'Satuan', 'Meteran'];
const _unit = {'Kiloan': 'kg', 'Satuan': 'pcs', 'Meteran': 'm'};

int _i(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}'.replaceAll(RegExp(r'\D'), '')) ?? 0;

/// Daftar diskon tersimpan dalam bentuk HTML: {id, name, type p/n, val, scope, min, until, on}.
/// Bentuk lama Mode Murni ([label, 'p10']) diubah di tempat tanpa kehilangan data.
List<Map<String, dynamic>> discountsOf(Map<String, dynamic> raw) {
  final src = raw['discounts'] is List ? raw['discounts'] as List : const [];
  final out = <Map<String, dynamic>>[];
  var nid = 4;
  for (final d in src) {
    if (d is Map) {
      out.add(Map<String, dynamic>.from(d));
    } else if (d is List && d.length > 1) {
      final m = RegExp(r'^([pn])(\d+)$').firstMatch('${d[1]}');
      if (m == null) continue;
      out.add({'name': '${d[0]}'.replaceFirst(RegExp(r'\s*\([^)]*\)$'), ''), 'type': m.group(1), 'val': int.parse(m.group(2)!), 'scope': discScopes[0], 'min': 0, 'until': '', 'on': true});
    }
  }
  for (final d in out) {
    if (_i(d['id']) >= nid) nid = _i(d['id']) + 1;
  }
  for (final d in out) {
    if (_i(d['id']) == 0) d['id'] = nid++;
  }
  raw['discounts'] = out;
  return out;
}

Map<String, dynamic> discCfgOf(Map<String, dynamic> raw) {
  final c = raw['discCfg'] is Map ? Map<String, dynamic>.from(raw['discCfg'] as Map) : <String, dynamic>{};
  c['manual'] = c['manual'] != false;
  c['maxPct'] = c['maxPct'] is num ? (c['maxPct'] as num).round().clamp(0, 100) : 20;
  raw['discCfg'] = c;
  return c;
}

int nextDiscId(List<Map<String, dynamic>> list) => list.fold<int>(3, (a, d) => _i(d['id']) > a ? _i(d['id']) : a) + 1;

String discLabel(Map d) => d['type'] == 'p' ? '${_i(d['val'])}%' : rp(_i(d['val']));

String discDesc(Map d) {
  final u = DateTime.tryParse('${d['until'] ?? ''}');
  final min = _i(d['min']);
  return '${d['scope']}${min > 0 ? ' · min ${rp(min)}' : ''}${u != null ? ' · s/d ${u.day} ${_bln[u.month - 1]} ${u.year}' : ''}';
}

bool discExpired(Map d, DateTime now) {
  final u = DateTime.tryParse('${d['until'] ?? ''}');
  return u != null && DateTime(u.year, u.month, u.day, 23, 59).isBefore(now);
}

bool discActive(Map d, DateTime now) => d['on'] != false && !discExpired(d, now);

/// Teks pilihan di Atur Pesanan, sama dengan HTML.
String discOption(Map d) {
  final min = _i(d['min']);
  return '${d['name']} · ${discLabel(d)}${d['scope'] != discScopes[0] ? ' (${d['scope']})' : ''}${min > 0 ? ' · min ${rp(min)}' : ''}';
}

/// Dasar hitung: semua layanan, atau hanya layanan dengan satuan cakupan diskon.
int discBase(Map d, List<OrderItem> cart) {
  final all = cart.fold<int>(0, (a, c) => a + c.subtotal);
  if (d['scope'] == discScopes[0] || cart.isEmpty) return all;
  return cart.where((c) => c.unit == _unit[d['scope']]).fold<int>(0, (a, c) => a + c.subtotal);
}

int discAmount(Map d, List<OrderItem> cart) {
  final b = discBase(d, cart);
  if (b == 0) return 0;
  final v = _i(d['val']);
  final a = d['type'] == 'p' ? (b * v / 100).round() : v;
  return a < b ? a : b;
}

/// Kunci diskon yang disimpan di pesanan: persen untuk semua layanan tetap persen, lainnya nominal.
String discKey(Map d, List<OrderItem> cart) {
  if (d['type'] == 'p' && d['scope'] == discScopes[0]) return 'p${_i(d['val'])}';
  return 'n${discAmount(d, cart)}';
}
