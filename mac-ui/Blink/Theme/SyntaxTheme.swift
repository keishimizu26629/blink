import AppKit

/// TokenType に対応する色を定義するシンタックステーマ（One Dark 風）
enum SyntaxTheme {
    /// TokenType 文字列から NSColor を返す
    /// - Parameter tokenType: Rust 側の TokenType に対応する文字列
    ///   ("Keyword", "String", "Comment", "Type", "Function", "Number", "Operator", "Punctuation", "Variable", "Plain")
    static func color(for tokenType: String) -> NSColor {
        switch tokenType {
        case "Keyword":
            // ピンク / マゼンタ (#C678DD)
            NSColor(red: 0.776, green: 0.471, blue: 0.867, alpha: 1.0)
        case "String":
            // 緑 (#98C379)
            NSColor(red: 0.596, green: 0.765, blue: 0.475, alpha: 1.0)
        case "Comment":
            // グレー (#5C6370)
            NSColor(red: 0.361, green: 0.388, blue: 0.439, alpha: 1.0)
        case "Type":
            // シアン (#56B6C2)
            NSColor(red: 0.337, green: 0.714, blue: 0.761, alpha: 1.0)
        case "Function":
            // 黄 (#E5C07B)
            NSColor(red: 0.898, green: 0.753, blue: 0.482, alpha: 1.0)
        case "Number":
            // オレンジ (#D19A66)
            NSColor(red: 0.820, green: 0.604, blue: 0.400, alpha: 1.0)
        case "Operator":
            // 白 (#ABB2BF)
            NSColor(red: 0.671, green: 0.698, blue: 0.749, alpha: 1.0)
        case "Punctuation":
            // 白（やや暗め） (#ABB2BF)
            NSColor(red: 0.671, green: 0.698, blue: 0.749, alpha: 1.0)
        case "Variable":
            // 赤味白 (#E06C75)
            NSColor(red: 0.878, green: 0.424, blue: 0.459, alpha: 1.0)
        default:
            // Plain / その他: 白 (#ABB2BF)
            NSColor(red: 0.671, green: 0.698, blue: 0.749, alpha: 1.0)
        }
    }

    /// ダークモード背景色 (#282C34)
    static var backgroundColor: NSColor {
        NSColor(red: 0.157, green: 0.173, blue: 0.204, alpha: 1.0)
    }

    /// デフォルトテキスト色 (#ABB2BF)
    static var defaultTextColor: NSColor {
        NSColor(red: 0.671, green: 0.698, blue: 0.749, alpha: 1.0)
    }
}
