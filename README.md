# TheoremReach Flutter SDK

Monetize your users through rewarded surveys. This package wraps TheoremReach's native SDKs: Android 3.7.2 and iOS
3.7.0.

## Requirements

- Flutter 3.35 or later.
- iOS 15.0 or later. Flutter's app template targets 15.0 from 3.47. An older app raises its Minimum Deployments to
  15.0 on the Runner target in Xcode, and with CocoaPods in `ios/Podfile` too (`platform :ios, '15.0'`).
- Android: `compileSdk` 35 or later (Google sign-in uses Credential Manager), `minSdk` 23 or later. Flutter's own
  defaults are above both.

## Install

```sh
flutter pub add theoremreach_sdk
```

The package bundles the iOS SDK, for Swift Package Manager (Flutter's default from 3.44) and CocoaPods alike, so there's
nothing else to add on iOS. Android takes `com.theoremreach:theoremreach` from Maven Central.

On Flutter 3.35 to 3.43, iOS builds use CocoaPods, those versions' default. An app on one of them that turned Swift
Package Manager on moves to 3.44, or turns it off in its own `pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

## Get your API key

Sign up for a developer account, create an app [here](https://theoremreach.com/developer/apps), and copy its API key.

## Usage

Listen to `onReward` from a part of your app that's alive while the reward center is open, such as its root, and start
the SDK once you know the user:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theoremreach_sdk/theoremreach_sdk.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final StreamSubscription<int> _rewards;

  @override
  void initState() {
    super.initState();
    _rewards = TheoremReach.onReward.listen((int quantity) {
      // Credit `quantity` of your currency to the user.
    });
    _startTheoremReach('THE_USER_ID');
  }

  @override
  void dispose() {
    _rewards.cancel();
    super.dispose();
  }

  // Once you know the user: the ID TheoremReach's server-side reward callback reports.
  Future<void> _startTheoremReach(String userId) async {
    await TheoremReach.initialize(apiKey: 'YOUR_API_KEY', userId: userId);
    // Any settings go after the start, which resets some of them.
    await TheoremReach.setNavigationBarText('Earn rewards');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FilledButton(
            // When the user is ready to take surveys.
            onPressed: () => TheoremReach.showRewardCenter(),
            child: const Text('Earn rewards'),
          ),
        ),
      ),
    );
  }
}
```

A reward that arrives while nothing listens to `onReward` waits for the next listener. A waiting reward is only ever the
current user's:

- from an `initialize` for another user until its start succeeds, the last user's rewards wait rather than reach a
  listener, and the success drops them;
- if that start fails, they reach the listeners after all.

The wait is in memory, so a reward is lost if the app is killed, or hot restarted, while it waits.

### Calls

| Call | What it does |
| --- | --- |
| `initialize(apiKey:, userId:)` | Starts the SDK for this user. Call it before the others; a second call for the same key and user does nothing. |
| `showRewardCenter({placementId})` | Opens the reward center, at a placement when you pass one. |
| `isSurveyAvailable()` | A `Future<bool>`: whether a survey is available. |
| `setLoadingBarColor(color)` | The loading bar's color, as a hex string such as `#FC178D`. |
| `setNavigationBarText(text)` | The reward center's title. |
| `setNavigationBarColor(color)` | The title bar's color, as a hex string. |
| `setNavigationBarTextColor(color)` | The title's color, as a hex string. |
| `setMmpInstallId(provider:, installId:)` | For an app that TheoremReach has set up for attribution with a mobile measurement partner (MMP): the partner, such as `apptrove`, and its install ID. Call it before the reward center opens. Other apps don't need it. |

Call the settings after `initialize`: starting the SDK resets some of them (the colors on iOS, the title on Android).
Each call returns a `Future`, which fails:

- with a `StateError` for a call before `initialize`;
- with an `ArgumentError` from `initialize`, for an empty key or user ID;
- with a `PlatformException` (code `no_activity`) from `initialize` on Android, when the app has no activity yet, as
  with an engine started before its activity. Call `initialize` again once the app has one.

### Streams

| Stream | Event |
| --- | --- |
| `onReward` | An `int`: the currency the user earned, in your app's units. |
| `onRewardCenterOpened` | The reward center opened. |
| `onRewardCenterClosed` | The reward center closed. |
| `onSurveyAvailable` | A `bool`, after each of the SDK's checks. |

Each is a broadcast stream. No second `onRewardCenterOpened` comes before the first one's `onRewardCenterClosed`, so
an app can pause for the reward center and resume at its close.

- On Android, `showRewardCenter` while the app is in the background, or while the reward center is open, does nothing:
  no reward center opens, and no event comes.
- On iOS the close comes at another moment in two cases. A start for another user while the reward center is open
  reports it at the start, though the reward center stays on screen until the user closes it. And one that UIKit took
  away without its own close (when the app dismisses the screen it opened over, or everything over its root) reports
  it at the next show or start.

## Troubleshooting

- **An Android release build fails with `Manifest merger failed : Attribute application@usesCleartextTraffic`:** the
  Android SDK's manifest allows cleartext (http) traffic, and your app's turns it off. To keep your app's setting, add
  `android:usesCleartextTraffic` to `tools:replace` on the `<application>` element of
  `android/app/src/main/AndroidManifest.xml` (comma-separated, if it already lists attributes), with
  `xmlns:tools="http://schemas.android.com/tools"` on its `<manifest>` element. Flutter's own templates don't set it,
  so an app made from one builds without the error, and the SDK's value allows cleartext traffic in its release
  builds.
- **The iOS build says the package needs iOS 15.0:** raise the app's iOS target to 15.0 (Requirements).
- **Swift Package Manager can't find the `FlutterFramework` package:** the app is on Flutter 3.35 to 3.43 with Swift
  Package Manager turned on (Install).

## Example app

`example/` holds an app that opens the reward center and logs every event, on TheoremReach's test apps. From
`example/`, run `flutter run`. It's made from Flutter 3.47's app template, the Flutter CI builds it with.

## Other platforms

[iOS](https://theoremreach.com/docs/ios) · [Android](https://theoremreach.com/docs/android) ·
[React Native](https://theoremreach.com/docs/react_native) · [Unity](https://theoremreach.com/docs/unity) ·
[Web](https://theoremreach.com/docs/web)

## License

The TheoremReach Publisher Terms and Conditions ([LICENSE](LICENSE)); the example app is MIT
([example/LICENSE](example/LICENSE)).
