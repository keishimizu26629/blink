import 'package:flutter/material.dart';

/// GitHub Dark テーマのシンタックスハイライトカラー
class SyntaxTheme {
  SyntaxTheme._();

  static const backgroundColor = Color(0xFF0B0D10);
  static const defaultTextColor = Color(0xFFE6EDF3);
  static const lineNumberColor = Color(0xFF9BA6B2);

  /// FRB生成のDartTokenSpan.tokenType (String) からColorを返す
  /// tokenTypeの値: "keyword", "string", "comment", "type", "function",
  /// "number", "operator", "punctuation", "variable", "plain"
  static Color colorFor(String tokenType) {
    return switch (tokenType) {
      'keyword' => const Color(0xFFFF7B72),
      'string' => const Color(0xFF7EE787),
      'comment' => const Color(0xFF8B949E),
      'type' => const Color(0xFF79C0FF),
      'function' => const Color(0xFFD2A8FF),
      'number' => const Color(0xFFF2CC60),
      'operator' => const Color(0xFFE6EDF3),
      'punctuation' => const Color(0xFFC9D1D9),
      'variable' => const Color(0xFFFFA657),
      _ => defaultTextColor, // "plain" and unknown
    };
  }

  /// コード表示用TextStyle (JetBrains Mono 13pt, lineHeight 1.5)
  static TextStyle get codeStyle => const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 13,
        color: defaultTextColor,
        height: 1.5,
      );

  /// 行番号表示用TextStyle (JetBrains Mono 11pt)
  static TextStyle get lineNumberStyle => const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        color: lineNumberColor,
      );
}
