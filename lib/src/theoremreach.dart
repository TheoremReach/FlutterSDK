import 'dart:async';

import 'package:meta/meta.dart';

import 'messages.g.dart';

/// TheoremReach's rewarded surveys.
///
/// Start the SDK with [initialize], for the signed-in user, before any other call. Then open the reward center with
/// [showRewardCenter], and listen to [onReward] for what the user earns.
abstract final class TheoremReach {
  static _TheoremReachSdk _sdk = _TheoremReachSdk();

  /// Starts the SDK for this user, with your app's API key from the TheoremReach dashboard. The user's ID is the one
  /// TheoremReach's server-side reward callback reports.
  ///
  /// Call it before the other calls. Calling it again for the same key and user does nothing, and shares the start
  /// that's on its way, if there is one. Once a start for another user succeeds, the rewards still waiting for an
  /// [onReward] listener are dropped, since they were the last user's; if it fails, they wait on.
  ///
  /// Throws an [ArgumentError] when either argument is empty. On Android it throws a `PlatformException` (code
  /// `no_activity`) when the app has no activity to start from yet; call it again once one is attached.
  static Future<void> initialize({required String apiKey, required String userId}) => _sdk.initialize(apiKey, userId);

  /// Opens the reward center, at [placementId] when you give one.
  ///
  /// On Android, a call while the app is in the background does nothing.
  static Future<void> showRewardCenter({String? placementId}) =>
      _sdk.call('showRewardCenter', (host) => host.showRewardCenter(placementId));

  /// Whether a survey is available for the user.
  static Future<bool> isSurveyAvailable() => _sdk.call('isSurveyAvailable', (host) => host.isSurveyAvailable());

  /// The loading bar's color, as a hex string such as `#FC178D`.
  static Future<void> setLoadingBarColor(String color) =>
      _sdk.call('setLoadingBarColor', (host) => host.setLoadingBarColor(color));

  /// The reward center's title.
  static Future<void> setNavigationBarText(String text) =>
      _sdk.call('setNavigationBarText', (host) => host.setNavigationBarText(text));

  /// The reward center's title bar color, as a hex string.
  static Future<void> setNavigationBarColor(String color) =>
      _sdk.call('setNavigationBarColor', (host) => host.setNavigationBarColor(color));

  /// The reward center's title color, as a hex string.
  static Future<void> setNavigationBarTextColor(String color) =>
      _sdk.call('setNavigationBarTextColor', (host) => host.setNavigationBarTextColor(color));

  /// For an app that TheoremReach has set up for attribution with a mobile measurement partner (MMP): the partner,
  /// such as `apptrove`, and its install ID, which each survey entry then carries. Set it before the reward center
  /// opens.
  static Future<void> setMmpInstallId({required String provider, required String installId}) =>
      _sdk.call('setMmpInstallId', (host) => host.setMmpInstallId(provider, installId));

  /// The currency the user earned, in your app's own units, each time TheoremReach rewards them.
  ///
  /// The SDK confirms a reward with TheoremReach once it has handed it over, so a reward that arrives while nothing
  /// listens here (before the screen that listens is built, say) waits for the next listeners. A waiting reward lives
  /// in memory, so it's lost if the app is killed or hot restarted.
  static Stream<int> get onReward => _sdk.rewards.stream;

  /// The reward center opened.
  static Stream<void> get onRewardCenterOpened => _sdk.rewardCenterOpened.stream;

  /// The reward center closed. It follows each [onRewardCenterOpened].
  static Stream<void> get onRewardCenterClosed => _sdk.rewardCenterClosed.stream;

  /// Whether a survey is available, after each of the SDK's checks.
  static Stream<bool> get onSurveyAvailable => _sdk.surveyAvailable.stream;

  /// Forgets the SDK's state, for a test that starts from scratch.
  @visibleForTesting
  static void resetForTesting() {
    _sdk.close();
    _sdk = _TheoremReachSdk();
  }
}

final class _TheoremReachSdk implements TheoremReachFlutterApi {
  final TheoremReachHostApi _host = TheoremReachHostApi();

  // Synchronous, so a reward reaches the listeners there are as it's added, rather than in a later microtask that a
  // listener could have cancelled before.
  late final StreamController<int> rewards = StreamController<int>.broadcast(
    sync: true,
    onListen: () => scheduleMicrotask(_deliverWaitingRewards),
  );
  final StreamController<void> rewardCenterOpened = StreamController<void>.broadcast(sync: true);
  final StreamController<void> rewardCenterClosed = StreamController<void>.broadcast(sync: true);
  final StreamController<bool> surveyAvailable = StreamController<bool>.broadcast(sync: true);

  // Rewards no listener has had yet, each with the user the SDK earned it for: only the current user's go out.
  final List<({String userId, int quantity})> _waitingRewards = <({String userId, int quantity})>[];
  bool _receiving = false;
  // The key and user of the last initialize, and the start made for them, which a call for the same pair shares. Set
  // before the start's reply, so the calls an app makes right after an initialize it doesn't await go through: the
  // platform takes them in order, after the start.
  ({String apiKey, String userId})? _requested;
  Future<void> _requestedStart = Future<void>.value();
  // The pair the native SDK last started for. Every reward it sends before a start's reply is the last user's, and
  // every one after it the new user's, since the platform's messages keep their order.
  ({String apiKey, String userId})? _started;
  // Counts the initializes, so only the latest decides the state when it fails.
  int _generation = 0;

  Future<void> initialize(String apiKey, String userId) {
    if (apiKey.isEmpty) {
      return Future<void>.error(ArgumentError.value(apiKey, 'apiKey', 'must not be empty'));
    }
    if (userId.isEmpty) {
      return Future<void>.error(ArgumentError.value(userId, 'userId', 'must not be empty'));
    }
    final ({String apiKey, String userId}) pair = (apiKey: apiKey, userId: userId);
    // Each native start fetches the user afresh and checks for rewards, so a second one could hand a waiting reward
    // over twice (iOS); a start also resets the settings.
    if (pair == _requested) {
      return _requestedStart;
    }
    if (!_receiving) {
      TheoremReachFlutterApi.setUp(this);
      _receiving = true;
    }
    _requested = pair;
    return _requestedStart = _start(pair, ++_generation);
  }

  Future<void> _start(({String apiKey, String userId}) pair, int generation) async {
    try {
      await _host.start(pair.apiKey, pair.userId);
    } catch (_) {
      // The SDK stays with the last pair it started for, and its user's waiting rewards are the current user's again.
      // An initialize made since decides for itself.
      if (generation == _generation) {
        _requested = _started;
        _requestedStart = Future<void>.value();
        scheduleMicrotask(_deliverWaitingRewards);
      }
      rethrow;
    }
    _started = pair;
    if (generation == _generation) {
      _waitingRewards.removeWhere((reward) => reward.userId != pair.userId);
    }
  }

  Future<T> call<T>(String name, Future<T> Function(TheoremReachHostApi host) body) async {
    if (_requested == null) {
      throw StateError('TheoremReach.$name: call TheoremReach.initialize first.');
    }
    return body(_host);
  }

  void close() {
    if (_receiving) {
      TheoremReachFlutterApi.setUp(null);
    }
    rewards.close();
    rewardCenterOpened.close();
    rewardCenterClosed.close();
    surveyAvailable.close();
  }

  @override
  void onReward(int quantity) {
    final String? userId = (_started ?? _requested)?.userId;
    if (userId == null) {
      return;
    }
    _waitingRewards.add((userId: userId, quantity: quantity));
    _deliverWaitingRewards();
  }

  // Each reward leaves the queue as it's delivered, so one that a listener throws on isn't delivered twice. The current
  // user is read for each, since a listener can start the SDK for another.
  void _deliverWaitingRewards() {
    while (rewards.hasListener) {
      final int index = _waitingRewards.indexWhere((reward) => reward.userId == _requested?.userId);
      if (index == -1) {
        return;
      }
      rewards.add(_waitingRewards.removeAt(index).quantity);
    }
  }

  @override
  void onRewardCenterOpened() => rewardCenterOpened.add(null);

  @override
  void onRewardCenterClosed() => rewardCenterClosed.add(null);

  @override
  void onSurveyAvailable(bool available) => surveyAvailable.add(available);
}
