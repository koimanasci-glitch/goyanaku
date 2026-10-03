import 'package:flutter/material.dart';

import 'hybrid/shell.dart';

// The native account screens from app.dart stay in the project for the
// upcoming Laravel login; the app now opens the final GOYANA design.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoyanaHybridApp());
}
