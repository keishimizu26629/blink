import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blink/src/theme/syntax_theme.dart';
import 'package:blink/src/theme/app_theme.dart';
import 'package:blink/src/models/tree_node.dart';
import 'package:blink/src/bridge/generated/dart_api.dart';
import 'package:blink/src/view_models/project_view_model.dart';

void main() {
  group('Blink smoke tests', () {
    test('SyntaxTheme.colorFor returns Color for known token types', () {
      expect(SyntaxTheme.colorFor('keyword'), isA<Color>());
      expect(SyntaxTheme.colorFor('string'), isA<Color>());
      expect(SyntaxTheme.colorFor('comment'), isA<Color>());
    });

    test('AppTheme.dark returns non-null ThemeData', () {
      final theme = AppTheme.dark;
      expect(theme, isNotNull);
      expect(theme, isA<ThemeData>());
    });

    test('TreeNode can be instantiated', () {
      final node = TreeNode(
        fileNode: const DartFileNode(
          id: 'test-1',
          path: '/tmp/test.dart',
          name: 'test.dart',
          isDir: false,
        ),
      );
      expect(node.name, 'test.dart');
      expect(node.isDir, false);
    });

    test('BringToFrontShortcut enum has displayName', () {
      for (final shortcut in BringToFrontShortcut.values) {
        expect(shortcut.displayName, isNotEmpty);
      }
    });

    test('EditorDisplayMode has code and diff values', () {
      expect(EditorDisplayMode.values, contains(EditorDisplayMode.code));
      expect(EditorDisplayMode.values, contains(EditorDisplayMode.diff));
    });
  });
}
