import Foundation

enum BringToFrontShortcut: String, CaseIterable {
    case shiftOptionSpace
    case commandShiftSpace
    case commandOptionSpace
    case controlOptionSpace

    var displayName: String {
        switch self {
        case .shiftOptionSpace:
            "Shift + Option + Space"
        case .commandShiftSpace:
            "Command + Shift + Space"
        case .commandOptionSpace:
            "Command + Option + Space"
        case .controlOptionSpace:
            "Control + Option + Space"
        }
    }
}

@MainActor
final class ProjectViewModel: ObservableObject {
    enum SidebarMode {
        case explorer
        case sourceControl
    }

    enum EditorDisplayMode {
        case code
        case diff
    }

    private enum SettingsKeys {
        static let windowOpacity = "blink.window.opacity"
        static let legacyEditorOpacity = "blink.editor.opacity"
        static let bringToFrontHotkeyEnabled = "blink.window.bringToFront.hotkey.enabled"
        static let bringToFrontHotkeyShortcut = "blink.window.bringToFront.hotkey.shortcut"
    }

    static let bringToFrontSettingsDidChangeNotification = Notification.Name(
        "blink.window.bringToFront.settingsDidChange"
    )

    @Published var rootNodes: [TreeNode] = []
    @Published var selectedFile: TreeNode?
    @Published var fileContent: String?
    @Published var highlightTokens: [TokenSpan] = []
    @Published var diffHighlightTokens: [TokenSpan] = []
    @Published var selectedDiff: GitFileDiff?
    @Published var isDiffLoading: Bool = false
    @Published var diffErrorMessage: String?
    @Published var editorDisplayMode: EditorDisplayMode = .code
    @Published var sidebarMode: SidebarMode = .explorer
    @Published var gitStatusResult: GitStatus?
    @Published var isGitStatusLoading: Bool = false
    @Published var gitStatusErrorMessage: String?
    @Published var activeBranchName: String?
    @Published var errorMessage: String?
    @Published var rootDirectoryName: String?
    @Published var windowOpacity: Double
    @Published var isBringToFrontHotkeyEnabled: Bool
    @Published var bringToFrontShortcut: BringToFrontShortcut

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

        let savedShortcut = defaults.string(forKey: SettingsKeys.bringToFrontHotkeyShortcut)
        bringToFrontShortcut = BringToFrontShortcut(rawValue: savedShortcut ?? "")
            ?? .shiftOptionSpace

        if defaults.object(forKey: SettingsKeys.bringToFrontHotkeyEnabled) == nil {
            isBringToFrontHotkeyEnabled = true
        } else {
            isBringToFrontHotkeyEnabled = defaults.bool(forKey: SettingsKeys.bringToFrontHotkeyEnabled)
        }
    }

    func updateWindowOpacity(_ value: Double) {
        let clampedValue = Self.clampOpacity(value)
        if abs(windowOpacity - clampedValue) < 0.000_1 {
            return
        }
        windowOpacity = clampedValue
        UserDefaults.standard.set(clampedValue, forKey: SettingsKeys.windowOpacity)
    }

    func updateBringToFrontHotkeyEnabled(_ value: Bool) {
        if isBringToFrontHotkeyEnabled == value {
            return
        }
        isBringToFrontHotkeyEnabled = value
        UserDefaults.standard.set(value, forKey: SettingsKeys.bringToFrontHotkeyEnabled)
        notifyBringToFrontSettingsDidChange()
    }

    func toggleBringToFrontHotkeyEnabled() {
        updateBringToFrontHotkeyEnabled(!isBringToFrontHotkeyEnabled)
    }

    func updateBringToFrontShortcut(_ shortcut: BringToFrontShortcut) {
        if bringToFrontShortcut == shortcut {
            return
        }
        bringToFrontShortcut = shortcut
        UserDefaults.standard.set(shortcut.rawValue, forKey: SettingsKeys.bringToFrontHotkeyShortcut)
        notifyBringToFrontSettingsDidChange()
    }

    func openProject(url: URL) async {
        updateSecurityScope(for: url)
        await openProject(path: url.path)
    }

    func openProject(path: String) async {
        rootPath = path
        rootDirectoryName = displayRootDirectoryName(from: path)
        visibleRangeFetchTask?.cancel()
        do {
            _ = try Blink.openProject(rootPath: path)
            let fileNodes = try listDir(rootPath: path, dirPath: path)
            rootNodes = fileNodes.map { TreeNode(node: $0) }
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            diffHighlightTokens = []
            selectedDiff = nil
            isDiffLoading = false
            diffErrorMessage = nil
            editorDisplayMode = .code
            gitStatusResult = nil
            isGitStatusLoading = false
            gitStatusErrorMessage = nil
            currentVisibleRange = nil
            totalLineCount = 0
            errorMessage = nil
            activeBranchName = nil
            refreshActiveBranch()
            if sidebarMode == .sourceControl {
                refreshGitStatus()
            }
        } catch {
            rootNodes = []
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            diffHighlightTokens = []
            selectedDiff = nil
            isDiffLoading = false
            diffErrorMessage = nil
            editorDisplayMode = .code
            gitStatusResult = nil
            isGitStatusLoading = false
            gitStatusErrorMessage = nil
            currentVisibleRange = nil
            totalLineCount = 0
            activeBranchName = nil
            rootDirectoryName = nil
            errorMessage = "フォルダを開けませんでした: \(error.localizedDescription)"
        }
    }

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
            diffHighlightTokens = []
            closeDiffPanel()

            let initialEndLine = min(totalLineCount, 220)
            if initialEndLine >= 1 {
                updateVisibleRange(startLine: 1, endLine: initialEndLine)
            }
            refreshDiffHighlightTokens(path: node.path, totalLines: totalLineCount)
        } catch {
            fileContent = nil
            highlightTokens = []
            diffHighlightTokens = []
            selectedDiff = nil
            isDiffLoading = false
            diffErrorMessage = nil
            editorDisplayMode = .code
            currentVisibleRange = nil
            totalLineCount = 0
        }
    }

    func selectFile(path: String) async {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let existing = findFileNode(in: rootNodes, path: path) {
            await selectFile(node: existing)
            return
        }

        let fallbackNode = TreeNode(
            node: FileNode(
                id: "git:\(path)",
                path: path,
                name: (path as NSString).lastPathComponent,
                kind: .file
            )
        )
        await selectFile(node: fallbackNode)
    }

    func toggleDir(node: TreeNode) async {
        guard node.kind == .dir else { return }
        rootNodes = toggleNodeInTree(nodes: rootNodes, targetId: node.id)
    }

    func setSidebarMode(_ mode: SidebarMode) {
        if sidebarMode == mode {
            if mode == .sourceControl {
                refreshGitStatus()
            }
            return
        }
        sidebarMode = mode
        if mode == .sourceControl {
            refreshGitStatus()
        }
    }

    func refreshGitStatus() {
        guard !rootPath.isEmpty else {
            gitStatusResult = nil
            gitStatusErrorMessage = "プロジェクトを開いてからGitステータスを表示してください。"
            activeBranchName = nil
            return
        }
        isGitStatusLoading = true
        gitStatusErrorMessage = nil
        refreshActiveBranch()

        let currentRootPath = rootPath
        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Result { try gitStatus(rootPath: currentRootPath) }
            }.value

            guard currentRootPath == rootPath else { return }
            switch result {
            case let .success(status):
                gitStatusResult = filterGitStatus(status, rootPath: currentRootPath)
                gitStatusErrorMessage = nil
            case let .failure(error):
                gitStatusResult = nil
                gitStatusErrorMessage = "Gitステータス取得に失敗しました: \(error.localizedDescription)"
            }
            isGitStatusLoading = false
        }
    }

    func refreshActiveBranch() {
        guard !rootPath.isEmpty else {
            activeBranchName = nil
            return
        }

        let currentRootPath = rootPath
        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Result { try gitCurrentBranch(rootPath: currentRootPath) }
            }.value

            guard currentRootPath == rootPath else { return }
            switch result {
            case let .success(branch):
                let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
                activeBranchName = trimmed.isEmpty ? nil : trimmed
            case .failure:
                activeBranchName = nil
            }
        }
    }

    func displayPathForSidebar(_ absolutePath: String) -> String {
        guard !rootPath.isEmpty else { return absolutePath }
        let normalizedRoot = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if absolutePath.hasPrefix(normalizedRoot) {
            return String(absolutePath.dropFirst(normalizedRoot.count))
        }
        return absolutePath
    }

    func switchToCodeMode() {
        editorDisplayMode = .code
    }

    func requestDiffForCurrentFile() {
        guard let path = selectedFile?.path else {
            diffErrorMessage = "Diffを表示するファイルを選択してください。"
            editorDisplayMode = .diff
            return
        }
        Task {
            await loadDiff(for: path)
            editorDisplayMode = .diff
        }
    }

    func requestDiffForPath(_ path: String) {
        Task {
            await selectFile(path: path)
            await loadDiff(for: path)
            editorDisplayMode = .diff
        }
    }

    func closeDiffPanel() {
        editorDisplayMode = .code
        isDiffLoading = false
        diffErrorMessage = nil
        selectedDiff = nil
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

    private func loadDiff(for path: String) async {
        isDiffLoading = true
        diffErrorMessage = nil
        selectedDiff = nil

        let result = await Task.detached(priority: .userInitiated) {
            Result { try gitFileDiff(path: path) }
        }.value

        guard selectedFile?.path == path else {
            isDiffLoading = false
            return
        }

        switch result {
        case let .success(diff):
            selectedDiff = diff
            diffErrorMessage = nil
        case let .failure(error):
            selectedDiff = nil
            diffErrorMessage = "差分取得に失敗しました: \(error.localizedDescription)"
        }
        isDiffLoading = false
    }

    private func refreshDiffHighlightTokens(path: String, totalLines: UInt32) {
        guard totalLines > 0 else {
            diffHighlightTokens = []
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let currentPath = path
            let tokens = await Task.detached(priority: .userInitiated) {
                (try? highlightRange(path: currentPath, startLine: 1, endLine: totalLines)) ?? []
            }.value
            guard selectedFile?.path == currentPath else { return }
            diffHighlightTokens = tokens
        }
    }

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

    private func notifyBringToFrontSettingsDidChange() {
        NotificationCenter.default.post(name: Self.bringToFrontSettingsDidChangeNotification, object: nil)
    }

    private func fetchVisibleRangeIfNeeded(_ range: ClosedRange<UInt32>, forceRefresh: Bool) {
        guard let path = selectedFile?.path else { return }
        if !forceRefresh, currentVisibleRange == range {
            return
        }

        currentVisibleRange = range
        visibleRangeFetchTask?.cancel()

        visibleRangeFetchTask = Task { [weak self] in
            guard let self else { return }
            let startLine = range.lowerBound
            let endLine = range.upperBound

            let tokens = await Task.detached(priority: .userInitiated) {
                (try? highlightRange(path: path, startLine: startLine, endLine: endLine)) ?? []
            }.value

            guard !Task.isCancelled, selectedFile?.path == path else { return }
            highlightTokens = tokens
        }
    }

    private func findFileNode(in nodes: [TreeNode], path: String) -> TreeNode? {
        for node in nodes {
            if node.kind == .file, node.path == path {
                return node
            }
            if let children = node.children,
               let found = findFileNode(in: children, path: path)
            {
                return found
            }
        }
        return nil
    }

    private func filterGitStatus(_ status: GitStatus, rootPath: String) -> GitStatus {
        let normalizedRoot = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let inRoot: (GitStatusEntry) -> Bool = { entry in
            entry.path == rootPath || entry.path.hasPrefix(normalizedRoot)
        }
        return GitStatus(
            staged: status.staged.filter(inRoot),
            unstaged: status.unstaged.filter(inRoot),
            untracked: status.untracked.filter(inRoot)
        )
    }

    private func displayRootDirectoryName(from path: String) -> String {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else { return "" }
        let lastComponent = (normalizedPath as NSString).lastPathComponent
        return lastComponent.isEmpty ? normalizedPath : lastComponent
    }
}
