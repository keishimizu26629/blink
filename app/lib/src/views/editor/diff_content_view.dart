import 'package:flutter/material.dart';

import '../../bridge/generated/dart_api.dart';
import '../../theme/syntax_theme.dart';

// ---------------------------------------------------------------------------
// DiffContentView - main wrapper
// ---------------------------------------------------------------------------

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
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
              child: _PRDiffTableView(
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

// ---------------------------------------------------------------------------
// Diff data models
// ---------------------------------------------------------------------------

enum _RowKind { meta, hunk, unchanged, removed, added, modified }
enum _RawKind { meta, hunk, context, removed, added }

class _RawLine {
  final _RawKind kind;
  final int? oldLine;
  final int? newLine;
  final String text;
  const _RawLine({required this.kind, this.oldLine, this.newLine, required this.text});
}

class _Row {
  final int id;
  final _RowKind kind;
  final int? oldLine;
  final int? newLine;
  final String oldText;
  final String newText;
  const _Row({
    required this.id,
    required this.kind,
    this.oldLine,
    this.newLine,
    required this.oldText,
    required this.newText,
  });
}

// ---------------------------------------------------------------------------
// PRDiffTableView
// ---------------------------------------------------------------------------

class _PRDiffTableView extends StatelessWidget {
  final String diffText;
  final List<DartTokenSpan> tokens;
  static const _lineColumnWidth = 56.0;
  static const _minContentWidth = 1100.0;
  static final _hunkRegex = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

  const _PRDiffTableView({required this.diffText, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final rows = _parse(diffText);
    final tokensByLine = _groupTokensByLine(tokens);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _minContentWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(),
              const Divider(height: 1, color: Color(0xFF30363D)),
              ...rows.map((row) => _rowView(row, tokensByLine)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      color: Colors.white.withValues(alpha:0.08),
      child: Row(
        children: [
          Expanded(child: _sideHeader('OLD')),
          Container(width: 1, color: const Color(0xFF30363D)),
          Expanded(child: _sideHeader('NEW')),
        ],
      ),
    );
  }

  Widget _sideHeader(String title) {
    return Row(
      children: [
        SizedBox(
          width: _lineColumnWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '#',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w600,
                color: SyntaxTheme.lineNumberColor,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w600,
                color: SyntaxTheme.defaultTextColor.withValues(alpha:0.92),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowView(_Row row, Map<int, List<DartTokenSpan>> tokensByLine) {
    if (row.kind == _RowKind.meta || row.kind == _RowKind.hunk) {
      return Container(
        width: _minContentWidth,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        color: row.kind == _RowKind.hunk
            ? Colors.blue.withValues(alpha:0.20)
            : Colors.white.withValues(alpha:0.05),
        child: Text(
          row.oldText,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'JetBrains Mono',
            color: row.kind == _RowKind.hunk
                ? Colors.white.withValues(alpha:0.95)
                : SyntaxTheme.defaultTextColor.withValues(alpha:0.8),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _sideRow(
            line: row.oldLine,
            text: row.oldText,
            background: _sideBackground(row.kind, _DiffSide.old),
            tokensByLine: tokensByLine,
          ),
        ),
        Container(width: 1, color: const Color(0xFF30363D)),
        Expanded(
          child: _sideRow(
            line: row.newLine,
            text: row.newText,
            background: _sideBackground(row.kind, _DiffSide.new_),
            tokensByLine: tokensByLine,
          ),
        ),
      ],
    );
  }

  Widget _sideRow({
    required int? line,
    required String text,
    required Color background,
    required Map<int, List<DartTokenSpan>> tokensByLine,
  }) {
    return Container(
      color: background,
      child: Row(
        children: [
          SizedBox(
            width: _lineColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                line?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                  color: SyntaxTheme.lineNumberColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: _highlightedText(text, line, tokensByLine),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightedText(String text, int? line, Map<int, List<DartTokenSpan>> tokensByLine) {
    if (line == null || text.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
          color: SyntaxTheme.defaultTextColor.withValues(alpha:0.96),
        ),
      );
    }

    final lineTokens = tokensByLine[line];
    if (lineTokens == null || lineTokens.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
          color: SyntaxTheme.defaultTextColor.withValues(alpha:0.96),
        ),
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    final length = text.length;
    final defaultStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'JetBrains Mono',
      color: SyntaxTheme.defaultTextColor.withValues(alpha:0.96),
    );

    for (final token in lineTokens) {
      final start = token.startCol.clamp(0, length);
      final end = token.endCol.clamp(start, length);

      if (cursor < start) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: defaultStyle));
      }
      if (start < end) {
        spans.add(TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'JetBrains Mono',
            color: SyntaxTheme.colorFor(token.tokenType),
          ),
        ));
      }
      cursor = end;
    }
    if (cursor < length) {
      spans.add(TextSpan(text: text.substring(cursor), style: defaultStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  // ---------------------------------------------------------------------------
  // Colors
  // ---------------------------------------------------------------------------

  Color _sideBackground(_RowKind kind, _DiffSide side) {
    return switch (kind) {
      _RowKind.removed => side == _DiffSide.old ? Colors.red.withValues(alpha:0.22) : Colors.transparent,
      _RowKind.added => side == _DiffSide.new_ ? Colors.green.withValues(alpha:0.22) : Colors.transparent,
      _RowKind.modified => side == _DiffSide.old ? Colors.red.withValues(alpha:0.18) : Colors.green.withValues(alpha:0.18),
      _ => Colors.transparent,
    };
  }

  // ---------------------------------------------------------------------------
  // Diff parsing (exact port from Swift PRDiffTableView)
  // ---------------------------------------------------------------------------

  static List<_Row> _parse(String diffText) {
    final lines = diffText.split('\n');
    final rawLines = _parseRaw(lines);
    return _convertRawToRows(rawLines);
  }

  static Map<int, List<DartTokenSpan>> _groupTokensByLine(List<DartTokenSpan> tokens) {
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

  static List<_RawLine> _parseRaw(List<String> lines) {
    final raw = <_RawLine>[];
    int? oldLine;
    int? newLine;

    for (final line in lines) {
      final hunkMatch = _hunkRegex.firstMatch(line);
      if (hunkMatch != null) {
        oldLine = int.parse(hunkMatch.group(1)!);
        newLine = int.parse(hunkMatch.group(2)!);
        raw.add(_RawLine(kind: _RawKind.hunk, text: line));
        continue;
      }

      if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('--- ') ||
          line.startsWith('+++ ')) {
        raw.add(_RawLine(kind: _RawKind.meta, text: line));
        continue;
      }

      if (line.startsWith('-') && !line.startsWith('---')) {
        raw.add(_RawLine(kind: _RawKind.removed, oldLine: oldLine, text: line.substring(1)));
        if (oldLine != null) oldLine++;
        continue;
      }

      if (line.startsWith('+') && !line.startsWith('+++')) {
        raw.add(_RawLine(kind: _RawKind.added, newLine: newLine, text: line.substring(1)));
        if (newLine != null) newLine++;
        continue;
      }

      if (line.startsWith(' ')) {
        raw.add(_RawLine(kind: _RawKind.context, oldLine: oldLine, newLine: newLine, text: line.substring(1)));
        if (oldLine != null) oldLine++;
        if (newLine != null) newLine++;
        continue;
      }

      raw.add(_RawLine(kind: _RawKind.meta, text: line));
    }
    return raw;
  }

  static List<_Row> _convertRawToRows(List<_RawLine> rawLines) {
    final rows = <_Row>[];
    final pendingRemoved = <_RawLine>[];
    final pendingAdded = <_RawLine>[];

    void appendRow({
      required _RowKind kind,
      int? oldLine,
      int? newLine,
      required String oldText,
      required String newText,
    }) {
      rows.add(_Row(
        id: rows.length,
        kind: kind,
        oldLine: oldLine,
        newLine: newLine,
        oldText: oldText,
        newText: newText,
      ));
    }

    void flushPending() {
      if (pendingRemoved.isEmpty && pendingAdded.isEmpty) return;
      final count = pendingRemoved.length > pendingAdded.length
          ? pendingRemoved.length
          : pendingAdded.length;
      for (var i = 0; i < count; i++) {
        final removed = i < pendingRemoved.length ? pendingRemoved[i] : null;
        final added = i < pendingAdded.length ? pendingAdded[i] : null;
        if (removed != null && added != null) {
          appendRow(kind: _RowKind.modified, oldLine: removed.oldLine, newLine: added.newLine, oldText: removed.text, newText: added.text);
        } else if (removed != null) {
          appendRow(kind: _RowKind.removed, oldLine: removed.oldLine, oldText: removed.text, newText: '');
        } else if (added != null) {
          appendRow(kind: _RowKind.added, newLine: added.newLine, oldText: '', newText: added.text);
        }
      }
      pendingRemoved.clear();
      pendingAdded.clear();
    }

    for (final raw in rawLines) {
      switch (raw.kind) {
        case _RawKind.removed:
          pendingRemoved.add(raw);
        case _RawKind.added:
          pendingAdded.add(raw);
        case _RawKind.context:
          flushPending();
          appendRow(kind: _RowKind.unchanged, oldLine: raw.oldLine, newLine: raw.newLine, oldText: raw.text, newText: raw.text);
        case _RawKind.meta:
          flushPending();
          appendRow(kind: _RowKind.meta, oldText: raw.text, newText: '');
        case _RawKind.hunk:
          flushPending();
          appendRow(kind: _RowKind.hunk, oldText: raw.text, newText: '');
      }
    }
    flushPending();
    return rows;
  }
}

enum _DiffSide { old, new_ }
