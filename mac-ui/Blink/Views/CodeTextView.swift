import AppKit
import SwiftUI

struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    let tokens: [TokenSpan]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.delegate = context.coordinator
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = SyntaxTheme.backgroundColor
        textView.textColor = SyntaxTheme.defaultTextColor
        textView.insertionPointColor = SyntaxTheme.defaultTextColor
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]

        let contentSize = scrollView.contentSize
        textView.minSize = NSSize(width: contentSize.width, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        let rulerView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string == text {
            applySyntaxHighlight(to: textView)
            if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
                rulerView.needsDisplay = true
            }
            return
        }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.textStorage?.replaceCharacters(in: fullRange, with: text)

        applySyntaxHighlight(to: textView)

        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.needsDisplay = true
        }
    }

    private func applySyntaxHighlight(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullText = textView.string as NSString
        guard fullText.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: fullText.length)
        textStorage.beginEditing()
        textStorage.setAttributes(
            [
                .foregroundColor: SyntaxTheme.defaultTextColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ],
            range: fullRange
        )

        if !tokens.isEmpty {
            let lines = textView.string.split(separator: "\n", omittingEmptySubsequences: false)
            var lineOffsets: [Int] = []
            var offset = 0
            for line in lines {
                lineOffsets.append(offset)
                offset += line.count + 1
            }

            for token in tokens {
                let lineIndex = Int(token.line) - 1
                guard lineIndex >= 0, lineIndex < lineOffsets.count else { continue }

                let lineStart = lineOffsets[lineIndex]
                let start = lineStart + Int(token.startCol)
                let length = Int(token.endCol) - Int(token.startCol)

                guard start >= 0, length > 0, start + length <= fullText.length else { continue }

                let range = NSRange(location: start, length: length)
                let color = SyntaxTheme.color(for: token.tokenType)
                textStorage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        textStorage.endEditing()
    }
}

extension CodeTextView {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView

        init(_ parent: CodeTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let foregroundColor = NSColor.secondaryLabelColor

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        SyntaxTheme.backgroundColor.setFill()
        rect.fill()

        NSColor.separatorColor.setStroke()
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
            .font: font,
            .foregroundColor: foregroundColor
        ]

        var lineNumber = 1
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleCharRange.location),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            lineNumber += 1
        }

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
            let lineText = "\(lineNumber)" as NSString
            let size = lineText.size(withAttributes: attributes)

            lineText.draw(
                at: NSPoint(
                    x: self.ruleThickness - size.width - 6,
                    y: relativeY + (lineRect.height - size.height) / 2
                ),
                withAttributes: attributes
            )

            lineNumber += 1
        }
    }
}
