import AppKit
import SwiftUI

struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    let tokens: [TokenSpan]
    private let lineNumberWidth: CGFloat = 48

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CodeTextContainerView {
        #if DEBUG
            resetDebugLogIfNeeded()
        #endif
        let containerView = CodeTextContainerView(gutterWidth: lineNumberWidth)
        let scrollView = containerView.scrollView
        let textView = containerView.textView

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
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false

        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true

        // Keep NSRulerView detached from NSScrollView ruler plumbing.
        scrollView.verticalRulerView = nil
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        #if DEBUG
            logLayout(phase: "make", textView: textView, scrollView: scrollView)
            logTextRenderingState(phase: "make", textView: textView)
        #endif

        return containerView
    }

    func updateNSView(_ containerView: CodeTextContainerView, context _: Context) {
        let scrollView = containerView.scrollView
        let textView = containerView.textView

        #if DEBUG
            debugLogToFileAndConsole(
                "[CodeTextView:update:start] bindingTextLength=\(text.count) tokenCount=\(tokens.count)"
            )
            logLayout(phase: "update-start", textView: textView, scrollView: scrollView)
            logTextRenderingState(phase: "update-start", textView: textView)
        #endif

        if textView.string != text {
            textView.string = text
        }
        applySyntaxHighlight(to: textView)

        containerView.layoutSubtreeIfNeeded()
        let contentSize = scrollView.contentView.bounds.size
        let hasValidViewport = contentSize.width > 1 && contentSize.height > 1
        guard hasValidViewport else {
            DispatchQueue.main.async { [weak containerView, weak scrollView, weak textView] in
                guard let containerView, let scrollView, let textView else { return }
                containerView.layoutSubtreeIfNeeded()
                let retrySize = scrollView.contentView.bounds.size
                guard retrySize.width > 1, retrySize.height > 1 else { return }

                if let textContainer = textView.textContainer {
                    textContainer.containerSize = NSSize(
                        width: resolvedContainerWidth(
                            textView: textView,
                            scrollView: scrollView
                        ),
                        height: CGFloat.greatestFiniteMagnitude
                    )
                    textView.layoutManager?.ensureLayout(for: textContainer)
                }
                textView.needsDisplay = true
                containerView.lineNumberView.needsDisplay = true

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

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: resolvedContainerWidth(
                    textView: textView,
                    scrollView: scrollView
                ),
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        containerView.layoutSubtreeIfNeeded()
        textView.needsDisplay = true
        containerView.lineNumberView.needsDisplay = true

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

    private func resolvedContainerWidth(
        textView: NSTextView,
        scrollView: NSScrollView
    ) -> CGFloat {
        let insetWidth = textView.textContainerInset.width * 2
        let textViewBoundsWidth = textView.bounds.width
        let contentBoundsWidth = scrollView.contentView.bounds.width
        let baseWidth = max(textViewBoundsWidth, contentBoundsWidth)
        return max(1, baseWidth - insetWidth)
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

final class CodeTextContainerView: NSView {
    let gutterWidth: CGFloat
    let scrollView: NSScrollView
    let textView: NSTextView
    let lineNumberView: LineNumberRulerView

    init(gutterWidth: CGFloat) {
        self.gutterWidth = gutterWidth
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Expected NSTextView as scrollView.documentView")
        }
        self.scrollView = scrollView
        self.textView = textView
        lineNumberView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        super.init(frame: .zero)

        addSubview(lineNumberView)
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let gutter = min(gutterWidth, max(0, bounds.width))
        lineNumberView.frame = NSRect(
            x: 0,
            y: 0,
            width: gutter,
            height: bounds.height
        )
        scrollView.frame = NSRect(
            x: gutter,
            y: 0,
            width: max(0, bounds.width - gutter),
            height: bounds.height
        )
        lineNumberView.needsDisplay = true

        #if DEBUG
            debugLogToFileAndConsole(
                "[CodeTextContainer:layout] bounds=\(bounds) gutterFrame=\(lineNumberView.frame) " +
                    "scrollFrame=\(scrollView.frame) contentBounds=\(scrollView.contentView.bounds) " +
                    "textBounds=\(textView.bounds) container=\(textView.textContainer?.containerSize ?? .zero)"
            )
        #endif
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private weak var observedClipView: NSClipView?
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private let foregroundColor = SyntaxTheme.lineNumberColor
    #if DEBUG
        private var debugDrawCount: Int = 0
    #endif

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48

        observedClipView = scrollView.contentView
        observedClipView?.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClipBoundsChanged),
            name: NSView.boundsDidChangeNotification,
            object: observedClipView
        )
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleClipBoundsChanged() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let scrollView,
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
        let clipBounds = scrollView.contentView.bounds
        let visibleRect = NSRect(
            x: 0,
            y: clipBounds.origin.y - textView.textContainerOrigin.y,
            width: textContainer.containerSize.width,
            height: clipBounds.height
        )
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )

        #if DEBUG
            debugDrawCount += 1
            if debugDrawCount <= 5 || debugDrawCount % 20 == 0 {
                debugLogToFileAndConsole(
                    "[LineNumberRuler:draw] count=\(debugDrawCount) rect=\(rect) " +
                        "clipBounds=\(clipBounds) visibleGlyph=\(visibleGlyphRange) " +
                        "visibleChar=\(visibleCharRange)"
                )
            }
        #endif

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

            let relativeY = lineRect.minY + textView.textContainerOrigin.y - clipBounds.origin.y
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
    private var didResetDebugLog = false

    private func resetDebugLogIfNeeded() {
        guard !didResetDebugLog else { return }
        didResetDebugLog = true
        let url = URL(fileURLWithPath: "/tmp/blink_code_text.log")
        try? FileManager.default.removeItem(at: url)
        debugLogToFileAndConsole("[CodeTextView] reset log file at \(url.path)")
    }

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
        let url = URL(fileURLWithPath: "/tmp/blink_code_text.log")

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
