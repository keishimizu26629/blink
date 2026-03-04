import 'package:flutter/material.dart';

import '../../bridge/generated/dart_api.dart';
import '../../theme/syntax_theme.dart';

class DiffContentView extends StatelessWidget {
  final DartGitFileDiff? diff;
  final bool isLoading;
  final String? errorMessage;
  final List<DartTokenSpan> tokens;

  const DiffContentView({
    super.key,
    required this.diff,
    required this.isLoading,
    required this.errorMessage,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SyntaxTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 10),
            child: Text(
              diff != null ? 'Diff: ${diff!.commit}' : 'Diff',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('差分を取得中...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else if (errorMessage != null && errorMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SelectableText(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (diff != null)
            Expanded(
              child: _CodeLikeDiffView(
                diffText: diff!.diffText,
                tokens: tokens,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Diffを表示するにはファイルを選択してください。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

enum _DiffLineKind { meta, hunk, context, removed, added }

class _DiffLine {
  final _DiffLineKind kind;
  final int? oldLine;
  final int? newLine;
  final String text;
  final String marker;

  const _DiffLine({
    required this.kind,
    required this.oldLine,
    required this.newLine,
    required this.text,
    required this.marker,
  });
}

class _CodeLikeDiffView extends StatelessWidget {
  final String diffText;
  final List<DartTokenSpan> tokens;

  static const _oldLineColumnWidth = 52.0;
  static const _newLineColumnWidth = 52.0;
  static const _lineHeight = 20.0;

  const _CodeLikeDiffView({required this.diffText, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final rows = _parse(diffText);
    final tokensByLine = _groupTokensByLine(tokens);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = _calculateContentWidth(
          rows,
        ).clamp(constraints.maxWidth, double.infinity);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: ListView.builder(
              itemCount: rows.length,
              itemExtent: _lineHeight,
              itemBuilder: (context, index) {
                final row = rows[index];
                final tokenLine = row.newLine ?? row.oldLine;
                final lineTokens =
                    tokenLine == null ? null : tokensByLine[tokenLine];
                return _DiffLineRow(row: row, lineTokens: lineTokens);
              },
            ),
          ),
        );
      },
    );
  }

  double _calculateContentWidth(List<_DiffLine> rows) {
    var maxLen = 0;
    for (final row in rows) {
      final len = row.text.length + row.marker.length;
      if (len > maxLen) maxLen = len;
    }
    const charWidth = 7.8;
    const horizontalPadding = 32.0;
    final codeWidth = (maxLen * charWidth + horizontalPadding).clamp(
      500.0,
      double.infinity,
    );
    return _oldLineColumnWidth + _newLineColumnWidth + 2 + codeWidth;
  }

  static Map<int, List<DartTokenSpan>> _groupTokensByLine(
    List<DartTokenSpan> tokens,
  ) {
    final grouped = <int, List<DartTokenSpan>>{};
    for (final token in tokens) {
      grouped.putIfAbsent(token.line, () => []).add(token);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        if (a.startCol != b.startCol) return a.startCol.compareTo(b.startCol);
        return a.endCol.compareTo(b.endCol);
      });
    }
    return grouped;
  }

  static List<_DiffLine> _parse(String diffText) {
    final lines = diffText.split('\n');
    final rows = <_DiffLine>[];

    final hunkRegex = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
    int? oldLine;
    int? newLine;

    for (final line in lines) {
      final hunkMatch = hunkRegex.firstMatch(line);
      if (hunkMatch != null) {
        oldLine = int.parse(hunkMatch.group(1)!);
        newLine = int.parse(hunkMatch.group(2)!);
        rows.add(
          _DiffLine(
            kind: _DiffLineKind.hunk,
            oldLine: null,
            newLine: null,
            text: line,
            marker: '',
          ),
        );
        continue;
      }

      if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('--- ') ||
          line.startsWith('+++ ')) {
        rows.add(
          _DiffLine(
            kind: _DiffLineKind.meta,
            oldLine: null,
            newLine: null,
            text: line,
            marker: '',
          ),
        );
        continue;
      }

      if (line.startsWith('-') && !line.startsWith('---')) {
        rows.add(
          _DiffLine(
            kind: _DiffLineKind.removed,
            oldLine: oldLine,
            newLine: null,
            text: line.substring(1),
            marker: '-',
          ),
        );
        if (oldLine != null) oldLine++;
        continue;
      }

      if (line.startsWith('+') && !line.startsWith('+++')) {
        rows.add(
          _DiffLine(
            kind: _DiffLineKind.added,
            oldLine: null,
            newLine: newLine,
            text: line.substring(1),
            marker: '+',
          ),
        );
        if (newLine != null) newLine++;
        continue;
      }

      if (line.startsWith(' ')) {
        rows.add(
          _DiffLine(
            kind: _DiffLineKind.context,
            oldLine: oldLine,
            newLine: newLine,
            text: line.substring(1),
            marker: ' ',
          ),
        );
        if (oldLine != null) oldLine++;
        if (newLine != null) newLine++;
        continue;
      }

      rows.add(
        _DiffLine(
          kind: _DiffLineKind.meta,
          oldLine: null,
          newLine: null,
          text: line,
          marker: '',
        ),
      );
    }

    return rows;
  }
}

class _DiffLineRow extends StatelessWidget {
  final _DiffLine row;
  final List<DartTokenSpan>? lineTokens;

  const _DiffLineRow({required this.row, required this.lineTokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor(row.kind),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lineNumberCell(
            row.oldLine,
            width: _CodeLikeDiffView._oldLineColumnWidth,
          ),
          _lineNumberCell(
            row.newLine,
            width: _CodeLikeDiffView._newLineColumnWidth,
          ),
          Container(width: 1, color: const Color(0xFF30363D)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText.rich(
                  TextSpan(
                    style: SyntaxTheme.codeStyle.copyWith(fontSize: 12),
                    children: _buildSpans(),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineNumberCell(int? line, {required double width}) {
    final text = line?.toString() ?? '';
    return Container(
      width: width,
      padding: const EdgeInsets.only(right: 8),
      alignment: Alignment.centerRight,
      color: Colors.black.withValues(alpha: 0.14),
      child: Text(
        text,
        style: SyntaxTheme.lineNumberStyle.copyWith(fontSize: 10.5),
      ),
    );
  }

  List<InlineSpan> _buildSpans() {
    if (row.kind == _DiffLineKind.meta || row.kind == _DiffLineKind.hunk) {
      return [
        TextSpan(
          text: row.text,
          style: TextStyle(
            color:
                row.kind == _DiffLineKind.hunk
                    ? const Color(0xFF79C0FF)
                    : SyntaxTheme.defaultTextColor.withValues(alpha: 0.75),
            fontFamily: 'JetBrains Mono',
            fontSize: 11.5,
          ),
        ),
      ];
    }

    final markerColor = switch (row.kind) {
      _DiffLineKind.added => const Color(0xFF7EE787),
      _DiffLineKind.removed => const Color(0xFFFF7B72),
      _ => SyntaxTheme.defaultTextColor.withValues(alpha: 0.65),
    };

    final spans = <InlineSpan>[
      TextSpan(text: row.marker, style: TextStyle(color: markerColor)),
    ];

    final text = row.text;
    final tokens = lineTokens ?? const <DartTokenSpan>[];
    if (tokens.isEmpty || text.isEmpty) {
      spans.add(TextSpan(text: text));
      return spans;
    }

    var cursor = 0;
    for (final token in tokens) {
      final start = token.startCol.clamp(0, text.length);
      final end = token.endCol.clamp(start, text.length);

      if (cursor < start) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      if (start < end) {
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(color: SyntaxTheme.colorFor(token.tokenType)),
          ),
        );
      }
      cursor = end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  Color _backgroundColor(_DiffLineKind kind) {
    return switch (kind) {
      _DiffLineKind.meta => Colors.white.withValues(alpha: 0.04),
      _DiffLineKind.hunk => const Color(0xFF1A2B45),
      _DiffLineKind.context => Colors.transparent,
      _DiffLineKind.removed => const Color(0xFF3A1F24),
      _DiffLineKind.added => const Color(0xFF1F3A2A),
    };
  }
}
