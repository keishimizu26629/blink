import 'package:flutter/material.dart';

import '../../view_models/project_view_model.dart';

class SidebarActivityBar extends StatelessWidget {
  final SidebarMode selectedMode;
  final void Function(SidebarMode mode) onSelectMode;
  final VoidCallback onRefreshSourceControl;

  const SidebarActivityBar({
    super.key,
    required this.selectedMode,
    required this.onSelectMode,
    required this.onRefreshSourceControl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x1F000000), // black.opacity(0.12)
        border: Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _modeButton(
            context,
            icon: Icons.folder_outlined,
            tooltip: 'Explorer',
            mode: SidebarMode.explorer,
          ),
          const SizedBox(width: 8),
          _modeButton(
            context,
            icon: Icons.fork_right,
            tooltip: 'Source Control',
            mode: SidebarMode.sourceControl,
          ),
          const Spacer(),
          if (selectedMode == SidebarMode.sourceControl)
            IconButton(
              icon: const Icon(Icons.refresh, size: 14),
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Gitステータス再取得',
              onPressed: onRefreshSourceControl,
            ),
        ],
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required SidebarMode mode,
  }) {
    final isSelected = selectedMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onSelectMode(mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14),
        ),
      ),
    );
  }
}
