use core_types::{TokenSpan, TokenType};
use tree_sitter::Parser;

/// 拡張子から言語名を判定する
pub fn detect_language(path: &str) -> Option<&'static str> {
    let ext = path.rsplit('.').next()?;
    match ext {
        "ts" | "tsx" => Some("typescript"),
        "js" | "jsx" => Some("javascript"),
        _ => None,
    }
}

/// テキストをトークン化して TokenSpan のリストを返す
pub fn tokenize(text: &str, language: &str) -> Result<Vec<TokenSpan>, String> {
    let mut parser = Parser::new();

    match language {
        "typescript" => {
            parser
                .set_language(&tree_sitter_typescript::LANGUAGE_TSX.into())
                .map_err(|e| format!("TypeScript パーサー設定エラー: {e}"))?;
        }
        "javascript" => {
            parser
                .set_language(&tree_sitter_javascript::LANGUAGE.into())
                .map_err(|e| format!("JavaScript パーサー設定エラー: {e}"))?;
        }
        _ => return Err(format!("未対応の言語: {language}")),
    }

    let tree = parser
        .parse(text, None)
        .ok_or_else(|| "パースに失敗しました".to_string())?;

    let root_node = tree.root_node();
    let mut tokens = Vec::new();
    let source = text.as_bytes();

    collect_tokens(root_node, source, &mut tokens);

    Ok(tokens)
}

/// AST ノードを再帰的に走査し、葉ノードを TokenSpan に変換する
fn collect_tokens(node: tree_sitter::Node, source: &[u8], tokens: &mut Vec<TokenSpan>) {
    // 名前付き葉ノード、または演算子・句読点などの無名葉ノードを対象にする
    if node.child_count() == 0 {
        let start = node.start_position();
        let end = node.end_position();

        // 複数行にまたがるノードは行ごとに分割
        if start.row != end.row {
            let text = node.utf8_text(source).unwrap_or("").to_string();
            let token_type = classify_node(&node);

            for (i, line) in text.split('\n').enumerate() {
                let line_num = start.row as u32 + i as u32 + 1;
                let start_col = if i == 0 { start.column as u32 } else { 0 };
                let end_col = start_col + line.len() as u32;
                if !line.is_empty() {
                    tokens.push(TokenSpan {
                        line: line_num,
                        start_col,
                        end_col,
                        token_type,
                    });
                }
            }
        } else {
            let token_type = classify_node(&node);
            tokens.push(TokenSpan {
                line: start.row as u32 + 1,
                start_col: start.column as u32,
                end_col: end.column as u32,
                token_type,
            });
        }
        return;
    }

    // call_expression の関数名部分を特別扱い
    if node.kind() == "call_expression" {
        if let Some(func_node) = node.child_by_field_name("function") {
            if func_node.child_count() == 0 {
                let start = func_node.start_position();
                let end = func_node.end_position();
                tokens.push(TokenSpan {
                    line: start.row as u32 + 1,
                    start_col: start.column as u32,
                    end_col: end.column as u32,
                    token_type: TokenType::Function,
                });

                // 残りの子ノードを処理（関数名以外）
                let mut cursor = node.walk();
                for child in node.children(&mut cursor) {
                    if child.id() != func_node.id() {
                        collect_tokens(child, source, tokens);
                    }
                }
                return;
            }
        }
    }

    // 子ノードを再帰処理
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        collect_tokens(child, source, tokens);
    }
}

/// ノード種別を TokenType にマッピング
fn classify_node(node: &tree_sitter::Node) -> TokenType {
    let kind = node.kind();
    let parent_kind = node.parent().map(|p| p.kind()).unwrap_or("");

    match kind {
        // キーワード
        "if" | "else" | "for" | "while" | "do" | "switch" | "case" | "break" | "continue"
        | "return" | "throw" | "try" | "catch" | "finally" | "new" | "delete" | "typeof"
        | "instanceof" | "in" | "of" | "void" | "yield" | "await" | "async" | "class"
        | "extends" | "super" | "import" | "export" | "from" | "as" | "default" | "const"
        | "let" | "var" | "function" | "static" | "get" | "set" | "this" | "with" | "debugger"
        | "interface" | "type" | "enum" | "implements" | "public" | "private" | "protected"
        | "readonly" | "abstract" | "declare" | "namespace" | "module" | "keyof" | "infer"
        | "satisfies" => TokenType::Keyword,

        // 文字列
        "string" | "string_fragment" | "template_string" | "template_literal_type" => {
            TokenType::String
        }

        // コメント
        "comment" => TokenType::Comment,

        // 型識別子
        "type_identifier" | "predefined_type" => TokenType::Type,

        // 数値
        "number" => TokenType::Number,

        // 関数定義名
        "property_identifier"
            if matches!(
                parent_kind,
                "function_declaration" | "method_definition" | "function" | "arrow_function"
            ) =>
        {
            TokenType::Function
        }

        // 変数名
        "identifier" => match parent_kind {
            "function_declaration" | "method_definition" => TokenType::Function,
            "type_annotation" | "type_alias_declaration" => TokenType::Type,
            _ => TokenType::Variable,
        },

        // 演算子
        "+" | "-" | "*" | "/" | "%" | "=" | "==" | "===" | "!=" | "!==" | "<" | ">" | "<="
        | ">=" | "&&" | "||" | "!" | "&" | "|" | "^" | "~" | "<<" | ">>" | ">>>" | "+=" | "-="
        | "*=" | "/=" | "%=" | "**" | "??" | "?." | "=>" | "..." | "++" | "--" | "?" | ":" => {
            TokenType::Operator
        }

        // 句読点
        "(" | ")" | "[" | "]" | "{" | "}" | ";" | "," | "." => TokenType::Punctuation,

        // true/false/null/undefined
        "true" | "false" | "null" | "undefined" => TokenType::Keyword,

        _ => TokenType::Plain,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokenize_javascript_variable_declaration() {
        let code = "const x = 42;";
        let tokens = tokenize(code, "javascript").unwrap();

        assert!(!tokens.is_empty());

        // "const" → Keyword
        let const_token = tokens.iter().find(|t| t.start_col == 0 && t.end_col == 5);
        assert!(const_token.is_some());
        assert_eq!(const_token.unwrap().token_type, TokenType::Keyword);

        // "42" → Number
        let num_token = tokens.iter().find(|t| t.token_type == TokenType::Number);
        assert!(num_token.is_some());
        assert_eq!(num_token.unwrap().start_col, 10);
        assert_eq!(num_token.unwrap().end_col, 12);
    }

    #[test]
    fn tokenize_typescript_function() {
        let code = "function greet(name: string): string { return \"hello\"; }";
        let tokens = tokenize(code, "typescript").unwrap();

        assert!(!tokens.is_empty());

        // "function" → Keyword
        let func_kw = tokens.iter().find(|t| t.start_col == 0 && t.end_col == 8);
        assert!(func_kw.is_some());
        assert_eq!(func_kw.unwrap().token_type, TokenType::Keyword);

        // "greet" → Function
        let func_name = tokens.iter().find(|t| t.start_col == 9 && t.end_col == 14);
        assert!(func_name.is_some());
        assert_eq!(func_name.unwrap().token_type, TokenType::Function);

        // "string" (引数型) → Type or Keyword (predefined_type)
        let string_type = tokens.iter().find(|t| t.start_col == 21 && t.end_col == 27);
        assert!(string_type.is_some());

        // "\"hello\"" → String
        let str_token = tokens.iter().find(|t| t.token_type == TokenType::String);
        assert!(str_token.is_some());
    }

    #[test]
    fn tokenize_javascript_with_comment() {
        let code = "// this is a comment\nlet y = 10;";
        let tokens = tokenize(code, "javascript").unwrap();

        assert!(!tokens.is_empty());

        // コメント → Comment
        let comment = tokens.iter().find(|t| t.token_type == TokenType::Comment);
        assert!(comment.is_some());
        assert_eq!(comment.unwrap().line, 1);

        // "let" → Keyword（2行目）
        let let_token = tokens
            .iter()
            .find(|t| t.line == 2 && t.token_type == TokenType::Keyword);
        assert!(let_token.is_some());
    }

    #[test]
    fn tokenize_multiline_typescript() {
        let code = r#"interface User {
    name: string;
    age: number;
}"#;
        let tokens = tokenize(code, "typescript").unwrap();

        assert!(!tokens.is_empty());

        // "interface" → Keyword
        let iface = tokens
            .iter()
            .find(|t| t.line == 1 && t.start_col == 0 && t.token_type == TokenType::Keyword);
        assert!(iface.is_some());

        // "User" → Type（type_identifier）
        let user_type = tokens.iter().find(|t| t.line == 1 && t.start_col == 10);
        assert!(user_type.is_some());
        assert_eq!(user_type.unwrap().token_type, TokenType::Type);
    }

    #[test]
    fn tokenize_unsupported_language_returns_error() {
        let result = tokenize("print('hello')", "python");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("未対応の言語"));
    }

    #[test]
    fn detect_language_returns_correct_language() {
        assert_eq!(detect_language("main.ts"), Some("typescript"));
        assert_eq!(detect_language("app.tsx"), Some("typescript"));
        assert_eq!(detect_language("index.js"), Some("javascript"));
        assert_eq!(detect_language("component.jsx"), Some("javascript"));
        assert_eq!(detect_language("main.rs"), None);
        assert_eq!(detect_language("no_extension"), None);
    }

    #[test]
    fn tokenize_empty_input() {
        let result = tokenize("", "javascript");
        assert!(result.is_ok());
    }
}
