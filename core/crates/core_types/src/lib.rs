uniffi::setup_scaffolding!();

/// ファイルノード（ツリー表示用）
/// children はSwift側で管理するため、FFI境界では含めない
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct FileNode {
    pub id: String,
    pub path: String,
    pub name: String,
    pub kind: NodeKind,
}

/// ノード種別
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum NodeKind {
    File,
    Dir,
}

/// シンタックスハイライト用トークン
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct TokenSpan {
    pub line: u32,
    pub start_col: u32,
    pub end_col: u32,
    pub token_type: TokenType,
}

/// トークン種別
#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
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
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct BlameLine {
    pub line: u32,
    pub author: String,
    pub author_time: i64,
    pub summary: String,
    pub commit: String,
}

/// Blame 行から参照するコミット差分
#[derive(Debug, Clone, PartialEq, uniffi::Record)]
pub struct BlameDiff {
    pub commit: String,
    pub path: String,
    pub diff_text: String,
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
    fn blame_diff_creation() {
        let diff = BlameDiff {
            commit: "abc1234".into(),
            path: "/tmp/file.rs".into(),
            diff_text: "@@ -1 +1 @@\n-old\n+new\n".into(),
        };
        assert_eq!(diff.commit, "abc1234");
        assert!(diff.diff_text.contains("+new"));
    }
}
