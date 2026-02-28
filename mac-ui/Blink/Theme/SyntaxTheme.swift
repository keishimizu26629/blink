import AppKit

/// TokenType に対応する高コントラストの黒基調シンタックステーマ
enum SyntaxTheme {
    /// UniFFI 生成の TokenType enum から NSColor を返す
    static func color(for tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            // 赤寄りピンク (#FF7B72)
            NSColor(red: 1.000, green: 0.482, blue: 0.447, alpha: 1.0)
        case .string:
            // 明るいグリーン (#7EE787)
            NSColor(red: 0.494, green: 0.906, blue: 0.529, alpha: 1.0)
        case .comment:
            // コメントグレー (#8B949E)
            NSColor(red: 0.545, green: 0.580, blue: 0.620, alpha: 1.0)
        case .type:
            // シアンブルー (#79C0FF)
            NSColor(red: 0.475, green: 0.753, blue: 1.000, alpha: 1.0)
        case .function:
            // パープル (#D2A8FF)
            NSColor(red: 0.824, green: 0.659, blue: 1.000, alpha: 1.0)
        case .number:
            // ゴールド (#F2CC60)
            NSColor(red: 0.949, green: 0.800, blue: 0.376, alpha: 1.0)
        case .operator:
            // ライトグレー (#E6EDF3)
            NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
        case .punctuation:
            // ミディアムグレー (#C9D1D9)
            NSColor(red: 0.788, green: 0.820, blue: 0.851, alpha: 1.0)
        case .variable:
            // オレンジ (#FFA657)
            NSColor(red: 1.000, green: 0.651, blue: 0.341, alpha: 1.0)
        case .plain:
            // ライトグレー (#E6EDF3)
            defaultTextColor
        }
    }

    /// 背景色 (#0B0D10)
    static var backgroundColor: NSColor {
        NSColor(red: 0.043, green: 0.051, blue: 0.063, alpha: 1.0)
    }

    /// デフォルトテキスト色 (#E6EDF3)
    static var defaultTextColor: NSColor {
        NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
    }

    /// 行番号色 (#9BA6B2)
    static var lineNumberColor: NSColor {
        NSColor(red: 0.608, green: 0.651, blue: 0.698, alpha: 1.0)
    }
}
