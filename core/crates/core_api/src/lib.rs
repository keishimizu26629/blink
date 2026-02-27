use std::path::Path;

use core_types::{BlameLine, FileNode, TokenSpan};

uniffi::setup_scaffolding!();

#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
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
#[uniffi::export]
pub fn open_project(root_path: String) -> Result<String, CoreError> {
    let path = Path::new(&root_path);
    if !path.exists() {
        return Err(core_error(format!("パスが存在しません: {root_path}")));
    }
    if !path.is_dir() {
        return Err(core_error(format!("パスがディレクトリではありません: {root_path}")));
    }
    Ok(root_path)
}

/// ディレクトリ内のファイル一覧を返す
#[uniffi::export]
pub fn list_dir(root_path: String, dir_path: String) -> Result<Vec<FileNode>, CoreError> {
    core_fs::list_dir(&root_path, &dir_path).map_err(core_error)
}

/// ファイルの内容を文字列として読み込む
#[uniffi::export]
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
#[uniffi::export]
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
/// 非Gitリポジトリの場合は空Vecを返す（エラーにしない）
#[uniffi::export]
pub fn blame_range(path: String, start_line: u32, end_line: u32) -> Result<Vec<BlameLine>, CoreError> {
    match core_git::blame_file(&path) {
        Ok(lines) => Ok(lines
            .into_iter()
            .filter(|bl| bl.line >= start_line && bl.line <= end_line)
            .collect()),
        Err(_) => Ok(vec![]),
    }
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
        assert!(result.unwrap_err().to_string().contains("パスが存在しません"));
    }

    #[test]
    fn open_project_file_not_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let file_path = tmp.path().join("test.txt");
        fs::write(&file_path, "hello").unwrap();

        let result = open_project(file_path.to_str().unwrap().to_string());
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("ディレクトリではありません"));
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
        assert!(result.unwrap_err().to_string().contains("ファイルが存在しません"));
    }

    #[test]
    fn read_file_directory() {
        let tmp = tempfile::tempdir().unwrap();
        let result = read_file(tmp.path().to_str().unwrap().to_string());
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("ファイルではありません"));
    }

    #[test]
    fn highlight_range_unsupported_lang_returns_empty() {
        let result = highlight_range("test.rs".to_string(), 1, 10);
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
    fn blame_range_non_git_returns_empty() {
        let result = blame_range("/tmp/nonexistent_file.rs".to_string(), 1, 10);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }
}
