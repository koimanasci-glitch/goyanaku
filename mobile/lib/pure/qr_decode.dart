// Membaca isi kode QR dari gambar yang diunggah (pengganti ZXing di HTML).
import 'dart:io';
import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';

/// null bila gambar tidak memuat QR yang terbaca atau pemindai tidak tersedia (mis. saat tes).
Future<String?> decodeQrImage(Uint8List bytes, String mime) async {
  File? f;
  final c = MobileScannerController(autoStart: false);
  try {
    final ext = mime.contains('png') ? 'png' : (mime.contains('webp') ? 'webp' : 'jpg');
    f = File('${Directory.systemTemp.path}/goyana-qris-${DateTime.now().microsecondsSinceEpoch}.$ext');
    await f.writeAsBytes(bytes, flush: true);
    final r = await c.analyzeImage(f.path).timeout(const Duration(seconds: 6));
    for (final b in r?.barcodes ?? const <Barcode>[]) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) return v;
    }
  } catch (_) {
  } finally {
    try {
      await c.dispose();
      await f?.delete();
    } catch (_) {}
  }
  return null;
}
