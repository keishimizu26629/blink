import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/syntax_theme.dart';
import '../view_models/project_view_model.dart';
import 'editor/code_text_view.dart';
import 'editor/diff_content_view.dart';
import 'editor/editor_mode_bar.dart';
import 'sidebar/project_tree_view.dart';
import 'sidebar/sidebar_activity_bar.dart';
import 'sidebar/source_control_view.dart';
import 'widgets/appearance_settings.dart';
import 'widgets/branch_status_badge.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  double _sidebarWidth = 250;
  static const _minSidebarWidth = 200.0;
  static const _maxSidebarWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(projectViewModelProvider);

    return Scaffold(
      body: Column(
        children: [
          // Toolbar
          _AppToolbar(
            rootDirectoryName: vm.rootDirectoryName,
            onOpenFolder: () => _openFolder(vm),
            onOpenAppearanceSettings: () => _openAppearanceSettings(context),
          ),
          // Main content
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // Sidebar
                    SizedBox(
                      width: _sidebarWidth,
                      child: Container(
                        color: AppTheme.sidebarBackgroundColor,
                        child: Column(
                          children: [
                            SidebarActivityBar(
                              selectedMode: vm.sidebarMode,
                              onSelectMode: vm.setSidebarMode,
                              onRefreshSourceControl: vm.refreshGitStatus,
                            ),
                            Expanded(
                              child: vm.sidebarMode == SidebarMode.explorer
                                  ? ProjectTreeView(
                                      nodes: vm.rootNodes,
                                      selectedFileId: vm.selectedFile?.id,
                                      onSelectFile: (node) =>
                                          vm.selectFile(node),
                                      onToggleDir: (node) => vm.toggleDir(node),
                                    )
                                  : SourceControlView(
                                      status: vm.gitStatusResult,
                                      isLoading: vm.isGitStatusLoading,
                                      errorMessage: vm.gitStatusErrorMessage,
                                      formatPath: vm.displayPathForSidebar,
                                      onSelectPath: vm.requestDiffForPath,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Resizable divider
                    GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + details.delta.dx)
                              .clamp(_minSidebarWidth, _maxSidebarWidth);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: Container(
                          width: 1,
                          color: AppTheme.dividerColor,
                        ),
                      ),
                    ),
                    // Detail area
                    Expanded(child: _DetailArea(vm: vm)),
                  ],
                ),
                // Branch status badge (bottom-left overlay)
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: BranchStatusBadge(
                    branchName: vm.activeBranchName,
                    hasProject: vm.rootDirectoryName != null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder(ProjectViewModel vm) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await vm.openProject(result);
    }
  }

  Future<void> _openAppearanceSettings(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final vm = ref.watch(projectViewModelProvider);
            return Dialog(
              child: AppearanceSettings(
                windowOpacity: vm.windowOpacity,
                isBringToFrontHotkeyEnabled: vm.isBringToFrontHotkeyEnabled,
                bringToFrontShortcut: vm.bringToFrontShortcut,
                onOpacityChanged: (value) => vm.updateWindowOpacity(value),
                onHotkeyEnabledChanged: (value) =>
                    vm.updateBringToFrontHotkeyEnabled(value),
                onShortcutChanged: (value) =>
                    vm.updateBringToFrontShortcut(value),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppToolbar extends StatelessWidget {
  final String? rootDirectoryName;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenAppearanceSettings;

  const _AppToolbar({
    required this.rootDirectoryName,
    required this.onOpenFolder,
    required this.onOpenAppearanceSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.toolbarBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          Text(
            rootDirectoryName ?? 'フォルダ未選択',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                tooltip: 'Open Folder',
                onPressed: onOpenFolder,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: '表示設定',
                onPressed: onOpenAppearanceSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailArea extends StatelessWidget {
  final ProjectViewModel vm;

  const _DetailArea({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.fileContent == null) {
      return Container(
        color: SyntaxTheme.backgroundColor,
        child: Center(
          child: Text(
            'フォルダまたはファイルを選択してください',
            style: TextStyle(
              fontSize: 16,
              color: SyntaxTheme.defaultTextColor.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    return Container(
      color: SyntaxTheme.backgroundColor,
      child: Column(
        children: [
          EditorModeBar(
            mode: vm.editorDisplayMode,
            canShowDiff:
                vm.selectedFile != null ||
                vm.selectedDiff != null ||
                vm.isDiffLoading ||
                (vm.diffErrorMessage?.isNotEmpty ?? false),
            onSelectCode: vm.switchToCodeMode,
            onSelectDiff: vm.requestDiffForCurrentFile,
          ),
          Expanded(
            child: vm.editorDisplayMode == EditorDisplayMode.diff
                ? DiffContentView(
                    diff: vm.selectedDiff,
                    isLoading: vm.isDiffLoading,
                    errorMessage: vm.diffErrorMessage,
                    tokens: vm.diffHighlightTokens,
                  )
                : CodeTextView(
                    text: vm.fileContent!,
                    tokens: vm.highlightTokens,
                    onVisibleLineRangeChange: (startLine, endLine) {
                      vm.updateVisibleRange(
                        startLine: startLine,
                        endLine: endLine,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
