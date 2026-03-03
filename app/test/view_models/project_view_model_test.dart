import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blink/src/view_models/project_view_model.dart';

void main() {
  // SharedPreferences requires the test binding and mock initial values.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Provide empty mock values so SharedPreferences.getInstance() works
    // in the test environment without a real platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  group('BringToFrontShortcut', () {
    test('shiftOptionSpace has correct displayName', () {
      expect(BringToFrontShortcut.shiftOptionSpace.displayName,
          'Shift + Option + Space');
    });

    test('commandShiftSpace has correct displayName', () {
      expect(BringToFrontShortcut.commandShiftSpace.displayName,
          'Command + Shift + Space');
    });

    test('commandOptionSpace has correct displayName', () {
      expect(BringToFrontShortcut.commandOptionSpace.displayName,
          'Command + Option + Space');
    });

    test('controlOptionSpace has correct displayName', () {
      expect(BringToFrontShortcut.controlOptionSpace.displayName,
          'Control + Option + Space');
    });

    test('all enum values have non-empty displayName', () {
      for (final shortcut in BringToFrontShortcut.values) {
        expect(shortcut.displayName, isNotEmpty);
      }
    });

    test('enum has exactly 4 values', () {
      expect(BringToFrontShortcut.values.length, 4);
    });
  });

  group('SidebarMode', () {
    test('has explorer and sourceControl values', () {
      expect(SidebarMode.values, contains(SidebarMode.explorer));
      expect(SidebarMode.values, contains(SidebarMode.sourceControl));
    });

    test('has exactly 2 values', () {
      expect(SidebarMode.values.length, 2);
    });
  });

  group('EditorDisplayMode', () {
    test('has code and diff values', () {
      expect(EditorDisplayMode.values, contains(EditorDisplayMode.code));
      expect(EditorDisplayMode.values, contains(EditorDisplayMode.diff));
    });

    test('has exactly 2 values', () {
      expect(EditorDisplayMode.values.length, 2);
    });
  });

  group('ProjectViewModel', () {
    late ProjectViewModel vm;

    setUp(() {
      vm = ProjectViewModel();
    });

    group('initial state', () {
      test('rootNodes is empty', () {
        expect(vm.rootNodes, isEmpty);
      });

      test('selectedFile is null', () {
        expect(vm.selectedFile, isNull);
      });

      test('fileContent is null', () {
        expect(vm.fileContent, isNull);
      });

      test('highlightTokens is empty', () {
        expect(vm.highlightTokens, isEmpty);
      });

      test('diffHighlightTokens is empty', () {
        expect(vm.diffHighlightTokens, isEmpty);
      });

      test('selectedDiff is null', () {
        expect(vm.selectedDiff, isNull);
      });

      test('isDiffLoading is false', () {
        expect(vm.isDiffLoading, false);
      });

      test('diffErrorMessage is null', () {
        expect(vm.diffErrorMessage, isNull);
      });

      test('editorDisplayMode is code', () {
        expect(vm.editorDisplayMode, EditorDisplayMode.code);
      });

      test('sidebarMode is explorer', () {
        expect(vm.sidebarMode, SidebarMode.explorer);
      });

      test('gitStatusResult is null', () {
        expect(vm.gitStatusResult, isNull);
      });

      test('isGitStatusLoading is false', () {
        expect(vm.isGitStatusLoading, false);
      });

      test('gitStatusErrorMessage is null', () {
        expect(vm.gitStatusErrorMessage, isNull);
      });

      test('activeBranchName is null', () {
        expect(vm.activeBranchName, isNull);
      });

      test('errorMessage is null', () {
        expect(vm.errorMessage, isNull);
      });

      test('rootDirectoryName is null', () {
        expect(vm.rootDirectoryName, isNull);
      });

      test('windowOpacity defaults to 1.0', () {
        expect(vm.windowOpacity, 1.0);
      });

      test('isBringToFrontHotkeyEnabled defaults to true', () {
        expect(vm.isBringToFrontHotkeyEnabled, true);
      });

      test('bringToFrontShortcut defaults to shiftOptionSpace', () {
        expect(
            vm.bringToFrontShortcut, BringToFrontShortcut.shiftOptionSpace);
      });
    });

    group('displayPathForSidebar', () {
      test('returns absolute path unchanged when rootPath is empty', () {
        final absolutePath = '/some/absolute/path/file.dart';
        expect(vm.displayPathForSidebar(absolutePath), absolutePath);
      });

      test('returns full path when rootPath not matching', () {
        final result =
            vm.displayPathForSidebar('/home/user/project/src/main.dart');
        // Since _rootPath is '' (initial), the full path is returned.
        expect(result, '/home/user/project/src/main.dart');
      });
    });

    group('switchToCodeMode', () {
      test('sets editorDisplayMode to code', () {
        vm.switchToCodeMode();
        expect(vm.editorDisplayMode, EditorDisplayMode.code);
      });

      test('notifies listeners', () {
        var notified = false;
        vm.addListener(() => notified = true);
        vm.switchToCodeMode();
        expect(notified, true);
      });
    });

    group('closeDiffPanel', () {
      test('sets editorDisplayMode to code', () {
        vm.closeDiffPanel();
        expect(vm.editorDisplayMode, EditorDisplayMode.code);
      });

      test('clears diff-related state', () {
        vm.closeDiffPanel();
        expect(vm.isDiffLoading, false);
        expect(vm.diffErrorMessage, isNull);
        expect(vm.selectedDiff, isNull);
      });

      test('notifies listeners', () {
        var notified = false;
        vm.addListener(() => notified = true);
        vm.closeDiffPanel();
        expect(notified, true);
      });
    });

    group('setSidebarMode', () {
      test('changes sidebarMode to sourceControl', () {
        vm.setSidebarMode(SidebarMode.sourceControl);
        expect(vm.sidebarMode, SidebarMode.sourceControl);
      });

      test('changes sidebarMode to explorer', () {
        vm.setSidebarMode(SidebarMode.sourceControl);
        vm.setSidebarMode(SidebarMode.explorer);
        expect(vm.sidebarMode, SidebarMode.explorer);
      });

      test('notifies listeners on mode change', () {
        var notified = false;
        vm.addListener(() => notified = true);
        vm.setSidebarMode(SidebarMode.sourceControl);
        expect(notified, true);
      });
    });

    group('requestDiffForCurrentFile', () {
      test('sets error message when no file is selected', () {
        vm.requestDiffForCurrentFile();
        expect(vm.diffErrorMessage, isNotNull);
        expect(vm.diffErrorMessage, contains('Diff'));
        expect(vm.editorDisplayMode, EditorDisplayMode.diff);
      });
    });
  });
}
