# Blink - プロジェクトルール

## プロジェクト概要
- **プロダクト名**: Blink（Mac用超軽量コードビューア）
- **技術スタック**: Rust Core + UniFFI + SwiftUI/AppKit
- **アイコン**: `~/Downloads/unnamed.png`

## Docker不使用（Global CLAUDE.mdルールの上書き）
このプロジェクトではDockerを使用しない。理由:
- macOSネイティブアプリ（SwiftUI/AppKit）のため、Dockerコンテナ内でビルド不可
- Rustは `Cargo.toml` + `target/` で依存が自動分離されるため仮想環境不要
- Rustバージョンは `rust-toolchain.toml` でプロジェクト単位に固定

**ビルド・テスト・実行はすべてホストMac上で直接行う。**

## 環境分離
| 端末 | 役割 | Xcode |
|------|------|-------|
| **開発端末（本機）** | コード編集、cargo test、PR作成 | 不要（CLTのみ） |
| **ビルド端末（別Mac）** | xcodebuild → .app 生成 | 必要 |

**この端末では `.app` のビルド・実行は行わない。**

## リポジトリ構成
```
blink/
  .ai/
    requirements.md          # 仕様書（必ず参照）
    plan/blink.md            # 実装計画
    tasks/phase{1-4}-*.md    # Phase別タスク
    coding-rules/            # コーディング規約（Codeモード時参照）
  mac-ui/                    # SwiftUI + AppKit（Xcodeプロジェクト）
  core/                      # Rust workspace
    Cargo.toml
    crates/
      core_api/              # UniFFI公開API（FFI境界）
      core_fs/               # file tree, ignore, watch
      core_git/              # blame via git CLI
      core_highlight/        # tree-sitter tokenize
      core_types/            # 共有型（FileNode, TokenSpan, BlameLine）
  scripts/
    build_rust.sh            # Rustビルド（ビルド端末用）
    gen_uniffi.sh            # UniFFI bindings生成
  rust-toolchain.toml        # Rustバージョン固定
```

## 開発フロー
```
コード編集 → cargo test → PR作成 → mainマージ → ビルド端末でpull & build
```

## 開発コマンド（本機で実行するもの）
```bash
# Rustテスト
cargo test --manifest-path core/Cargo.toml

# Rustチェック（コンパイルエラー確認、バイナリ生成なし）
cargo check --manifest-path core/Cargo.toml

# Lint
cargo clippy --manifest-path core/Cargo.toml -- -D warnings

# フォーマット
cargo fmt --manifest-path core/Cargo.toml

# 特定crateのテスト
cargo test -p core_fs --manifest-path core/Cargo.toml
cargo test -p core_api --manifest-path core/Cargo.toml
```

## Rust コーディング規約
- **エディション**: 2021
- **エラー処理**: `Result<T, E>` を使用。`unwrap()` はテストコードのみ許可
- **UniFFI互換**: 公開型は `uniffi::Record` / `uniffi::Enum` に対応する形で定義
- **crate間依存**: 各機能crateは `core_types` にのみ依存。互いに依存しない
- **API設計**: highlight / blame は必ずレンジ引数（start_line, end_line）を持つ
- **非同期**: Swift側で `Task` を使うため、Rust APIはブロッキングでOK（同期関数）

## Swift コーディング規約
- **UI**: SwiftUI（レイアウト） + AppKit（NSTextView表示）
- **非同期**: Rust API呼び出しは必ず `Task { }` で非同期実行（UIスレッドブロック禁止）
- **ファイル配置**: Views/, ViewModels/, Theme/ に分類

## 配布
- **個人・身内運用**（App Store不使用）
- GitHub Releases に `.zip` アップロード
