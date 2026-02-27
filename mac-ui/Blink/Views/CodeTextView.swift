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

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true

        // NOTE: Temporarily disable NSRulerView to isolate rendering/interaction issue.
        scrollView.verticalRulerView = nil
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        #if DEBUG
            logLayout(phase: "make", textView: textView, scrollView: scrollView)
        #endif

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }
        applySyntaxHighlight(to: textView)

        let contentSize = scrollView.contentSize
        let hasValidViewport = contentSize.width > 1 && contentSize.height > 1
        guard hasValidViewport else {
            DispatchQueue.main.async { [weak scrollView, weak textView] in
                guard let scrollView, let textView else { return }
                let retrySize = scrollView.contentSize
                guard retrySize.width > 1, retrySize.height > 1 else { return }

                textView.frame.size = retrySize
                if let textContainer = textView.textContainer {
                    textContainer.containerSize = NSSize(
                        width: retrySize.width,
                        height: CGFloat.greatestFiniteMagnitude
                    )
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
                textView.needsDisplay = true

                #if DEBUG
                    logLayout(phase: "async-reflow", textView: textView, scrollView: scrollView)
                    logTextRenderingState(phase: "async-reflow", textView: textView)
                #endif
            }

            #if DEBUG
                logLayout(phase: "update-skip-zero-size", textView: textView, scrollView: scrollView)
                logTextRenderingState(phase: "update-skip-zero-size", textView: textView)
            #endif
            return
        }

        textView.frame.size = contentSize
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        textView.needsDisplay = true

        #if DEBUG
            logLayout(phase: "update", textView: textView, scrollView: scrollView)
            logTextRenderingState(phase: "update", textView: textView)
        #endif
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

#if DEBUG
    private func logLayout(phase: String, textView: NSTextView, scrollView: NSScrollView) {
        let rulerFrame = scrollView.verticalRulerView?.frame ?? .zero
        let contentViewFrame = scrollView.contentView.frame
        let documentVisibleRect = scrollView.documentVisibleRect
        let message =
            "[CodeTextView:\(phase)] textLength=\(textView.string.count) " +
            "contentSize=\(scrollView.contentSize) " +
            "frame=\(textView.frame) " +
            "visible=\(textView.visibleRect) " +
            "container=\(textView.textContainer?.containerSize ?? .zero) " +
            "textHidden=\(textView.isHidden) alpha=\(textView.alphaValue) " +
            "rulerVisible=\(scrollView.hasVerticalRuler && scrollView.rulersVisible) " +
            "rulerFrame=\(rulerFrame) contentViewFrame=\(contentViewFrame) " +
            "documentVisibleRect=\(documentVisibleRect)"
        debugLogToFileAndConsole(message)
    }

    private func debugLogToFileAndConsole(_ message: String) {
        NSLog("%@", message)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("blink_code_text.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url)
            {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    private func logTextRenderingState(phase: String, textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let textLength = textStorage.length
        let sampleLocation = max(0, min(textLength - 1, 0))

        var fgDesc = "nil"
        var fontDesc = "nil"
        if textLength > 0 {
            if let color = textStorage.attribute(.foregroundColor, at: sampleLocation, effectiveRange: nil) as? NSColor {
                fgDesc = color.description
            }
            if let font = textStorage.attribute(.font, at: sampleLocation, effectiveRange: nil) as? NSFont {
                fontDesc = "\(font.fontName) \(font.pointSize)"
            }
        }

        let glyphCount = textView.layoutManager?.numberOfGlyphs ?? -1
        let usedRect: NSRect = textView.layoutManager
            .flatMap { layoutManager in
                textView.textContainer.map { textContainer in
                    layoutManager.usedRect(for: textContainer)
                }
            } ?? .zero
        debugLogToFileAndConsole(
            "[CodeTextView:\(phase):render] len=\(textLength) glyphs=\(glyphCount) fg=\(fgDesc) font=\(fontDesc) usedRect=\(usedRect)"
        )
    }
#endif
