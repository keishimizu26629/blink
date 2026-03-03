import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blink/src/theme/syntax_theme.dart';

void main() {
  group('SyntaxTheme', () {
    group('colorFor', () {
      test('keyword returns red-ish color (0xFFFF7B72)', () {
        expect(SyntaxTheme.colorFor('keyword'), const Color(0xFFFF7B72));
      });

      test('string returns green-ish color (0xFF7EE787)', () {
        expect(SyntaxTheme.colorFor('string'), const Color(0xFF7EE787));
      });

      test('comment returns gray color (0xFF8B949E)', () {
        expect(SyntaxTheme.colorFor('comment'), const Color(0xFF8B949E));
      });

      test('number returns yellow color (0xFFF2CC60)', () {
        expect(SyntaxTheme.colorFor('number'), const Color(0xFFF2CC60));
      });

      test('type returns blue color (0xFF79C0FF)', () {
        expect(SyntaxTheme.colorFor('type'), const Color(0xFF79C0FF));
      });

      test('function returns purple color (0xFFD2A8FF)', () {
        expect(SyntaxTheme.colorFor('function'), const Color(0xFFD2A8FF));
      });

      test('operator returns default text color (0xFFE6EDF3)', () {
        expect(SyntaxTheme.colorFor('operator'), const Color(0xFFE6EDF3));
      });

      test('variable returns orange color (0xFFFFA657)', () {
        expect(SyntaxTheme.colorFor('variable'), const Color(0xFFFFA657));
      });

      test('punctuation returns light gray (0xFFC9D1D9)', () {
        expect(SyntaxTheme.colorFor('punctuation'), const Color(0xFFC9D1D9));
      });

      test('plain returns defaultTextColor', () {
        expect(SyntaxTheme.colorFor('plain'), SyntaxTheme.defaultTextColor);
      });

      test('unknown token type returns defaultTextColor', () {
        expect(
            SyntaxTheme.colorFor('unknown_xyz'), SyntaxTheme.defaultTextColor);
        expect(SyntaxTheme.colorFor(''), SyntaxTheme.defaultTextColor);
        expect(SyntaxTheme.colorFor('namespace'), SyntaxTheme.defaultTextColor);
        expect(SyntaxTheme.colorFor('embedded'), SyntaxTheme.defaultTextColor);
        expect(SyntaxTheme.colorFor('property'), SyntaxTheme.defaultTextColor);
      });
    });

    group('static colors', () {
      test('backgroundColor is not null', () {
        // ignore: unnecessary_null_comparison
        expect(SyntaxTheme.backgroundColor, isNotNull);
        expect(SyntaxTheme.backgroundColor, const Color(0xFF0B0D10));
      });

      test('lineNumberColor is not null', () {
        // ignore: unnecessary_null_comparison
        expect(SyntaxTheme.lineNumberColor, isNotNull);
        expect(SyntaxTheme.lineNumberColor, const Color(0xFF9BA6B2));
      });

      test('defaultTextColor is not null', () {
        // ignore: unnecessary_null_comparison
        expect(SyntaxTheme.defaultTextColor, isNotNull);
        expect(SyntaxTheme.defaultTextColor, const Color(0xFFE6EDF3));
      });
    });

    group('text styles', () {
      test('codeStyle uses JetBrains Mono font family', () {
        final style = SyntaxTheme.codeStyle;
        expect(style.fontFamily, 'JetBrains Mono');
      });

      test('codeStyle has fontSize 13', () {
        final style = SyntaxTheme.codeStyle;
        expect(style.fontSize, 13);
      });

      test('codeStyle has defaultTextColor', () {
        final style = SyntaxTheme.codeStyle;
        expect(style.color, SyntaxTheme.defaultTextColor);
      });

      test('codeStyle has line height 1.5', () {
        final style = SyntaxTheme.codeStyle;
        expect(style.height, 1.5);
      });

      test('lineNumberStyle uses JetBrains Mono font family', () {
        final style = SyntaxTheme.lineNumberStyle;
        expect(style.fontFamily, 'JetBrains Mono');
      });

      test('lineNumberStyle has fontSize 11', () {
        final style = SyntaxTheme.lineNumberStyle;
        expect(style.fontSize, 11);
      });

      test('lineNumberStyle has lineNumberColor', () {
        final style = SyntaxTheme.lineNumberStyle;
        expect(style.color, SyntaxTheme.lineNumberColor);
      });
    });
  });
}
