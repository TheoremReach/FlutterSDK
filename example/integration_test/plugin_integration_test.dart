// The plugin's round trip on a device or simulator: the Dart API starts the native SDK for one of TheoremReach's test
// apps, and the SDK's survey check comes back through the plugin. CI runs it on Android's emulator and iOS's
// simulator.
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:theoremreach_sdk/theoremreach_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("the native SDK starts, and its survey check reaches Dart", (WidgetTester tester) async {
    final String apiKey = Platform.isIOS ? '30a936dc7328c6e2bef47c0b1e13' : 'f4bfc509292953a3cf4274038763';
    final Future<bool> checked = TheoremReach.onSurveyAvailable.first.timeout(const Duration(seconds: 60));

    await TheoremReach.initialize(apiKey: apiKey, userId: 'FLUTTER_EXAMPLE_CI_USER');
    final bool available = await checked;

    expect(await TheoremReach.isSurveyAvailable(), available);
  });
}
