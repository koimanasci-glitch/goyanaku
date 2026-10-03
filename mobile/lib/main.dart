import 'package:flutter/material.dart';

import 'core/store.dart';
import 'pure/pure_shell.dart';

/// GOYANA Android: 100% Flutter (tanpa WebView). Data di database SQLite HP (GoyanaStore).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoyanaRoot());
}

class GoyanaRoot extends StatelessWidget {
  const GoyanaRoot({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Goyana',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffe8493f)), scaffoldBackgroundColor: Colors.white),
        home: const PureShell(store: DeviceKvStore()),
      );
}
