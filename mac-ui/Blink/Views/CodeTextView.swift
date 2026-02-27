import AppKit
import SwiftUI

// MARK: - CodeTextView

/// NSTextView を SwiftUI にブリッジする読み取り専用コードビューア
struct CodeTextView: NSViewRepresentable {
    let text: String
    let tokens: [TokenSpan]

    func makeNSView(context _: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // 読み取り専用
        textView.isEditable = false
        textView.isSelectable = true

        // 等幅フォント（SF Mono, 13pt）
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // ダークテーマ背景 & デフォルトテキスト色
        textView.backgroundColor = SyntaxTheme.backgroundColor
        textView.textColor = SyntaxTheme.defaultTextColor
        textView.insertionPointColor = SyntaxTheme.defaultTextColor

        // 行番号はカスタム ruler で表示
        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        // 自動折り返しを無効化（水平スクロール可能に）
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // テキストをセット
        textView.string = text

        // シンタックスハイライトを適用
        applySyntaxHighlight(to: textView)

        // ruler を更新
        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.needsDisplay = true
        }
    }

    // MARK: - Syntax Highlight

    /// TokenSpan 配列を NSTextStorage の属性に変換して適用する
    private func applySyntaxHighlight(to textView: NSTextView) {
        guard !tokens.isEmpty else { return }
        guard let textStorage = textView.textStorage else { return }

        let fullText = textView.string as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // まずデフォルト属性をリセット
        let fullRange = NSRange(location: 0, length: fullText.length)
        textStorage.beginEditing()
        textStorage.addAttributes(
            [
                .foregroundColor: SyntaxTheme.defaultTextColor,
                .font: font
            ],
            range: fullRange
        )

        // 各行の開始オフセットを事前計算
        let lines = textView.string.split(separator: "\n", omittingEmptySubsequences: false)
        var lineOffsets: [Int] = []
        var offset = 0
        for line in lines {
            lineOffsets.append(offset)
            offset += line.count + 1 // +1 for newline
        }

        // トークンごとに色を適用
        for token in tokens {
            let lineIndex = Int(token.line) - 1 // 1-based → 0-based
            guard lineIndex >= 0, lineIndex < lineOffsets.count else { continue }

            let lineStart = lineOffsets[lineIndex]
            let start = lineStart + Int(token.startCol)
            let length = Int(token.endCol) - Int(token.startCol)

            guard start >= 0, length > 0, start + length <= fullText.length else { continue }

            let range = NSRange(location: start, length: length)
            let color = SyntaxTheme.color(for: token.tokenType)
            textStorage.addAttribute(.foregroundColor, value: color, range: range)
        }

        textStorage.endEditing()
    }
}

// MARK: - LineNumberRulerView

/// NSTextView に行番号を表示するカスタム ruler
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let lineNumberColor = NSColor.secondaryLabelColor

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40

        // テキスト変更時に再描画
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textDidChange(_: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        // 背景描画（テーマに合わせる）
        SyntaxTheme.backgroundColor.setFill()
        rect.fill()

        // セパレータ線
        let separatorColor = NSColor.separatorColor
        separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        separatorPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: rect.minY))
        separatorPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        separatorPath.lineWidth = 0.5
        separatorPath.stroke()

        let text = textView.string as NSString
        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]

        var lineNumber = 1

        // 可視範囲前の行数をカウント
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleCharRange.location),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            lineNumber += 1
        }

        // 可視範囲内の行番号を描画
        text.enumerateSubstrings(
            in: visibleCharRange,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: substringRange,
                actualCharacterRange: nil
            )
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )

            let relativeY = lineRect.minY - visibleRect.minY + self.convert(NSPoint.zero, from: self.clientView).y
            let lineStr = "\(lineNumber)" as NSString
            let strSize = lineStr.size(withAttributes: attributes)

            lineStr.draw(
                at: NSPoint(
                    x: self.ruleThickness - strSize.width - 6,
                    y: relativeY + (lineRect.height - strSize.height) / 2
                ),
                withAttributes: attributes
            )

            lineNumber += 1
        }
    }
}
