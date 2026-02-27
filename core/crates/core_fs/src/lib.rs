use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::Path;

use core_types::{FileNode, NodeKind};
use ignore::WalkBuilder;

/// パス文字列からIDを生成（ハッシュの先頭8文字）
fn path_to_id(path: &str) -> String {
    let mut hasher = DefaultHasher::new();
    path.hash(&mut hasher);
    format!("{:016x}", hasher.finish())[..8].to_string()
}

/// 指定ディレクトリ直下のファイル・ディレクトリ一覧を返す。
/// .gitignore に記載されたパスは除外される。
///
/// # Arguments
/// * `root_path` - プロジェクトルート（.gitignore 探索の起点）
/// * `dir_path` - 列挙対象ディレクトリの絶対パス
pub fn list_dir(root_path: &str, dir_path: &str) -> Result<Vec<FileNode>, String> {
    let root = Path::new(root_path);
    let dir = Path::new(dir_path);

    if !root.exists() {
        return Err(format!("root_path が存在しません: {root_path}"));
    }
    if !dir.exists() {
        return Err(format!("dir_path が存在しません: {dir_path}"));
    }
    if !dir.is_dir() {
        return Err(format!("dir_path がディレクトリではありません: {dir_path}"));
    }

    let walker = WalkBuilder::new(dir)
        .max_depth(Some(1))
        .hidden(true) // ドットファイルを除外
        .git_ignore(true)
        .git_global(false)
        .git_exclude(true)
        .sort_by_file_path(|a, b| a.cmp(b))
        .build();

    let mut nodes: Vec<FileNode> = Vec::new();

    for entry in walker {
        let entry = entry.map_err(|e| format!("ディレクトリ読み取りエラー: {e}"))?;
        let entry_path = entry.path();

        // ルートエントリ自身はスキップ
        if entry_path == dir {
            continue;
        }

        let name = entry_path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        let path_str = entry_path.to_string_lossy().to_string();
        let kind = if entry_path.is_dir() {
            NodeKind::Dir
        } else {
            NodeKind::File
        };

        nodes.push(FileNode {
            id: path_to_id(&path_str),
            path: path_str,
            name,
            kind,
            children: None,
        });
    }

    // ソート: Dir優先 → 名前順（case insensitive）
    nodes.sort_by(|a, b| {
        let dir_order = |k: &NodeKind| -> u8 {
            match k {
                NodeKind::Dir => 0,
                NodeKind::File => 1,
            }
        };
        dir_order(&a.kind)
            .cmp(&dir_order(&b.kind))
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    Ok(nodes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// テスト用の一時ディレクトリを作成するヘルパー
    fn setup_test_dir() -> tempfile::TempDir {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        // .git ディレクトリ（ignore crate が .gitignore を認識するために必要）
        fs::create_dir(root.join(".git")).unwrap();

        // ディレクトリ構成
        fs::create_dir_all(root.join("src")).unwrap();
        fs::create_dir_all(root.join("docs")).unwrap();
        fs::create_dir_all(root.join("target/debug")).unwrap();

        // ファイル作成
        fs::write(root.join("README.md"), "# Test").unwrap();
        fs::write(root.join("Cargo.toml"), "[package]").unwrap();
        fs::write(root.join("src/main.rs"), "fn main() {}").unwrap();
        fs::write(root.join("src/lib.rs"), "// lib").unwrap();
        fs::write(root.join("docs/guide.md"), "# Guide").unwrap();

        // .gitignore
        fs::write(root.join(".gitignore"), "target/\n").unwrap();

        tmp
    }

    #[test]
    fn list_dir_returns_sorted_entries() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();

        let result = list_dir(root, root).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        // Dir優先 → 名前順
        assert!(names.contains(&"docs"));
        assert!(names.contains(&"src"));
        assert!(names.contains(&"Cargo.toml"));
        assert!(names.contains(&"README.md"));

        // target/ は .gitignore で除外
        assert!(!names.contains(&"target"));

        // Dir が File より先に来る
        let first_file_idx = result.iter().position(|n| n.kind == NodeKind::File);
        let last_dir_idx = result.iter().rposition(|n| n.kind == NodeKind::Dir);
        if let (Some(fi), Some(di)) = (first_file_idx, last_dir_idx) {
            assert!(di < fi, "Dir should come before File");
        }
    }

    #[test]
    fn list_dir_gitignore_excludes_target() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();

        let result = list_dir(root, root).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(!names.contains(&"target"), "target/ should be ignored");
    }

    #[test]
    fn list_dir_subdirectory() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();
        let src_dir = tmp.path().join("src");
        let src_path = src_dir.to_str().unwrap();

        let result = list_dir(root, src_path).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&"main.rs"));
        assert!(names.contains(&"lib.rs"));
        assert_eq!(result.len(), 2);
    }

    #[test]
    fn list_dir_nonexistent_root() {
        let result = list_dir("/nonexistent/path", "/nonexistent/path");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("root_path が存在しません"));
    }

    #[test]
    fn list_dir_nonexistent_dir() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();

        let result = list_dir(root, "/nonexistent/dir");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("dir_path が存在しません"));
    }

    #[test]
    fn list_dir_file_as_dir() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();
        let file_path = tmp.path().join("README.md");
        let file_str = file_path.to_str().unwrap();

        let result = list_dir(root, file_str);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .contains("dir_path がディレクトリではありません"));
    }

    #[test]
    fn path_to_id_deterministic() {
        let id1 = path_to_id("/some/path");
        let id2 = path_to_id("/some/path");
        assert_eq!(id1, id2);
        assert_eq!(id1.len(), 8);
    }

    #[test]
    fn path_to_id_different_paths() {
        let id1 = path_to_id("/path/a");
        let id2 = path_to_id("/path/b");
        assert_ne!(id1, id2);
    }

    #[test]
    fn list_dir_case_insensitive_sort() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::write(root.join("Zebra.txt"), "").unwrap();
        fs::write(root.join("alpha.txt"), "").unwrap();
        fs::write(root.join("Beta.txt"), "").unwrap();

        let result = list_dir(root.to_str().unwrap(), root.to_str().unwrap()).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert_eq!(names, vec!["alpha.txt", "Beta.txt", "Zebra.txt"]);
    }

    #[test]
    fn list_dir_hidden_files_excluded() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::write(root.join("visible.txt"), "").unwrap();
        fs::write(root.join(".hidden"), "").unwrap();
        fs::create_dir(root.join(".hidden_dir")).unwrap();

        let result = list_dir(root.to_str().unwrap(), root.to_str().unwrap()).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&"visible.txt"));
        assert!(!names.contains(&".hidden"));
        assert!(!names.contains(&".hidden_dir"));
    }
}
