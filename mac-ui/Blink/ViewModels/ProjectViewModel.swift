import Foundation

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var rootNodes: [FileNode] = []
    @Published var selectedFile: FileNode?
    @Published var fileContent: String?
    @Published var isBlameVisible: Bool = false
    @Published var blameLines: [BlameLineInfo] = []

    /// プロジェクトを開く
    func openProject(path: String) async {
        // TODO: Replace with UniFFI call — open_project(root_path:) + list_dir(handle:, dir_path:)
        rootNodes = Self.mockRootNodes(rootPath: path)
    }

    /// ファイルを選択して内容を読み込む
    func selectFile(node: FileNode) async {
        guard node.kind == .file else { return }
        selectedFile = node

        // TODO: Replace with UniFFI call — read_file(path:)
        fileContent = Self.mockFileContent(for: node.path)

        // TODO: Replace with UniFFI call — blame_range(path:, start_line:, end_line:)
        blameLines = Self.mockBlameLines(for: node.path)
    }

    /// ディレクトリの展開/折りたたみ
    func toggleDir(node: FileNode) async {
        guard node.kind == .dir else { return }

        // ツリー内のノードを再帰的に探して更新
        rootNodes = Self.toggleNodeInTree(nodes: rootNodes, targetId: node.id)
    }

    // MARK: - Tree Update

    private static func toggleNodeInTree(nodes: [FileNode], targetId: String) -> [FileNode] {
        nodes.map { node in
            if node.id == targetId {
                var updated = node
                updated.isExpanded.toggle()
                if updated.isExpanded, updated.children == nil {
                    // TODO: Replace with UniFFI call — list_dir(handle:, dir_path:)
                    updated.children = mockChildren(for: node.path)
                }
                return updated
            } else if node.kind == .dir, let children = node.children {
                var updated = node
                updated.children = toggleNodeInTree(nodes: children, targetId: targetId)
                return updated
            }
            return node
        }
    }

    // MARK: - Mock Data

    static func mockRootNodes(rootPath: String) -> [FileNode] {
        [
            FileNode(
                id: "1",
                path: "\(rootPath)/src",
                name: "src",
                kind: .dir,
                children: nil,
            ),
            FileNode(
                id: "2",
                path: "\(rootPath)/Cargo.toml",
                name: "Cargo.toml",
                kind: .file,
                children: nil,
            ),
            FileNode(
                id: "3",
                path: "\(rootPath)/README.md",
                name: "README.md",
                kind: .file,
                children: nil,
            ),
            FileNode(
                id: "4",
                path: "\(rootPath)/.gitignore",
                name: ".gitignore",
                kind: .file,
                children: nil,
            ),
        ]
    }

    static func mockChildren(for dirPath: String) -> [FileNode] {
        [
            FileNode(
                id: "\(dirPath)/main.rs",
                path: "\(dirPath)/main.rs",
                name: "main.rs",
                kind: .file,
                children: nil,
            ),
            FileNode(
                id: "\(dirPath)/lib.rs",
                path: "\(dirPath)/lib.rs",
                name: "lib.rs",
                kind: .file,
                children: nil,
            ),
            FileNode(
                id: "\(dirPath)/utils",
                path: "\(dirPath)/utils",
                name: "utils",
                kind: .dir,
                children: nil,
            ),
        ]
    }

    static func mockBlameLines(for _: String) -> [BlameLineInfo] {
        // モックデータ: 実際にはUniFFI経由でblame_range()を呼ぶ
        (1 ... 10).map { line in
            BlameLineInfo(
                line: UInt32(line),
                author: line <= 5 ? "Alice" : "Bob",
                authorTime: line <= 5 ? 1_700_000_000 : 1_700_100_000,
                summary: line <= 5 ? "initial commit" : "fix: update logic",
                commit: line <= 5 ? "abcdef1" : "1234567",
            )
        }
    }

    static func mockFileContent(for path: String) -> String {
        let name = (path as NSString).lastPathComponent
        switch name {
        case "main.rs":
            return """
            use std::env;

            fn main() {
                let args: Vec<String> = env::args().collect();
                println!("Hello, Blink!");

                if args.len() > 1 {
                    println!("Opening: {}", args[1]);
                }
            }
            """
        case "lib.rs":
            return """
            pub mod utils;

            /// Core library for Blink
            pub fn version() -> &'static str {
                env!("CARGO_PKG_VERSION")
            }

            #[cfg(test)]
            mod tests {
                use super::*;

                #[test]
                fn test_version() {
                    assert!(!version().is_empty());
                }
            }
            """
        case "Cargo.toml":
            return """
            [package]
            name = "blink"
            version = "0.1.0"
            edition = "2021"

            [dependencies]
            ignore = "0.4"
            notify = "6.1"
            tree-sitter = "0.22"
            """
        case "README.md":
            return """
            # Blink

            Mac用超軽量コードビューア

            ## Features
            - プロジェクトツリー表示（.gitignore対応）
            - シンタックスハイライト（tree-sitter）
            - Git Blame表示
            """
        case ".gitignore":
            return """
            /target
            *.o
            *.d
            .DS_Store
            """
        default:
            return "// \(name)\n"
        }
    }
}
