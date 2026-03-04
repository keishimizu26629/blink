String _normalizeSeparators(String path) => path.replaceAll('\\', '/');

bool _isWindowsLikePath(String path) {
  final normalized = _normalizeSeparators(path);
  return RegExp(r'^[A-Za-z]:/').hasMatch(normalized) ||
      normalized.startsWith('//');
}

String _trimTrailingSeparators(String path) {
  final normalized = _normalizeSeparators(path);
  if (normalized == '/') return normalized;
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

String _normalizeForCompare(String path) {
  final normalized = _trimTrailingSeparators(path);
  if (_isWindowsLikePath(normalized)) {
    return normalized.toLowerCase();
  }
  return normalized;
}

String displayPathForSidebar({
  required String absolutePath,
  required String rootPath,
}) {
  if (rootPath.isEmpty) return absolutePath;

  final normalizedPath = _trimTrailingSeparators(absolutePath);
  final normalizedRoot = _trimTrailingSeparators(rootPath);
  final comparePath = _normalizeForCompare(normalizedPath);
  final compareRoot = _normalizeForCompare(normalizedRoot);
  final rootPrefix = '$compareRoot/';

  if (comparePath.startsWith(rootPrefix)) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return absolutePath;
}

bool isPathInRoot({required String path, required String rootPath}) {
  final normalizedPath = _trimTrailingSeparators(path);
  final normalizedRoot = _trimTrailingSeparators(rootPath);

  final comparePath = _normalizeForCompare(normalizedPath);
  final compareRoot = _normalizeForCompare(normalizedRoot);
  return comparePath == compareRoot || comparePath.startsWith('$compareRoot/');
}

String displayRootDirectoryName(String path) {
  final normalized = _trimTrailingSeparators(path.trim());
  if (normalized.isEmpty) return '';
  final lastComponent = normalized.split('/').last;
  return lastComponent.isEmpty ? normalized : lastComponent;
}
