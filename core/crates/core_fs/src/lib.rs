use std::collections::hash_map::DefaultHasher;
use std::collections::HashSet;
use std::fs;
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
        .hidden(false) // ドットファイルも表示（.gitignore 判定は維持）
        .git_ignore(true)
        .git_global(false)
        .git_exclude(true)
        .sort_by_file_path(|a, b| a.cmp(b))
        .build();

    let mut nodes: Vec<FileNode> = Vec::new();
    let mut seen_paths: HashSet<String> = HashSet::new();

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

        seen_paths.insert(path_str.clone());
        nodes.push(FileNode {
            id: path_to_id(&path_str),
            path: path_str,
            name,
            kind,
        });
    }

    // .gitignore で除外される隠しエントリ（例: .ai）を補完する。
    // 隠しファイル/ディレクトリはユーザー操作上重要なため、列挙対象に含める。
    let dir_entries = fs::read_dir(dir).map_err(|e| format!("ディレクトリ読み取りエラー: {e}"))?;
    for entry in dir_entries {
        let entry = entry.map_err(|e| format!("ディレクトリ読み取りエラー: {e}"))?;
        let entry_path = entry.path();
        let name = entry
            .file_name()
            .to_str()
            .map(|s| s.to_string())
            .unwrap_or_default();

        if !name.starts_with('.') {
            continue;
        }

        let path_str = entry_path.to_string_lossy().to_string();
        if seen_paths.contains(&path_str) {
            continue;
        }

        let kind = if entry_path.is_dir() {
            NodeKind::Dir
        } else {
            NodeKind::File
        };

        nodes.push(FileNode {
            id: path_to_id(&path_str),
            path: path_str.clone(),
            name,
            kind,
        });
        seen_paths.insert(path_str);
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
    #[cfg(unix)]
    use std::os::unix::fs as unix_fs;

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
    fn list_dir_hidden_files_included() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::write(root.join("visible.txt"), "").unwrap();
        fs::write(root.join(".hidden"), "").unwrap();
        fs::create_dir(root.join(".hidden_dir")).unwrap();

        let result = list_dir(root.to_str().unwrap(), root.to_str().unwrap()).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&"visible.txt"));
        assert!(names.contains(&".hidden"));
        assert!(names.contains(&".hidden_dir"));
    }

    // ── .gitignore advanced patterns ──────────────────────────

    #[test]
    fn list_dir_gitignore_negation_pattern() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join(".git")).unwrap();
        fs::write(root.join(".gitignore"), "*.log\n!important.log\n").unwrap();
        fs::write(root.join("debug.log"), "").unwrap();
        fs::write(root.join("important.log"), "").unwrap();
        fs::write(root.join("app.txt"), "").unwrap();

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(!names.contains(&"debug.log"), "debug.log should be ignored");
        assert!(
            names.contains(&"important.log"),
            "important.log should be kept by negation"
        );
        assert!(names.contains(&"app.txt"));
    }

    #[test]
    fn list_dir_gitignore_globstar_pattern() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join(".git")).unwrap();
        fs::write(root.join(".gitignore"), "**/node_modules\n").unwrap();
        fs::create_dir_all(root.join("node_modules")).unwrap();
        fs::write(root.join("node_modules/pkg.json"), "").unwrap();
        fs::write(root.join("index.js"), "").unwrap();

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(
            !names.contains(&"node_modules"),
            "node_modules should be ignored"
        );
        assert!(names.contains(&"index.js"));
    }

    #[test]
    fn list_dir_hidden_entry_is_included_even_if_gitignored() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join(".git")).unwrap();
        fs::create_dir(root.join(".ai")).unwrap();
        fs::write(root.join(".ai/notes.md"), "memo").unwrap();
        fs::write(root.join(".gitignore"), ".ai/\n").unwrap();
        fs::write(root.join("visible.txt"), "").unwrap();

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&".ai"));
        assert!(names.contains(&"visible.txt"));
    }

    #[test]
    fn list_dir_empty_gitignore() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join(".git")).unwrap();
        fs::write(root.join(".gitignore"), "").unwrap();
        fs::write(root.join("file_a.txt"), "").unwrap();
        fs::write(root.join("file_b.rs"), "").unwrap();
        fs::create_dir(root.join("src")).unwrap();

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&"src"));
        assert!(names.contains(&"file_a.txt"));
        assert!(names.contains(&"file_b.rs"));
    }

    #[test]
    fn list_dir_nested_gitignore() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join(".git")).unwrap();
        fs::write(root.join(".gitignore"), "").unwrap();
        fs::create_dir_all(root.join("subdir")).unwrap();
        fs::write(root.join("subdir/.gitignore"), "*.tmp\n").unwrap();
        fs::write(root.join("subdir/keep.txt"), "").unwrap();
        fs::write(root.join("subdir/remove.tmp"), "").unwrap();

        let r = root.to_str().unwrap();
        let sub = root.join("subdir");
        let result = list_dir(r, sub.to_str().unwrap()).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(names.contains(&"keep.txt"));
        assert!(
            !names.contains(&"remove.tmp"),
            "remove.tmp should be ignored by nested .gitignore"
        );
    }

    // ── Special filesystem ────────────────────────────────────

    #[cfg(unix)]
    #[test]
    fn list_dir_symlink_in_directory() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join("real_dir")).unwrap();
        fs::write(root.join("real_dir/file.txt"), "").unwrap();
        unix_fs::symlink(root.join("real_dir"), root.join("link_dir")).unwrap();

        let r = root.to_str().unwrap();
        // Should not panic
        let result = list_dir(r, r);
        assert!(result.is_ok(), "symlink should not cause panic");
    }

    #[test]
    fn list_dir_unicode_filename() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::write(root.join("日本語ファイル.txt"), "内容").unwrap();
        fs::write(root.join("normal.txt"), "").unwrap();

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();

        assert!(
            names.contains(&"日本語ファイル.txt"),
            "Unicode filename should appear in results"
        );
        assert!(names.contains(&"normal.txt"));
    }

    #[test]
    fn list_dir_many_files() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        for i in 0..100 {
            fs::write(root.join(format!("file_{i:03}.txt")), "").unwrap();
        }

        let r = root.to_str().unwrap();
        let result = list_dir(r, r).unwrap();

        assert_eq!(result.len(), 100, "all 100 files should be returned");

        // Verify sort order (all files, case-insensitive name sort)
        let names: Vec<&str> = result.iter().map(|n| n.name.as_str()).collect();
        let mut sorted = names.clone();
        sorted.sort_by_key(|a| a.to_lowercase());
        assert_eq!(names, sorted, "files should be sorted by name");
    }

    // ── Snapshot ──────────────────────────────────────────────

    #[test]
    fn list_dir_snapshot() {
        let tmp = setup_test_dir();
        let root = tmp.path().to_str().unwrap();

        let result = list_dir(root, root).unwrap();

        // Only snapshot name + kind (path and id change per run)
        let snapshot: Vec<(&str, &NodeKind)> =
            result.iter().map(|n| (n.name.as_str(), &n.kind)).collect();

        insta::assert_yaml_snapshot!(snapshot);
    }
}
