import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theoremreach_sdk_example/main.dart';

void main() {
  testWidgets('the example offers each call', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    for (final String label in <String>[
      'Open the reward center',
      'Open it at a placement',
      'Is a survey available?',
      'Use a light title bar',
      'Stop listening for rewards',
      'Open the reward center in 5 s',
      'Start for FLUTTER_EXAMPLE_USER_2 in 5 s',
    ]) {
      final Finder button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((Widget widget) => widget is ButtonStyleButton),
      );
      expect(button, findsOneWidget, reason: label);
    }
  });
}
