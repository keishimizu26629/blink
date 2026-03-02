/// ファイルノード（ツリー表示用）
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct FileNode {
    pub id: String,
    pub path: String,
    pub name: String,
    pub kind: NodeKind,
}

/// ノード種別
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
pub enum NodeKind {
    File,
    Dir,
}

/// シンタックスハイライト用トークン
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct TokenSpan {
    pub line: u32,
    pub start_col: u32,
    pub end_col: u32,
    pub token_type: TokenType,
}

/// トークン種別
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
pub enum TokenType {
    Keyword,
    String,
    Comment,
    Type,
    Function,
    Number,
    Operator,
    Punctuation,
    Variable,
    Plain,
}

/// Git Blame 行情報
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct BlameLine {
    pub line: u32,
    pub author: String,
    pub author_time: i64,
    pub summary: String,
    pub commit: String,
}

/// Git差分（コミット差分または作業ツリー差分）
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct GitFileDiff {
    pub commit: String,
    pub path: String,
    pub diff_text: String,
}

/// Git status の1エントリ
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct GitStatusEntry {
    pub path: String,
    pub status: String,
}

/// Git status 分類結果
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct GitStatus {
    pub staged: Vec<GitStatusEntry>,
    pub unstaged: Vec<GitStatusEntry>,
    pub untracked: Vec<GitStatusEntry>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_node_creation() {
        let node = FileNode {
            id: "abc123".into(),
            path: "/src/main.rs".into(),
            name: "main.rs".into(),
            kind: NodeKind::File,
        };
        assert_eq!(node.name, "main.rs");
        assert_eq!(node.kind, NodeKind::File);
    }

    #[test]
    fn dir_node_creation() {
        let dir = FileNode {
            id: "dir1".into(),
            path: "/src".into(),
            name: "src".into(),
            kind: NodeKind::Dir,
        };
        assert_eq!(dir.kind, NodeKind::Dir);
    }

    #[test]
    fn token_span_creation() {
        let span = TokenSpan {
            line: 1,
            start_col: 0,
            end_col: 5,
            token_type: TokenType::Keyword,
        };
        assert_eq!(span.token_type, TokenType::Keyword);
    }

    #[test]
    fn blame_line_creation() {
        let blame = BlameLine {
            line: 42,
            author: "Alice".into(),
            author_time: 1700000000,
            summary: "fix: resolve null pointer".into(),
            commit: "abc1234".into(),
        };
        assert_eq!(blame.line, 42);
        assert_eq!(blame.author, "Alice");
    }

    #[test]
    fn git_file_diff_creation() {
        let diff = GitFileDiff {
            commit: "abc1234".into(),
            path: "/tmp/file.rs".into(),
            diff_text: "@@ -1 +1 @@\n-old\n+new\n".into(),
        };
        assert_eq!(diff.commit, "abc1234");
        assert!(diff.diff_text.contains("+new"));
    }

    #[test]
    fn git_status_creation() {
        let status = GitStatus {
            staged: vec![GitStatusEntry {
                path: "/tmp/a.swift".into(),
                status: "M ".into(),
            }],
            unstaged: vec![GitStatusEntry {
                path: "/tmp/b.swift".into(),
                status: " M".into(),
            }],
            untracked: vec![GitStatusEntry {
                path: "/tmp/c.swift".into(),
                status: "??".into(),
            }],
        };
        assert_eq!(status.staged.len(), 1);
        assert_eq!(status.unstaged.len(), 1);
        assert_eq!(status.untracked.len(), 1);
        assert_eq!(status.untracked[0].status, "??");
    }

    #[test]
    fn file_node_empty_fields() {
        let node = FileNode {
            id: "".into(),
            path: "".into(),
            name: "".into(),
            kind: NodeKind::File,
        };
        assert_eq!(node.id, "");
        assert_eq!(node.path, "");
        assert_eq!(node.name, "");
    }

    #[test]
    fn file_node_special_characters() {
        let node = FileNode {
            id: "sp1".into(),
            path: "/home/user/テスト.txt".into(),
            name: "テスト.txt".into(),
            kind: NodeKind::File,
        };
        assert_eq!(node.path, "/home/user/テスト.txt");
        assert_eq!(node.name, "テスト.txt");

        let spaced = FileNode {
            id: "sp2".into(),
            path: "/my docs/hello world.rs".into(),
            name: "hello world.rs".into(),
            kind: NodeKind::Dir,
        };
        assert_eq!(spaced.path, "/my docs/hello world.rs");
        assert_eq!(spaced.name, "hello world.rs");
    }

    #[test]
    fn token_span_all_token_types_roundtrip() {
        let variants = [
            TokenType::Keyword,
            TokenType::String,
            TokenType::Comment,
            TokenType::Type,
            TokenType::Function,
            TokenType::Number,
            TokenType::Operator,
            TokenType::Punctuation,
            TokenType::Variable,
            TokenType::Plain,
        ];
        for (i, tt) in variants.iter().enumerate() {
            let span = TokenSpan {
                line: i as u32,
                start_col: 0,
                end_col: 10,
                token_type: *tt,
            };
            assert_eq!(span.token_type, *tt);
            assert_eq!(span.line, i as u32);
        }
    }

    #[test]
    fn blame_line_empty_summary() {
        let blame = BlameLine {
            line: 0,
            author: "".into(),
            author_time: 0,
            summary: "".into(),
            commit: "".into(),
        };
        assert_eq!(blame.line, 0);
        assert_eq!(blame.author, "");
        assert_eq!(blame.author_time, 0);
        assert_eq!(blame.summary, "");
        assert_eq!(blame.commit, "");
    }

    #[test]
    fn git_status_all_empty() {
        let status = GitStatus {
            staged: vec![],
            unstaged: vec![],
            untracked: vec![],
        };
        assert!(status.staged.is_empty());
        assert!(status.unstaged.is_empty());
        assert!(status.untracked.is_empty());
    }
}
