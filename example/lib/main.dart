import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:theoremreach_sdk/theoremreach_sdk.dart';

// TheoremReach's test apps (iOS 12451, Android 12453), as the native SDKs' examples use.
final String apiKey = Platform.isIOS ? '30a936dc7328c6e2bef47c0b1e13' : 'f4bfc509292953a3cf4274038763';
const String userId = 'FLUTTER_EXAMPLE_USER';
// A second user, to start for while the reward center is open, as an app that switches users at a login can.
const String otherUserId = 'FLUTTER_EXAMPLE_USER_2';
// Placements are made per app in TheoremReach's dashboard. The test apps have none, so this one opens the usual
// reward center, though the entry still carries it.
const String placementId = '0776c7a4-5ff7-48fd-bab2-79e7b6a626bc';
// The install ID your MMP's SDK gives you. The test apps measure no installs, so any ID will do here.
const String mmpInstallId = 'flutter-example-install';

typedef TitleBar = ({String color, String textColor});

// The example's own title bar, unlike the SDK's defaults (#1B0C47 and #FFFFFF) so a setter that didn't take shows, and
// a light one with a dark title, which the status bar over the reward center follows with dark icons.
const TitleBar titleBar = (color: '#0B3D91', textColor: '#FFD60A');
const TitleBar lightTitleBar = (color: '#F2F2F7', textColor: '#1C1C1E');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  // Light and dark, following the system.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TR Flutter Example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0B3D91)),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF0B3D91), brightness: Brightness.dark),
      home: const ExampleScreen(),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  final List<String> _log = <String>[];
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];
  final List<Timer> _timers = <Timer>[];
  StreamSubscription<int>? _rewards;
  bool _lightTitleBar = false;
  String _userId = userId;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      TheoremReach.onRewardCenterOpened.listen((_) => _append('onRewardCenterOpened')),
      TheoremReach.onRewardCenterClosed.listen((_) => _append('onRewardCenterClosed')),
      TheoremReach.onSurveyAvailable.listen((bool available) => _append('onSurveyAvailable $available')),
    ]);
    _listenForRewards(true);
    _start(userId, titleBar);
  }

  @override
  void dispose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      subscription.cancel();
    }
    _rewards?.cancel();
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _append(String line) {
    if (!mounted) {
      return;
    }
    final TimeOfDay time = TimeOfDay.now();
    final String seconds = DateTime.now().second.toString().padLeft(2, '0');
    setState(() => _log.insert(0, '${time.format(context)}:$seconds  $line'));
  }

  // The settings go after the start, which resets some of them.
  Future<void> _start(String user, TitleBar bar) async {
    try {
      await TheoremReach.initialize(apiKey: apiKey, userId: user);
      await TheoremReach.setNavigationBarText('TheoremReach Example');
      await TheoremReach.setNavigationBarColor(bar.color);
      await TheoremReach.setNavigationBarTextColor(bar.textColor);
      await TheoremReach.setLoadingBarColor('#9A5CF8');
      await TheoremReach.setMmpInstallId(provider: 'apptrove', installId: mmpInstallId);
      _append('Started for $user');
    } on Exception catch (error) {
      _append('The start failed: $error');
    }
  }

  // With no onReward listener, a reward waits in the package for the next one.
  void _listenForRewards(bool listen) {
    _rewards?.cancel();
    _rewards = listen ? TheoremReach.onReward.listen((int quantity) => _append('onReward $quantity')) : null;
  }

  void _toggleRewardListener() {
    final bool listen = _rewards == null;
    _listenForRewards(listen);
    _append(listen ? 'onReward listener back' : 'No onReward listener: rewards wait');
  }

  Future<void> _checkAvailability() async {
    _append('isSurveyAvailable ${await TheoremReach.isSurveyAvailable()}');
  }

  // The colors apply from the next open.
  Future<void> _toggleTitleBar() async {
    final bool light = !_lightTitleBar;
    final TitleBar bar = light ? lightTitleBar : titleBar;
    await TheoremReach.setNavigationBarColor(bar.color);
    await TheoremReach.setNavigationBarTextColor(bar.textColor);
    setState(() => _lightTitleBar = light);
    _append(light ? 'A light title bar, with a dark title' : "The example's title bar");
  }

  // Leave the app within the five seconds: on Android the show finds it paused, and nothing opens or is heard.
  void _showSoon() {
    _append('Opening the reward center in 5 seconds');
    _timers.add(
      Timer(const Duration(seconds: 5), () {
        _append('Opening the reward center now');
        TheoremReach.showRewardCenter();
      }),
    );
  }

  // Open the reward center within the five seconds, and the start for the other user comes while it's open: on iOS,
  // Dart should hear its close then.
  void _switchUserSoon() {
    final String next = _userId == userId ? otherUserId : userId;
    _append('Starting for $next in 5 seconds');
    _timers.add(Timer(const Duration(seconds: 5), () => _start(next, _lightTitleBar ? lightTitleBar : titleBar)));
    setState(() => _userId = next);
  }

  @override
  Widget build(BuildContext context) {
    final String nextUser = _userId == userId ? otherUserId : userId;
    return Scaffold(
      appBar: AppBar(title: const Text('TR Flutter Example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton(
                onPressed: () => TheoremReach.showRewardCenter(),
                child: const Text('Open the reward center'),
              ),
              FilledButton.tonal(
                onPressed: () => TheoremReach.showRewardCenter(placementId: placementId),
                child: const Text('Open it at a placement'),
              ),
              OutlinedButton(onPressed: _checkAvailability, child: const Text('Is a survey available?')),
              OutlinedButton(
                onPressed: _toggleTitleBar,
                child: Text(_lightTitleBar ? "Use the example's title bar" : 'Use a light title bar'),
              ),
              OutlinedButton(
                onPressed: _toggleRewardListener,
                child: Text(_rewards != null ? 'Stop listening for rewards' : 'Listen for rewards again'),
              ),
              OutlinedButton(onPressed: _showSoon, child: const Text('Open the reward center in 5 s')),
              OutlinedButton(onPressed: _switchUserSoon, child: Text('Start for $nextUser in 5 s')),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (BuildContext context, int index) => Text(_log[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
