import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theoremreach_sdk/theoremreach_sdk.dart';

const String hostChannel = 'dev.flutter.pigeon.theoremreach_sdk.TheoremReachHostApi';
const String flutterChannel = 'dev.flutter.pigeon.theoremreach_sdk.TheoremReachFlutterApi';
const MessageCodec<Object?> codec = StandardMessageCodec();

const List<String> hostMethods = <String>[
  'start',
  'showRewardCenter',
  'isSurveyAvailable',
  'setLoadingBarColor',
  'setMmpInstallId',
  'setNavigationBarText',
  'setNavigationBarColor',
  'setNavigationBarTextColor',
];

/// The native plugin, as the Dart API sees it through Pigeon's channels.
class FakeHost {
  final List<String> calls = <String>[];
  bool surveyAvailable = false;
  List<Object?>? startError;
  Completer<void>? holdStart;

  void install() {
    for (final String method in hostMethods) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>('$hostChannel.$method', codec),
        (Object? message) async {
          final List<Object?> args = (message as List<Object?>?) ?? const <Object?>[];
          calls.add(<Object?>[method, ...args].join(' '));
          if (method == 'start') {
            await holdStart?.future;
            if (startError != null) {
              return startError;
            }
          }
          if (method == 'isSurveyAvailable') {
            return <Object?>[surveyAvailable];
          }
          return <Object?>[];
        },
      );
    }
  }

  List<String> get starts => calls.where((String call) => call.startsWith('start ')).toList();
}

/// A callback from the native SDK, sent the way the native plugin sends it.
Future<void> nativeSends(String method, [List<Object?> args = const <Object?>[]]) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    '$flutterChannel.$method',
    codec.encodeMessage(args),
    (ByteData? reply) {},
  );
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;

  setUp(() {
    TheoremReach.resetForTesting();
    host = FakeHost()..install();
  });

  group('initialize', () {
    test('starts the native SDK with the key and user', () async {
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');

      expect(host.calls, <String>['start key user-1']);
    });

    test('rejects an empty key or user without starting', () async {
      await expectLater(TheoremReach.initialize(apiKey: '', userId: 'user-1'), throwsArgumentError);
      await expectLater(TheoremReach.initialize(apiKey: 'key', userId: ''), throwsArgumentError);

      expect(host.calls, isEmpty);
    });

    test('does nothing the second time for the same key and user', () async {
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');

      expect(host.starts, <String>['start key user-1']);
    });

    test('starts again for another user or key', () async {
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      await TheoremReach.initialize(apiKey: 'other-key', userId: 'user-2');

      expect(host.starts, <String>['start key user-1', 'start key user-2', 'start other-key user-2']);
    });

    test("passes on the native start's error, and a retry starts again", () async {
      host.startError = <Object?>['no_activity', 'No activity to start from.', null];

      await expectLater(
        TheoremReach.initialize(apiKey: 'key', userId: 'user-1'),
        throwsA(isA<PlatformException>().having((PlatformException e) => e.code, 'code', 'no_activity')),
      );
      await expectLater(TheoremReach.showRewardCenter(), throwsStateError);

      host.startError = null;
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');

      expect(host.starts, <String>['start key user-1', 'start key user-1']);
    });

    test('leaves nothing started after overlapping starts that both fail, and a retry starts', () async {
      host.startError = <Object?>['no_activity', 'No activity to start from.', null];

      final Future<void> first = TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      final Future<void> second = TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      await expectLater(first, throwsA(isA<PlatformException>()));
      await expectLater(second, throwsA(isA<PlatformException>()));
      await expectLater(TheoremReach.showRewardCenter(), throwsStateError);

      host.startError = null;
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');

      expect(host.starts, <String>['start key user-1', 'start key user-2', 'start key user-1']);
    });

    test('shares an unfinished start with a second call for the same key and user, its error too', () async {
      host.holdStart = Completer<void>();
      host.startError = <Object?>['no_activity', 'No activity to start from.', null];

      final Future<void> first = TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      final Future<void> second = TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      host.holdStart!.complete();

      await expectLater(first, throwsA(isA<PlatformException>()));
      await expectLater(second, throwsA(isA<PlatformException>()));
      expect(host.starts, <String>['start key user-1']);
    });

    test("lets the calls right after it through before its reply, in order", () async {
      host.holdStart = Completer<void>();

      final Future<void> started = TheoremReach.initialize(apiKey: 'key', userId: 'user-1');
      final Future<void> titled = TheoremReach.setNavigationBarText('Earn coins');
      host.holdStart!.complete();
      await Future.wait(<Future<void>>[started, titled]);

      expect(host.calls, <String>['start key user-1', 'setNavigationBarText Earn coins']);
    });
  });

  group('before initialize', () {
    final Map<String, Future<Object?> Function()> calls = <String, Future<Object?> Function()>{
      'showRewardCenter': () => TheoremReach.showRewardCenter(),
      'isSurveyAvailable': () => TheoremReach.isSurveyAvailable(),
      'setLoadingBarColor': () => TheoremReach.setLoadingBarColor('#FC178D'),
      'setNavigationBarText': () => TheoremReach.setNavigationBarText('Earn coins'),
      'setNavigationBarColor': () => TheoremReach.setNavigationBarColor('#0B3D91'),
      'setNavigationBarTextColor': () => TheoremReach.setNavigationBarTextColor('#FFD60A'),
      'setMmpInstallId': () => TheoremReach.setMmpInstallId(provider: 'apptrove', installId: 'install-1'),
    };

    for (final MapEntry<String, Future<Object?> Function()> call in calls.entries) {
      test('${call.key} throws a StateError and calls nothing', () async {
        await expectLater(call.value(), throwsStateError);

        expect(host.calls, isEmpty);
      });
    }
  });

  group('after initialize', () {
    setUp(() => TheoremReach.initialize(apiKey: 'key', userId: 'user-1'));

    test('showRewardCenter passes the placement, or none', () async {
      await TheoremReach.showRewardCenter(placementId: 'placement-1');
      await TheoremReach.showRewardCenter();

      expect(host.calls.skip(1), <String>['showRewardCenter placement-1', 'showRewardCenter null']);
    });

    test("isSurveyAvailable answers with the native SDK's", () async {
      host.surveyAvailable = true;
      expect(await TheoremReach.isSurveyAvailable(), isTrue);

      host.surveyAvailable = false;
      expect(await TheoremReach.isSurveyAvailable(), isFalse);
    });

    test('the setters pass their values', () async {
      await TheoremReach.setLoadingBarColor('#FC178D');
      await TheoremReach.setNavigationBarText('Earn coins');
      await TheoremReach.setNavigationBarColor('#0B3D91');
      await TheoremReach.setNavigationBarTextColor('#FFD60A');
      await TheoremReach.setMmpInstallId(provider: 'apptrove', installId: 'install-1');

      expect(host.calls.skip(1), <String>[
        'setLoadingBarColor #FC178D',
        'setNavigationBarText Earn coins',
        'setNavigationBarColor #0B3D91',
        'setNavigationBarTextColor #FFD60A',
        'setMmpInstallId apptrove install-1',
      ]);
    });

    test('the reward center and survey streams carry the native callbacks', () async {
      final List<String> heard = <String>[];
      TheoremReach.onRewardCenterOpened.listen((_) => heard.add('opened'));
      TheoremReach.onRewardCenterClosed.listen((_) => heard.add('closed'));
      TheoremReach.onSurveyAvailable.listen((bool available) => heard.add('available $available'));

      await nativeSends('onSurveyAvailable', <Object?>[true]);
      await nativeSends('onRewardCenterOpened');
      await nativeSends('onRewardCenterClosed');
      await nativeSends('onSurveyAvailable', <Object?>[false]);

      expect(heard, <String>['available true', 'opened', 'closed', 'available false']);
    });
  });

  group('rewards', () {
    setUp(() => TheoremReach.initialize(apiKey: 'key', userId: 'user-1'));

    test('reach a listener as they arrive', () async {
      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);

      await nativeSends('onReward', <Object?>[500]);

      expect(rewards, <int>[500]);
    });

    test('wait for the next listener, and reach it once the code that subscribed has run', () async {
      await nativeSends('onReward', <Object?>[500]);
      await nativeSends('onReward', <Object?>[260]);

      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      expect(rewards, isEmpty);

      await settle();
      expect(rewards, <int>[500, 260]);
    });

    test('go to every listener there is', () async {
      final List<int> first = <int>[];
      final List<int> second = <int>[];
      TheoremReach.onReward.listen(first.add);
      TheoremReach.onReward.listen(second.add);

      await nativeSends('onReward', <Object?>[260]);

      expect(first, <int>[260]);
      expect(second, <int>[260]);
    });

    test('wait again once the last listener cancels', () async {
      final List<int> first = <int>[];
      final StreamSubscription<int> subscription = TheoremReach.onReward.listen(first.add);
      await nativeSends('onReward', <Object?>[500]);
      await subscription.cancel();

      await nativeSends('onReward', <Object?>[260]);
      final List<int> second = <int>[];
      TheoremReach.onReward.listen(second.add);
      await settle();

      expect(first, <int>[500]);
      expect(second, <int>[260]);
    });

    test('keep waiting across a second initialize for the same user', () async {
      await nativeSends('onReward', <Object?>[260]);
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-1');

      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      await settle();

      expect(rewards, <int>[260]);
    });

    test('are dropped by an initialize for another user, even one made before listening', () async {
      await nativeSends('onReward', <Object?>[260]);

      final Future<void> switched = TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      await switched;
      await settle();

      expect(rewards, isEmpty);
    });

    test("that arrive during another user's start are dropped at its reply", () async {
      host.holdStart = Completer<void>();
      final Future<void> switched = TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      await nativeSends('onReward', <Object?>[260]);
      host.holdStart!.complete();
      await switched;

      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      await settle();

      expect(rewards, isEmpty);
    });

    test('wait on through a failed start for another user', () async {
      await nativeSends('onReward', <Object?>[260]);
      host.startError = <Object?>['no_activity', 'No activity to start from.', null];
      await expectLater(TheoremReach.initialize(apiKey: 'key', userId: 'user-2'), throwsA(isA<PlatformException>()));

      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      await settle();

      expect(rewards, <int>[260]);
    });

    test("for the last user don't reach a listener while another user's start is on its way", () async {
      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      host.holdStart = Completer<void>();

      final Future<void> switched = TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      await nativeSends('onReward', <Object?>[260]);
      host.holdStart!.complete();
      await switched;
      await nativeSends('onReward', <Object?>[500]);

      expect(rewards, <int>[500]);
    });

    test("that arrive after another user's start are that user's", () async {
      await TheoremReach.initialize(apiKey: 'key', userId: 'user-2');
      await nativeSends('onReward', <Object?>[260]);

      final List<int> rewards = <int>[];
      TheoremReach.onReward.listen(rewards.add);
      await settle();

      expect(rewards, <int>[260]);
    });
  });
}
