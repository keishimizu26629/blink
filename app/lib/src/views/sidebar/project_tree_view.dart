import 'package:flutter/material.dart';

import '../../models/tree_node.dart';

class ProjectTreeView extends StatelessWidget {
  final List<TreeNode> nodes;
  final String? selectedFileId;
  final void Function(TreeNode node) onSelectFile;
  final void Function(TreeNode node) onToggleDir;

  const ProjectTreeView({
    super.key,
    required this.nodes,
    required this.selectedFileId,
    required this.onSelectFile,
    required this.onToggleDir,
  });

  @override
  Widget build(BuildContext context) {
    final flatList = _flatten(nodes, 0);
    return ListView.builder(
      itemCount: flatList.length,
      itemExtent: 28,
      itemBuilder: (context, index) {
        final entry = flatList[index];
        return _FileNodeRow(
          node: entry.node,
          depth: entry.depth,
          selectedFileId: selectedFileId,
          onSelectFile: onSelectFile,
          onToggleDir: onToggleDir,
        );
      },
    );
  }

  /// Flatten the tree into a list (only expanded directories show children)
  List<_FlatEntry> _flatten(List<TreeNode> nodes, int depth) {
    final result = <_FlatEntry>[];
    for (final node in nodes) {
      result.add(_FlatEntry(node: node, depth: depth));
      if (node.isDir && node.isExpanded && node.children != null) {
        result.addAll(_flatten(node.children!, depth + 1));
      }
    }
    return result;
  }
}

class _FlatEntry {
  final TreeNode node;
  final int depth;
  const _FlatEntry({required this.node, required this.depth});
}

class _FileNodeRow extends StatelessWidget {
  final TreeNode node;
  final int depth;
  final String? selectedFileId;
  final void Function(TreeNode) onSelectFile;
  final void Function(TreeNode) onToggleDir;

  const _FileNodeRow({
    required this.node,
    required this.depth,
    required this.selectedFileId,
    required this.onSelectFile,
    required this.onToggleDir,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = node.id == selectedFileId;
    final indent = depth * 16.0;

    return InkWell(
      onTap: () {
        if (node.isDir) {
          onToggleDir(node);
        } else {
          onSelectFile(node);
        }
      },
      child: Container(
        height: 28,
        padding: EdgeInsets.only(left: indent + 8, right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (node.isDir)
              Icon(
                node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: Colors.white70,
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            Icon(
              node.isDir ? Icons.folder : _fileIcon(node.name),
              size: 16,
              color: node.isDir ? const Color(0xFF79C0FF) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'dart' || 'rs' || 'swift' || 'js' || 'ts' || 'jsx' || 'tsx' || 'py' || 'rb' || 'go' => Icons.code,
      'json' || 'yaml' || 'yml' || 'toml' || 'xml' => Icons.data_object,
      'md' || 'txt' || 'rtf' => Icons.description,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' || 'webp' => Icons.image,
      _ => Icons.insert_drive_file,
    };
  }
}
