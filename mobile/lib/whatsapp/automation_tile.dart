import 'package:flutter/material.dart';

import '../native/common.dart';

/// Mount this in the existing AutomationPage after integration approval.
/// Parent loads authoritative value/entitlement per WhatsApp device from Laravel.
class WaStatusAutomationTile extends StatelessWidget {
  const WaStatusAutomationTile({
    super.key,
    required this.value,
    required this.allowed,
    required this.busy,
    required this.onChanged,
  });
  final bool value, allowed, busy;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    activeColor: gBrand,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    title: Text('Balas Status WhatsApp', style: gText(13, w: FontWeight.w500)),
    subtitle: Text(
      'Otomatis menjawab pertanyaan status pesanan.',
      style: gText(11),
    ),
    // Existing setting can always be turned off even if package no longer permits activation.
    onChanged: busy || (!allowed && !value)
        ? null
        : (v) => onChanged(v ?? false),
  );
}
