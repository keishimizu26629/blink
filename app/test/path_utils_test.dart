import 'package:blink/src/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathUtils', () {
    test('displayPathForSidebar strips unix root prefix', () {
      expect(
        displayPathForSidebar(
          absolutePath: '/Users/me/blink/lib/main.dart',
          rootPath: '/Users/me/blink',
        ),
        'lib/main.dart',
      );
    });

    test('displayPathForSidebar strips windows root prefix', () {
      expect(
        displayPathForSidebar(
          absolutePath: r'C:\work\blink\lib\main.dart',
          rootPath: r'C:\work\blink',
        ),
        'lib/main.dart',
      );
    });

    test('isPathInRoot supports windows path separators', () {
      expect(
        isPathInRoot(
          path: r'C:\work\blink\lib\main.dart',
          rootPath: r'C:\work\blink',
        ),
        isTrue,
      );
    });

    test('displayRootDirectoryName returns last segment for windows path', () {
      expect(displayRootDirectoryName(r'C:\work\blink'), 'blink');
    });
  });
}
