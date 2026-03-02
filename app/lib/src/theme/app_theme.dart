import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'syntax_theme.dart';

/// アプリ全体のテーマ
class AppTheme {
  AppTheme._();

  /// GitHub blue
  static const _primaryColor = Color(0xFF58A6FF);
  /// Surface
  static const _surfaceColor = Color(0xFF0D1117);
  /// Divider
  static const dividerColor = Color(0xFF30363D);

  /// Sidebar関連
  static const sidebarBackgroundColor = Color(0xFF010409);
  static const sidebarHeaderColor = Color(0xFF161B22);
  static const toolbarBackgroundColor = Color(0xFF161B22);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SyntaxTheme.backgroundColor,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        surface: _surfaceColor,
        onSurface: SyntaxTheme.defaultTextColor,
      ),
      dividerColor: dividerColor,
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme).apply(
        bodyColor: SyntaxTheme.defaultTextColor,
        displayColor: SyntaxTheme.defaultTextColor,
      ),
      iconTheme: const IconThemeData(
        color: SyntaxTheme.defaultTextColor,
        size: 18,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          const Color(0xFF30363D),
        ),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }
}
