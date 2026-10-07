// Tambah / Edit Pelanggan (HTML #customeradd v88 + v126 jenis kelamin + v128 lokasi Maps + v178 kontak HP).
// Alur sama dengan Hibrida: popup "pria atau wanita?" dulu, lalu nama, no HP, alamat, lokasi Maps.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import 'map_pick.dart';
import 'pages.dart';

const _svgMale = "<svg viewBox=\"0 0 64 64\" aria-hidden=\"true\"><path d=\"M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54\" fill=\"#5C97F8\"></path><circle cx=\"32\" cy=\"26\" r=\"11\" fill=\"#FFD6B3\"></circle><path d=\"M21 24.5c0-8.5 4.5-13.5 11-13.5 6.6 0 11 5 11 13.5v2.1H21v-2.1z\" fill=\"#26384D\"></path><circle cx=\"28\" cy=\"26\" r=\"1.3\" fill=\"#26384D\"></circle><circle cx=\"36\" cy=\"26\" r=\"1.3\" fill=\"#26384D\"></circle><path d=\"M29 31c1.6 1.6 4.4 1.6 6 0\" stroke=\"#D58A78\" stroke-width=\"1.7\" fill=\"none\" stroke-linecap=\"round\"></path></svg>";
const _svgFemale = "<svg viewBox=\"0 0 64 64\" aria-hidden=\"true\"><path d=\"M17 54c1.2-8.4 6.1-12.6 15-12.6S45.8 45.6 47 54\" fill=\"#E56A8C\"></path><circle cx=\"32\" cy=\"26\" r=\"11\" fill=\"#FFD8C7\"></circle><path d=\"M18.5 26.2c0-9.6 5.1-15 13.5-15s13.5 5.4 13.5 15c0 4.5-1.7 8.4-4.4 11-1.1-6.9-4.3-10.6-9.1-10.6s-8 3.7-9.1 10.6c-2.7-2.6-4.4-6.5-4.4-11z\" fill=\"#6D4A3C\"></path><circle cx=\"28\" cy=\"26\" r=\"1.3\" fill=\"#453126\"></circle><circle cx=\"36\" cy=\"26\" r=\"1.3\" fill=\"#453126\"></circle><path d=\"M29 31c1.6 1.6 4.4 1.6 6 0\" stroke=\"#D88A86\" stroke-width=\"1.7\" fill=\"none\" stroke-linecap=\"round\"></path></svg>";

/// Baca isian lokasi: "lat, lng" atau tautan Google Maps. Null = kosong, '' = tidak dikenali, selain itu tautan Maps.
String? parseMapsInput(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$').firstMatch(t);
  if (m != null) {
    final la = double.parse(m.group(1)!), lo = double.parse(m.group(2)!);
    if (la.abs() <= 90 && lo.abs() <= 180) return 'https://maps.google.com/?q=$la,$lo';
  }
  if (RegExp(r'^https?://(maps\.app\.goo\.gl|goo\.gl/maps|maps\.google\.|www\.google\.[^/]+/maps)', caseSensitive: false).hasMatch(t)) return t;
  return '';
}

/// Titik (lat, lng) bila isian lokasi berupa koordinat; null untuk tautan/kosong.
(double, double)? mapsPoint(String v) {
  final m = RegExp(r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$').firstMatch(v.trim());
  if (m == null) return null;
  final la = double.parse(m.group(1)!), lo = double.parse(m.group(2)!);
  return la.abs() <= 90 && lo.abs() <= 180 ? (la, lo) : null;
}

class CustomerAddPage extends PurePage {
  CustomerAddPage(super.host);
  String? editing;
  bool forOrder = false;
  String name = '', phone = '', address = '', maps = '', gender = 'male';
  List<Map<String, String>> contacts = [];
  String contactQuery = '';

  /// Siapkan halaman: [c] null = pelanggan baru (popup jenis kelamin muncul dulu).
  void start(Customer? c, {bool forOrder = false}) {
    editing = c?.name;
    this.forOrder = forOrder;
    name = c?.name ?? '';
    phone = c?.phone ?? '';
    address = c?.address ?? '';
    maps = c?.maps ?? '';
    gender = c?.gender == 'female' ? 'female' : 'male';
  }

  @override
  String get title => editing == null ? 'TAMBAH PELANGGAN' : 'EDIT PELANGGAN';
  @override
  String get back => forOrder ? 'addorder' : 'customers';
  @override
  int get navActive => 0;

  @override
  void opened() {
    if (editing == null) host.openPageSheet('gp128');
  }

  String get _mapsHint {
    final r = parseMapsInput(maps);
    if (r == null) return 'Opsional · tempel link Maps atau share lokasi WA pelanggan untuk kurir.';
    if (r.isEmpty) return 'Link tidak dikenali. Pakai link Google Maps atau koordinat, contoh -6.2615, 107.1520';
    return RegExp(r'^\s*-?\d').hasMatch(maps) ? '✓ Titik lokasi terbaca ($maps)' : '✓ Link Maps tersimpan';
  }

  @override
  List<Map<String, dynamic>> items() => [
        {'type': 'button', 't': 'Pilih dari Kontak HP', 'primary': true, 'i': 0},
        {'type': 'row', 't': gender == 'female' ? 'Wanita' : 'Pria', 's': 'Jenis kelamin · untuk avatar', 'btn': 'Ganti', 'svg': gender == 'female' ? _svgFemale : _svgMale, 'i': 1},
        {'type': 'input', 'v': name, 'ph': 'Nama Pelanggan', 'i': 0},
        {'type': 'input', 'v': phone, 'ph': 'No Handphone', 'numeric': true, 'i': 1},
        {'type': 'input', 'v': address, 'ph': 'Alamat', 'i': 2},
        {'type': 'input', 'v': maps, 'ph': 'Lokasi pelanggan / tautan Maps (opsional)', 'i': 3},
        {'type': 'buttons', 'cols': 2, 'options': [
          {'t': '📍 Lokasi saya', 'on': false, 'i': 5}, {'t': '📋 Tempel link', 'on': false, 'i': 6},
        ]},
        if (parseMapsInput(maps)?.isNotEmpty == true) {'type': 'button', 't': 'Cek di Peta', 'primary': false, 'i': 8},
        {'type': 'button', 't': editing == null ? 'Tambahkan' : 'Simpan', 'primary': true, 'i': 7},
        {'type': 'hint', 't': _mapsHint},
        {'type': 'hint', 't': 'Nama dan no handphone wajib diisi. Alamat dan Maps boleh dikosongkan.'},
      ];

  @override
  void input(int i, Object value) {
    final v = '$value';
    if (i == 0) name = v;
    if (i == 1) phone = v;
    if (i == 2) address = v;
    if (i == 3) {
      maps = v;
      host.refresh();
    }
  }

  void _openUrl(String url) => host.device.invokeMethod('App.openUrl', {'url': url}).catchError((_) => null);

  @override
  void button(int i) async {
    switch (i) {
      case 0:
        try {
          final r = await host.device.invokeMapMethod<String, dynamic>('GoyanaDevice.contacts');
          contacts = [
            for (final c in (r?['contacts'] as List? ?? const []).whereType<Map>())
              if ('${c['name'] ?? ''}'.trim().isNotEmpty) {'name': '${c['name']}'.trim(), 'phone': '${c['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9+]'), '')},
          ];
        } on PlatformException catch (e) {
          return host.toast(e.message ?? 'Izin kontak belum diberikan. Cek Pengaturan → Izin Aplikasi.');
        } catch (_) {
          return host.toast('Kontak HP tidak dapat dibaca');
        }
        if (contacts.isEmpty) return host.toast('Tidak ada kontak di HP ini');
        contactQuery = '';
        return host.openPageSheet('contacts178');
      case 1:
        return host.openPageSheet('gp128');
      case 5:
        // Lokasi saya: ambil titik GPS lalu buka peta di dalam aplikasi untuk ditandai (pin bisa digeser).
        host.toast('Mengambil lokasi…');
        final p = await _gps();
        final at = p ?? mapsPoint(maps);
        _mapStart = at ?? const (-6.200000, 106.816666);
        _mapLocated = p != null;
        _mapZoom = at == null ? 11 : 17;
        if (p == null) host.toast('Lokasi HP belum didapat · geser peta ke rumah pelanggan');
        return host.openPageSheet('map203');
      case 6:
        try {
          final r = await host.device.invokeMapMethod<String, dynamic>('Clipboard.read');
          final t = '${r?['text'] ?? ''}'.trim();
          if (t.isEmpty) return host.toast('Belum ada teks yang disalin');
          maps = t;
          host.refresh();
        } catch (_) {
          host.toast('Tekan lama di kolom lalu pilih Tempel');
        }
        return;
      case 8:
        // Titik koordinat dibuka di peta dalam aplikasi; tautan Maps (tanpa koordinat) dibuka di Google Maps.
        final at = mapsPoint(maps);
        if (at != null) {
          _mapStart = at;
          _mapLocated = false;
          _mapZoom = 17;
          return host.openPageSheet('map203');
        }
        final link = parseMapsInput(maps);
        if (link != null && link.isNotEmpty) _openUrl(link);
        return;
      case 7:
        final loc = parseMapsInput(maps);
        if (loc != null && loc.isEmpty) return host.toast('Link Maps tidak dikenali · kosongkan atau perbaiki dulu');
        final c = Customer(name: name.trim(), phone: phone.trim(), address: address.trim(), gender: gender, maps: maps.trim());
        final err = host.business.saveCustomer(c, originalName: editing);
        if (err != null) return host.toast(err);
        await host.saveAll();
        host.toast(editing == null ? 'Pelanggan ${c.name} ditambahkan' : 'Data pelanggan disimpan');
        host.customerSaved(c.name, forOrder: forOrder);
    }
  }

  // ---------- peta dalam aplikasi (map203) ----------
  (double, double) _mapStart = const (-6.200000, 106.816666);
  bool _mapLocated = false;
  int _mapZoom = 17;

  Future<(double, double)?> _gps() async {
    try {
      final p = await host.device.invokeMapMethod<String, dynamic>('Geolocation.getCurrentPosition', {'enableHighAccuracy': true, 'timeout': 10000});
      final c = p?['coords'] as Map?;
      final la = (c?['latitude'] as num?)?.toDouble(), lo = (c?['longitude'] as num?)?.toDouble();
      return la == null || lo == null ? null : (la, lo);
    } catch (_) {
      return null;
    }
  }

  /// Popup peta ditutup dengan titik terpilih: isi kolom lokasi.
  void pickPoint(double lat, double lng) {
    maps = mapCoordText(lat, lng);
    host.closePageSheet('map203');
    host.toast('Lokasi ditandai');
    host.refresh();
  }

  @override
  Widget? sheetWidget(String id, BuildContext context) {
    if (id != 'map203') return null;
    return MapPick(
      key: ValueKey('map203-${_mapStart.$1}-${_mapStart.$2}'),
      lat: _mapStart.$1, lng: _mapStart.$2, zoom: _mapZoom, located: _mapLocated,
      onPick: pickPoint, onClose: () => host.closePageSheet('map203'), onLocate: _gps,
    );
  }

  // ---------- popup: jenis kelamin (gp128) & kontak HP (contacts178) ----------
  List<Map<String, String>> get _shown {
    final q = contactQuery.trim().toLowerCase();
    return [for (final c in contacts) if (q.isEmpty || '${c['name']} ${c['phone']}'.toLowerCase().contains(q)) c].take(60).toList();
  }

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    if (id == 'gp128') {
      return [
        {'type': 'title', 't': 'Pelanggan ini pria atau wanita?', 's': ''},
        {'type': 'hint', 't': 'Untuk avatar pelanggan di daftar & pesanan'},
        {'type': 'buttons', 'cols': 2, 'options': [
          {'t': 'Pria', 'svg': _svgMale, 'file': '', 'after': false, 'on': false, 'i': 0},
          {'t': 'Wanita', 'svg': _svgFemale, 'file': '', 'after': false, 'on': false, 'i': 1},
        ]},
      ];
    }
    if (id != 'contacts178') return null;
    final list = _shown;
    return [
      {'type': 'title', 't': 'Pilih dari Kontak HP', 's': ''},
      {'type': 'input', 'v': contactQuery, 'ph': 'Cari nama / nomor', 'i': 0},
      if (list.isEmpty) {'type': 'hint', 't': 'Kontak tidak ditemukan'},
      for (var k = 0; k < list.length; k++) {'type': 'card', 't': list[k]['name'], 's': list[k]['phone'], 'svg': '', 'ic': '👤', 'badge': '', 'meta': '', 'on': false, 'i': k},
      {'type': 'button', 't': 'Batal', 'primary': false, 'i': 1000},
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    if (id == 'gp128') {
      if (kind == 'button') gender = index == 1 ? 'female' : 'male';
      host.closePageSheet('gp128');
      return host.refresh();
    }
    if (id != 'contacts178') return;
    if (kind == 'input') {
      contactQuery = '${value ?? ''}';
      return host.refresh();
    }
    if (kind == 'button' && index < 1000) {
      final list = _shown;
      if (index >= 0 && index < list.length) {
        name = list[index]['name'] ?? '';
        phone = list[index]['phone'] ?? '';
      }
    }
    host.closePageSheet('contacts178');
    host.refresh();
  }
}
