import Foundation

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var rootNodes: [TreeNode] = []
    @Published var selectedFile: TreeNode?
    @Published var fileContent: String?
    @Published var isBlameVisible: Bool = false
    @Published var blameLines: [BlameLine] = []
    @Published var highlightTokens: [TokenSpan] = []

    private var rootPath: String = ""

    /// プロジェクトを開く
    func openProject(path: String) async {
        rootPath = path
        do {
            _ = try openProject(rootPath: path)
            let fileNodes = try listDir(rootPath: path, dirPath: path)
            rootNodes = fileNodes.map { TreeNode(node: $0) }
        } catch {
            print("Failed to open project: \(error)")
            rootNodes = []
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
}
