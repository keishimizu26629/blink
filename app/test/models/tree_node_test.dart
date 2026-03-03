import 'package:flutter_test/flutter_test.dart';

import 'package:blink/src/bridge/generated/dart_api.dart';
import 'package:blink/src/models/tree_node.dart';

void main() {
  group('TreeNode', () {
    DartFileNode makeFileNode({
      String id = 'file-1',
      String path = '/tmp/src/main.dart',
      String name = 'main.dart',
      bool isDir = false,
    }) {
      return DartFileNode(id: id, path: path, name: name, isDir: isDir);
    }

    group('basic properties', () {
      test('id delegates to fileNode.id', () {
        final node = TreeNode(fileNode: makeFileNode(id: 'abc-123'));
        expect(node.id, 'abc-123');
      });

      test('path delegates to fileNode.path', () {
        final node =
            TreeNode(fileNode: makeFileNode(path: '/home/user/test.rs'));
        expect(node.path, '/home/user/test.rs');
      });

      test('name delegates to fileNode.name', () {
        final node = TreeNode(fileNode: makeFileNode(name: 'lib.rs'));
        expect(node.name, 'lib.rs');
      });

      test('isDir delegates to fileNode.isDir', () {
        final dirNode = TreeNode(fileNode: makeFileNode(isDir: true));
        expect(dirNode.isDir, true);

        final fileNode = TreeNode(fileNode: makeFileNode(isDir: false));
        expect(fileNode.isDir, false);
      });
    });

    group('isExpanded', () {
      test('defaults to false', () {
        final node = TreeNode(fileNode: makeFileNode());
        expect(node.isExpanded, false);
      });

      test('can be set to true on construction', () {
        final node = TreeNode(fileNode: makeFileNode(), isExpanded: true);
        expect(node.isExpanded, true);
      });

      test('can be mutated after creation', () {
        final node = TreeNode(fileNode: makeFileNode());
        expect(node.isExpanded, false);
        node.isExpanded = true;
        expect(node.isExpanded, true);
      });
    });

    group('children', () {
      test('defaults to null', () {
        final node = TreeNode(fileNode: makeFileNode());
        expect(node.children, isNull);
      });

      test('can be set on construction', () {
        final child = TreeNode(fileNode: makeFileNode(id: 'child-1'));
        final parent = TreeNode(
          fileNode: makeFileNode(id: 'parent', isDir: true),
          children: [child],
        );
        expect(parent.children, isNotNull);
        expect(parent.children!.length, 1);
        expect(parent.children!.first.id, 'child-1');
      });

      test('can be assigned empty list', () {
        final node = TreeNode(
          fileNode: makeFileNode(isDir: true),
          children: [],
        );
        expect(node.children, isNotNull);
        expect(node.children!.isEmpty, true);
      });

      test('can add children after creation', () {
        final node = TreeNode(
          fileNode: makeFileNode(isDir: true),
          children: [],
        );
        final child = TreeNode(fileNode: makeFileNode(id: 'new-child'));
        node.children!.add(child);
        expect(node.children!.length, 1);
        expect(node.children!.first.id, 'new-child');
      });

      test('supports nested children (tree structure)', () {
        final grandchild = TreeNode(
          fileNode: makeFileNode(id: 'gc', name: 'deep.dart'),
        );
        final child = TreeNode(
          fileNode: makeFileNode(id: 'c', name: 'src', isDir: true),
          children: [grandchild],
        );
        final root = TreeNode(
          fileNode: makeFileNode(id: 'r', name: 'project', isDir: true),
          children: [child],
        );

        expect(root.children!.first.children!.first.name, 'deep.dart');
      });
    });

    group('fileNode reference', () {
      test('stores the original DartFileNode', () {
        final fileNode = makeFileNode(id: 'ref-test');
        final treeNode = TreeNode(fileNode: fileNode);
        expect(identical(treeNode.fileNode, fileNode), true);
      });
    });
  });
}
