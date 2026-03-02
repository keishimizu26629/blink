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
        case added
        case removed
        case context
        case hunk
        case meta
    }

    private struct Row: Identifiable {
        let id: Int
        let oldLine: Int?
        let newLine: Int?
        let kind: RowKind
        let text: String
    }

    private static let hunkRegex = try? NSRegularExpression(
        pattern: #"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
    )

    private let rows: [Row]
    private let lineColumnWidth: CGFloat = 56
    private let markerColumnWidth: CGFloat = 22

    init(diffText: String) {
        rows = Self.parse(diffText: diffText)
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider()
                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        lineCell(lineNumberText(row.oldLine))
                        lineCell(lineNumberText(row.newLine))
                        markerCell(markerText(for: row.kind))
                        Text(codeText(for: row))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(foregroundColor(for: row.kind))
                    .background(backgroundColor(for: row.kind))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            lineCell("old")
            lineCell("new")
            markerCell("")
            Text("code")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .font(.system(size: 11, design: .monospaced).weight(.semibold))
        .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.9))
        .background(Color.white.opacity(0.06))
    }

    private func lineCell(_ text: String) -> some View {
        Text(text)
            .frame(width: lineColumnWidth, alignment: .trailing)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color(nsColor: SyntaxTheme.lineNumberColor))
    }

    private func markerCell(_ text: String) -> some View {
        Text(text)
            .frame(width: markerColumnWidth, alignment: .center)
            .padding(.vertical, 2)
    }

    private func lineNumberText(_ value: Int?) -> String {
        if let value {
            return "\(value)"
        }
        return ""
    }

    private func markerText(for kind: RowKind) -> String {
        switch kind {
        case .added:
            return "+"
        case .removed:
            return "-"
        case .context:
            return " "
        case .hunk:
            return "@"
        case .meta:
            return " "
        }
    }

    private func codeText(for row: Row) -> String {
        switch row.kind {
        case .added:
            return "+ " + row.text
        case .removed:
            return "- " + row.text
        case .context:
            return "  " + row.text
        case .hunk:
            return row.text
        case .meta:
            return row.text
        }
    }

    private func foregroundColor(for kind: RowKind) -> Color {
        switch kind {
        case .added:
            return Color.white.opacity(0.95)
        case .removed:
            return Color.white.opacity(0.95)
        case .context:
            return Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.9)
        case .hunk:
            return Color.white.opacity(0.95)
        case .meta:
            return Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.75)
        }
    }

    private func backgroundColor(for kind: RowKind) -> Color {
        switch kind {
        case .added:
            return Color.green.opacity(0.20)
        case .removed:
            return Color.red.opacity(0.20)
        case .context:
            return Color.clear
        case .hunk:
            return Color.blue.opacity(0.25)
        case .meta:
            return Color.white.opacity(0.04)
        }
    }

    private static func parse(diffText: String) -> [Row] {
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var rows: [Row] = []
        var oldLine: Int?
        var newLine: Int?

        for (index, line) in lines.enumerated() {
            if let (nextOld, nextNew) = parseHunkHeader(line) {
                oldLine = nextOld
                newLine = nextNew
                rows.append(Row(id: index, oldLine: nil, newLine: nil, kind: .hunk, text: line))
                continue
            }

            if line.hasPrefix("diff --git")
                || line.hasPrefix("index ")
                || line.hasPrefix("--- ")
                || line.hasPrefix("+++ ")
            {
                rows.append(Row(id: index, oldLine: nil, newLine: nil, kind: .meta, text: line))
                continue
            }

            if line.hasPrefix("+"), !line.hasPrefix("+++") {
                rows.append(Row(id: index, oldLine: nil, newLine: newLine, kind: .added, text: String(line.dropFirst())))
                if let current = newLine {
                    newLine = current + 1
                }
                continue
            }

            if line.hasPrefix("-"), !line.hasPrefix("---") {
                rows.append(Row(id: index, oldLine: oldLine, newLine: nil, kind: .removed, text: String(line.dropFirst())))
                if let current = oldLine {
                    oldLine = current + 1
                }
                continue
            }

            if line.hasPrefix(" ") {
                rows.append(Row(id: index, oldLine: oldLine, newLine: newLine, kind: .context, text: String(line.dropFirst())))
                if let current = oldLine {
                    oldLine = current + 1
                }
                if let current = newLine {
                    newLine = current + 1
                }
                continue
            }

            rows.append(Row(id: index, oldLine: nil, newLine: nil, kind: .meta, text: line))
        }

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
