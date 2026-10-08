// Penghubung Mode Murni ke modul perangkat WhatsApp (lib/whatsapp): satu sumber data untuk halaman Hubungkan WhatsApp
// dan sakelar "Balas Status WhatsApp" di Otomasi. Memakai sesi server yang sudah ada (ServerSync); tidak ada login kedua.
// QR, kode pemasangan, kuota slot, dan status terhubung selalu dari server GOYANA — HP hanya menyimpan draf.

import '../whatsapp/device_store.dart';
import '../whatsapp/kv_storage.dart';
import 'pages.dart';
import 'server_sync.dart' show ServerFailure, ServerSync;

class WaLink {
  WaLink(this.host);
  final PureHost host;
  WaDeviceStore? _store;
  String _sig = '';

  /// Keterangan terakhir dari muat/sinkron (kosong = lancar).
  String note = '';
  bool busy = false;

  /// Store dibuat ulang bila akun, peran, atau daftar outlet berubah, supaya draf dan token akun lain tidak terbawa.
  WaDeviceStore get store {
    final s = host.server;
    final scope = s.loggedIn ? 'srv-${s.businessInfo['id'] ?? s.user['id'] ?? 'akun'}' : 'local';
    final outlets = [
      for (final o in host.business.outlets)
        WaOutlet(key: o.id, name: o.name.isEmpty ? 'Outlet' : o.name, serverId: ServerSync.outletNumber(o.id)),
    ];
    final sig = '$scope|${s.isOwner}|${outlets.map((o) => '${o.key}:${o.name}').join(',')}';
    if (_store == null || sig != _sig) {
      _store = WaDeviceStore(storage: WaKvStorage(host.kv), accountScope: scope, outlets: outlets, request: s.isOwner ? _request : null);
      _sig = sig;
      note = '';
    }
    return _store!;
  }

  /// Karyawan yang masuk dengan PIN tidak mengatur nomor WhatsApp usaha.
  bool get staffOnly => host.server.loggedIn && !host.server.isOwner;

  List<WaDevice> get registered => [for (final d in store.devices) if (d.registered) d];

  String outletName(WaDevice d) => store.outlets.where((o) => o.key == d.outletKey).firstOrNull?.name ?? 'Outlet belum dipetakan';

  Future<Map<String, dynamic>> _request(String method, String path, Map<String, dynamic>? body) async {
    try {
      return await host.server.api(method, path.startsWith('/api/') ? path.substring(4) : path, body);
    } on ServerFailure catch (e) {
      if (e.offline) throw const WaFailure('Butuh internet untuk mengatur WhatsApp di server.');
      if (e.status == 404) {
        throw WaFailure(path.endsWith('/devices')
            ? 'Layanan WhatsApp belum diaktifkan di server GOYANA. Draf tetap tersimpan di HP ini.'
            : 'Perangkat tidak ditemukan di server. Muat ulang daftar.');
      }
      if (e.status == 503) throw const WaFailure('Layanan WhatsApp belum tersambung ke server GOYANA. QR dan kode pemasangan tersedia setelah tersambung.');
      throw WaFailure(e.message);
    }
  }

  /// Muat draf di HP, lalu daftar dan kuota dari server bila pemilik sedang masuk.
  Future<void> sync() async {
    final st = store;
    note = '';
    try {
      await st.load();
      if (st.request != null) await st.refresh();
    } on WaFailure catch (e) {
      note = e.message;
    } catch (_) {
      note = 'Daftar perangkat belum dapat dimuat.';
    }
    host.refresh();
  }

  /// Jalankan satu perubahan; kegagalan ditampilkan apa adanya, tidak pernah dianggap berhasil.
  Future<bool> run(Future<void> Function() work, {String ok = ''}) async {
    if (busy) {
      host.toast('Tunggu proses sebelumnya selesai.');
      return false;
    }
    busy = true;
    host.refresh();
    try {
      await work();
      if (ok.isNotEmpty) host.toast(ok);
      return true;
    } on WaFailure catch (e) {
      host.toast(e.message);
      return false;
    } catch (_) {
      host.toast('Proses belum berhasil. Periksa koneksi lalu coba lagi.');
      return false;
    } finally {
      busy = false;
      host.refresh();
    }
  }
}
