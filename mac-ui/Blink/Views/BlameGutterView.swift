import SwiftUI

/// Blame 情報を行ごとに表示するガタービュー
struct BlameGutterView: View {
    let blameLines: [BlameLineInfo]
    let lineHeight: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blameLines.enumerated()), id: \.offset) { index, blame in
                let showInfo = shouldShowInfo(at: index)
                HStack(spacing: 4) {
                    if showInfo {
                        Text(shortAuthor(blame.author))
                            .frame(width: 60, alignment: .leading)
                            .lineLimit(1)
                        Text(relativeDate(from: blame.authorTime))
                            .frame(width: 50, alignment: .trailing)
                            .lineLimit(1)
                    } else {
                        Spacer()
                            .frame(width: 114)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(height: lineHeight)
            }
        }
        .padding(.horizontal, 4)
    }

    /// 同一コミットの連続行は最初の行のみ表示
    private func shouldShowInfo(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return blameLines[index].commit != blameLines[index - 1].commit
    }

    /// 著者名を短縮（最大8文字）
    private func shortAuthor(_ name: String) -> String {
        if name.count <= 8 {
            return name
        }
        return String(name.prefix(7)) + "…"
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

/// Blame行情報（Swift側モデル）
struct BlameLineInfo: Identifiable {
    let id = UUID()
    let line: UInt32
    let author: String
    let authorTime: Int64
    let summary: String
    let commit: String
}
