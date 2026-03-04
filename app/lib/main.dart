import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'src/bridge/generated/frb_generated.dart';
import 'src/theme/app_theme.dart';
import 'src/view_models/project_view_model.dart';
import 'src/views/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 500),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Blink',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: BlinkApp()));
}

class BlinkApp extends ConsumerStatefulWidget {
  const BlinkApp({super.key});
  @override
  ConsumerState<BlinkApp> createState() => _BlinkAppState();
}

class _BlinkAppState extends ConsumerState<BlinkApp> {
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(projectViewModelProvider);

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Open Folder...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  ref.read(projectViewModelProvider).openProject(result);
                }
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: '最前面に表示',
              onSelected: vm.toggleBringToFrontVisibility,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        title: 'Blink',
        theme: AppTheme.dark,
        home: const AppShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
