import AppKit
import SwiftUI

/// NSTextView を SwiftUI にブリッジする読み取り専用コードビューア
/// TODO: BlameGutterView とのスクロール同期（Phase 3+）
struct CodeTextView: NSViewRepresentable {
    let text: String

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

        // テキストカラー
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor

        // 行番号（ruler）
        scrollView.hasVerticalRuler = false
        scrollView.hasHorizontalRuler = false
        scrollView.rulersVisible = false

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
            height: CGFloat.greatestFiniteMagnitude,
        )

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.string = text

        // ruler を更新
        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.needsDisplay = true
        }
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
            object: textView,
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

        // 背景描画
        let bgColor = NSColor.controlBackgroundColor
        bgColor.setFill()
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
            in: textContainer,
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil,
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor,
        ]

        var lineNumber = 1
        var index = 0

        // 可視範囲前の行数をカウント
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleCharRange.location),
            options: [.byLines, .substringNotRequired],
        ) { _, _, _, _ in
            lineNumber += 1
        }

        // 可視範囲内の行番号を描画
        text.enumerateSubstrings(
            in: visibleCharRange,
            options: [.byLines, .substringNotRequired],
        ) { _, substringRange, _, _ in
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: substringRange,
                actualCharacterRange: nil,
            )
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil,
            )

            let relativeY = lineRect.minY - visibleRect.minY + self.convert(NSPoint.zero, from: self.clientView).y
            let lineStr = "\(lineNumber)" as NSString
            let strSize = lineStr.size(withAttributes: attributes)

            lineStr.draw(
                at: NSPoint(
                    x: self.ruleThickness - strSize.width - 6,
                    y: relativeY + (lineRect.height - strSize.height) / 2,
                ),
                withAttributes: attributes,
            )

            lineNumber += 1
            index += 1
        }
    }
}
