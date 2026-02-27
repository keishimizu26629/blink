import SwiftUI

// MARK: - TreeNode (UniFFI FileNode の UI 用ラッパー)

/// UniFFI 生成の FileNode にツリー UI 管理用プロパティを追加
struct TreeNode: Identifiable, Equatable {
    let node: FileNode
    var children: [TreeNode]?
    var isExpanded: Bool = false

    var id: String {
        node.id
    }

    var path: String {
        node.path
    }

    var name: String {
        node.name
    }

    var kind: NodeKind {
        node.kind
    }

    static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs.id == rhs.id
            && lhs.isExpanded == rhs.isExpanded
            && lhs.children == rhs.children
    }
}

// MARK: - ProjectTreeView

struct ProjectTreeView: View {
    let nodes: [TreeNode]
    let selectedFileId: String?
    let onSelectFile: (TreeNode) -> Void
    let onToggleDir: (TreeNode) -> Void

    var body: some View {
        List {
            ForEach(nodes) { node in
                FileNodeRow(
                    node: node,
                    selectedFileId: selectedFileId,
                    onSelectFile: onSelectFile,
                    onToggleDir: onToggleDir
                )
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - FileNodeRow

private struct FileNodeRow: View {
    let node: TreeNode
    let selectedFileId: String?
    let onSelectFile: (TreeNode) -> Void
    let onToggleDir: (TreeNode) -> Void

    var body: some View {
        switch node.kind {
        case .dir:
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { _ in onToggleDir(node) }
                )
            ) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileNodeRow(
                            node: child,
                            selectedFileId: selectedFileId,
                            onSelectFile: onSelectFile,
                            onToggleDir: onToggleDir
                        )
                    }
                }
            } label: {
                Label(node.name, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
            }

        case .file:
            Button(action: { onSelectFile(node) }) {
                Label(node.name, systemImage: fileIcon(for: node.name))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 1)
            .background(
                node.id == selectedFileId
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(4)
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "rs": return "doc.text"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json", "yaml", "yml", "toml": return "doc.text"
        case "md": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default: return "doc"
        }
    }
}
