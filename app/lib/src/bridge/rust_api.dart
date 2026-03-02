import 'generated/dart_api.dart' as api;

/// Rust Core API の薄いラッパー
class RustApi {
  RustApi._();

  static Future<String> openProject({required String rootPath}) =>
      api.openProject(rootPath: rootPath);

  static Future<List<api.DartFileNode>> listDir({
    required String rootPath,
    required String dirPath,
  }) =>
      api.listDir(rootPath: rootPath, dirPath: dirPath);

  static Future<String> readFile({required String path}) =>
      api.readFile(path: path);

  static Future<List<api.DartTokenSpan>> highlightRange({
    required String path,
    required int startLine,
    required int endLine,
  }) =>
      api.highlightRange(path: path, startLine: startLine, endLine: endLine);

  static Future<List<api.DartBlameLine>> blameRange({
    required String path,
    required int startLine,
    required int endLine,
  }) =>
      api.blameRange(path: path, startLine: startLine, endLine: endLine);

  static Future<api.DartGitFileDiff> blameCommitDiff({
    required String path,
    required String commit,
  }) =>
      api.blameCommitDiff(path: path, commit: commit);

  static Future<api.DartGitFileDiff> gitFileDiff({required String path}) =>
      api.gitFileDiff(path: path);

  static Future<api.DartGitStatus> gitStatus({required String rootPath}) =>
      api.gitStatus(rootPath: rootPath);

  static Future<String> gitCurrentBranch({required String rootPath}) =>
      api.gitCurrentBranch(rootPath: rootPath);
}
