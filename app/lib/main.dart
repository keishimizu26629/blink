import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'src/bridge/generated/frb_generated.dart';
import 'src/theme/app_theme.dart';
import 'src/views/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 500),
    title: 'Blink',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: BlinkApp()));
}

class BlinkApp extends ConsumerWidget {
  const BlinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Blink',
      theme: AppTheme.dark,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
