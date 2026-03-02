import Foundation
import SwiftUI

/// Blame 情報を行ごとに表示するガタービュー
struct BlameGutterView: View {
    let blameLines: [BlameLine]
    let onSelectLine: (BlameLine) -> Void
    let lineHeight: CGFloat = 18
    private let lineNumberWidth: CGFloat = 34
    private let authorWidth: CGFloat = 60
    private let dateWidth: CGFloat = 50
    private let baseTextColor = Color.white

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blameLines.enumerated()), id: \.offset) { _, blame in
                Button {
                    NSLog("[BlameGutterView:tap] line=%u commit=%@", blame.line, blame.commit)
                    onSelectLine(blame)
                } label: {
                    HStack(spacing: 6) {
                        Text("\(blame.line)")
                            .frame(width: lineNumberWidth, alignment: .trailing)
                            .foregroundStyle(baseTextColor.opacity(0.52))
                            .lineLimit(1)

                        Text(displayAuthor(blame))
                            .frame(width: authorWidth, alignment: .leading)
                            .foregroundStyle(baseTextColor.opacity(0.82))
                            .lineLimit(1)
                        Text(relativeDate(from: blame.authorTime))
                            .frame(width: dateWidth, alignment: .trailing)
                            .foregroundStyle(baseTextColor.opacity(0.68))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: lineHeight)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.20))
    }

    /// 著者名を短縮（最大8文字）
    private func shortAuthor(_ name: String) -> String {
        if name.count <= 8 {
            return name
        }
        return String(name.prefix(7)) + "…"
    }

    private func displayAuthor(_ blame: BlameLine) -> String {
        let trimmed = blame.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return shortAuthor(trimmed)
        }
        return blame.commit
    }

    /// エポック秒から相対日付文字列を生成
    private func relativeDate(from epoch: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let now = Date()
        let interval = now.timeIntervalSince(date)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        let weeks = Int(interval / 604_800)
        let months = Int(interval / 2_592_000)
        let years = Int(interval / 31_536_000)

        if years > 0 { return "\(years)y ago" }
        if months > 0 { return "\(months)mo ago" }
        if weeks > 0 { return "\(weeks)w ago" }
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        if minutes > 0 { return "\(minutes)m ago" }
        return "now"
    }
}
