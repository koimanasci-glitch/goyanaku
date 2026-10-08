// Hubungkan WhatsApp (wadevices195): daftar nomor WhatsApp usaha, tiap nomor untuk satu outlet.
// Susunan mengikuti halaman HTML v195 (Tambah Device, baris perangkat dengan Hubungkan/Edit/Hapus, popup Scan QR / Kode WhatsApp).
// Data dan aturan dari modul lib/whatsapp: draf di HP, pendaftaran dan kuota slot di server, QR/kode asli dari layanan WhatsApp.

import 'dart:async';

import '../whatsapp/device_store.dart';
import 'pages.dart';
import 'wa_link.dart';

class WaDevicesPage extends PurePage {
  WaDevicesPage(super.host, this.wa);
  final WaLink wa;

  static const _form = 'wa195-form', _pair = 'wa195-pair', _del = 'wa195-del';

  String? _editId;
  String _name = '', _phone = '';
  int _outlet = 0;
  String? _targetId;
  String _method = 'qr';
  WaPairing? _pairing;
  Timer? _expiry;

  @override
  String get title => 'HUBUNGKAN WHATSAPP';

  @override
  void opened() {
    _clearPairing();
    wa.sync();
  }

  WaDevice? get _target => wa.store.devices.where((d) => d.id == _targetId).firstOrNull;

  void _clearPairing() {
    _expiry?.cancel();
    _expiry = null;
    _pairing = null;
  }

  String _status(WaDevice d) => switch (d.status) {
        'draft' => 'Draf di HP ini, belum dihubungkan',
        'connected' => 'Terhubung (pemeriksaan terakhir)',
        'pairing' => 'Menunggu penautan',
        'disconnected' => 'Belum terhubung',
        _ => 'Status belum diperiksa',
      };

  @override
  List<Map<String, dynamic>> items() {
    final st = wa.store;
    final out = <Map<String, dynamic>>[
      {'type': 'hint', 't': 'Kelola beberapa nomor WhatsApp dan pilih cabang untuk setiap perangkat.'},
    ];
    if (wa.staffOnly) {
      out.add({'type': 'hint', 't': 'Hanya pemilik usaha yang dapat mengatur nomor WhatsApp.'});
      return out;
    }
    out.add({'type': 'button', 't': '+ Tambah Device', 'primary': true, 'file': '', 'after': false, 'i': 0});
    final limit = st.slotLimit;
    if (limit != null) {
      out.add({
        'type': 'hint',
        't': limit == 0
            ? 'Paket saat ini belum mendukung WhatsApp. Nomor WhatsApp tersedia mulai paket Silver.'
            : 'Slot nomor WhatsApp: ${st.slotsUsed ?? 0} dari $limit terpakai. Menambah cabang tidak menambah slot.',
      });
    }
    if (wa.note.isNotEmpty) out.add({'type': 'hint', 't': wa.note});
    final list = st.devices;
    if (list.isEmpty) {
      out
        ..add({'type': 'title', 't': 'Belum ada perangkat'})
        ..add({'type': 'hint', 't': 'Ketuk Tambah Device, lalu isi nomor dan pilih cabang.'});
    }
    for (var k = 0; k < list.length; k++) {
      final d = list[k];
      out.add({
        'type': 'entry', 't': d.name,
        'lines': ['+${d.phone} · ${wa.outletName(d)}', _status(d), if (d.registered && d.replyStatus) 'Balas Status WhatsApp aktif'],
        'badge': '', 'avatar': d.name.isEmpty ? 'W' : d.name[0].toUpperCase(), 'svg': '', 'color': '', 'amount': '',
        'btns': [
          {'t': d.status == 'connected' ? 'Cek Status' : 'Hubungkan', 'on': d.status != 'connected', 'i': 1000 + 10 * k},
          {'t': 'Edit', 'on': false, 'i': 1001 + 10 * k},
          {'t': 'Hapus', 'on': false, 'i': 1002 + 10 * k},
        ],
      });
    }
    out.add({
      'type': 'hint',
      't': host.server.loggedIn
          ? 'Perangkat baru tersimpan sebagai draf di HP ini sampai dihubungkan. QR dan kode pemasangan berasal dari layanan WhatsApp GOYANA.'
          : 'Perangkat tersimpan di HP ini. Masuk ke akun GOYANA untuk menautkan WhatsApp.',
    });
    return out;
  }

  @override
  void button(int i) {
    if (wa.staffOnly) return;
    final st = wa.store;
    if (i == 0) {
      if (st.outlets.isEmpty) return host.toast('Tambahkan pusat atau cabang di Pengaturan Outlet terlebih dahulu.');
      _editId = null;
      _name = '';
      _phone = '';
      _outlet = 0;
      return host.openPageSheet(_form);
    }
    if (i < 1000) return;
    final k = (i - 1000) ~/ 10, act = (i - 1000) % 10;
    if (k >= st.devices.length) return;
    final d = st.devices[k];
    switch (act) {
      case 0:
        if (d.status == 'connected') {
          wa.run(() => st.refreshDevice(d.id), ok: 'Status diperbarui');
          return;
        }
        _targetId = d.id;
        _method = 'qr';
        _clearPairing();
        host.openPageSheet(_pair);
      case 1:
        _editId = d.id;
        _name = d.name;
        _phone = d.phone;
        final at = st.outlets.indexWhere((o) => o.key == d.outletKey);
        _outlet = at < 0 ? 0 : at;
        host.openPageSheet(_form);
      case 2:
        _targetId = d.id;
        host.openPageSheet(_del);
    }
  }

  Map<String, dynamic> _input(String v, String ph, int i) =>
      {'type': 'input', 'v': v, 'ph': ph, 'multiline': false, 'numeric': false, 'decimal': false, 'ro': false, 'secret': false, 'email': false, 'i': i};

  Map<String, dynamic> _button(String t, int i, {bool primary = false}) => {'type': 'button', 't': t, 'primary': primary, 'file': '', 'after': false, 'i': i};

  @override
  List<Map<String, dynamic>>? sheetItems(String id) {
    final st = wa.store;
    if (id == _form) {
      return [
        {'type': 'title', 't': _editId == null ? 'Tambah Device' : 'Edit Device', 's': ''},
        {'type': 'hint', 't': 'Satu nomor WhatsApp untuk satu outlet.'},
        {'type': 'label', 't': 'Nama perangkat'},
        _input(_name, 'Contoh: WA Kasir', 0),
        {'type': 'label', 't': 'Nomor WhatsApp'},
        _input(_phone, '08xxxxxxxxxx', 1),
        {'type': 'label', 't': 'Outlet'},
        {'type': 'select', 'options': [for (final o in st.outlets) o.name], 'index': _outlet.clamp(0, st.outlets.isEmpty ? 0 : st.outlets.length - 1), 'i': 2},
        _button('Simpan', 0, primary: true),
      ];
    }
    final d = _target;
    if (d == null) return null;
    if (id == _del) {
      return [
        {'type': 'title', 't': 'Hapus perangkat?', 's': ''},
        {
          'type': 'hint',
          't': d.registered
              ? 'Sambungan ${d.name} akan diputus di server. Bila server gagal memutus, perangkat tetap tersimpan.'
              : 'Draf ${d.name} dihapus dari HP ini.',
        },
        _button('Hapus', 0, primary: true),
        _button('Batal', 1),
      ];
    }
    if (id != _pair) return null;
    final p = _pairing;
    final qr = _method == 'qr';
    final expired = p != null && !p.expiresAt.isAfter(st.clock());
    return [
      {'type': 'title', 't': 'Hubungkan WhatsApp', 's': ''},
      {'type': 'hint', 't': '${d.name} · +${d.phone} · ${wa.outletName(d)}'},
      {'type': 'hint', 't': 'Pilih cara menautkan nomor WhatsApp outlet.'},
      {
        'type': 'buttons',
        'options': [
          {'t': 'Scan QR', 'svg': '', 'file': '', 'after': false, 'on': qr, 'i': 0},
          {'t': 'Kode WhatsApp', 'svg': '', 'file': '', 'after': false, 'on': !qr, 'i': 1},
        ],
      },
      {
        'type': 'hint',
        't': qr
            ? 'Buka WhatsApp di HP nomor outlet. Pilih Perangkat tertaut, lalu Tautkan perangkat dan pindai QR di bawah.'
            : 'Buka WhatsApp di HP nomor outlet. Pilih Perangkat tertaut, Tautkan perangkat, lalu Tautkan dengan nomor telepon dan masukkan kode di bawah.',
      },
      if (p == null)
        _button(wa.busy ? 'Meminta…' : (qr ? 'Tampilkan QR' : 'Minta Kode'), 3, primary: true)
      else if (expired) ...[
        {'type': 'hint', 't': 'QR atau kode sudah kedaluwarsa.'},
        _button('Minta Ulang', 3, primary: true),
      ] else ...[
        if (p.kind == 'qr') {'type': 'qr', 'data': p.value, 'size': 220} else {'type': 'title', 't': p.value, 's': ''},
        {'type': 'hint', 't': 'Berlaku sampai ${_clock(p.expiresAt)}. Setelah menautkan, ketuk Periksa Status.'},
        _button('Periksa Status', 4, primary: true),
      ],
      _button('Tutup', 2),
    ];
  }

  @override
  void sheetEvent(String id, String kind, int index, Object? value) {
    final st = wa.store;
    if (id == _form) {
      if (kind == 'input') {
        switch (index) {
          case 0:
            _name = '${value ?? ''}';
          case 1:
            _phone = '${value ?? ''}';
          case 2:
            _outlet = value is int ? value : int.tryParse('$value') ?? 0;
            host.refresh();
        }
        return;
      }
      if (kind != 'button' || index != 0) return;
      if (_outlet < 0 || _outlet >= st.outlets.length) {
        host.toast('Pilih outlet yang sudah dibuat.');
        return;
      }
      wa.run(() => st.save(id: _editId, name: _name, phone: _phone, outletKey: st.outlets[_outlet].key), ok: 'Perangkat tersimpan').then((done) {
        if (done) host.closePageSheet(_form);
      });
      return;
    }
    if (kind != 'button') return;
    final d = _target;
    if (id == _del) {
      host.closePageSheet(_del);
      if (index == 0 && d != null) wa.run(() => st.remove(d.id), ok: 'Perangkat dihapus');
      return;
    }
    if (id != _pair) return;
    switch (index) {
      case 0 || 1:
        _method = index == 0 ? 'qr' : 'code';
        _clearPairing();
        host.refresh();
      case 2:
        _clearPairing();
        host.closePageSheet(_pair);
      case 3:
        if (d == null) return;
        if (!host.server.loggedIn) return host.toast('Masuk ke akun GOYANA dulu untuk menautkan WhatsApp.');
        _clearPairing();
        wa.run(() async {
          final p = await st.pair(d.id, _method);
          _pairing = p;
          final left = p.expiresAt.difference(st.clock());
          _expiry = Timer(left + const Duration(seconds: 1), host.refresh);
        });
      case 4:
        if (d == null) return;
        wa.run(() => st.refreshDevice(d.id)).then((done) {
          if (!done) return;
          if (_target?.status == 'connected') {
            _clearPairing();
            host.closePageSheet(_pair);
            host.toast('WhatsApp terhubung');
          } else {
            host.toast('Belum terhubung. Selesaikan penautan di WhatsApp lalu periksa lagi.');
          }
        });
    }
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.hour)}.${two(l.minute)}';
}
