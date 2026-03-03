import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blink/src/theme/app_theme.dart';
import 'package:blink/src/theme/syntax_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark returns non-null ThemeData', () {
      final theme = AppTheme.dark;
      expect(theme, isNotNull);
      expect(theme, isA<ThemeData>());
    });

    test('dark theme has dark brightness', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
    });

    test('dark theme colorScheme is dark', () {
      final theme = AppTheme.dark;
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('dark theme primary color is GitHub blue', () {
      final theme = AppTheme.dark;
      expect(theme.colorScheme.primary, const Color(0xFF58A6FF));
    });

    test('dark theme scaffoldBackgroundColor matches SyntaxTheme', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, SyntaxTheme.backgroundColor);
    });

    test('dark theme dividerColor is correct', () {
      final theme = AppTheme.dark;
      expect(theme.dividerColor, AppTheme.dividerColor);
    });

    test('dark theme iconTheme has correct defaults', () {
      final theme = AppTheme.dark;
      expect(theme.iconTheme.color, SyntaxTheme.defaultTextColor);
      expect(theme.iconTheme.size, 18);
    });

    test('dividerColor constant is defined', () {
      expect(AppTheme.dividerColor, const Color(0xFF30363D));
    });

    test('sidebarBackgroundColor constant is defined', () {
      expect(AppTheme.sidebarBackgroundColor, const Color(0xFF010409));
    });

    test('sidebarHeaderColor constant is defined', () {
      expect(AppTheme.sidebarHeaderColor, const Color(0xFF161B22));
    });

    test('toolbarBackgroundColor constant is defined', () {
      expect(AppTheme.toolbarBackgroundColor, const Color(0xFF161B22));
    });
  });
}
