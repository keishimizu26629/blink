import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ProjectViewModel()
    @State private var isFolderImporterPresented = false

    var body: some View {
        NavigationSplitView {
            ProjectTreeView(
                nodes: viewModel.rootNodes,
                selectedFileId: viewModel.selectedFile?.id,
                onSelectFile: { node in
                    Task {
                        await viewModel.selectFile(node: node)
                    }
                },
                onToggleDir: { node in
                    Task {
                        await viewModel.toggleDir(node: node)
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            ZStack {
                Color(nsColor: SyntaxTheme.backgroundColor)
                    .ignoresSafeArea()

                if let content = viewModel.fileContent {
                    VStack(spacing: 0) {
                        if viewModel.isBlameVisible, let blameError = viewModel.blameErrorMessage, !blameError.isEmpty {
                            Text("Blame取得失敗: \(blameError)")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.08))
                        }

                        HStack(spacing: 0) {
                            if viewModel.isBlameVisible {
                                ScrollView(.vertical, showsIndicators: false) {
                                    BlameGutterView(
                                        blameLines: viewModel.blameLines,
                                        onSelectLine: { line in
                                            Task {
                                                await viewModel.selectBlameLine(line)
                                            }
                                        }
                                    )
                                }
                                .frame(width: 170)
                                .background(Color(nsColor: SyntaxTheme.backgroundColor).opacity(0.98))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .zIndex(1)

                                Divider()
                            }

                            CodeTextView(
                                text: Binding(
                                    get: { viewModel.fileContent ?? content },
                                    set: { viewModel.fileContent = $0 }
                                ),
                                tokens: viewModel.highlightTokens,
                                onVisibleLineRangeChange: { startLine, endLine in
                                    viewModel.updateVisibleRange(startLine: startLine, endLine: endLine)
                                }
                            )
                            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if viewModel.isDiffPanelVisible {
                            Divider()
                            BlameDiffPanelView(
                                diff: viewModel.selectedBlameDiff,
                                isLoading: viewModel.isDiffLoading,
                                errorMessage: viewModel.diffErrorMessage,
                                onClose: { viewModel.closeDiffPanel() }
                            )
                            .frame(height: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("フォルダまたはファイルを選択してください")
                        .font(.title3)
                        .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.toggleBlameVisibility()
                } label: {
                    Label(
                        "Blame",
                        systemImage: viewModel.isBlameVisible ? "person.fill" : "person"
                    )
                }
                .help("Git Blame の表示切替")
                .disabled(viewModel.fileContent == nil)
            }
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { viewModel.windowOpacity },
                            set: { viewModel.updateWindowOpacity($0) }
                        ),
                        in: 0.6 ... 1.0
                    )
                    .frame(width: 140)
                    Text("\(Int(viewModel.windowOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
                .help("ウィンドウ不透明度")
            }
        }
        .background(
            WindowOpacityConfigurator(opacity: viewModel.windowOpacity)
                .allowsHitTesting(false)
        )
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.openProject(url: url)
                }
            case let .failure(error):
                viewModel.errorMessage = "フォルダ選択に失敗しました: \(error.localizedDescription)"
            }
        }
        .alert("エラー", isPresented: errorPresentedBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .focusedSceneValue(\.projectViewModel, viewModel)
    }

    private func openFolder() {
        isFolderImporterPresented = true
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct WindowOpacityConfigurator: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyWindowOpacity(opacity, to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            applyWindowOpacity(opacity, to: nsView.window)
        }
    }

    private func applyWindowOpacity(_ opacity: Double, to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = CGFloat(opacity)
    }
}

private struct BlameDiffPanelView: View {
    let diff: BlameDiff?
    let isLoading: Bool
    let errorMessage: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(panelTitle)
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("差分を取得中...")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let diff {
                PRDiffTableView(diffText: diff.diffText)
            } else {
                Text("Blame 行を選択すると差分を表示します。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: SyntaxTheme.backgroundColor))
    }

    private var panelTitle: String {
        if let diff {
            return "Diff: \(diff.commit)"
        }
        return "Diff"
    }
}

private struct PRDiffTableView: View {
    private enum RowKind {
        case meta
        case hunk
        case unchanged
        case removed
        case added
        case modified
    }

    private enum RawKind {
        case meta
        case hunk
        case context
        case removed
        case added
    }

    private struct RawLine {
        let kind: RawKind
        let oldLine: Int?
        let newLine: Int?
        let text: String
    }

    private struct Row: Identifiable {
        let id: Int
        let kind: RowKind
        let oldLine: Int?
        let newLine: Int?
        let oldText: String
        let newText: String
    }

    private static let hunkRegex = try? NSRegularExpression(
        pattern: #"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
    )

    private let rows: [Row]
    private let lineColumnWidth: CGFloat = 56
    private let minContentWidth: CGFloat = 1100

    init(diffText: String) {
        rows = Self.parse(diffText: diffText)
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider()
                ForEach(rows) { row in
                    rowView(row)
                }
            }
            .frame(minWidth: minContentWidth, alignment: .leading)
        }
        .textSelection(.enabled)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sideHeader("OLD")
            Divider()
            sideHeader("NEW")
        }
        .frame(minWidth: minContentWidth, alignment: .leading)
        .font(.system(size: 11, design: .monospaced).weight(.semibold))
        .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.92))
        .background(Color.white.opacity(0.08))
    }

    private func sideHeader(_ title: String) -> some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: lineColumnWidth, alignment: .trailing)
                .foregroundStyle(Color(nsColor: SyntaxTheme.lineNumberColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)

            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row.kind {
        case .meta, .hunk:
            Text(row.oldText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minWidth: minContentWidth, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .foregroundStyle(metaForegroundColor(for: row.kind))
                .background(metaBackgroundColor(for: row.kind))
        default:
            HStack(spacing: 0) {
                sideRow(
                    line: row.oldLine,
                    text: row.oldText,
                    background: sideBackground(kind: row.kind, side: .old)
                )
                Divider()
                sideRow(
                    line: row.newLine,
                    text: row.newText,
                    background: sideBackground(kind: row.kind, side: .new)
                )
            }
            .frame(minWidth: minContentWidth, alignment: .leading)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.96))
        }
    }

    private enum DiffSide {
        case old
        case new
    }

    private func sideRow(line: Int?, text: String, background: Color) -> some View {
        HStack(spacing: 0) {
            Text(line.map(String.init) ?? "")
                .frame(width: lineColumnWidth, alignment: .trailing)
                .foregroundStyle(Color(nsColor: SyntaxTheme.lineNumberColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)

            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    private func metaForegroundColor(for kind: RowKind) -> Color {
        switch kind {
        case .hunk:
            Color.white.opacity(0.95)
        default:
            Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.8)
        }
    }

    private func metaBackgroundColor(for kind: RowKind) -> Color {
        switch kind {
        case .hunk:
            Color.blue.opacity(0.20)
        default:
            Color.white.opacity(0.05)
        }
    }

    private func sideBackground(kind: RowKind, side: DiffSide) -> Color {
        switch kind {
        case .removed:
            side == .old ? Color.red.opacity(0.22) : Color.clear
        case .added:
            side == .new ? Color.green.opacity(0.22) : Color.clear
        case .modified:
            side == .old ? Color.red.opacity(0.18) : Color.green.opacity(0.18)
        case .unchanged:
            Color.clear
        default:
            Color.clear
        }
    }

    private static func parse(diffText: String) -> [Row] {
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let rawLines = parseRaw(lines: lines)
        return convertRawToRows(rawLines)
    }

    private static func parseRaw(lines: [String]) -> [RawLine] {
        var raw: [RawLine] = []
        var oldLine: Int?
        var newLine: Int?

        for line in lines {
            if let (nextOld, nextNew) = parseHunkHeader(line) {
                oldLine = nextOld
                newLine = nextNew
                raw.append(RawLine(kind: .hunk, oldLine: nil, newLine: nil, text: line))
                continue
            }

            if line.hasPrefix("diff --git")
                || line.hasPrefix("index ")
                || line.hasPrefix("--- ")
                || line.hasPrefix("+++ ")
            {
                raw.append(RawLine(kind: .meta, oldLine: nil, newLine: nil, text: line))
                continue
            }

            if line.hasPrefix("-"), !line.hasPrefix("---") {
                raw.append(RawLine(kind: .removed, oldLine: oldLine, newLine: nil, text: String(line.dropFirst())))
                if let current = oldLine {
                    oldLine = current + 1
                }
                continue
            }

            if line.hasPrefix("+"), !line.hasPrefix("+++") {
                raw.append(RawLine(kind: .added, oldLine: nil, newLine: newLine, text: String(line.dropFirst())))
                if let current = newLine {
                    newLine = current + 1
                }
                continue
            }

            if line.hasPrefix(" ") {
                raw.append(
                    RawLine(
                        kind: .context,
                        oldLine: oldLine,
                        newLine: newLine,
                        text: String(line.dropFirst())
                    )
                )
                if let current = oldLine {
                    oldLine = current + 1
                }
                if let current = newLine {
                    newLine = current + 1
                }
                continue
            }

            raw.append(RawLine(kind: .meta, oldLine: nil, newLine: nil, text: line))
        }

        return raw
    }

    private static func convertRawToRows(_ rawLines: [RawLine]) -> [Row] {
        var rows: [Row] = []
        var pendingRemoved: [RawLine] = []
        var pendingAdded: [RawLine] = []

        func appendRow(
            kind: RowKind,
            oldLine: Int?,
            newLine: Int?,
            oldText: String,
            newText: String
        ) {
            rows.append(
                Row(
                    id: rows.count,
                    kind: kind,
                    oldLine: oldLine,
                    newLine: newLine,
                    oldText: oldText,
                    newText: newText
                )
            )
        }

        func flushPending() {
            guard !pendingRemoved.isEmpty || !pendingAdded.isEmpty else { return }
            let count = max(pendingRemoved.count, pendingAdded.count)
            for index in 0 ..< count {
                let removed = index < pendingRemoved.count ? pendingRemoved[index] : nil
                let added = index < pendingAdded.count ? pendingAdded[index] : nil
                if let removed, let added {
                    appendRow(
                        kind: .modified,
                        oldLine: removed.oldLine,
                        newLine: added.newLine,
                        oldText: removed.text,
                        newText: added.text
                    )
                } else if let removed {
                    appendRow(
                        kind: .removed,
                        oldLine: removed.oldLine,
                        newLine: nil,
                        oldText: removed.text,
                        newText: ""
                    )
                } else if let added {
                    appendRow(
                        kind: .added,
                        oldLine: nil,
                        newLine: added.newLine,
                        oldText: "",
                        newText: added.text
                    )
                }
            }
            pendingRemoved.removeAll(keepingCapacity: true)
            pendingAdded.removeAll(keepingCapacity: true)
        }

        for raw in rawLines {
            switch raw.kind {
            case .removed:
                pendingRemoved.append(raw)
            case .added:
                pendingAdded.append(raw)
            case .context:
                flushPending()
                appendRow(
                    kind: .unchanged,
                    oldLine: raw.oldLine,
                    newLine: raw.newLine,
                    oldText: raw.text,
                    newText: raw.text
                )
            case .meta:
                flushPending()
                appendRow(
                    kind: .meta,
                    oldLine: nil,
                    newLine: nil,
                    oldText: raw.text,
                    newText: ""
                )
            case .hunk:
                flushPending()
                appendRow(
                    kind: .hunk,
                    oldLine: nil,
                    newLine: nil,
                    oldText: raw.text,
                    newText: ""
                )
            }
        }
        flushPending()
        return rows
    }

    private static func parseHunkHeader(_ line: String) -> (Int, Int)? {
        guard let hunkRegex,
              let match = hunkRegex.firstMatch(
                  in: line,
                  options: [],
                  range: NSRange(location: 0, length: (line as NSString).length)
              )
        else { return nil }

        let oldRange = match.range(at: 1)
        let newRange = match.range(at: 2)
        guard oldRange.location != NSNotFound,
              newRange.location != NSNotFound
        else { return nil }

        let nsLine = line as NSString
        let oldText = nsLine.substring(with: oldRange)
        let newText = nsLine.substring(with: newRange)
        guard let old = Int(oldText), let new = Int(newText) else { return nil }
        return (old, new)
    }
}
