import 'package:flutter/material.dart';

import '../../bridge/generated/dart_api.dart';
import '../../theme/syntax_theme.dart';

class CodeTextView extends StatefulWidget {
  final String text;
  final List<DartTokenSpan> tokens;
  final void Function(int startLine, int endLine) onVisibleLineRangeChange;

  const CodeTextView({
    super.key,
    required this.text,
    required this.tokens,
    required this.onVisibleLineRangeChange,
  });

  @override
  State<CodeTextView> createState() => _CodeTextViewState();
}

class _CodeTextViewState extends State<CodeTextView> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  late List<String> _lines;
  // fontSize(13) * lineHeight(1.5) = 19.5
  static const double _lineHeight = 19.5;
  static const double _gutterWidth = 52.0;

  int _lastReportedStart = -1;
  int _lastReportedEnd = -1;

  @override
  void initState() {
    super.initState();
    _lines = widget.text.split('\n');
    _verticalController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CodeTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = widget.text.split('\n');
      _lastReportedStart = -1;
      _lastReportedEnd = -1;
    }
  }

  @override
  void dispose() {
    _verticalController.removeListener(_onScroll);
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _reportVisibleRange();
  }

  void _reportVisibleRange() {
    if (!_verticalController.hasClients || _lines.isEmpty) return;
    final viewportHeight = _verticalController.position.viewportDimension;
    final scrollOffset = _verticalController.offset;
    final startLine = (scrollOffset / _lineHeight).floor() + 1;
    final endLine = ((scrollOffset + viewportHeight) / _lineHeight).ceil();
    final clampedStart = startLine.clamp(1, _lines.length);
    final clampedEnd = endLine.clamp(1, _lines.length);

    if (clampedStart == _lastReportedStart && clampedEnd == _lastReportedEnd) {
      return;
    }

    _lastReportedStart = clampedStart;
    _lastReportedEnd = clampedEnd;
    widget.onVisibleLineRangeChange(clampedStart, clampedEnd);
  }

  @override
  Widget build(BuildContext context) {
    // Group tokens by line for efficient lookup.
    final tokensByLine = <int, List<DartTokenSpan>>{};
    for (final token in widget.tokens) {
      tokensByLine.putIfAbsent(token.line, () => []).add(token);
    }

    // Sort each line's tokens by startCol.
    for (final list in tokensByLine.values) {
      list.sort((a, b) {
        if (a.startCol != b.startCol) {
          return a.startCol.compareTo(b.startCol);
        }
        return a.endCol.compareTo(b.endCol);
      });
    }

    return Container(
      color: SyntaxTheme.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Report initial visible range after build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _reportVisibleRange();
          });

          final contentWidth = (_calculateMaxLineWidth() + _gutterWidth + 1)
              .clamp(constraints.maxWidth, double.infinity);

          return Scrollbar(
            controller: _verticalController,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: _lines.length,
                  itemExtent: _lineHeight,
                  itemBuilder: (context, index) {
                    final lineNumber = index + 1;
                    return _CodeLineRow(
                      lineNumber: lineNumber,
                      lineText: _lines[index],
                      lineTokens: tokensByLine[lineNumber],
                      gutterWidth: _gutterWidth,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _calculateMaxLineWidth() {
    var maxLen = 0;
    for (final line in _lines) {
      if (line.length > maxLen) maxLen = line.length;
    }
    // Approximate character width for JetBrains Mono 13pt.
    const charWidth = 7.8;
    return (maxLen * charWidth + 32).clamp(400.0, double.infinity);
  }
}

class _CodeLineRow extends StatelessWidget {
  final int lineNumber;
  final String lineText;
  final List<DartTokenSpan>? lineTokens;
  final double gutterWidth;

  const _CodeLineRow({
    required this.lineNumber,
    required this.lineText,
    required this.lineTokens,
    required this.gutterWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: gutterWidth,
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            color: SyntaxTheme.backgroundColor,
            child: Text('$lineNumber', style: SyntaxTheme.lineNumberStyle),
          ),
        ),
        Container(width: 1, color: const Color(0xFF30363D)),
        Expanded(
          child: Container(
            color: SyntaxTheme.backgroundColor,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SelectableText.rich(
              TextSpan(
                style: SyntaxTheme.codeStyle,
                children: _buildLineSpans(lineText, lineTokens ?? const []),
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _buildLineSpans(String line, List<DartTokenSpan> tokens) {
    if (tokens.isEmpty || line.isEmpty) {
      return [TextSpan(text: line)];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final token in tokens) {
      final start = token.startCol.clamp(0, line.length);
      final end = token.endCol.clamp(start, line.length);

      if (cursor < start) {
        spans.add(TextSpan(text: line.substring(cursor, start)));
      }
      if (start < end) {
        spans.add(
          TextSpan(
            text: line.substring(start, end),
            style: TextStyle(color: SyntaxTheme.colorFor(token.tokenType)),
          ),
        );
      }
      cursor = end;
    }

    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }

    return spans;
  }
}
