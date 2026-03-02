mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod dart_api;
use std::path::Path;

use core_types::{BlameLine, FileNode, GitFileDiff, GitStatus, TokenSpan};

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("{reason}")]
    Message { reason: String },
}

fn core_error(reason: impl Into<String>) -> CoreError {
    CoreError::Message {
        reason: reason.into(),
    }
}

/// プロジェクトを開く（MVPではルートパスをそのまま返す）
pub fn open_project(root_path: String) -> Result<String, CoreError> {
    let path = Path::new(&root_path);
    if !path.exists() {
        return Err(core_error(format!("パスが存在しません: {root_path}")));
    }
    if !path.is_dir() {
        return Err(core_error(format!(
            "パスがディレクトリではありません: {root_path}"
        )));
    }
    Ok(root_path)
}

/// ディレクトリ内のファイル一覧を返す
pub fn list_dir(root_path: String, dir_path: String) -> Result<Vec<FileNode>, CoreError> {
    core_fs::list_dir(&root_path, &dir_path).map_err(core_error)
}

/// ファイルの内容を文字列として読み込む
pub fn read_file(path: String) -> Result<String, CoreError> {
    let p = Path::new(&path);
    if !p.exists() {
        return Err(core_error(format!("ファイルが存在しません: {path}")));
    }
    if !p.is_file() {
        return Err(core_error(format!("パスがファイルではありません: {path}")));
    }
    std::fs::read_to_string(&path).map_err(|e| core_error(format!("ファイル読み取りエラー: {e}")))
}

/// シンタックスハイライト: ファイルを読み込み、指定範囲のトークンを返す
pub fn highlight_range(
    path: String,
    start_line: u32,
    end_line: u32,
) -> Result<Vec<TokenSpan>, CoreError> {
    let language = match core_highlight::detect_language(&path) {
        Some(lang) => lang,
        None => return Ok(vec![]),
    };

    let content = read_file(path)?;
    let tokens = core_highlight::tokenize(&content, language).map_err(core_error)?;

    Ok(tokens
        .into_iter()
        .filter(|t| t.line >= start_line && t.line <= end_line)
        .collect())
}

/// Git Blame: 指定範囲の行に対する blame 情報を返す
/// 取得不能時は理由付きエラーを返す
pub fn blame_range(
    path: String,
    start_line: u32,
    end_line: u32,
) -> Result<Vec<BlameLine>, CoreError> {
    match core_git::blame_file(&path) {
        Ok(lines) => {
            let raw_count = lines.len();
            let first_line = lines.first().map(|l| l.line).unwrap_or(0);
            let last_line = lines.last().map(|l| l.line).unwrap_or(0);
            let filtered: Vec<BlameLine> = lines
                .into_iter()
                .filter(|bl| bl.line >= start_line && bl.line <= end_line)
                .collect();

            if filtered.is_empty() {
                return Err(core_error(format!(
                    "blame_range empty: path={path}, range={start_line}-{end_line}, raw_count={raw_count}, first_line={first_line}, last_line={last_line}"
                )));
            }

            Ok(filtered)
        }
        Err(reason) => Err(core_error(format!(
            "blame_range error: path={path}, range={start_line}-{end_line}, reason={reason}"
        ))),
    }
}

/// Blame 行で選択したコミットの差分を返す
pub fn blame_commit_diff(path: String, commit: String) -> Result<GitFileDiff, CoreError> {
    core_git::blame_commit_diff(&path, &commit).map_err(core_error)
}

/// 対象ファイルの現在差分（staged/unstaged/untracked）を返す
pub fn git_file_diff(path: String) -> Result<GitFileDiff, CoreError> {
    core_git::git_file_diff(&path).map_err(core_error)
}

/// リポジトリの変更状態（staged / unstaged / untracked）を返す
pub fn git_status(root_path: String) -> Result<GitStatus, CoreError> {
    core_git::git_status(&root_path).map_err(core_error)
}

/// 現在のブランチ名を返す
pub fn git_current_branch(root_path: String) -> Result<String, CoreError> {
    core_git::git_current_branch(&root_path).map_err(core_error)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn open_project_valid_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().to_str().unwrap().to_string();

        let result = open_project(root.clone());
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), root);
    }

    #[test]
    fn open_project_nonexistent() {
        let result = open_project("/nonexistent/path".to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("パスが存在しません"));
    }

    #[test]
    fn open_project_file_not_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.txt");
        fs::write(&file_path, "hello").unwrap();

        let result = open_project(file_path.to_str().unwrap().to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ディレクトリではありません"));
    }

    #[test]
    fn list_dir_delegates_to_core_fs() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();

        fs::create_dir(root.join("src")).unwrap();
        fs::write(root.join("main.rs"), "fn main() {}").unwrap();

        let root_str = root.to_str().unwrap().to_string();
        let result = list_dir(root_str.clone(), root_str);
        assert!(result.is_ok());

        let nodes = result.unwrap();
        let names: Vec<&str> = nodes.iter().map(|n| n.name.as_str()).collect();
        assert!(names.contains(&"src"));
        assert!(names.contains(&"main.rs"));
    }

    #[test]
    fn read_file_success() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.txt");
        fs::write(&file_path, "hello world").unwrap();

        let result = read_file(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "hello world");
    }

    #[test]
    fn read_file_nonexistent() {
        let result = read_file("/nonexistent/file.txt".to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ファイルが存在しません"));
    }

    #[test]
    fn read_file_directory() {
        let tmp = tempfile::tempdir().unwrap();
        let result = read_file(tmp.path().to_str().unwrap().to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ファイルではありません"));
    }

    #[test]
    fn highlight_range_unsupported_lang_returns_empty() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.txt");
        fs::write(&file_path, "plain text").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 1, 10);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn highlight_range_javascript_file() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.js");
        fs::write(&file_path, "const x = 42;\nlet y = 10;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 1, 2);
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(!tokens.is_empty());
        assert!(tokens.iter().all(|t| t.line >= 1 && t.line <= 2));
    }

    #[test]
    fn highlight_range_filters_by_line() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.ts");
        fs::write(&file_path, "const a = 1;\nconst b = 2;\nconst c = 3;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 2, 2);
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(!tokens.is_empty());
        assert!(tokens.iter().all(|t| t.line == 2));
    }

    #[test]
    fn blame_range_non_git_returns_error() {
        let result = blame_range("/tmp/nonexistent_file.rs".to_string(), 1, 10);
        assert!(result.is_err());
    }

    #[test]
    fn blame_commit_diff_invalid_commit_returns_error() {
        let result = blame_commit_diff(file!().to_string(), "invalid-commit".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn git_file_diff_non_git_returns_error() {
        let result = git_file_diff("/tmp/nonexistent_file_for_blink_diff.swift".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn git_status_non_git_returns_error() {
        let result = git_status("/tmp/nonexistent_root_for_blink".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn git_current_branch_non_git_returns_error() {
        let result = git_current_branch("/tmp/nonexistent_root_for_blink".to_string());
        assert!(result.is_err());
    }

    // ── open_project 追加テスト ──

    #[test]
    fn open_project_symlink_directory() {
        let tmp = tempfile::tempdir().unwrap();
        let real_dir = tmp.path().join("real");
        fs::create_dir(&real_dir).unwrap();
        let link = tmp.path().join("link");
        std::os::unix::fs::symlink(&real_dir, &link).unwrap();

        let result = open_project(link.to_str().unwrap().to_string());
        assert!(result.is_ok());
    }

    #[test]
    fn open_project_empty_string() {
        let result = open_project("".to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("パスが存在しません"));
    }

    // ── read_file 追加テスト ──

    #[test]
    fn read_file_empty_file() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("empty.txt");
        fs::write(&file_path, "").unwrap();

        let result = read_file(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "");
    }

    #[test]
    fn read_file_non_utf8_returns_error() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("binary.bin");
        fs::write(&file_path, &[0xFF, 0xFE, 0x00, 0x80, 0xC0]).unwrap();

        let result = read_file(file_path.to_str().unwrap().to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ファイル読み取りエラー"));
    }

    #[test]
    fn read_file_empty_path() {
        let result = read_file("".to_string());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ファイルが存在しません"));
    }

    // ── list_dir 追加テスト ──

    #[test]
    fn list_dir_empty_directory() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().to_str().unwrap().to_string();

        let result = list_dir(root.clone(), root);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn list_dir_deep_nesting() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path();
        let deep = root.join("a").join("b").join("c");
        fs::create_dir_all(&deep).unwrap();
        fs::write(deep.join("deep.txt"), "deep").unwrap();

        let root_str = root.to_str().unwrap().to_string();
        let result = list_dir(root_str.clone(), root_str);
        assert!(result.is_ok());
        let nodes = result.unwrap();
        // root直下には "a" のみ
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0].name, "a");
    }

    #[test]
    fn list_dir_special_characters_in_path() {
        let tmp = tempfile::tempdir().unwrap();
        let special = tmp.path().join("my dir (1)");
        fs::create_dir(&special).unwrap();
        fs::write(special.join("file.txt"), "ok").unwrap();

        let root = tmp.path().to_str().unwrap().to_string();
        let special_str = special.to_str().unwrap().to_string();
        let result = list_dir(root, special_str);
        assert!(result.is_ok());
        let nodes = result.unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0].name, "file.txt");
    }

    // ── highlight_range 追加テスト ──

    #[test]
    fn highlight_range_start_line_zero() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.js");
        fs::write(&file_path, "const x = 1;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 0, 0);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn highlight_range_start_greater_than_end() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.js");
        fs::write(&file_path, "const x = 1;\nlet y = 2;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 5, 1);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn highlight_range_beyond_file_length() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.js");
        fs::write(&file_path, "const x = 1;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 100, 200);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn highlight_range_single_line() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.js");
        fs::write(&file_path, "const a = 1;\nconst b = 2;\nconst c = 3;").unwrap();

        let result = highlight_range(file_path.to_str().unwrap().to_string(), 2, 2);
        assert!(result.is_ok());
        let tokens = result.unwrap();
        assert!(!tokens.is_empty());
        assert!(tokens.iter().all(|t| t.line == 2));
    }

    #[test]
    fn highlight_range_nonexistent_file_returns_error() {
        let result = highlight_range("/nonexistent/test.js".to_string(), 1, 10);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("ファイルが存在しません"));
    }

    // ── highlight_range スナップショットテスト ──

    #[test]
    fn highlight_range_js_snapshot() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("snapshot.js");
        fs::write(&file_path, "const x = 42;\nlet y = \"hello\";").unwrap();

        let tokens = highlight_range(file_path.to_str().unwrap().to_string(), 1, 2).unwrap();
        let formatted: Vec<String> = tokens
            .iter()
            .map(|t| format!("L{}:{}-{} {:?}", t.line, t.start_col, t.end_col, t.token_type))
            .collect();
        insta::assert_yaml_snapshot!(formatted);
    }

    #[test]
    fn highlight_range_rust_snapshot() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("snapshot.rs");
        fs::write(&file_path, "fn main() {\n    let x: i32 = 42;\n}").unwrap();

        let tokens = highlight_range(file_path.to_str().unwrap().to_string(), 1, 3).unwrap();
        let formatted: Vec<String> = tokens
            .iter()
            .map(|t| format!("L{}:{}-{} {:?}", t.line, t.start_col, t.end_col, t.token_type))
            .collect();
        insta::assert_yaml_snapshot!(formatted);
    }

    // ── blame_range 追加テスト ──

    #[test]
    fn blame_range_start_zero() {
        // 実在のgitリポジトリ内ファイルで line 0 を指定 → 空結果でErr
        let this_file = file!().to_string();
        // file!() はクレートルートからの相対パス。絶対パスに変換
        let manifest_dir = env!("CARGO_MANIFEST_DIR");
        let abs_path = format!("{}/{}", manifest_dir, this_file);

        let result = blame_range(abs_path, 0, 0);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("blame_range"));
    }

    #[test]
    fn blame_range_start_greater_than_end() {
        let manifest_dir = env!("CARGO_MANIFEST_DIR");
        let abs_path = format!("{}/{}", manifest_dir, file!());

        let result = blame_range(abs_path, 100, 1);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("blame_range"));
    }

    // ── エラー一貫性テスト ──

    #[test]
    fn error_messages_contain_path_information() {
        let bad_path = "/some/bad/path/file.txt";
        let result = read_file(bad_path.to_string());
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(
            err_msg.contains(bad_path),
            "Error message should contain the bad path: {err_msg}"
        );

        let bad_dir = "/some/bad/dir";
        let result = open_project(bad_dir.to_string());
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(
            err_msg.contains(bad_dir),
            "Error message should contain the bad dir: {err_msg}"
        );
    }

    #[test]
    fn all_api_errors_are_core_error_message_variant() {
        // 各APIのエラーがすべて CoreError::Message であることを確認
        let e1 = open_project("/nonexistent".to_string()).unwrap_err();
        assert!(matches!(e1, CoreError::Message { .. }));

        let e2 = read_file("/nonexistent/file.txt".to_string()).unwrap_err();
        assert!(matches!(e2, CoreError::Message { .. }));

        let e3 = highlight_range("/nonexistent/test.js".to_string(), 1, 1).unwrap_err();
        assert!(matches!(e3, CoreError::Message { .. }));

        let e4 = blame_range("/nonexistent/file.rs".to_string(), 1, 1).unwrap_err();
        assert!(matches!(e4, CoreError::Message { .. }));
    }
}
