// Kunci ganti/hapus QRIS di aplikasi (keputusan Paduka 10 Okt 2026): bila HP masuk akun server, hanya pemilik yang boleh,
// setelah konfirmasi password akun atau kode yang dikirim ke email (berlaku 10 menit). Server menegakkan aturan yang sama
// (App\Support\QrisGuard), jadi QRIS tidak bisa diganti diam-diam dari HP kasir.

import 'pages.dart';
import 'server_sync.dart' show ServerFailure;

class QrisUnlock {
  QrisUnlock(this.host);
  final PureHost host;
  static const sheet = 'qris-unlock';
  static DateTime? _until;

  String _secret = '', _email = '';
  bool _codeSent = false, _busy = false;
  void Function()? _then;

  bool get _active => _until != null && _until!.isAfter(host.now);

  /// true = boleh langsung lanjut; false = menunggu konfirmasi (aksi dijalankan setelah berhasil) atau ditolak.
  bool request(void Function() then) {
    final s = host.server;
    if (!s.loggedIn) return true; // HP tanpa akun server: QRIS hanya tersimpan di HP ini
    if (!s.isOwner) {
      host.toast('QRIS hanya bisa diganti pemilik usaha.');
      return false;
    }
    if (_active) return true;
    _then = then;
    _secret = '';
    host.openPageSheet(sheet);
    return false;
  }

  List<Map<String, dynamic>> items() => [
        {'type': 'title', 't': 'Konfirmasi Pemilik', 's': 'Ganti / hapus QRIS'},
        {'type': 'hint', 't': _codeSent ? 'Kode 6 angka dikirim ke $_email. Masukkan kode di bawah.' : 'Masukkan password akun pemilik. Berlaku 10 menit.'},
        {'type': 'input', 'v': _secret, 'ph': _codeSent ? 'Kode 6 angka' : 'Password akun', 'multiline': false, 'numeric': _codeSent, 'decimal': false, 'ro': false, 'secret': !_codeSent, 'email': false, 'i': 0},
        {'type': 'button', 't': _busy ? 'Memeriksa…' : 'Konfirmasi', 'primary': true, 'i': 0},
        if (!_codeSent) {'type': 'button', 't': 'Masuk pakai Google? Kirim kode ke email', 'primary': false, 'i': 1},
        {'type': 'button', 't': 'Batal', 'primary': false, 'i': 2},
      ];

  Future<void> event(String kind, int index, Object? value) async {
    if (kind == 'input') {
      _secret = '${value ?? ''}';
      return;
    }
    if (kind != 'button' || _busy) return;
    if (index == 2) {
      _then = null;
      _codeSent = false;
      return host.closePageSheet(sheet);
    }
    _busy = true;
    host.refresh();
    try {
      if (index == 1) {
        final j = await host.server.api('POST', '/qris/code');
        _email = '${j['email'] ?? 'email pemilik'}';
        _codeSent = true;
        _secret = '';
        return;
      }
      if (_secret.trim().isEmpty) return host.toast(_codeSent ? 'Masukkan kode dari email.' : 'Masukkan password akun.');
      await host.server.api('POST', '/qris/unlock', _codeSent ? {'code': _secret.trim()} : {'password': _secret});
      _until = host.now.add(const Duration(minutes: 9, seconds: 30));
      _codeSent = false;
      _secret = '';
      host.closePageSheet(sheet);
      final then = _then;
      _then = null;
      then?.call();
    } on ServerFailure catch (e) {
      host.toast(e.offline ? 'Butuh internet untuk konfirmasi pemilik.' : e.message);
    } catch (_) {
      host.toast('Konfirmasi belum berhasil. Coba lagi.');
    } finally {
      _busy = false;
      host.refresh();
    }
  }
}
