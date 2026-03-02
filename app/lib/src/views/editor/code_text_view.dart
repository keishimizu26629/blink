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
  // Line height: fontSize(13) * lineHeight(1.5) = 19.5
  static const double _lineHeight = 19.5;
  static const double _gutterWidth = 48.0;

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
    if (!_verticalController.hasClients) return;
    final viewportHeight = _verticalController.position.viewportDimension;
    final scrollOffset = _verticalController.offset;
    final startLine = (scrollOffset / _lineHeight).floor() + 1;
    final endLine = ((scrollOffset + viewportHeight) / _lineHeight).ceil();
    final clampedStart = startLine.clamp(1, _lines.length);
    final clampedEnd = endLine.clamp(1, _lines.length);

    if (clampedStart == _lastReportedStart &&
        clampedEnd == _lastReportedEnd) {
      return;
    }
    _lastReportedStart = clampedStart;
    _lastReportedEnd = clampedEnd;
    widget.onVisibleLineRangeChange(clampedStart, clampedEnd);
  }

  @override
  Widget build(BuildContext context) {
    // Group tokens by line for efficient lookup
    final tokensByLine = <int, List<DartTokenSpan>>{};
    for (final token in widget.tokens) {
      tokensByLine.putIfAbsent(token.line, () => []).add(token);
    }
    // Sort each line's tokens by startCol
    for (final list in tokensByLine.values) {
      list.sort((a, b) => a.startCol != b.startCol
          ? a.startCol.compareTo(b.startCol)
          : a.endCol.compareTo(b.endCol));
    }

    return Container(
      color: SyntaxTheme.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Report initial visible range after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _reportVisibleRange();
          });

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line number gutter
              SizedBox(
                width: _gutterWidth,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: _SyncedGutter(
                    mainController: _verticalController,
                    lineCount: _lines.length,
                    lineHeight: _lineHeight,
                    gutterWidth: _gutterWidth,
                  ),
                ),
              ),
              // Vertical separator
              Container(width: 1, color: const Color(0xFF30363D)),
              // Code area
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _calculateMaxLineWidth(),
                        child: SelectableText.rich(
                          _buildTextSpan(tokensByLine),
                          style: SyntaxTheme.codeStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextSpan _buildTextSpan(Map<int, List<DartTokenSpan>> tokensByLine) {
    final children = <InlineSpan>[];
    for (var i = 0; i < _lines.length; i++) {
      final lineNum = i + 1; // 1-based
      final line = _lines[i];
      final lineTokens = tokensByLine[lineNum];

      if (lineTokens != null && lineTokens.isNotEmpty) {
        children.addAll(_buildHighlightedLine(line, lineTokens));
      } else {
        children.add(TextSpan(text: line));
      }

      if (i < _lines.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }
    return TextSpan(children: children);
  }

  List<InlineSpan> _buildHighlightedLine(
    String line,
    List<DartTokenSpan> tokens,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final token in tokens) {
      final start = token.startCol.clamp(0, line.length);
      final end = token.endCol.clamp(start, line.length);

      if (cursor < start) {
        spans.add(TextSpan(text: line.substring(cursor, start)));
      }
      if (start < end) {
        spans.add(TextSpan(
          text: line.substring(start, end),
          style: TextStyle(color: SyntaxTheme.colorFor(token.tokenType)),
        ));
      }
      cursor = end;
    }

    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }

    return spans;
  }

  double _calculateMaxLineWidth() {
    // Estimate: max line length * character width + padding
    var maxLen = 0;
    for (final line in _lines) {
      if (line.length > maxLen) maxLen = line.length;
    }
    // Approximate character width for monospace 13pt
    const charWidth = 7.8;
    return (maxLen * charWidth + 32).clamp(400.0, double.infinity);
  }
}

/// Gutter that syncs its scroll position with the main vertical controller.
class _SyncedGutter extends StatefulWidget {
  final ScrollController mainController;
  final int lineCount;
  final double lineHeight;
  final double gutterWidth;

  const _SyncedGutter({
    required this.mainController,
    required this.lineCount,
    required this.lineHeight,
    required this.gutterWidth,
  });

  @override
  State<_SyncedGutter> createState() => _SyncedGutterState();
}

class _SyncedGutterState extends State<_SyncedGutter> {
  final ScrollController _gutterController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.mainController.addListener(_syncScroll);
  }

  @override
  void didUpdateWidget(_SyncedGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mainController != widget.mainController) {
      oldWidget.mainController.removeListener(_syncScroll);
      widget.mainController.addListener(_syncScroll);
    }
  }

  @override
  void dispose() {
    widget.mainController.removeListener(_syncScroll);
    _gutterController.dispose();
    super.dispose();
  }

  void _syncScroll() {
    if (_gutterController.hasClients && widget.mainController.hasClients) {
      _gutterController.jumpTo(widget.mainController.offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.lineCount * widget.lineHeight,
      child: ListView.builder(
        controller: _gutterController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.lineCount,
        itemExtent: widget.lineHeight,
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '${index + 1}',
              style: SyntaxTheme.lineNumberStyle,
            ),
          );
        },
      ),
    );
  }
}
