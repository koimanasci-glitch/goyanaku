// Import Data dari file CSV (revisi Koiman): Pelanggan, Layanan & Harga, Transaksi Lama.
// Kolom dikenali dari judul kolomnya (mis. "Nama", "No HP", "Alamat"); hasil baca ditampilkan dulu sebagai
// pratinjau (baru / duplikat / tidak lengkap) sebelum disimpan. Di HTML asli fitur ini belum dibuat.

import '../core/business.dart';
import '../core/models.dart';
import '../core/money.dart';

/// Baca teks CSV: pemisah koma, titik koma atau tab (dikenali otomatis), tanda kutip ganda didukung.
List<List<String>> parseCsv(String text) {
  var t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (t.startsWith('﻿')) t = t.substring(1);
  final first = t.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  int count(String c) => c.allMatches(first).length;
  final sep = count('\t') > count(',') && count('\t') > count(';') ? '\t' : (count(';') > count(',') ? ';' : ',');
  final rows = <List<String>>[];
  var row = <String>[], cell = StringBuffer(), quoted = false;
  for (var i = 0; i < t.length; i++) {
    final ch = t[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.isEmpty) {
      quoted = true;
    } else if (ch == sep) {
      row.add(cell.toString().trim());
      cell = StringBuffer();
    } else if (ch == '\n') {
      row.add(cell.toString().trim());
      cell = StringBuffer();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString().trim());
  if (row.any((c) => c.isNotEmpty)) rows.add(row);
  return rows;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

const importKinds = ['Pelanggan', 'Layanan & Harga', 'Transaksi Lama'];

/// Kolom per jenis import: [kunci, label, wajib?, nama-nama judul kolom yang dikenali].
const _cols = <int, List<List<Object>>>{
  0: [
    ['name', 'Nama', true, ['nama', 'namapelanggan', 'pelanggan', 'name', 'customer', 'namacustomer']],
    ['phone', 'No HP', true, ['hp', 'nohp', 'nohandphone', 'handphone', 'telepon', 'telp', 'notelp', 'notelepon', 'phone', 'wa', 'whatsapp', 'nowa', 'nomor', 'nomorhp', 'nomorwa']],
    ['address', 'Alamat', false, ['alamat', 'address']],
    ['gender', 'Jenis kelamin', false, ['gender', 'jeniskelamin', 'jk', 'kelamin', 'lp']],
    ['maps', 'Lokasi Maps', false, ['maps', 'lokasi', 'linkmaps', 'koordinat']],
  ],
  1: [
    ['name', 'Nama layanan', true, ['nama', 'layanan', 'namalayanan', 'name', 'service', 'kategori']],
    ['unit', 'Satuan', false, ['satuan', 'unit']],
    ['reg', 'Harga Reguler', true, ['reguler', 'regular', 'harga', 'hargareguler', 'price']],
    ['exp', 'Harga Express', false, ['express', 'ekspres', 'hargaexpress', 'hargaekspres']],
    ['kilat', 'Harga Kilat', false, ['kilat', 'hargakilat']],
  ],
  2: [
    ['date', 'Tanggal', true, ['tanggal', 'tgl', 'date', 'waktu', 'tanggalmasuk', 'tglmasuk']],
    ['name', 'Pelanggan', true, ['pelanggan', 'nama', 'namapelanggan', 'customer', 'name']],
    ['phone', 'No HP', false, ['hp', 'nohp', 'telepon', 'telp', 'phone', 'wa', 'whatsapp', 'nowa']],
    ['service', 'Layanan', true, ['layanan', 'namalayanan', 'item', 'service', 'jasa']],
    ['qty', 'Jumlah', false, ['qty', 'jumlah', 'berat', 'kuantitas', 'kg']],
    ['unit', 'Satuan', false, ['satuan', 'unit']],
    ['price', 'Harga satuan', false, ['harga', 'hargasatuan', 'price']],
    ['total', 'Total', false, ['total', 'subtotal', 'totalbayar', 'tagihan']],
    ['status', 'Status bayar', false, ['status', 'pembayaran', 'bayar', 'statusbayar', 'lunas']],
    ['method', 'Metode', false, ['metode', 'metodebayar', 'method', 'carabayar']],
    ['dur', 'Paket', false, ['paket', 'durasi', 'duration', 'jenis']],
  ],
};

/// Contoh isi file untuk tiap jenis import (baris pertama = judul kolom).
const importTemplates = [
  'Nama;No HP;Alamat;Jenis Kelamin\nBudi Santoso;081234567890;Jl. Melati 5 Bekasi;L\nSiti Aminah;085711112222;Perum Griya Asri B2;P\n',
  'Nama Layanan;Satuan;Reguler;Express;Kilat\nCuci Setrika;kg;7000;10500;14000\nBed Cover;pcs;25000;37500;50000\nKarpet;m;15000;22500;30000\n',
  'Tanggal;Pelanggan;No HP;Layanan;Jumlah;Satuan;Harga;Total;Status;Metode\n01/09/2026;Budi Santoso;081234567890;Cuci Setrika;3,5;kg;7000;24500;Lunas;Tunai\n03/09/2026;Siti Aminah;085711112222;Bed Cover;1;pcs;25000;25000;Belum;\n',
];
const importTemplateNames = ['contoh-import-pelanggan.csv', 'contoh-import-layanan.csv', 'contoh-import-transaksi.csv'];

String importPhone(String v) {
  var d = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('62')) d = '0${d.substring(2)}';
  if (d.startsWith('8')) d = '0$d';
  return d;
}

/// Tanggal "31/12/2025", "31-12-2025 14:30" atau "2025-12-31".
DateTime? importDate(String v) {
  final t = v.trim();
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2})[:.](\d{2}))?').firstMatch(t);
  if (m != null) return _dt(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!), m.group(4), m.group(5));
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?:[ ,]+(\d{1,2})[:.](\d{2}))?').firstMatch(t);
  if (m == null) return null;
  var y = int.parse(m.group(3)!);
  if (y < 100) y += 2000;
  return _dt(y, int.parse(m.group(2)!), int.parse(m.group(1)!), m.group(4), m.group(5));
}

DateTime? _dt(int y, int mo, int d, String? h, String? mi) {
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  return DateTime(y, mo, d, int.tryParse(h ?? '') ?? 12, int.tryParse(mi ?? '') ?? 0);
}

class ImportPlan {
  ImportPlan(this.kind);
  final int kind;
  String? error;
  /// "Nama ← kolom Nama Pelanggan"
  final List<String> mapping = [];
  final List<String> sample = [];
  int rows = 0, dup = 0, bad = 0;
  final List<Map<String, String>> fresh = [];
  String get title => 'Import ${importKinds[kind]}';
  String get summary => '$rows baris terbaca · ${fresh.length} siap diimport · $dup duplikat dilewati · $bad tidak lengkap';
}

/// Baca [text] sebagai file import jenis [kind] (0 pelanggan, 1 layanan, 2 transaksi) dan bandingkan dengan data sekarang.
ImportPlan planImport(int kind, String text, Business b) {
  final plan = ImportPlan(kind);
  final rows = parseCsv(text);
  if (rows.length < 2) {
    plan.error = 'File kosong atau tidak terbaca. Pakai file CSV dengan judul kolom di baris pertama.';
    return plan;
  }
  final head = rows.first.map(_norm).toList();
  final idx = <String, int>{};
  for (final c in _cols[kind]!) {
    final names = c[3] as List;
    final k = head.indexWhere((h) => names.contains(h));
    if (k >= 0 && !idx.containsValue(k)) {
      idx['${c[0]}'] = k;
      plan.mapping.add('${c[1]} ← kolom "${rows.first[k]}"');
    }
  }
  final missing = [for (final c in _cols[kind]!) if (c[2] == true && !idx.containsKey(c[0])) '${c[1]}'];
  if (missing.isNotEmpty) {
    plan.error = 'Kolom wajib tidak ditemukan: ${missing.join(', ')}. Judul kolom yang terbaca: ${rows.first.where((e) => e.isNotEmpty).join(', ')}.';
    return plan;
  }
  String cell(List<String> r, String key) => idx[key] == null || idx[key]! >= r.length ? '' : r[idx[key]!].trim();
  final seen = <String>{};
  for (final r in rows.skip(1)) {
    plan.rows++;
    final name = cell(r, 'name');
    switch (kind) {
      case 0:
        final phone = importPhone(cell(r, 'phone'));
        if (name.isEmpty || phone.length < 8) {
          plan.bad++;
        } else if (b.customerByName(name) != null || !seen.add(name.toLowerCase())) {
          plan.dup++;
        } else {
          final g = cell(r, 'gender').toLowerCase();
          plan.fresh.add({'name': name, 'phone': phone, 'address': cell(r, 'address'), 'maps': cell(r, 'maps'), 'gender': RegExp(r'^(p|w|f)$|wanita|perempuan|female|cewek').hasMatch(g) ? 'female' : 'male'});
        }
      case 1:
        final reg = parseRupiah(cell(r, 'reg'));
        if (name.isEmpty || reg <= 0) {
          plan.bad++;
        } else if (b.services.any((s) => s.name.toLowerCase() == name.toLowerCase()) || !seen.add(name.toLowerCase())) {
          plan.dup++;
        } else {
          final u = cell(r, 'unit').toLowerCase();
          plan.fresh.add({
            'name': name, 'unit': RegExp(r'^(pc|pcs|buah|satuan|potong|lembar|psg|pasang)').hasMatch(u) ? 'pcs' : (RegExp(r'^m').hasMatch(u) ? 'm' : 'kg'),
            'reg': '$reg', 'exp': '${parseRupiah(cell(r, 'exp'))}', 'kilat': '${parseRupiah(cell(r, 'kilat'))}',
          });
        }
      default:
        final at = importDate(cell(r, 'date')), service = cell(r, 'service');
        final qty = parseQty(cell(r, 'qty').isEmpty ? '1' : cell(r, 'qty'));
        var price = parseRupiah(cell(r, 'price'));
        final total = parseRupiah(cell(r, 'total'));
        if (price <= 0 && total > 0 && qty > 0) price = (total / qty).round();
        if (at == null || name.isEmpty || service.isEmpty || qty <= 0 || price <= 0) {
          plan.bad++;
        } else {
          final st = cell(r, 'status').toLowerCase(), dur = cell(r, 'dur');
          final known = b.services.where((s) => s.name.toLowerCase() == service.toLowerCase()).firstOrNull;
          plan.fresh.add({
            'at': at.toIso8601String(), 'name': name, 'phone': importPhone(cell(r, 'phone')), 'service': service, 'qty': '$qty', 'price': '$price',
            'unit': cell(r, 'unit').isNotEmpty ? cell(r, 'unit') : (known?.unit ?? 'pcs'),
            'paid': idx['status'] == null || (RegExp('lunas|paid|sudah|selesai').hasMatch(st) && !RegExp('belum|blm|hutang|unpaid').hasMatch(st)) ? '1' : '0',
            'method': cell(r, 'method').isEmpty ? 'Tunai' : cell(r, 'method'),
            'dur': RegExp('kilat', caseSensitive: false).hasMatch(dur) ? 'Kilat' : (RegExp('expres|ekspres', caseSensitive: false).hasMatch(dur) ? 'Express' : 'Reguler'),
          });
        }
    }
  }
  for (final f in plan.fresh.take(3)) {
    plan.sample.add(switch (kind) {
      0 => '${f['name']} · ${f['phone']}${f['address']!.isEmpty ? '' : ' · ${f['address']}'}',
      1 => '${f['name']} · ${rp(int.parse(f['reg']!))}/${f['unit']}',
      _ => '${f['at']!.substring(0, 10)} · ${f['name']} · ${f['service']} · ${rp((double.parse(f['qty']!) * int.parse(f['price']!)).round())}',
    });
  }
  return plan;
}

/// Simpan isi [plan] ke data usaha. Mengembalikan jumlah yang tersimpan.
int applyImport(ImportPlan plan, Business b) {
  var n = 0;
  for (final f in plan.fresh) {
    switch (plan.kind) {
      case 0:
        if (b.saveCustomer(Customer(name: f['name']!, phone: f['phone']!, address: f['address']!, gender: f['gender']!, maps: f['maps']!)) == null) n++;
      case 1:
        final reg = int.parse(f['reg']!), exp = int.parse(f['exp']!), kilat = int.parse(f['kilat']!);
        b.services.add(Service({
          'key': f['name']!.toLowerCase(), 'name': f['name'], 'unit': f['unit'],
          'prices': {'Reguler': reg, 'Express': exp > 0 ? exp : (reg * 1.5 / 500).round() * 500, 'Kilat': kilat > 0 ? kilat : reg * 2},
          'enabled': {'Reguler': true, 'Express': true, 'Kilat': true}, 'proc': ['Cuci', 'Kering', 'Setrika', 'Packing'],
        }));
        n++;
      default:
        b.importOrder(
          customer: f['name']!, phone: f['phone']!, dur: f['dur']!, at: DateTime.parse(f['at']!), paid: f['paid'] == '1', method: f['method']!,
          items: [OrderItem(name: f['service']!, unit: f['unit']!, price: int.parse(f['price']!), qty: double.parse(f['qty']!))],
        );
        n++;
    }
  }
  return n;
}
