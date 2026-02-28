use std::{
    collections::HashMap,
    process::Command,
    sync::{Mutex, OnceLock},
};

use core_types::{BlameDiff, BlameLine};

static DIFF_CACHE: OnceLock<Mutex<HashMap<String, BlameDiff>>> = OnceLock::new();

fn diff_cache() -> &'static Mutex<HashMap<String, BlameDiff>> {
    DIFF_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// git blame --line-porcelain の出力をパースして BlameLine のリストを返す
pub fn blame_file(file_path: &str) -> Result<Vec<BlameLine>, String> {
    let output = Command::new("git")
        .args(["blame", "--line-porcelain", file_path])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("git blame 失敗: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_porcelain(&stdout)
}

/// 指定コミットの対象ファイル差分を unified diff 文字列で返す
pub fn blame_commit_diff(file_path: &str, commit: &str) -> Result<BlameDiff, String> {
    if file_path.trim().is_empty() {
        return Err("file_path が空です".to_string());
    }
    if commit.trim().is_empty() {
        return Err("commit が空です".to_string());
    }

    let cache_key = format!("{commit}::{file_path}");
    if let Some(cached) = diff_cache()
        .lock()
        .map_err(|e| format!("diff cache lock 失敗: {e}"))?
        .get(&cache_key)
        .cloned()
    {
        return Ok(cached);
    }

    let output = Command::new("git")
        .args(["show", "--no-color", "--format=", commit, "--", file_path])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("git show 失敗: {stderr}"));
    }

    let diff_text = String::from_utf8_lossy(&output.stdout).to_string();
    if diff_text.trim().is_empty() {
        return Err("差分が見つかりませんでした".to_string());
    }

    let diff = BlameDiff {
        commit: commit.to_string(),
        path: file_path.to_string(),
        diff_text,
    };

    diff_cache()
        .lock()
        .map_err(|e| format!("diff cache lock 失敗: {e}"))?
        .insert(cache_key, diff.clone());
    Ok(diff)
}

/// line-porcelain 形式の出力をパースする
fn parse_porcelain(input: &str) -> Result<Vec<BlameLine>, String> {
    let mut results = Vec::new();
    let mut lines = input.lines().peekable();

    while let Some(header) = lines.next() {
        let header = header.trim_end();
        if header.is_empty() {
            continue;
        }

        // ヘッダー行: <40-char-hash> <orig_line> <final_line> [<num_lines>]
        let parts: Vec<&str> = header.split_whitespace().collect();
        if parts.len() < 3 {
            continue;
        }

        let commit_hash = parts[0];
        // commit hash は40文字のhex
        if commit_hash.len() != 40 || !commit_hash.chars().all(|c| c.is_ascii_hexdigit()) {
            continue;
        }

        let final_line: u32 = parts[2]
            .parse()
            .map_err(|_| format!("行番号のパースに失敗: {}", parts[2]))?;

        let commit = commit_hash[..7].to_string();
        let mut author = String::new();
        let mut author_time: i64 = 0;
        let mut summary = String::new();

        // メタデータ行を読む（TAB始まりの行まで）
        for line in lines.by_ref() {
            if line.starts_with('\t') {
                // TAB始まりはコード行 → このエントリ完了
                break;
            }

            if let Some(val) = line.strip_prefix("author ") {
                author = val.to_string();
            } else if let Some(val) = line.strip_prefix("author-time ") {
                author_time = val.parse().unwrap_or(0);
            } else if let Some(val) = line.strip_prefix("summary ") {
                summary = val.to_string();
            }
        }

        results.push(BlameLine {
            line: final_line,
            author,
            author_time,
            summary,
            commit,
        });
    }

    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// ハードコードした porcelain 出力で基本パースをテスト
    #[test]
    fn parse_porcelain_basic() {
        let input = "\
abcdef1234567890abcdef1234567890abcdef12 1 1 3
author Alice
author-mail <alice@example.com>
author-time 1700000000
author-tz +0900
committer Alice
committer-mail <alice@example.com>
committer-time 1700000000
committer-tz +0900
summary initial commit
filename src/main.rs
\tuse std::env;
abcdef1234567890abcdef1234567890abcdef12 2 2
author Alice
author-mail <alice@example.com>
author-time 1700000000
author-tz +0900
committer Alice
committer-mail <alice@example.com>
committer-time 1700000000
committer-tz +0900
summary initial commit
filename src/main.rs
\t
abcdef1234567890abcdef1234567890abcdef12 3 3
author Alice
author-mail <alice@example.com>
author-time 1700000000
author-tz +0900
committer Alice
committer-mail <alice@example.com>
committer-time 1700000000
committer-tz +0900
summary initial commit
filename src/main.rs
\tfn main() {}
";

        let result = parse_porcelain(input).unwrap();
        assert_eq!(result.len(), 3);

        assert_eq!(result[0].line, 1);
        assert_eq!(result[0].author, "Alice");
        assert_eq!(result[0].author_time, 1700000000);
        assert_eq!(result[0].summary, "initial commit");
        assert_eq!(result[0].commit, "abcdef1");

        assert_eq!(result[1].line, 2);
        assert_eq!(result[2].line, 3);
    }

    /// 複数の異なるコミットを含む porcelain 出力のパーステスト
    #[test]
    fn parse_porcelain_multiple_commits() {
        let input = "\
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1 1 1
author Alice
author-time 1700000000
summary first commit
filename lib.rs
\tline1
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 1 2 1
author Bob
author-time 1700100000
summary second commit
filename lib.rs
\tline2
";

        let result = parse_porcelain(input).unwrap();
        assert_eq!(result.len(), 2);

        assert_eq!(result[0].author, "Alice");
        assert_eq!(result[0].commit, "aaaaaaa");
        assert_eq!(result[0].summary, "first commit");

        assert_eq!(result[1].author, "Bob");
        assert_eq!(result[1].commit, "bbbbbbb");
        assert_eq!(result[1].line, 2);
        assert_eq!(result[1].author_time, 1700100000);
    }

    /// 空入力の場合は空Vecを返す
    #[test]
    fn parse_porcelain_empty_input() {
        let result = parse_porcelain("").unwrap();
        assert!(result.is_empty());
    }

    /// 不正なヘッダー行はスキップされる
    #[test]
    fn parse_porcelain_invalid_header_skipped() {
        let input = "not-a-valid-header\n\tsome content\n";
        let result = parse_porcelain(input).unwrap();
        assert!(result.is_empty());
    }

    /// 実際の git リポジトリで blame_file が動作するテスト
    #[test]
    fn blame_file_on_real_repo() {
        // このテストファイル自身を blame する（git 管理下のため）
        let result = blame_file(file!());
        // CI 環境や浅いクローンでは失敗する可能性があるのでエラーは許容
        if let Ok(lines) = result {
            assert!(!lines.is_empty());
            // 各行に基本情報が設定されていることを確認
            for line in &lines {
                assert!(!line.commit.is_empty());
                assert!(line.line > 0);
            }
        }
    }

    /// 存在しないファイルに対してはエラーを返す
    #[test]
    fn blame_file_nonexistent() {
        let result = blame_file("/nonexistent/path/file.rs");
        assert!(result.is_err());
    }

    /// 無効コミットに対する差分取得はエラーを返す
    #[test]
    fn blame_commit_diff_invalid_commit_returns_err() {
        let result = blame_commit_diff(file!(), "this-is-not-a-commit");
        assert!(result.is_err());
    }

    /// 空入力はバリデーションエラーにする
    #[test]
    fn blame_commit_diff_empty_args_return_err() {
        assert!(blame_commit_diff("", "abc1234").is_err());
        assert!(blame_commit_diff(file!(), "").is_err());
    }
}
