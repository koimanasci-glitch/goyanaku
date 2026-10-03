// Scan barcode / QR pesanan dengan kamera (mode murni).

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../native/common.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.title = 'Scan Barcode Pesanan'});
  final String title;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.all]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_done) return;
            final code = capture.barcodes.map((b) => b.rawValue ?? '').firstWhere((v) => v.isNotEmpty, orElse: () => '');
            if (code.isEmpty) return;
            _done = true;
            Navigator.of(context).pop(code);
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Kamera tidak bisa dibuka. Izinkan akses kamera untuk GOYANA.\n(${error.errorCode.name})',
                  textAlign: TextAlign.center, style: gText(14, c: Colors.white)),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 250, height: 250,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(22)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
              Expanded(child: Text(widget.title, style: gText(16, w: FontWeight.w600, c: Colors.white))),
              IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white)),
            ]),
          ),
        ),
        Positioned(
          left: 24, right: 24, bottom: 48,
          child: Text('Arahkan kamera ke barcode di struk atau label kantong', textAlign: TextAlign.center, style: gText(13, c: Colors.white70)),
        ),
      ]),
    );
  }
}
