import 'package:flutter/material.dart';

import '../../theme/syntax_theme.dart';

class BranchStatusBadge extends StatelessWidget {
  final String? branchName;
  final bool hasProject;

  const BranchStatusBadge({
    super.key,
    required this.branchName,
    required this.hasProject,
  });

  @override
  Widget build(BuildContext context) {
    final label = (branchName != null && branchName!.trim().isNotEmpty)
        ? branchName!
        : hasProject
            ? 'No Branch'
            : 'No Project';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fork_right, size: 11, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: SyntaxTheme.defaultTextColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
