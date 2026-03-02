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
  HotKey? _registeredHotKey;

  @override
  void initState() {
    super.initState();
    // Defer hotkey registration to after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncHotKey();
    });
  }

  @override
  void dispose() {
    _unregisterHotKey();
    super.dispose();
  }

  Future<void> _syncHotKey() async {
    final vm = ref.read(projectViewModelProvider);
    await _unregisterHotKey();

    if (!vm.isBringToFrontHotkeyEnabled) return;

    final modifiers = switch (vm.bringToFrontShortcut) {
      BringToFrontShortcut.shiftOptionSpace => [HotKeyModifier.shift, HotKeyModifier.alt],
      BringToFrontShortcut.commandShiftSpace => [HotKeyModifier.meta, HotKeyModifier.shift],
      BringToFrontShortcut.commandOptionSpace => [HotKeyModifier.meta, HotKeyModifier.alt],
      BringToFrontShortcut.controlOptionSpace => [HotKeyModifier.control, HotKeyModifier.alt],
    };

    final hotKey = HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(hotKey, keyDownHandler: (_) => _toggleAppVisibility());
    _registeredHotKey = hotKey;
  }

  Future<void> _unregisterHotKey() async {
    if (_registeredHotKey != null) {
      await hotKeyManager.unregister(_registeredHotKey!);
      _registeredHotKey = null;
    }
  }

  Future<void> _toggleAppVisibility() async {
    final isFocused = await windowManager.isFocused();
    final isVisible = await windowManager.isVisible();

    if (isFocused && isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for hotkey setting changes
    ref.watch(projectViewModelProvider);
    ref.listen(projectViewModelProvider, (previous, next) {
      if (previous?.isBringToFrontHotkeyEnabled != next.isBringToFrontHotkeyEnabled ||
          previous?.bringToFrontShortcut != next.bringToFrontShortcut) {
        _syncHotKey();
      }
    });

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
              onSelected: _toggleAppVisibility,
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
