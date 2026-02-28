import Foundation

@MainActor
final class ProjectViewModel: ObservableObject {
    private enum SettingsKeys {
        static let windowOpacity = "blink.window.opacity"
        static let legacyEditorOpacity = "blink.editor.opacity"
    }

    @Published var rootNodes: [TreeNode] = []
    @Published var selectedFile: TreeNode?
    @Published var fileContent: String?
    @Published var isBlameVisible: Bool = false
    @Published var blameLines: [BlameLine] = []
    @Published var highlightTokens: [TokenSpan] = []
    @Published var selectedBlameDiff: BlameDiff?
    @Published var isDiffPanelVisible: Bool = false
    @Published var isDiffLoading: Bool = false
    @Published var diffErrorMessage: String?
    @Published var errorMessage: String?
    @Published var windowOpacity: Double

    private var rootPath: String = ""
    private var securityScopedDirectoryURL: URL?
    private var hasActiveSecurityScope = false
    private var totalLineCount: UInt32 = 0
    private var currentVisibleRange: ClosedRange<UInt32>?
    private var visibleRangeFetchTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let savedOpacity = (defaults.object(forKey: SettingsKeys.windowOpacity) as? Double)
            ?? (defaults.object(forKey: SettingsKeys.legacyEditorOpacity) as? Double)
            ?? 1.0
        windowOpacity = Self.clampOpacity(savedOpacity)
    }

    func updateWindowOpacity(_ value: Double) {
        let clampedValue = Self.clampOpacity(value)
        if abs(windowOpacity - clampedValue) < 0.000_1 {
            return
        }
        windowOpacity = clampedValue
        UserDefaults.standard.set(clampedValue, forKey: SettingsKeys.windowOpacity)
    }

    /// Security-scoped URL からプロジェクトを開く
    func openProject(url: URL) async {
        updateSecurityScope(for: url)
        await openProject(path: url.path)
    }

    /// プロジェクトを開く
    func openProject(path: String) async {
        rootPath = path
        visibleRangeFetchTask?.cancel()
        do {
            _ = try Blink.openProject(rootPath: path)
            let fileNodes = try listDir(rootPath: path, dirPath: path)
            rootNodes = fileNodes.map { TreeNode(node: $0) }
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            blameLines = []
            selectedBlameDiff = nil
            isDiffPanelVisible = false
            isDiffLoading = false
            diffErrorMessage = nil
            currentVisibleRange = nil
            totalLineCount = 0
            errorMessage = nil
        } catch {
            print("Failed to open project: \(error)")
            rootNodes = []
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            blameLines = []
            selectedBlameDiff = nil
            isDiffPanelVisible = false
            isDiffLoading = false
            diffErrorMessage = nil
            currentVisibleRange = nil
            totalLineCount = 0
            errorMessage = "フォルダを開けませんでした: \(error.localizedDescription)"
        }
    }

    /// ファイルを選択して内容を読み込む
    func selectFile(node: TreeNode) async {
        guard node.kind == .file else { return }
        selectedFile = node

        do {
            let content = try readFile(path: node.path)
            fileContent = content
            totalLineCount = UInt32(content.components(separatedBy: "\n").count)
            visibleRangeFetchTask?.cancel()
            currentVisibleRange = nil
            highlightTokens = []
            blameLines = []
            closeDiffPanel()

            let initialEndLine = min(totalLineCount, 220)
            if initialEndLine >= 1 {
                updateVisibleRange(startLine: 1, endLine: initialEndLine)
            }
        } catch {
            print("Failed to read file: \(error)")
            fileContent = nil
            highlightTokens = []
            blameLines = []
            selectedBlameDiff = nil
            isDiffPanelVisible = false
            isDiffLoading = false
            diffErrorMessage = nil
            currentVisibleRange = nil
            totalLineCount = 0
        }
    }

    /// ディレクトリの展開/折りたたみ
    func toggleDir(node: TreeNode) async {
        guard node.kind == .dir else { return }
        rootNodes = toggleNodeInTree(nodes: rootNodes, targetId: node.id)
    }

    func toggleBlameVisibility() {
        isBlameVisible.toggle()
        if isBlameVisible {
            if let visible = currentVisibleRange {
                fetchVisibleRangeIfNeeded(visible, forceRefresh: true)
            }
        } else {
            blameLines = []
        }
    }

    func updateVisibleRange(startLine: UInt32, endLine: UInt32) {
        guard fileContent != nil,
              selectedFile?.kind == .file,
              totalLineCount > 0
        else { return }

        let normalizedStart = min(max(startLine, 1), totalLineCount)
        let normalizedEnd = max(normalizedStart, min(endLine, totalLineCount))

        let preload: UInt32 = 80
        let fetchStart = max(1, normalizedStart > preload ? normalizedStart - preload : 1)
        let fetchEnd: UInt32 = if normalizedEnd > UInt32.max - preload {
            totalLineCount
        } else {
            min(totalLineCount, normalizedEnd + preload)
        }
        let targetRange = fetchStart ... fetchEnd

        fetchVisibleRangeIfNeeded(targetRange, forceRefresh: false)
    }

    func closeDiffPanel() {
        isDiffPanelVisible = false
        isDiffLoading = false
        diffErrorMessage = nil
        selectedBlameDiff = nil
    }

    func selectBlameLine(_ line: BlameLine) async {
        guard let selectedFile else { return }
        let filePath = selectedFile.path

        isDiffPanelVisible = true
        isDiffLoading = true
        diffErrorMessage = nil

        let result = await Task.detached(priority: .userInitiated) {
            Result { try blameCommitDiff(path: filePath, commit: line.commit) }
        }.value

        guard selectedFile.path == filePath else {
            isDiffLoading = false
            return
        }

        switch result {
        case let .success(diff):
            selectedBlameDiff = diff
        case let .failure(error):
            selectedBlameDiff = nil
            diffErrorMessage = "差分取得に失敗しました: \(error.localizedDescription)"
        }
        isDiffLoading = false
    }

    // MARK: - Tree Update

    private func toggleNodeInTree(nodes: [TreeNode], targetId: String) -> [TreeNode] {
        nodes.map { treeNode in
            if treeNode.id == targetId {
                var updated = treeNode
                updated.isExpanded.toggle()
                if updated.isExpanded, updated.children == nil {
                    do {
                        let fileNodes = try listDir(rootPath: rootPath, dirPath: treeNode.path)
                        updated.children = fileNodes.map { TreeNode(node: $0) }
                    } catch {
                        print("Failed to list dir: \(error)")
                        updated.children = []
                    }
                }
                return updated
            } else if treeNode.kind == .dir, let children = treeNode.children {
                var updated = treeNode
                updated.children = toggleNodeInTree(nodes: children, targetId: targetId)
                return updated
            }
            return treeNode
        }
    }

    private func updateSecurityScope(for selectedURL: URL) {
        let directoryPath = selectedURL.path
        if securityScopedDirectoryURL?.path == directoryPath {
            return
        }

        if hasActiveSecurityScope, let currentURL = securityScopedDirectoryURL {
            currentURL.stopAccessingSecurityScopedResource()
        }

        hasActiveSecurityScope = selectedURL.startAccessingSecurityScopedResource()
        securityScopedDirectoryURL = selectedURL
    }

    private static func clampOpacity(_ value: Double) -> Double {
        min(max(value, 0.6), 1.0)
    }

    private func fetchVisibleRangeIfNeeded(_ range: ClosedRange<UInt32>, forceRefresh: Bool) {
        guard let path = selectedFile?.path else { return }
        if !forceRefresh, currentVisibleRange == range {
            return
        }

        currentVisibleRange = range
        visibleRangeFetchTask?.cancel()

        let shouldFetchBlame = isBlameVisible
        visibleRangeFetchTask = Task { [weak self] in
            guard let self else { return }
            let startLine = range.lowerBound
            let endLine = range.upperBound

            let fetched = await Task.detached(priority: .userInitiated) {
                let tokens = (try? highlightRange(
                    path: path,
                    startLine: startLine,
                    endLine: endLine
                )) ?? []
                let blame = shouldFetchBlame ? ((try? blameRange(
                    path: path,
                    startLine: startLine,
                    endLine: endLine
                )) ?? []) : []
                return (tokens, blame)
            }.value

            guard !Task.isCancelled, selectedFile?.path == path else { return }
            highlightTokens = fetched.0
            blameLines = fetched.1
        }
    }
}
