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
    @Published var errorMessage: String?
    @Published var windowOpacity: Double

    private var rootPath: String = ""
    private var securityScopedDirectoryURL: URL?
    private var hasActiveSecurityScope = false

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
        do {
            _ = try Blink.openProject(rootPath: path)
            let fileNodes = try listDir(rootPath: path, dirPath: path)
            rootNodes = fileNodes.map { TreeNode(node: $0) }
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            blameLines = []
            errorMessage = nil
        } catch {
            print("Failed to open project: \(error)")
            rootNodes = []
            selectedFile = nil
            fileContent = nil
            highlightTokens = []
            blameLines = []
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

            let lineCount = UInt32(content.components(separatedBy: "\n").count)

            // ハイライト取得（失敗しても空配列）
            highlightTokens = (try? highlightRange(
                path: node.path,
                startLine: 1,
                endLine: lineCount
            )) ?? []

            // Blame取得（非Gitリポジトリでは空配列）
            blameLines = (try? blameRange(
                path: node.path,
                startLine: 1,
                endLine: lineCount
            )) ?? []
        } catch {
            print("Failed to read file: \(error)")
            fileContent = nil
            highlightTokens = []
            blameLines = []
        }
    }

    /// ディレクトリの展開/折りたたみ
    func toggleDir(node: TreeNode) async {
        guard node.kind == .dir else { return }
        rootNodes = toggleNodeInTree(nodes: rootNodes, targetId: node.id)
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
}
