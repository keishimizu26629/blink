import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../bridge/generated/dart_api.dart';
import '../bridge/rust_api.dart';
import '../models/tree_node.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum SidebarMode { explorer, sourceControl }

enum EditorDisplayMode { code, diff }

enum BringToFrontShortcut {
  shiftOptionSpace('Shift + Option + Space'),
  commandShiftSpace('Command + Shift + Space'),
  commandOptionSpace('Command + Option + Space'),
  controlOptionSpace('Control + Option + Space');

  const BringToFrontShortcut(this.displayName);
  final String displayName;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final projectViewModelProvider = ChangeNotifierProvider<ProjectViewModel>((
  ref,
) {
  return ProjectViewModel();
});

// ---------------------------------------------------------------------------
// ProjectViewModel
// ---------------------------------------------------------------------------

class ProjectViewModel extends ChangeNotifier {
  // -----------------------------------------------------------------------
  // Settings keys (mirrors Swift SettingsKeys)
  // -----------------------------------------------------------------------
  static const _keyWindowOpacity = 'blink.window.opacity';
  static const _keyBringToFrontEnabled =
      'blink.window.bringToFront.hotkey.enabled';
  static const _keyBringToFrontShortcut =
      'blink.window.bringToFront.hotkey.shortcut';

  // -----------------------------------------------------------------------
  // Public state (equivalent to Swift @Published)
  // -----------------------------------------------------------------------

  List<TreeNode> _rootNodes = [];
  List<TreeNode> get rootNodes => _rootNodes;

  TreeNode? _selectedFile;
  TreeNode? get selectedFile => _selectedFile;

  String? _fileContent;
  String? get fileContent => _fileContent;

  List<DartTokenSpan> _highlightTokens = [];
  List<DartTokenSpan> get highlightTokens => _highlightTokens;

  List<DartTokenSpan> _diffHighlightTokens = [];
  List<DartTokenSpan> get diffHighlightTokens => _diffHighlightTokens;

  DartGitFileDiff? _selectedDiff;
  DartGitFileDiff? get selectedDiff => _selectedDiff;

  bool _isDiffLoading = false;
  bool get isDiffLoading => _isDiffLoading;

  String? _diffErrorMessage;
  String? get diffErrorMessage => _diffErrorMessage;

  EditorDisplayMode _editorDisplayMode = EditorDisplayMode.code;
  EditorDisplayMode get editorDisplayMode => _editorDisplayMode;

  SidebarMode _sidebarMode = SidebarMode.explorer;
  SidebarMode get sidebarMode => _sidebarMode;

  DartGitStatus? _gitStatusResult;
  DartGitStatus? get gitStatusResult => _gitStatusResult;

  bool _isGitStatusLoading = false;
  bool get isGitStatusLoading => _isGitStatusLoading;

  String? _gitStatusErrorMessage;
  String? get gitStatusErrorMessage => _gitStatusErrorMessage;

  String? _activeBranchName;
  String? get activeBranchName => _activeBranchName;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _rootDirectoryName;
  String? get rootDirectoryName => _rootDirectoryName;

  double _windowOpacity = 1.0;
  double get windowOpacity => _windowOpacity;

  bool _isBringToFrontHotkeyEnabled = true;
  bool get isBringToFrontHotkeyEnabled => _isBringToFrontHotkeyEnabled;

  BringToFrontShortcut _bringToFrontShortcut =
      BringToFrontShortcut.shiftOptionSpace;
  BringToFrontShortcut get bringToFrontShortcut => _bringToFrontShortcut;

  // -----------------------------------------------------------------------
  // Private state
  // -----------------------------------------------------------------------
  String _rootPath = '';
  int _totalLineCount = 0;

  /// Currently fetched visible range (startLine, endLine).
  (int, int)? _currentVisibleRange;

  /// Generation counter for highlight fetch cancellation.
  int _highlightGeneration = 0;
  HotKey? _registeredBringToFrontHotKey;
  bool _isBringToFrontToggleInProgress = false;
  DateTime? _lastBringToFrontToggleAt;

  // _currentHighlightPath removed (unused, generation counter is sufficient)
  // -----------------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------------

  ProjectViewModel() {
    _loadSettings();
  }

  // -----------------------------------------------------------------------
  // Settings persistence
  // -----------------------------------------------------------------------

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedOpacity = prefs.getDouble(_keyWindowOpacity) ?? 1.0;
    _windowOpacity = _clampOpacity(savedOpacity);

    final savedShortcutName = prefs.getString(_keyBringToFrontShortcut);
    _bringToFrontShortcut = BringToFrontShortcut.values.firstWhere(
      (s) => s.name == savedShortcutName,
      orElse: () => BringToFrontShortcut.shiftOptionSpace,
    );

    // If the key has never been stored, default to true.
    if (prefs.containsKey(_keyBringToFrontEnabled)) {
      _isBringToFrontHotkeyEnabled =
          prefs.getBool(_keyBringToFrontEnabled) ?? true;
    } else {
      _isBringToFrontHotkeyEnabled = true;
    }

    await _applyWindowOpacity(_windowOpacity);
    await _syncBringToFrontHotKeyRegistration();
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Window opacity
  // -----------------------------------------------------------------------

  Future<void> updateWindowOpacity(double value) async {
    final clamped = _clampOpacity(value);
    if ((_windowOpacity - clamped).abs() < 0.0001) return;
    _windowOpacity = clamped;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWindowOpacity, clamped);
    await _applyWindowOpacity(clamped);
  }

  // -----------------------------------------------------------------------
  // Bring-to-front hotkey settings
  // -----------------------------------------------------------------------

  Future<void> updateBringToFrontHotkeyEnabled(bool value) async {
    if (_isBringToFrontHotkeyEnabled == value) return;
    _isBringToFrontHotkeyEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBringToFrontEnabled, value);
    await _syncBringToFrontHotKeyRegistration();
  }

  Future<void> toggleBringToFrontHotkeyEnabled() async {
    await updateBringToFrontHotkeyEnabled(!_isBringToFrontHotkeyEnabled);
  }

  /// Exposed for menu actions. Shares the same logic as the global hotkey.
  Future<void> toggleBringToFrontVisibility() async {
    await _handleBringToFrontHotKeyPressed();
  }

  Future<void> updateBringToFrontShortcut(BringToFrontShortcut shortcut) async {
    if (_bringToFrontShortcut == shortcut) return;
    _bringToFrontShortcut = shortcut;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBringToFrontShortcut, shortcut.name);
    await _syncBringToFrontHotKeyRegistration();
  }

  // -----------------------------------------------------------------------
  // openProject
  // -----------------------------------------------------------------------

  Future<void> openProject(String path) async {
    _rootPath = path;
    _rootDirectoryName = _displayRootDirectoryName(path);
    _highlightGeneration++;

    try {
      await RustApi.openProject(rootPath: path);
      final fileNodes = await RustApi.listDir(rootPath: path, dirPath: path);
      _rootNodes = fileNodes.map((n) => TreeNode(fileNode: n)).toList();
      _selectedFile = null;
      _fileContent = null;
      _highlightTokens = [];
      _diffHighlightTokens = [];
      _selectedDiff = null;
      _isDiffLoading = false;
      _diffErrorMessage = null;
      _editorDisplayMode = EditorDisplayMode.code;
      _gitStatusResult = null;
      _isGitStatusLoading = false;
      _gitStatusErrorMessage = null;
      _currentVisibleRange = null;
      _totalLineCount = 0;
      _errorMessage = null;
      _activeBranchName = null;
      notifyListeners();

      refreshActiveBranch();
      if (_sidebarMode == SidebarMode.sourceControl) {
        refreshGitStatus();
      }
    } catch (e) {
      _rootNodes = [];
      _selectedFile = null;
      _fileContent = null;
      _highlightTokens = [];
      _diffHighlightTokens = [];
      _selectedDiff = null;
      _isDiffLoading = false;
      _diffErrorMessage = null;
      _editorDisplayMode = EditorDisplayMode.code;
      _gitStatusResult = null;
      _isGitStatusLoading = false;
      _gitStatusErrorMessage = null;
      _currentVisibleRange = null;
      _totalLineCount = 0;
      _activeBranchName = null;
      _rootDirectoryName = null;
      _errorMessage = 'フォルダを開けませんでした: $e';
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // selectFile
  // -----------------------------------------------------------------------

  Future<void> selectFile(TreeNode node) async {
    if (node.isDir) return;
    _selectedFile = node;
    notifyListeners();

    try {
      final content = await RustApi.readFile(path: node.path);
      _fileContent = content;
      _totalLineCount = '\n'.allMatches(content).length + 1;
      _highlightGeneration++;
      _currentVisibleRange = null;
      _highlightTokens = [];
      _diffHighlightTokens = [];
      closeDiffPanel();
      notifyListeners();

      final initialEndLine = math.min(_totalLineCount, 220);
      if (initialEndLine >= 1) {
        updateVisibleRange(startLine: 1, endLine: initialEndLine);
      }
      _refreshDiffHighlightTokens(node.path, _totalLineCount);
    } catch (_) {
      _fileContent = null;
      _highlightTokens = [];
      _diffHighlightTokens = [];
      _selectedDiff = null;
      _isDiffLoading = false;
      _diffErrorMessage = null;
      _editorDisplayMode = EditorDisplayMode.code;
      _currentVisibleRange = null;
      _totalLineCount = 0;
      notifyListeners();
    }
  }

  /// Select a file by its absolute path.
  /// If the node is not found in the tree, a fallback TreeNode is created.
  Future<void> selectFileByPath(String path) async {
    if (path.trim().isEmpty) return;

    final existing = _findFileNode(_rootNodes, path);
    if (existing != null) {
      await selectFile(existing);
      return;
    }

    // Fallback: create an ad-hoc node.
    final name = path.split('/').last;
    final fallbackNode = TreeNode(
      fileNode: DartFileNode(
        id: 'git:$path',
        path: path,
        name: name,
        isDir: false,
      ),
    );
    await selectFile(fallbackNode);
  }

  // -----------------------------------------------------------------------
  // toggleDir
  // -----------------------------------------------------------------------

  Future<void> toggleDir(TreeNode node) async {
    if (!node.isDir) return;
    _rootNodes = await _toggleNodeInTree(_rootNodes, node.id);
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Sidebar mode
  // -----------------------------------------------------------------------

  void setSidebarMode(SidebarMode mode) {
    if (_sidebarMode == mode) {
      if (mode == SidebarMode.sourceControl) {
        refreshGitStatus();
      }
      return;
    }
    _sidebarMode = mode;
    notifyListeners();
    if (mode == SidebarMode.sourceControl) {
      refreshGitStatus();
    }
  }

  // -----------------------------------------------------------------------
  // Editor display mode / Diff
  // -----------------------------------------------------------------------

  void switchToCodeMode() {
    _editorDisplayMode = EditorDisplayMode.code;
    notifyListeners();
  }

  void requestDiffForCurrentFile() {
    final path = _selectedFile?.path;
    if (path == null) {
      _diffErrorMessage = 'Diffを表示するファイルを選択してください。';
      _editorDisplayMode = EditorDisplayMode.diff;
      notifyListeners();
      return;
    }
    _loadDiff(path).then((_) {
      _editorDisplayMode = EditorDisplayMode.diff;
      notifyListeners();
    });
  }

  void requestDiffForPath(String path) {
    selectFileByPath(path).then((_) {
      _loadDiff(path).then((_) {
        _editorDisplayMode = EditorDisplayMode.diff;
        notifyListeners();
      });
    });
  }

  void closeDiffPanel() {
    _editorDisplayMode = EditorDisplayMode.code;
    _isDiffLoading = false;
    _diffErrorMessage = null;
    _selectedDiff = null;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Git status / branch
  // -----------------------------------------------------------------------

  Future<void> refreshGitStatus() async {
    if (_rootPath.isEmpty) {
      _gitStatusResult = null;
      _gitStatusErrorMessage = 'プロジェクトを開いてからGitステータスを表示してください。';
      _activeBranchName = null;
      notifyListeners();
      return;
    }

    _isGitStatusLoading = true;
    _gitStatusErrorMessage = null;
    notifyListeners();
    refreshActiveBranch();

    final capturedRootPath = _rootPath;
    try {
      final status = await RustApi.gitStatus(rootPath: capturedRootPath);
      if (capturedRootPath != _rootPath) return;
      _gitStatusResult = _filterGitStatus(status, capturedRootPath);
      _gitStatusErrorMessage = null;
    } catch (e) {
      if (capturedRootPath != _rootPath) return;
      _gitStatusResult = null;
      _gitStatusErrorMessage = 'Gitステータス取得に失敗しました: $e';
    }
    _isGitStatusLoading = false;
    notifyListeners();
  }

  Future<void> refreshActiveBranch() async {
    if (_rootPath.isEmpty) {
      _activeBranchName = null;
      notifyListeners();
      return;
    }

    final capturedRootPath = _rootPath;
    try {
      final branch = await RustApi.gitCurrentBranch(rootPath: capturedRootPath);
      if (capturedRootPath != _rootPath) return;
      final trimmed = branch.trim();
      _activeBranchName = trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      if (capturedRootPath != _rootPath) return;
      _activeBranchName = null;
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Visible range / highlight
  // -----------------------------------------------------------------------

  void updateVisibleRange({required int startLine, required int endLine}) {
    if (_fileContent == null) return;
    if (_selectedFile == null || _selectedFile!.isDir) return;
    if (_totalLineCount <= 0) return;

    final normalizedStart = math.min(math.max(startLine, 1), _totalLineCount);
    final normalizedEnd = math.max(
      normalizedStart,
      math.min(endLine, _totalLineCount),
    );

    const preload = 80;
    final fetchStart = math.max(1, normalizedStart - preload);
    final fetchEnd = math.min(_totalLineCount, normalizedEnd + preload);

    _fetchVisibleRangeIfNeeded(fetchStart, fetchEnd, forceRefresh: false);
  }

  // -----------------------------------------------------------------------
  // Display helpers
  // -----------------------------------------------------------------------

  String displayPathForSidebar(String absolutePath) {
    if (_rootPath.isEmpty) return absolutePath;
    final normalizedRoot = _rootPath.endsWith('/') ? _rootPath : '$_rootPath/';
    if (absolutePath.startsWith(normalizedRoot)) {
      return absolutePath.substring(normalizedRoot.length);
    }
    return absolutePath;
  }

  // -----------------------------------------------------------------------
  // Private: loadDiff
  // -----------------------------------------------------------------------

  Future<void> _loadDiff(String path) async {
    _isDiffLoading = true;
    _diffErrorMessage = null;
    _selectedDiff = null;
    notifyListeners();

    try {
      final diff = await RustApi.gitFileDiff(path: path);
      if (_selectedFile?.path != path) {
        _isDiffLoading = false;
        notifyListeners();
        return;
      }
      _selectedDiff = diff;
      _diffErrorMessage = null;
    } catch (e) {
      if (_selectedFile?.path != path) {
        _isDiffLoading = false;
        notifyListeners();
        return;
      }
      _selectedDiff = null;
      _diffErrorMessage = '差分取得に失敗しました: $e';
    }
    _isDiffLoading = false;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Private: refreshDiffHighlightTokens
  // -----------------------------------------------------------------------

  void _refreshDiffHighlightTokens(String path, int totalLines) {
    if (totalLines <= 0) {
      _diffHighlightTokens = [];
      notifyListeners();
      return;
    }

    final capturedPath = path;
    RustApi.highlightRange(
          path: capturedPath,
          startLine: 1,
          endLine: totalLines,
        )
        .then((tokens) {
          if (_selectedFile?.path != capturedPath) return;
          _diffHighlightTokens = tokens;
          notifyListeners();
        })
        .catchError((_) {
          // Silently ignore highlight errors for diff tokens.
        });
  }

  // -----------------------------------------------------------------------
  // Private: fetchVisibleRangeIfNeeded (with generation-based cancellation)
  // -----------------------------------------------------------------------

  void _fetchVisibleRangeIfNeeded(
    int fetchStart,
    int fetchEnd, {
    required bool forceRefresh,
  }) {
    final path = _selectedFile?.path;
    if (path == null) return;

    final range = (fetchStart, fetchEnd);
    if (!forceRefresh && _currentVisibleRange == range) return;

    _currentVisibleRange = range;
    _highlightGeneration++;
    final generation = _highlightGeneration;
    RustApi.highlightRange(path: path, startLine: fetchStart, endLine: fetchEnd)
        .then((tokens) {
          // Check if this fetch is still relevant.
          if (_highlightGeneration != generation) return;
          if (_selectedFile?.path != path) return;
          _highlightTokens = tokens;
          notifyListeners();
        })
        .catchError((_) {
          // Silently ignore; stale/cancelled highlight requests are expected.
        });
  }

  // -----------------------------------------------------------------------
  // Private: toggleNodeInTree (recursive, with lazy loading)
  // -----------------------------------------------------------------------

  Future<List<TreeNode>> _toggleNodeInTree(
    List<TreeNode> nodes,
    String targetId,
  ) async {
    final result = <TreeNode>[];
    for (final treeNode in nodes) {
      if (treeNode.id == targetId) {
        treeNode.isExpanded = !treeNode.isExpanded;
        if (treeNode.isExpanded && treeNode.children == null) {
          try {
            final fileNodes = await RustApi.listDir(
              rootPath: _rootPath,
              dirPath: treeNode.path,
            );
            treeNode.children = fileNodes
                .map((n) => TreeNode(fileNode: n))
                .toList();
          } catch (_) {
            treeNode.children = [];
          }
        }
        result.add(treeNode);
      } else if (treeNode.isDir && treeNode.children != null) {
        treeNode.children = await _toggleNodeInTree(
          treeNode.children!,
          targetId,
        );
        result.add(treeNode);
      } else {
        result.add(treeNode);
      }
    }
    return result;
  }

  // -----------------------------------------------------------------------
  // Private: findFileNode (recursive search)
  // -----------------------------------------------------------------------

  TreeNode? _findFileNode(List<TreeNode> nodes, String path) {
    for (final node in nodes) {
      if (!node.isDir && node.path == path) return node;
      if (node.children != null) {
        final found = _findFileNode(node.children!, path);
        if (found != null) return found;
      }
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Private: filterGitStatus
  // -----------------------------------------------------------------------

  DartGitStatus _filterGitStatus(DartGitStatus status, String rootPath) {
    final normalizedRoot = rootPath.endsWith('/') ? rootPath : '$rootPath/';
    bool inRoot(DartGitStatusEntry entry) =>
        entry.path == rootPath || entry.path.startsWith(normalizedRoot);

    return DartGitStatus(
      staged: status.staged.where(inRoot).toList(),
      unstaged: status.unstaged.where(inRoot).toList(),
      untracked: status.untracked.where(inRoot).toList(),
    );
  }

  // -----------------------------------------------------------------------
  // Private: clampOpacity
  // -----------------------------------------------------------------------

  static double _clampOpacity(double value) =>
      math.max(0.6, math.min(1.0, value));

  Future<void> _applyWindowOpacity(double value) async {
    try {
      await windowManager.setOpacity(value);
    } catch (_) {
      // Ignore window-manager failures to keep initialization resilient.
    }
  }

  Future<void> _syncBringToFrontHotKeyRegistration() async {
    final previous = _registeredBringToFrontHotKey;
    if (previous != null) {
      try {
        await hotKeyManager.unregister(previous);
      } catch (_) {
        // Ignore unregister failures and continue with re-registration.
      }
      _registeredBringToFrontHotKey = null;
    }

    if (!_isBringToFrontHotkeyEnabled) return;

    final hotKey = _buildBringToFrontHotKey(_bringToFrontShortcut);
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) {
          unawaited(_handleBringToFrontHotKeyPressed());
        },
      );
      _registeredBringToFrontHotKey = hotKey;
    } catch (_) {
      // Keep app usable even when global hotkey registration fails.
    }
  }

  HotKey _buildBringToFrontHotKey(BringToFrontShortcut shortcut) {
    return HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: _hotKeyModifiersForShortcut(shortcut),
      scope: HotKeyScope.system,
    );
  }

  List<HotKeyModifier> _hotKeyModifiersForShortcut(
    BringToFrontShortcut shortcut,
  ) {
    switch (shortcut) {
      case BringToFrontShortcut.shiftOptionSpace:
        return const [HotKeyModifier.shift, HotKeyModifier.alt];
      case BringToFrontShortcut.commandShiftSpace:
        return const [HotKeyModifier.meta, HotKeyModifier.shift];
      case BringToFrontShortcut.commandOptionSpace:
        return const [HotKeyModifier.meta, HotKeyModifier.alt];
      case BringToFrontShortcut.controlOptionSpace:
        return const [HotKeyModifier.control, HotKeyModifier.alt];
    }
  }

  Future<void> _handleBringToFrontHotKeyPressed() async {
    final now = DateTime.now();
    final last = _lastBringToFrontToggleAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 220)) {
      return;
    }
    if (_isBringToFrontToggleInProgress) {
      return;
    }
    _isBringToFrontToggleInProgress = true;
    _lastBringToFrontToggleAt = now;

    try {
      final focused = await windowManager.isFocused();
      final visible = await windowManager.isVisible();
      final minimized = await windowManager.isMinimized();

      // Toggle off when currently frontmost.
      if (focused && visible && !minimized) {
        await windowManager.minimize();
        return;
      }

      if (!visible) {
        await windowManager.show();
      }
      if (minimized) {
        await windowManager.restore();
      }
      await windowManager.focus();
    } catch (e) {
      // Keep app alive even if window manager APIs fail in transient states.
      debugPrint('Bring-to-front hotkey handling failed: $e');
    } finally {
      _isBringToFrontToggleInProgress = false;
    }
  }

  // -----------------------------------------------------------------------
  // Private: displayRootDirectoryName
  // -----------------------------------------------------------------------

  String _displayRootDirectoryName(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return '';
    final lastComponent = normalized.split('/').last;
    return lastComponent.isEmpty ? normalized : lastComponent;
  }

  @override
  void dispose() {
    final hotKey = _registeredBringToFrontHotKey;
    if (hotKey != null) {
      unawaited(hotKeyManager.unregister(hotKey));
      _registeredBringToFrontHotKey = null;
    }
    super.dispose();
  }
}
