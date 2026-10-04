import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'common.dart';

/// Same order ID and URL as the existing receipt QR. No demo order fallback.
String? orderStatusId(Map<String, dynamic> detail) {
  final value = detail['sub'];
  if (value is! String) return null;
  final id = value.split(' · ').first.trim();
  return RegExp(r'^[A-Za-z0-9-]{1,80}$').hasMatch(id) ? id : null;
}

String orderStatusUrl(String id) => Uri.https('goyana.id', '/s/$id').toString();

class NativeOrderStatusQr extends StatelessWidget {
  const NativeOrderStatusQr({super.key, required this.orderId,
    required this.onClose, this.customerName = ''});
  final String orderId;
  final String customerName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(color: Colors.white,
    child: SafeArea(top: false, child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('QR STATUS', style: gText(14.5, w: FontWeight.w600, ls: .7))),
          IconButton(tooltip: 'Tutup', onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 22), visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 12),
        Text(orderId, textAlign: TextAlign.center,
          style: gText(17, w: FontWeight.w500, h: 23.8)),
        if (customerName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(customerName, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis, style: gText(12, c: const Color(0xff8a8fa3))),
        ],
        const SizedBox(height: 18),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240),
          child: AspectRatio(aspectRatio: 1, child: QrImageView(
            key: const Key('order-status-qr-image'),
            data: orderStatusUrl(orderId), version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white, padding: const EdgeInsets.all(16),
          )))),
        const SizedBox(height: 16),
        Text('Pindai QR untuk membuka tautan status pesanan.',
          textAlign: TextAlign.center, style: gText(12, c: const Color(0xff8a8fa3), h: 18)),
        const SizedBox(height: 6),
        Text('goyana.id/s/$orderId', textAlign: TextAlign.center,
          style: gText(10.5, c: const Color(0xff9299a6), h: 15)),
        const SizedBox(height: 22),
        SizedBox(height: 46, child: FilledButton(onPressed: onClose,
          style: FilledButton.styleFrom(backgroundColor: gBrand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Tutup', style: gText(12.5, w: FontWeight.w500, c: Colors.white)))),
      ]),
    )),
  );
}
