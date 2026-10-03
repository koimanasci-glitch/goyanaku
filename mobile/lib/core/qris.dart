// QRIS: baca TLV, cek CRC16-CCITT, ubah QRIS statis outlet menjadi dinamis bernominal (sama dengan HTML).

String crc16(String s) {
  var c = 0xFFFF;
  for (final unit in s.codeUnits) {
    c ^= unit << 8;
    for (var j = 0; j < 8; j++) {
      c = (c & 0x8000) != 0 ? ((c << 1) ^ 0x1021) : (c << 1);
      c &= 0xFFFF;
    }
  }
  return c.toRadixString(16).toUpperCase().padLeft(4, '0');
}

String tlv(String id, String v) => '$id${v.length.toString().padLeft(2, '0')}$v';

/// Daftar [id, nilai]; null bila format rusak.
List<List<String>>? parseTlv(String s) {
  final out = <List<String>>[];
  var i = 0;
  while (i + 4 <= s.length) {
    final id = s.substring(i, i + 2);
    final len = int.tryParse(s.substring(i + 2, i + 4));
    if (len == null || i + 4 + len > s.length) return null;
    out.add([id, s.substring(i + 4, i + 4 + len)]);
    i += 4 + len;
  }
  return i == s.length ? out : null;
}

bool qrisValid(String s) {
  if (s.length < 30 || !s.startsWith('000201')) return false;
  final body = s.substring(0, s.length - 4);
  return crc16(body) == s.substring(s.length - 4).toUpperCase() && parseTlv(s) != null;
}

/// Nama & kota merchant dari QRIS.
({String name, String city}) qrisMerchant(String s) {
  var n = '', c = '';
  for (final x in parseTlv(s) ?? const <List<String>>[]) {
    if (x[0] == '59') n = x[1];
    if (x[0] == '60') c = x[1];
  }
  return (name: n, city: c);
}

/// Statis → dinamis: tag 01 = 12, tag 54 = nominal, CRC dihitung ulang.
String qrisDynamic(String s, num amount) {
  final p = (parseTlv(s) ?? <List<String>>[]).where((x) => x[0] != '54' && x[0] != '63').map((x) => [...x]).toList();
  if (!p.any((x) => x[0] == '01')) p.add(['01', '12']);
  for (final x in p) {
    if (x[0] == '01') x[1] = '12';
  }
  p.add(['54', '${amount.round()}']);
  p.sort((a, b) => int.parse(a[0]).compareTo(int.parse(b[0])));
  final body = '${p.map((x) => tlv(x[0], x[1])).join()}6304';
  return body + crc16(body);
}
