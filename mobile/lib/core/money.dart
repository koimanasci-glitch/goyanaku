// Format angka rupiah persis seperti aplikasi HTML (toLocaleString('id-ID')).

/// 14000 → "14.000"; negatif → "-14.000".
String thousands(num value) {
  final n = value.round();
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return neg ? '-$b' : b.toString();
}

/// Kartu & struk: "Rp14.000".
String rp(num value) => 'Rp${thousands(value)}';

/// Rincian & pembayaran: "Rp 14.000".
String rpSpaced(num value) => 'Rp ${thousands(value)}';

/// "Rp 14.000", "14000", "Rp14.000,-" → 14000.
int parseRupiah(Object? v) {
  if (v is num) return v.round();
  final digits = '${v ?? ''}'.split(',').first.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}

/// Jumlah (berat/pcs) boleh pakai koma atau titik: "1,3" → 1.3.
double parseQty(Object? v) {
  if (v is num) return v.toDouble();
  final s = '${v ?? ''}'.trim().replaceAll(',', '.');
  return double.tryParse(s) ?? 0;
}

/// 2 → "2", 1.5 → "1,5" (gaya Indonesia).
String qtyText(num q) {
  if (q == q.roundToDouble()) return q.round().toString();
  var s = q.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll('.', ',');
}

/// Nomor WhatsApp internasional tanpa tanda: "0812…" / "812…" / "+62 812…" → "62812…". Kosong bila tidak ada angka.
/// Satu-satunya tempat aturan ini (dulu disalin di banyak halaman dan nomor tanpa 0 di depan salah tujuan).
String waNumber(Object? phone) {
  var d = '${phone ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0')) {
    d = '62${d.substring(1)}';
  } else if (d.startsWith('8')) {
    d = '62$d';
  }
  return d;
}
