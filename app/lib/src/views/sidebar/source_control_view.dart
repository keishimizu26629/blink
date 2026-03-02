import 'package:flutter/material.dart';

import '../../bridge/generated/dart_api.dart';
import '../../theme/syntax_theme.dart';

class SourceControlView extends StatelessWidget {
  final DartGitStatus? status;
  final bool isLoading;
  final String? errorMessage;
  final String Function(String) formatPath;
  final void Function(String) onSelectPath;

  const SourceControlView({
    super.key,
    required this.status,
    required this.isLoading,
    required this.errorMessage,
    required this.formatPath,
    required this.onSelectPath,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Gitステータスを読み込み中...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (status == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Source Controlを選択するとGitステータスを表示します。',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final s = status!;
    if (s.staged.isEmpty && s.unstaged.isEmpty && s.untracked.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('変更はありません。', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      children: [
        if (s.staged.isNotEmpty) _section('Staged Changes', s.staged, Icons.check_circle, Colors.green),
        if (s.unstaged.isNotEmpty) _section('Changes', s.unstaged, Icons.edit, Colors.orange),
        if (s.untracked.isNotEmpty) _section('Untracked Files', s.untracked, Icons.help_outline, Colors.blue),
      ],
    );
  }

  Widget _section(String title, List<DartGitStatusEntry> entries, IconData icon, Color tint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SyntaxTheme.defaultTextColor.withValues(alpha:0.7),
            ),
          ),
        ),
        ...entries.map((entry) => InkWell(
              onTap: () => onSelectPath(entry.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: tint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatPath(entry.path),
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'JetBrains Mono',
                        color: SyntaxTheme.defaultTextColor.withValues(alpha:0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
