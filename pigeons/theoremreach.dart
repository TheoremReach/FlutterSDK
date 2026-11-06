// The channel between the Dart API and the native plugins. After a change, regenerate with
// `dart run pigeon --input pigeons/theoremreach.dart`; CI fails when the generated files differ.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'theoremreach_sdk',
    kotlinOut: 'android/src/main/kotlin/com/theoremreach/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.theoremreach.flutter'),
    swiftOut: 'ios/theoremreach_sdk/Sources/theoremreach_sdk/Messages.g.swift',
  ),
)
/// Calls into the native SDKs, made on the platform's main thread.
@HostApi()
abstract class TheoremReachHostApi {
  void start(String apiKey, String userId);

  void showRewardCenter(String? placementId);

  bool isSurveyAvailable();

  void setLoadingBarColor(String color);

  void setMmpInstallId(String provider, String installId);

  void setNavigationBarText(String text);

  void setNavigationBarColor(String color);

  void setNavigationBarTextColor(String color);
}

/// The native SDKs' callbacks, which the Dart API turns into its streams.
@FlutterApi()
abstract class TheoremReachFlutterApi {
  void onReward(int quantity);

  void onRewardCenterOpened();

  void onRewardCenterClosed();

  void onSurveyAvailable(bool available);
}
