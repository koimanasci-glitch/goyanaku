import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class GoyanaApi {
  Future<void> login(String email, String password);
  Future<Map<String, dynamic>> profile();
  Future<void> logout();
}
class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
}
class HttpGoyanaApi implements GoyanaApi {
  HttpGoyanaApi(String address) {
    final uri = Uri.tryParse(address.trim());
    final localDebug = kDebugMode && uri != null &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment ||
        !(uri.scheme == 'https' || (uri.scheme == 'http' && localDebug)) ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiFailure('Gunakan alamat server HTTPS tanpa path, misalnya https://uji.goyana.id.');
    }
    _base = uri.replace(path: '/');
  }
  late final Uri _base;
  String? _token;
  Future<Map<String, dynamic>> _request(String method, String path,
      [Map<String, String>? data]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.openUrl(method, _base.resolve(path));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (_token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
        if (data != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(data));
        }
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 1024 * 1024) throw const ApiFailure('Respons server terlalu besar.');
          bytes.addAll(chunk);
        }
        if (response.statusCode == 401) {
          _token = null;
          throw const ApiFailure('Sesi berakhir. Silakan masuk kembali.');
        }
        if (response.statusCode == 422) {
          throw const ApiFailure('Email atau password tidak sesuai.');
        }
        if (response.statusCode == 429) throw const ApiFailure('Terlalu banyak percobaan. Tunggu sebentar.');
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const ApiFailure('Server belum dapat melayani permintaan. Coba kembali.');
        }
        if (bytes.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) throw const ApiFailure('Respons server tidak sesuai.');
        return decoded;
      })().timeout(const Duration(seconds: 15));
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure('Tidak dapat terhubung. Periksa koneksi dan alamat server.');
    } finally {
      client.close(force: true);
    }
  }
  @override
  Future<void> login(String email, String password) async {
    final result = await _request('POST', '/api/session', {'email': email.trim(), 'password': password});
    final token = result['token'];
    if (token is! String || token.isEmpty) throw const ApiFailure('Server tidak memberikan sesi yang valid.');
    _token = token; // Memory only; never persisted to preferences or logs.
  }
  @override
  Future<Map<String, dynamic>> profile() => _request('GET', '/api/me');
  @override
  Future<void> logout() async {
    try { await _request('DELETE', '/api/session'); } finally { _token = null; }
  }
}
