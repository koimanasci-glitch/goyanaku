// Masuk dengan Google di HP: meminta tanda masuk (ID token) untuk server GOYANA.
// Aplikasi tidak pernah melihat password Google; pemeriksaan tandanya dilakukan server.

import 'package:google_sign_in/google_sign_in.dart';

/// Membuka pilihan akun Google lalu mengembalikan tanda masuk untuk [serverClientId] (Client ID yang diterima server).
/// null = pengguna membatalkan. Melempar [GoogleLoginFailure] bila Google menolak atau HP belum siap.
Future<String?> googleIdToken(String serverClientId) async {
  final google = GoogleSignIn(serverClientId: serverClientId, scopes: const ['email']);
  try {
    // Selalu tampilkan pilihan akun, supaya HP yang dipakai bergantian tidak otomatis memakai akun sebelumnya.
    await google.signOut();
    final account = await google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    final token = auth.idToken;
    if (token == null || token.isEmpty) throw const GoogleLoginFailure('Google tidak memberikan tanda masuk. Coba lagi.');
    return token;
  } on GoogleLoginFailure {
    rethrow;
  } catch (_) {
    throw const GoogleLoginFailure('Masuk dengan Google belum bisa di HP ini. Periksa internet dan Layanan Google Play, lalu coba lagi.');
  }
}

class GoogleLoginFailure implements Exception {
  const GoogleLoginFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
