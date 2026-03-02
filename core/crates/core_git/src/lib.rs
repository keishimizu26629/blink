use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    process::Command,
    sync::{Mutex, OnceLock},
};

use core_types::{BlameLine, GitFileDiff, GitStatus, GitStatusEntry};

static DIFF_CACHE: OnceLock<Mutex<HashMap<String, GitFileDiff>>> = OnceLock::new();

fn diff_cache() -> &'static Mutex<HashMap<String, GitFileDiff>> {
    DIFF_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

#[cfg(target_os = "macos")]
static GIT_BINARY_PATH: OnceLock<String> = OnceLock::new();

#[cfg(target_os = "macos")]
fn resolve_git_binary_path() -> String {
    // App Sandbox では /usr/bin/git が xcrun 経由にフォールバックして失敗するケースがあるため、
    // xcrun を介さない実体 git バイナリを優先する。
    let candidates = [
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
        "/usr/bin/git",
    ];

    candidates
        .iter()
        .find(|path| fs::metadata(path).map(|m| m.is_file()).unwrap_or(false))
        .unwrap_or(&"/usr/bin/git")
        .to_string()
}

fn git_command() -> Command {
    #[cfg(target_os = "macos")]
    {
        let mut command = Command::new(
            GIT_BINARY_PATH
                .get_or_init(resolve_git_binary_path)
                .as_str(),
        );
        // Xcode 実行環境の環境変数を引き継ぐと xcrun 解決に寄ることがあるため除去する。
        command.env_remove("DEVELOPER_DIR");
        command.env_remove("SDKROOT");
        command
    }
    #[cfg(not(target_os = "macos"))]
    {
        Command::new("git")
    }
}

fn resolve_repo_context(file_path: &str) -> Result<(PathBuf, String), String> {
    let path = Path::new(file_path);
    let absolute_path = fs::canonicalize(path)
        .map_err(|e| format!("対象ファイルの正規化に失敗しました: {file_path}: {e}"))?;
    let search_dir = absolute_path
        .parent()
        .ok_or_else(|| format!("対象ファイルの親ディレクトリを取得できません: {file_path}"))?;

    let repo_root_output = git_command()
        .arg("-C")
        .arg(search_dir)
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !repo_root_output.status.success() {
        let stderr = String::from_utf8_lossy(&repo_root_output.stderr);
        return Err(format!("git rev-parse 失敗: {stderr}"));
    }

    let repo_root_raw = String::from_utf8_lossy(&repo_root_output.stdout);
    let repo_root = fs::canonicalize(repo_root_raw.trim())
        .map_err(|e| format!("リポジトリルートの正規化に失敗しました: {e}"))?;

    let relative_path = absolute_path.strip_prefix(&repo_root).map_err(|_| {
        format!(
            "対象ファイルがリポジトリ配下にありません: file={} repo={}",
            absolute_path.display(),
            repo_root.display()
        )
    })?;

    let relative_path = relative_path.to_string_lossy().replace('\\', "/");
    Ok((repo_root, relative_path))
}

fn resolve_repo_root(target_path: &str) -> Result<PathBuf, String> {
    let path = Path::new(target_path);
    let absolute_path = fs::canonicalize(path)
        .map_err(|e| format!("対象パスの正規化に失敗しました: {target_path}: {e}"))?;
    let search_dir = if absolute_path.is_dir() {
        absolute_path.clone()
    } else {
        absolute_path
            .parent()
            .ok_or_else(|| format!("対象パスの親ディレクトリを取得できません: {target_path}"))?
            .to_path_buf()
    };

    let repo_root_output = git_command()
        .arg("-C")
        .arg(&search_dir)
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !repo_root_output.status.success() {
        let stderr = String::from_utf8_lossy(&repo_root_output.stderr);
        return Err(format!("git rev-parse 失敗: {stderr}"));
    }

    let repo_root_raw = String::from_utf8_lossy(&repo_root_output.stdout);
    fs::canonicalize(repo_root_raw.trim())
        .map_err(|e| format!("リポジトリルートの正規化に失敗しました: {e}"))
}

/// git blame --line-porcelain の出力をパースして BlameLine のリストを返す
pub fn blame_file(file_path: &str) -> Result<Vec<BlameLine>, String> {
    let (repo_root, relative_path) = resolve_repo_context(file_path)?;

    let output = git_command()
        .current_dir(&repo_root)
        .args(["blame", "--line-porcelain", "--", &relative_path])
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
pub fn blame_commit_diff(file_path: &str, commit: &str) -> Result<GitFileDiff, String> {
    if file_path.trim().is_empty() {
        return Err("file_path が空です".to_string());
    }
    if commit.trim().is_empty() {
        return Err("commit が空です".to_string());
    }

    let (repo_root, relative_path) = resolve_repo_context(file_path)?;
    let cache_key = format!("{commit}::{}::{relative_path}", repo_root.display());
    if let Some(cached) = diff_cache()
        .lock()
        .map_err(|e| format!("diff cache lock 失敗: {e}"))?
        .get(&cache_key)
        .cloned()
    {
        return Ok(cached);
    }

    let output = git_command()
        .current_dir(&repo_root)
        .args([
            "show",
            "--no-color",
            "--format=",
            commit,
            "--",
            &relative_path,
        ])
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

    let diff = GitFileDiff {
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

/// 対象ファイルの現在差分（staged/unstaged/untracked）を unified diff 文字列で返す
pub fn git_file_diff(file_path: &str) -> Result<GitFileDiff, String> {
    if file_path.trim().is_empty() {
        return Err("file_path が空です".to_string());
    }

    let absolute_path = fs::canonicalize(file_path)
        .map_err(|e| format!("対象ファイルの正規化に失敗しました: {file_path}: {e}"))?;
    let (repo_root, relative_path) = resolve_repo_context(file_path)?;

    let unstaged_output = git_command()
        .current_dir(&repo_root)
        .args(["diff", "--no-color", "--", &relative_path])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !unstaged_output.status.success() {
        let stderr = String::from_utf8_lossy(&unstaged_output.stderr);
        return Err(format!("git diff 失敗: {stderr}"));
    }

    let staged_output = git_command()
        .current_dir(&repo_root)
        .args(["diff", "--no-color", "--cached", "--", &relative_path])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !staged_output.status.success() {
        let stderr = String::from_utf8_lossy(&staged_output.stderr);
        return Err(format!("git diff --cached 失敗: {stderr}"));
    }

    let mut sections: Vec<String> = Vec::new();
    let unstaged_diff = String::from_utf8_lossy(&unstaged_output.stdout).to_string();
    if !unstaged_diff.trim().is_empty() {
        sections.push(unstaged_diff);
    }

    let staged_diff = String::from_utf8_lossy(&staged_output.stdout).to_string();
    if !staged_diff.trim().is_empty() {
        sections.push(staged_diff);
    }

    if sections.is_empty() {
        let untracked_output = git_command()
            .current_dir(&repo_root)
            .args([
                "ls-files",
                "--others",
                "--exclude-standard",
                "--",
                &relative_path,
            ])
            .output()
            .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

        if !untracked_output.status.success() {
            let stderr = String::from_utf8_lossy(&untracked_output.stderr);
            return Err(format!("git ls-files 失敗: {stderr}"));
        }

        if !String::from_utf8_lossy(&untracked_output.stdout)
            .trim()
            .is_empty()
        {
            let absolute_path_text = absolute_path.to_string_lossy().to_string();
            let untracked_diff_output = git_command()
                .current_dir(&repo_root)
                .args([
                    "diff",
                    "--no-color",
                    "--no-index",
                    "--",
                    "/dev/null",
                    &absolute_path_text,
                ])
                .output()
                .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

            let status_code = untracked_diff_output.status.code();
            if !(untracked_diff_output.status.success() || status_code == Some(1)) {
                let stderr = String::from_utf8_lossy(&untracked_diff_output.stderr);
                return Err(format!("git diff --no-index 失敗: {stderr}"));
            }

            let untracked_diff = String::from_utf8_lossy(&untracked_diff_output.stdout).to_string();
            if !untracked_diff.trim().is_empty() {
                sections.push(untracked_diff);
            }
        }
    }

    if sections.is_empty() {
        return Err("差分が見つかりませんでした".to_string());
    }

    let diff_text = sections.join("\n");
    Ok(GitFileDiff {
        commit: "working-tree".to_string(),
        path: file_path.to_string(),
        diff_text,
    })
}

/// リポジトリの変更状態（staged / unstaged / untracked）を返す
pub fn git_status(root_path: &str) -> Result<GitStatus, String> {
    if root_path.trim().is_empty() {
        return Err("root_path が空です".to_string());
    }

    let repo_root = resolve_repo_root(root_path)?;
    let output = git_command()
        .current_dir(&repo_root)
        .args(["status", "--porcelain", "--untracked-files=all"])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("git status 失敗: {stderr}"));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_status_porcelain(&stdout, &repo_root)
}

/// 現在のブランチ名を返す（detached HEADの場合は detached@<short_sha>）
pub fn git_current_branch(root_path: &str) -> Result<String, String> {
    if root_path.trim().is_empty() {
        return Err("root_path が空です".to_string());
    }

    let repo_root = resolve_repo_root(root_path)?;

    let branch_output = git_command()
        .current_dir(&repo_root)
        .args(["branch", "--show-current"])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !branch_output.status.success() {
        let stderr = String::from_utf8_lossy(&branch_output.stderr);
        return Err(format!("git branch --show-current 失敗: {stderr}"));
    }

    let branch_name = String::from_utf8_lossy(&branch_output.stdout)
        .trim()
        .to_string();
    if !branch_name.is_empty() {
        return Ok(branch_name);
    }

    let head_output = git_command()
        .current_dir(&repo_root)
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .map_err(|e| format!("git コマンドの実行に失敗しました: {e}"))?;

    if !head_output.status.success() {
        let stderr = String::from_utf8_lossy(&head_output.stderr);
        return Err(format!("git rev-parse --short HEAD 失敗: {stderr}"));
    }

    let short_sha = String::from_utf8_lossy(&head_output.stdout)
        .trim()
        .to_string();
    if short_sha.is_empty() {
        return Err("ブランチ名を取得できませんでした".to_string());
    }
    Ok(format!("detached@{short_sha}"))
}

fn parse_status_porcelain(input: &str, repo_root: &Path) -> Result<GitStatus, String> {
    let mut staged: Vec<GitStatusEntry> = Vec::new();
    let mut unstaged: Vec<GitStatusEntry> = Vec::new();
    let mut untracked: Vec<GitStatusEntry> = Vec::new();

    for line in input.lines() {
        if line.is_empty() {
            continue;
        }
        if line.len() < 3 {
            continue;
        }

        let bytes = line.as_bytes();
        let x = bytes[0] as char;
        let y = bytes[1] as char;
        let raw_path = line[3..].trim();
        if raw_path.is_empty() {
            continue;
        }

        let relative_path = normalize_status_path(raw_path);
        let absolute_path = repo_root
            .join(relative_path)
            .to_string_lossy()
            .replace('\\', "/");
        let status = format!("{x}{y}");

        if x == '?' && y == '?' {
            untracked.push(GitStatusEntry {
                path: absolute_path,
                status,
            });
            continue;
        }

        if x != ' ' {
            staged.push(GitStatusEntry {
                path: absolute_path.clone(),
                status: status.clone(),
            });
        }
        if y != ' ' {
            unstaged.push(GitStatusEntry {
                path: absolute_path,
                status,
            });
        }
    }

    Ok(GitStatus {
        staged,
        unstaged,
        untracked,
    })
}

fn normalize_status_path(raw_path: &str) -> String {
    let target = if let Some((_, new_path)) = raw_path.split_once(" -> ") {
        new_path
    } else {
        raw_path
    };

    let trimmed = target.trim();
    let without_quotes = trimmed
        .strip_prefix('"')
        .and_then(|s| s.strip_suffix('"'))
        .unwrap_or(trimmed);
    without_quotes.replace("\\\"", "\"")
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
    use std::{fs, path::PathBuf};

    fn repository_file_path() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("src/lib.rs")
    }

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

    #[test]
    fn resolve_repo_context_for_repository_file() {
        let file_path = repository_file_path();
        let file_str = file_path.to_str().unwrap();
        let (repo_root, relative_path) = resolve_repo_context(file_str).unwrap();

        assert!(repo_root.exists());
        assert!(!relative_path.is_empty());
        assert_eq!(relative_path, "core/crates/core_git/src/lib.rs");
    }

    #[test]
    fn resolve_repo_context_non_git_file_returns_error() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();
        let file = tmp_dir.join("sample.txt");
        fs::write(&file, "hello").unwrap();

        let result = resolve_repo_context(file.to_str().unwrap());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("git rev-parse 失敗"));
        let _ = fs::remove_dir_all(tmp_dir);
    }

    /// 実際の git リポジトリで blame_file が動作するテスト
    #[test]
    fn blame_file_on_real_repo() {
        let file_path = repository_file_path();
        let result = blame_file(file_path.to_str().unwrap());
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

    #[test]
    fn git_file_diff_modified_file_returns_unified_diff() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-diff-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();

        let run_git = |args: &[&str]| {
            let output = git_command()
                .current_dir(&tmp_dir)
                .args(args)
                .output()
                .unwrap();
            assert!(
                output.status.success(),
                "git {:?} failed: {}",
                args,
                String::from_utf8_lossy(&output.stderr)
            );
        };

        run_git(&["init"]);
        run_git(&["config", "user.name", "Blink Test"]);
        run_git(&["config", "user.email", "blink@example.com"]);

        let file_path = tmp_dir.join("sample.swift");
        fs::write(&file_path, "let value = 1\n").unwrap();
        run_git(&["add", "sample.swift"]);
        run_git(&["commit", "-m", "initial"]);

        fs::write(&file_path, "let value = 2\n").unwrap();

        let diff = git_file_diff(file_path.to_str().unwrap()).unwrap();
        assert!(diff.diff_text.contains("diff --git"));
        assert!(diff.diff_text.contains("-let value = 1"));
        assert!(diff.diff_text.contains("+let value = 2"));

        let _ = fs::remove_dir_all(tmp_dir);
    }

    #[test]
    fn git_file_diff_non_git_file_returns_error() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-diff-non-git-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();
        let file_path = tmp_dir.join("sample.swift");
        fs::write(&file_path, "let value = 1\n").unwrap();

        let result = git_file_diff(file_path.to_str().unwrap());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("git rev-parse 失敗"));

        let _ = fs::remove_dir_all(tmp_dir);
    }

    #[test]
    fn parse_status_porcelain_classifies_entries() {
        let repo_root = PathBuf::from("/tmp/blink-repo");
        let input = " M src/working.swift\nM  src/staged.swift\nMM src/both.swift\nR  src/old_name.swift -> src/new_name.swift\n?? src/new_file.swift\n";

        let status = parse_status_porcelain(input, &repo_root).unwrap();

        assert_eq!(status.staged.len(), 3);
        assert_eq!(status.unstaged.len(), 2);
        assert_eq!(status.untracked.len(), 1);

        assert_eq!(status.staged[0].status, "M ");
        assert!(status.staged[0].path.ends_with("/src/staged.swift"));
        assert!(status.unstaged[0].path.ends_with("/src/working.swift"));
        assert!(status.untracked[0].path.ends_with("/src/new_file.swift"));
        assert!(status.staged[2].path.ends_with("/src/new_name.swift"));
    }

    #[test]
    fn parse_status_porcelain_empty_returns_no_entries() {
        let repo_root = PathBuf::from("/tmp/blink-repo");
        let status = parse_status_porcelain("", &repo_root).unwrap();
        assert!(status.staged.is_empty());
        assert!(status.unstaged.is_empty());
        assert!(status.untracked.is_empty());
    }

    #[test]
    fn git_status_non_git_directory_returns_error() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-status-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();
        let result = git_status(tmp_dir.to_str().unwrap());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("git rev-parse 失敗"));
        let _ = fs::remove_dir_all(tmp_dir);
    }

    #[test]
    fn git_current_branch_returns_non_empty_for_git_repo() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-branch-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();

        let run_git = |args: &[&str]| {
            let output = git_command()
                .current_dir(&tmp_dir)
                .args(args)
                .output()
                .unwrap();
            assert!(
                output.status.success(),
                "git {:?} failed: {}",
                args,
                String::from_utf8_lossy(&output.stderr)
            );
        };

        run_git(&["init"]);
        run_git(&["config", "user.name", "Blink Test"]);
        run_git(&["config", "user.email", "blink@example.com"]);
        fs::write(tmp_dir.join("sample.swift"), "let value = 1\n").unwrap();
        run_git(&["add", "sample.swift"]);
        run_git(&["commit", "-m", "initial"]);

        let branch = git_current_branch(tmp_dir.to_str().unwrap()).unwrap();
        assert!(!branch.trim().is_empty());

        let _ = fs::remove_dir_all(tmp_dir);
    }

    #[test]
    fn git_current_branch_non_git_directory_returns_error() {
        let tmp_dir = std::env::temp_dir().join(format!(
            "blink-core-git-branch-non-git-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&tmp_dir).unwrap();

        let result = git_current_branch(tmp_dir.to_str().unwrap());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("git rev-parse 失敗"));

        let _ = fs::remove_dir_all(tmp_dir);
    }
}
