import 'package:flutter/material.dart';

import 'core/store.dart';
import 'hybrid/shell.dart';
import 'pure/pure_shell.dart';

/// true = mode murni Flutter (tanpa WebView), false = versi lengkap (hybrid). Disimpan di database HP.
final pureMode = ValueNotifier<bool?>(null);

Future<void> switchMode(bool pure) async {
  await setPureMode(const DeviceKvStore(), pure);
  pureMode.value = pure;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pureModeEnabled(const DeviceKvStore()).then((v) => pureMode.value = v);
  runApp(const GoyanaRoot());
}

class GoyanaRoot extends StatelessWidget {
  const GoyanaRoot({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
        valueListenable: pureMode,
        builder: (context, pure, _) {
          if (pure == null) return const ColoredBox(color: Colors.white);
          if (!pure) return GoyanaHybridApp(onPureMode: () => switchMode(true));
          return MaterialApp(
            title: 'Goyana',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffe8493f)), scaffoldBackgroundColor: Colors.white),
            home: PureShell(store: const DeviceKvStore(), onExit: () => switchMode(false)),
          );
        },
      );
}
