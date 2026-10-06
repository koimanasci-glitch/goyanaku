import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Historical goldens keep every pixel outside the explicitly approved brand
/// rectangle locked. The new header itself is checked by brand_test.dart.
class _BrandMigrationComparator extends LocalFileComparator {
  _BrandMigrationComparator(super.testFile);
  Future<ui.Image> _decode(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    if (golden.path.contains('branding_')) {
      return super.compare(imageBytes, golden);
    }
    final image = await _decode(imageBytes),
        reference = await _decode(await getGoldenBytes(golden));
    try {
      if (image.width != reference.width || image.height != reference.height) {
        return super.compare(imageBytes, golden);
      }
      final actual = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final expected = (await reference.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      // Locked header tests use a 31px inset. The scan button and all body
      // pixels remain unmasked; sheet-only captures have no coral header.
      final probe = (50 * image.width + 2) * 4;
      if (image.height < 95 ||
          actual[probe] <= actual[probe + 1] * 1.3 ||
          expected[probe] <= expected[probe + 1] * 1.3) {
        return super.compare(imageBytes, golden);
      }
      for (var y = 40; y < 88; y++) {
        for (var x = 9; x < 225 && x < image.width; x++) {
          final offset = (y * image.width + x) * 4;
          actual.setRange(offset, offset + 4, expected, offset);
        }
      }
      final complete = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        actual,
        image.width,
        image.height,
        ui.PixelFormat.rgba8888,
        complete.complete,
      );
      final masked = await complete.future;
      try {
        return await super.compare(
          (await masked.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
          golden,
        );
      } finally {
        masked.dispose();
      }
    } finally {
      image.dispose();
      reference.dispose();
    }
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = _BrandMigrationComparator(
    Uri.file('${Directory.current.path}/test/flutter_test_config.dart'),
  );
  await testMain();
}
