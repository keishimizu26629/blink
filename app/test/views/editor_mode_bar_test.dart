import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blink/src/views/editor/editor_mode_bar.dart';
import 'package:blink/src/view_models/project_view_model.dart';

void main() {
  group('EditorModeBar', () {
    Widget buildTestWidget({
      EditorDisplayMode mode = EditorDisplayMode.code,
      bool canShowDiff = true,
      VoidCallback? onSelectCode,
      VoidCallback? onSelectDiff,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EditorModeBar(
            mode: mode,
            canShowDiff: canShowDiff,
            onSelectCode: onSelectCode ?? () {},
            onSelectDiff: onSelectDiff ?? () {},
          ),
        ),
      );
    }

    testWidgets('displays Code button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Code'), findsOneWidget);
    });

    testWidgets('displays Diff button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Diff'), findsOneWidget);
    });

    testWidgets('displays Code and Diff icons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.vertical_split_outlined), findsOneWidget);
    });

    testWidgets('Code button calls onSelectCode when tapped',
        (WidgetTester tester) async {
      var codeTapped = false;
      await tester.pumpWidget(buildTestWidget(
        onSelectCode: () => codeTapped = true,
      ));

      await tester.tap(find.text('Code'));
      expect(codeTapped, true);
    });

    testWidgets('Diff button calls onSelectDiff when tapped and enabled',
        (WidgetTester tester) async {
      var diffTapped = false;
      await tester.pumpWidget(buildTestWidget(
        canShowDiff: true,
        onSelectDiff: () => diffTapped = true,
      ));

      await tester.tap(find.text('Diff'));
      expect(diffTapped, true);
    });

    testWidgets('Diff button does not call onSelectDiff when disabled',
        (WidgetTester tester) async {
      var diffTapped = false;
      await tester.pumpWidget(buildTestWidget(
        canShowDiff: false,
        onSelectDiff: () => diffTapped = true,
      ));

      await tester.tap(find.text('Diff'));
      expect(diffTapped, false);
    });

    testWidgets('Diff button has reduced opacity when disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(canShowDiff: false));

      // The Diff button is wrapped in an Opacity widget with 0.4 when disabled.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      // There should be at least one Opacity with 0.4 (the disabled Diff button)
      final hasReducedOpacity =
          opacityWidgets.any((w) => (w.opacity - 0.4).abs() < 0.01);
      expect(hasReducedOpacity, true);
    });

    testWidgets('Code button has full opacity when enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mode: EditorDisplayMode.code));

      // The Code button is always enabled, so its Opacity should be 1.0.
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      final hasFullOpacity =
          opacityWidgets.any((w) => (w.opacity - 1.0).abs() < 0.01);
      expect(hasFullOpacity, true);
    });

    testWidgets('renders with code mode selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mode: EditorDisplayMode.code));
      // Should build without errors
      expect(find.byType(EditorModeBar), findsOneWidget);
    });

    testWidgets('renders with diff mode selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mode: EditorDisplayMode.diff));
      // Should build without errors
      expect(find.byType(EditorModeBar), findsOneWidget);
    });

    testWidgets('contains a Row with buttons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      // The widget should contain Row widgets for layout
      expect(find.byType(Row), findsWidgets);
    });
  });
}
