//! Flutter (Dart) 向け API レイヤー
//!
//! FRB (flutter_rust_bridge) がスキャンするモジュール。
//! core_types の型は外部 crate のため FRB には opaque に見える。
//! ここで FRB 可視な型を定義し、薄い変換レイヤーを提供する。

use core_types::NodeKind;

// ─── FRB 可視型 ───

/// ファイルノード
pub struct DartFileNode {
    pub id: String,
    pub path: String,
    pub name: String,
    pub is_dir: bool,
}

impl From<core_types::FileNode> for DartFileNode {
    fn from(n: core_types::FileNode) -> Self {
        Self {
            id: n.id,
            path: n.path,
            name: n.name,
            is_dir: matches!(n.kind, NodeKind::Dir),
        }
    }
}

/// シンタックスハイライト用トークン
pub struct DartTokenSpan {
    pub line: u32,
    pub start_col: u32,
    pub end_col: u32,
    /// "keyword", "string", "comment", "type", "function",
    /// "number", "operator", "punctuation", "variable", "plain"
    pub token_type: String,
}

impl From<core_types::TokenSpan> for DartTokenSpan {
    fn from(t: core_types::TokenSpan) -> Self {
        Self {
            line: t.line,
            start_col: t.start_col,
            end_col: t.end_col,
            token_type: match t.token_type {
                core_types::TokenType::Keyword => "keyword",
                core_types::TokenType::String => "string",
                core_types::TokenType::Comment => "comment",
                core_types::TokenType::Type => "type",
                core_types::TokenType::Function => "function",
                core_types::TokenType::Number => "number",
                core_types::TokenType::Operator => "operator",
                core_types::TokenType::Punctuation => "punctuation",
                core_types::TokenType::Variable => "variable",
                core_types::TokenType::Plain => "plain",
            }
            .to_string(),
        }
    }
}

/// Git Blame 行情報
pub struct DartBlameLine {
    pub line: u32,
    pub author: String,
    pub author_time: i64,
    pub summary: String,
    pub commit: String,
}

impl From<core_types::BlameLine> for DartBlameLine {
    fn from(b: core_types::BlameLine) -> Self {
        Self {
            line: b.line,
            author: b.author,
            author_time: b.author_time,
            summary: b.summary,
            commit: b.commit,
        }
    }
}

/// Git 差分
pub struct DartGitFileDiff {
    pub commit: String,
    pub path: String,
    pub diff_text: String,
}

impl From<core_types::GitFileDiff> for DartGitFileDiff {
    fn from(d: core_types::GitFileDiff) -> Self {
        Self {
            commit: d.commit,
            path: d.path,
            diff_text: d.diff_text,
        }
    }
}

/// Git status エントリ
pub struct DartGitStatusEntry {
    pub path: String,
    pub status: String,
}

impl From<core_types::GitStatusEntry> for DartGitStatusEntry {
    fn from(e: core_types::GitStatusEntry) -> Self {
        Self {
            path: e.path,
            status: e.status,
        }
    }
}

/// Git status 分類結果
pub struct DartGitStatus {
    pub staged: Vec<DartGitStatusEntry>,
    pub unstaged: Vec<DartGitStatusEntry>,
    pub untracked: Vec<DartGitStatusEntry>,
}

impl From<core_types::GitStatus> for DartGitStatus {
    fn from(s: core_types::GitStatus) -> Self {
        Self {
            staged: s.staged.into_iter().map(Into::into).collect(),
            unstaged: s.unstaged.into_iter().map(Into::into).collect(),
            untracked: s.untracked.into_iter().map(Into::into).collect(),
        }
    }
}

// ─── API 関数 ───

fn map_err(e: crate::CoreError) -> String {
    e.to_string()
}

/// プロジェクトを開く
pub fn open_project(root_path: String) -> Result<String, String> {
    crate::open_project(root_path).map_err(map_err)
}

/// ディレクトリ内のファイル一覧を返す
pub fn list_dir(root_path: String, dir_path: String) -> Result<Vec<DartFileNode>, String> {
    crate::list_dir(root_path, dir_path)
        .map(|v| v.into_iter().map(Into::into).collect())
        .map_err(map_err)
}

/// ファイルの内容を文字列として読み込む
pub fn read_file(path: String) -> Result<String, String> {
    crate::read_file(path).map_err(map_err)
}

/// シンタックスハイライト
pub fn highlight_range(
    path: String,
    start_line: u32,
    end_line: u32,
) -> Result<Vec<DartTokenSpan>, String> {
    crate::highlight_range(path, start_line, end_line)
        .map(|v| v.into_iter().map(Into::into).collect())
        .map_err(map_err)
}

/// Git Blame
pub fn blame_range(
    path: String,
    start_line: u32,
    end_line: u32,
) -> Result<Vec<DartBlameLine>, String> {
    crate::blame_range(path, start_line, end_line)
        .map(|v| v.into_iter().map(Into::into).collect())
        .map_err(map_err)
}

/// Blame コミット差分
pub fn blame_commit_diff(path: String, commit: String) -> Result<DartGitFileDiff, String> {
    crate::blame_commit_diff(path, commit)
        .map(Into::into)
        .map_err(map_err)
}

/// ファイル差分
pub fn git_file_diff(path: String) -> Result<DartGitFileDiff, String> {
    crate::git_file_diff(path)
        .map(Into::into)
        .map_err(map_err)
}

/// Git status
pub fn git_status(root_path: String) -> Result<DartGitStatus, String> {
    crate::git_status(root_path)
        .map(Into::into)
        .map_err(map_err)
}

/// 現在のブランチ名
pub fn git_current_branch(root_path: String) -> Result<String, String> {
    crate::git_current_branch(root_path).map_err(map_err)
}
