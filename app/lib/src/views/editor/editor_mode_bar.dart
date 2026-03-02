import 'package:flutter/material.dart';

import '../../view_models/project_view_model.dart';

class EditorModeBar extends StatelessWidget {
  final EditorDisplayMode mode;
  final bool canShowDiff;
  final VoidCallback onSelectCode;
  final VoidCallback onSelectDiff;

  const EditorModeBar({
    super.key,
    required this.mode,
    required this.canShowDiff,
    required this.onSelectCode,
    required this.onSelectDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.10),
        border: const Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      child: Row(
        children: [
          _modeButton(
            context,
            title: 'Code',
            icon: Icons.description_outlined,
            isSelected: mode == EditorDisplayMode.code,
            onTap: onSelectCode,
            enabled: true,
          ),
          const SizedBox(width: 8),
          _modeButton(
            context,
            title: 'Diff',
            icon: Icons.vertical_split_outlined,
            isSelected: mode == EditorDisplayMode.diff,
            onTap: onSelectDiff,
            enabled: canShowDiff,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha:0.30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
