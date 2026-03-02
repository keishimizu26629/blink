import '../bridge/generated/dart_api.dart';

/// ファイルツリーのノード (DartFileNodeのラッパー)
class TreeNode {
  final DartFileNode fileNode;
  List<TreeNode>? children;
  bool isExpanded;

  TreeNode({
    required this.fileNode,
    this.children,
    this.isExpanded = false,
  });

  String get id => fileNode.id;
  String get path => fileNode.path;
  String get name => fileNode.name;
  bool get isDir => fileNode.isDir;
}
