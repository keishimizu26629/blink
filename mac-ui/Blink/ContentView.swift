import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ProjectViewModel()
    @State private var isFolderImporterPresented = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarActivityBar(
                    selectedMode: viewModel.sidebarMode,
                    onSelectMode: { mode in
                        viewModel.setSidebarMode(mode)
                    },
                    onRefreshSourceControl: {
                        viewModel.refreshGitStatus()
                    }
                )

                if viewModel.sidebarMode == .explorer {
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
                } else {
                    SourceControlView(
                        status: viewModel.gitStatusResult,
                        isLoading: viewModel.isGitStatusLoading,
                        errorMessage: viewModel.gitStatusErrorMessage,
                        formatPath: { path in
                            viewModel.displayPathForSidebar(path)
                        },
                        onSelectPath: { path in
                            viewModel.requestDiffForPath(path)
                        }
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            ZStack {
                Color(nsColor: SyntaxTheme.backgroundColor)
                    .ignoresSafeArea()

                if let content = viewModel.fileContent {
                    VStack(spacing: 0) {
                        EditorDisplayModeBar(
                            mode: viewModel.editorDisplayMode,
                            canShowDiff: viewModel.selectedFile != nil
                                || viewModel.selectedDiff != nil
                                || viewModel.isDiffLoading
                                || !(viewModel.diffErrorMessage?.isEmpty ?? true),
                            onSelectCode: { viewModel.switchToCodeMode() },
                            onSelectDiff: { viewModel.requestDiffForCurrentFile() }
                        )

                        if viewModel.editorDisplayMode == .diff {
                            DiffContentView(
                                diff: viewModel.selectedDiff,
                                isLoading: viewModel.isDiffLoading,
                                errorMessage: viewModel.diffErrorMessage,
                                tokens: viewModel.diffHighlightTokens
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            ToolbarItem(placement: .principal) {
                Text(viewModel.rootDirectoryName ?? "フォルダ未選択")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 520, alignment: .center)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
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
            WindowOpacityConfigurator(
                opacity: viewModel.windowOpacity,
                title: viewModel.rootDirectoryName
            )
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
        .overlay(alignment: .bottomLeading) {
            BranchStatusBadge(
                branchName: viewModel.activeBranchName,
                hasProject: viewModel.rootDirectoryName != nil
            )
            .padding(.leading, 10)
            .padding(.bottom, 8)
        }
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

private struct SidebarActivityBar: View {
    let selectedMode: ProjectViewModel.SidebarMode
    let onSelectMode: (ProjectViewModel.SidebarMode) -> Void
    let onRefreshSourceControl: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            modeButton(
                title: "Explorer",
                icon: "folder",
                mode: .explorer
            )
            modeButton(
                title: "Source Control",
                icon: "arrow.triangle.branch",
                mode: .sourceControl
            )

            Spacer(minLength: 0)

            if selectedMode == .sourceControl {
                Button {
                    onRefreshSourceControl()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help("Gitステータス再取得")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.12))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func modeButton(
        title: String,
        icon: String,
        mode: ProjectViewModel.SidebarMode
    ) -> some View {
        Button {
            onSelectMode(mode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 12, height: 12)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedMode == mode ? Color.accentColor.opacity(0.30) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct BranchStatusBadge: View {
    let branchName: String?
    let hasProject: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green)
            Text(labelText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.30))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var labelText: String {
        if let branchName, !branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return branchName
        }
        return hasProject ? "No Branch" : "No Project"
    }
}

private struct SourceControlView: View {
    let status: GitStatus?
    let isLoading: Bool
    let errorMessage: String?
    let formatPath: (String) -> String
    let onSelectPath: (String) -> Void

    var body: some View {
        List {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Gitステータスを読み込み中...")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if let status {
                section("Staged Changes", entries: status.staged, icon: "checkmark.circle.fill", tint: .green)
                section("Changes", entries: status.unstaged, icon: "pencil.circle.fill", tint: .orange)
                section("Untracked Files", entries: status.untracked, icon: "questionmark.circle.fill", tint: .blue)

                if status.staged.isEmpty, status.unstaged.isEmpty, status.untracked.isEmpty {
                    Text("変更はありません。")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Source Controlを選択するとGitステータスを表示します。")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
    }

    private func section(
        _ title: String,
        entries: [GitStatusEntry],
        icon: String,
        tint: Color
    ) -> some View {
        Section {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                Button {
                    onSelectPath(entry.path)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(tint)
                        Text(formatPath(entry.path))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Text(entry.status)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(title)
        }
    }
}

private struct EditorDisplayModeBar: View {
    let mode: ProjectViewModel.EditorDisplayMode
    let canShowDiff: Bool
    let onSelectCode: () -> Void
    let onSelectDiff: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            modeButton(
                title: "Code",
                icon: "doc.text",
                isSelected: mode == .code,
                action: onSelectCode
            )
            modeButton(
                title: "Diff",
                icon: "rectangle.split.2x1",
                isSelected: mode == .diff,
                action: onSelectDiff
            )
            .disabled(!canShowDiff)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.10))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func modeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor.opacity(0.30) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WindowOpacityConfigurator: NSViewRepresentable {
    let opacity: Double
    let title: String?

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyWindowChrome(opacity: opacity, title: title, to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            applyWindowChrome(opacity: opacity, title: title, to: nsView.window)
        }
    }

    private func applyWindowChrome(opacity: Double, title: String?, to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = CGFloat(opacity)
        window.titleVisibility = .hidden
        window.title = title ?? ""
    }
}

private struct DiffContentView: View {
    let diff: GitFileDiff?
    let isLoading: Bool
    let errorMessage: String?
    let tokens: [TokenSpan]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(panelTitle)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("差分を取得中...")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            } else if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
            } else if let diff {
                PRDiffTableView(diffText: diff.diffText, tokens: tokens)
            } else {
                Text("Diffを表示するにはファイルを選択してください。")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    private let tokensByLine: [Int: [TokenSpan]]
    private let lineColumnWidth: CGFloat = 56
    private let minContentWidth: CGFloat = 1100

    init(diffText: String, tokens: [TokenSpan]) {
        rows = Self.parse(diffText: diffText)
        tokensByLine = Self.groupTokensByLine(tokens)
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

            highlightedText(text, line: line)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    private func highlightedText(_ text: String, line: Int?) -> Text {
        guard let line,
              let lineTokens = tokensByLine[line],
              !lineTokens.isEmpty,
              !text.isEmpty
        else {
            return Text(verbatim: text)
                .foregroundColor(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.96))
        }

        let nsText = text as NSString
        let length = nsText.length
        if length == 0 {
            return Text("")
        }

        var cursor = 0
        var rendered = Text("")
        for token in lineTokens {
            let start = min(max(Int(token.startCol), 0), length)
            let end = min(max(Int(token.endCol), start), length)
            if cursor < start {
                rendered = rendered + Text(verbatim: nsText.substring(with: NSRange(location: cursor, length: start - cursor)))
                    .foregroundColor(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.96))
            }
            if start < end {
                rendered = rendered + Text(verbatim: nsText.substring(with: NSRange(location: start, length: end - start)))
                    .foregroundColor(Color(nsColor: SyntaxTheme.color(for: token.tokenType)))
            }
            cursor = max(cursor, end)
        }

        if cursor < length {
            rendered = rendered + Text(verbatim: nsText.substring(with: NSRange(location: cursor, length: length - cursor)))
                .foregroundColor(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.96))
        }

        return rendered
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

    private static func groupTokensByLine(_ tokens: [TokenSpan]) -> [Int: [TokenSpan]] {
        var grouped: [Int: [TokenSpan]] = [:]
        for token in tokens {
            let key = Int(token.line)
            grouped[key, default: []].append(token)
        }
        for (line, lineTokens) in grouped {
            grouped[line] = lineTokens.sorted { lhs, rhs in
                if lhs.startCol == rhs.startCol {
                    return lhs.endCol < rhs.endCol
                }
                return lhs.startCol < rhs.startCol
            }
        }
        return grouped
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
