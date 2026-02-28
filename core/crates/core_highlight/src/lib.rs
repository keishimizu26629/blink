use core_types::{TokenSpan, TokenType};
use tree_sitter::{Node, Parser};

/// 拡張子から言語名を判定する
pub fn detect_language(path: &str) -> Option<&'static str> {
    let ext = path.rsplit('.').next()?.to_ascii_lowercase();
    match ext.as_str() {
        "ts" | "tsx" => Some("typescript"),
        "js" | "jsx" | "mjs" | "cjs" => Some("javascript"),
        "json" => Some("json"),
        "yaml" | "yml" => Some("yaml"),
        "swift" => Some("swift"),
        "rs" => Some("rust"),
        "dart" => Some("dart"),
        "html" | "htm" => Some("html"),
        "css" => Some("css"),
        "py" => Some("python"),
        _ => None,
    }
}

/// テキストをトークン化して TokenSpan のリストを返す
pub fn tokenize(text: &str, language: &str) -> Result<Vec<TokenSpan>, String> {
    let mut parser = Parser::new();

    match language {
        "typescript" => parser
            .set_language(&tree_sitter_typescript::LANGUAGE_TSX.into())
            .map_err(|e| format!("TypeScript パーサー設定エラー: {e}"))?,
        "javascript" => parser
            .set_language(&tree_sitter_javascript::LANGUAGE.into())
            .map_err(|e| format!("JavaScript パーサー設定エラー: {e}"))?,
        "json" => parser
            .set_language(&tree_sitter_json::LANGUAGE.into())
            .map_err(|e| format!("JSON パーサー設定エラー: {e}"))?,
        "yaml" => parser
            .set_language(&tree_sitter_yaml::LANGUAGE.into())
            .map_err(|e| format!("YAML パーサー設定エラー: {e}"))?,
        "swift" => parser
            .set_language(&tree_sitter_swift::LANGUAGE.into())
            .map_err(|e| format!("Swift パーサー設定エラー: {e}"))?,
        "rust" => parser
            .set_language(&tree_sitter_rust::LANGUAGE.into())
            .map_err(|e| format!("Rust パーサー設定エラー: {e}"))?,
        "dart" => parser
            .set_language(&tree_sitter_dart::language())
            .map_err(|e| format!("Dart パーサー設定エラー: {e}"))?,
        "html" => parser
            .set_language(&tree_sitter_html::LANGUAGE.into())
            .map_err(|e| format!("HTML パーサー設定エラー: {e}"))?,
        "css" => parser
            .set_language(&tree_sitter_css::LANGUAGE.into())
            .map_err(|e| format!("CSS パーサー設定エラー: {e}"))?,
        "python" => parser
            .set_language(&tree_sitter_python::LANGUAGE.into())
            .map_err(|e| format!("Python パーサー設定エラー: {e}"))?,
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
fn collect_tokens(node: Node, source: &[u8], tokens: &mut Vec<TokenSpan>) {
    if node.child_count() == 0 {
        let start = node.start_position();
        let end = node.end_position();

        if start.row != end.row {
            let text = node.utf8_text(source).unwrap_or("").to_string();
            let token_type = classify_node(node);
            for (i, line) in text.split('\n').enumerate() {
                if line.is_empty() {
                    continue;
                }
                let line_num = start.row as u32 + i as u32 + 1;
                let start_col = if i == 0 { start.column as u32 } else { 0 };
                let end_col = start_col + line.len() as u32;
                tokens.push(TokenSpan {
                    line: line_num,
                    start_col,
                    end_col,
                    token_type,
                });
            }
        } else {
            let token_type = classify_node(node);
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

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        collect_tokens(child, source, tokens);
    }
}

/// ノード種別を TokenType にマッピング
fn classify_node(node: Node) -> TokenType {
    let kind = node.kind();
    let parent_kind = node.parent().map(|p| p.kind()).unwrap_or("");

    if is_comment_kind(kind) {
        return TokenType::Comment;
    }
    if is_string_kind(kind) {
        return TokenType::String;
    }
    if is_number_kind(kind) {
        return TokenType::Number;
    }
    if is_keyword_kind(kind) {
        return TokenType::Keyword;
    }
    if is_operator_kind(kind) {
        return TokenType::Operator;
    }
    if is_punctuation_kind(kind) {
        return TokenType::Punctuation;
    }
    if is_type_kind(kind) {
        return TokenType::Type;
    }
    if is_function_kind(kind, parent_kind) {
        return TokenType::Function;
    }
    if is_variable_kind(kind, parent_kind) {
        return TokenType::Variable;
    }

    TokenType::Plain
}

fn is_comment_kind(kind: &str) -> bool {
    matches!(
        kind,
        "comment" | "line_comment" | "block_comment" | "html_comment"
    )
}

fn is_string_kind(kind: &str) -> bool {
    matches!(
        kind,
        "string"
            | "string_fragment"
            | "template_string"
            | "template_literal_type"
            | "interpreted_string_literal"
            | "raw_string_literal"
            | "char_literal"
            | "escape_sequence"
    )
}

fn is_number_kind(kind: &str) -> bool {
    matches!(
        kind,
        "number"
            | "integer"
            | "float"
            | "integer_literal"
            | "float_literal"
            | "hex_literal"
            | "binary_literal"
            | "octal_literal"
    )
}

fn is_keyword_kind(kind: &str) -> bool {
    matches!(
        kind,
        "if"
            | "else"
            | "for"
            | "while"
            | "do"
            | "switch"
            | "case"
            | "default"
            | "break"
            | "continue"
            | "return"
            | "throw"
            | "try"
            | "catch"
            | "finally"
            | "new"
            | "delete"
            | "typeof"
            | "instanceof"
            | "in"
            | "of"
            | "void"
            | "yield"
            | "await"
            | "async"
            | "class"
            | "extends"
            | "super"
            | "import"
            | "export"
            | "from"
            | "as"
            | "const"
            | "let"
            | "var"
            | "function"
            | "static"
            | "get"
            | "set"
            | "this"
            | "with"
            | "debugger"
            | "interface"
            | "type"
            | "enum"
            | "implements"
            | "public"
            | "private"
            | "protected"
            | "readonly"
            | "abstract"
            | "declare"
            | "namespace"
            | "module"
            | "keyof"
            | "infer"
            | "satisfies"
            | "fn"
            | "impl"
            | "trait"
            | "struct"
            | "match"
            | "mut"
            | "pub"
            | "where"
            | "use"
            | "mod"
            | "crate"
            | "self"
            | "Self"
            | "let_statement"
            | "func"
            | "protocol"
            | "guard"
            | "defer"
            | "repeat"
            | "inout"
            | "operator"
            | "subscript"
            | "init"
            | "deinit"
            | "associatedtype"
            | "some"
            | "any"
            | "extension"
            | "enum_declaration"
            | "class_declaration"
            | "func_literal"
            | "def"
            | "lambda"
            | "elif"
            | "except"
            | "pass"
            | "raise"
            | "global"
            | "nonlocal"
            | "del"
            | "assert"
            | "True"
            | "False"
            | "None"
            | "null"
            | "undefined"
            | "true"
            | "false"
    )
}

fn is_operator_kind(kind: &str) -> bool {
    matches!(
        kind,
        "+" | "-"
            | "*"
            | "/"
            | "%"
            | "="
            | "=="
            | "==="
            | "!="
            | "!=="
            | "<"
            | ">"
            | "<="
            | ">="
            | "&&"
            | "||"
            | "!"
            | "&"
            | "|"
            | "^"
            | "~"
            | "<<"
            | ">>"
            | ">>>"
            | "+="
            | "-="
            | "*="
            | "/="
            | "%="
            | "**"
            | "??"
            | "?."
            | "=>"
            | "..."
            | "++"
            | "--"
            | "?"
            | ":"
            | "->"
            | "::"
            | "@"
            | "#"
    )
}

fn is_punctuation_kind(kind: &str) -> bool {
    matches!(
        kind,
        "(" | ")" | "[" | "]" | "{" | "}" | ";" | "," | "." | "<" | ">" | "/" | "\\"
    )
}

fn is_type_kind(kind: &str) -> bool {
    matches!(
        kind,
        "type_identifier"
            | "predefined_type"
            | "type_annotation"
            | "type_alias_declaration"
            | "primitive_type"
            | "generic_type"
            | "enum_variant"
            | "tag_name"
    )
}

fn is_function_kind(kind: &str, parent_kind: &str) -> bool {
    if matches!(
        kind,
        "function_item"
            | "function_declaration"
            | "function_definition"
            | "method_definition"
            | "method_declaration"
            | "function_name"
            | "constructor"
    ) {
        return true;
    }

    matches!(
        (kind, parent_kind),
        ("identifier", "function_declaration")
            | ("identifier", "method_definition")
            | ("identifier", "function_item")
            | ("identifier", "call_expression")
            | ("property_identifier", "function_declaration")
            | ("property_identifier", "method_definition")
    )
}

fn is_variable_kind(kind: &str, parent_kind: &str) -> bool {
    matches!(
        kind,
        "identifier"
            | "property_identifier"
            | "field_identifier"
            | "attribute_name"
            | "property_name"
            | "variable_name"
            | "module_identifier"
    ) || matches!(
        parent_kind,
        "pair" | "object_pair" | "assignment_expression" | "lexical_declaration"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detect_language_returns_correct_language() {
        assert_eq!(detect_language("main.ts"), Some("typescript"));
        assert_eq!(detect_language("app.tsx"), Some("typescript"));
        assert_eq!(detect_language("index.js"), Some("javascript"));
        assert_eq!(detect_language("component.jsx"), Some("javascript"));
        assert_eq!(detect_language("config.json"), Some("json"));
        assert_eq!(detect_language("config.yaml"), Some("yaml"));
        assert_eq!(detect_language("config.yml"), Some("yaml"));
        assert_eq!(detect_language("App.swift"), Some("swift"));
        assert_eq!(detect_language("main.rs"), Some("rust"));
        assert_eq!(detect_language("main.dart"), Some("dart"));
        assert_eq!(detect_language("index.html"), Some("html"));
        assert_eq!(detect_language("styles.css"), Some("css"));
        assert_eq!(detect_language("script.py"), Some("python"));
        assert_eq!(detect_language("no_extension"), None);
    }

    #[test]
    fn tokenize_unsupported_language_returns_error() {
        let result = tokenize("hello", "kotlin");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("未対応の言語"));
    }

    #[test]
    fn tokenize_javascript_variable_declaration() {
        let code = "const x = 42;";
        let tokens = tokenize(code, "javascript").unwrap();
        assert!(!tokens.is_empty());

        let const_token = tokens.iter().find(|t| t.start_col == 0 && t.end_col == 5);
        assert!(const_token.is_some());
        assert_eq!(const_token.unwrap().token_type, TokenType::Keyword);

        let num_token = tokens.iter().find(|t| t.token_type == TokenType::Number);
        assert!(num_token.is_some());
    }

    #[test]
    fn tokenize_typescript_function() {
        let code = "function greet(name: string): string { return \"hello\"; }";
        let tokens = tokenize(code, "typescript").unwrap();
        assert!(!tokens.is_empty());
        assert!(tokens.iter().any(|t| t.token_type == TokenType::Keyword));
        assert!(tokens.iter().any(|t| t.token_type == TokenType::String));
    }

    #[test]
    fn tokenize_supported_languages_smoke() {
        let cases = vec![
            ("json", r#"{"name":"blink","v":1}"#),
            ("yaml", "name: blink\nversion: 1"),
            ("swift", "func greet(name: String) -> String { return \"hi\" }"),
            ("rust", "fn main() { let x = 1; }"),
            ("dart", "void main() { final x = 1; }"),
            ("html", "<div class=\"app\">hello</div>"),
            ("css", ".app { color: #fff; margin: 4px; }"),
            ("python", "def greet(name):\n    return f\"hi {name}\""),
        ];

        for (lang, src) in cases {
            let tokens = tokenize(src, lang).unwrap_or_else(|e| {
                panic!("{lang} tokenize failed: {e}");
            });
            assert!(!tokens.is_empty(), "{lang} token should not be empty");
        }
    }

    #[test]
    fn tokenize_empty_input() {
        let result = tokenize("", "javascript");
        assert!(result.is_ok());
    }
}
