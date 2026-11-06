import Flutter
import XCTest

@testable import theoremreach_sdk

/// The messages the plugin sends Dart, by channel, as the engine's messenger would carry them.
private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
  var sent: [(channel: String, args: [Any?])] = []

  func send(onChannel channel: String, message: Data?) {
    send(onChannel: channel, message: message, binaryReply: nil)
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {
    let args = message.flatMap { MessagesPigeonCodec.shared.decode($0) as? [Any?] } ?? []
    sent.append((channel, args))
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func messages(to method: String) -> [[Any?]] {
    sent.filter { $0.channel == "dev.flutter.pigeon.theoremreach_sdk.TheoremReachFlutterApi.\(method)" }.map(\.args)
  }
}

// The SDK's callbacks, as they reach Dart. Starting and showing need the SDK itself, so the integration test and the
// device passes cover them.
final class RunnerTests: XCTestCase {
  private var messenger: RecordingMessenger!
  private var plugin: TheoremReachPlugin!

  override func setUp() {
    super.setUp()
    messenger = RecordingMessenger()
    plugin = TheoremReachPlugin(flutterApi: TheoremReachFlutterApi(binaryMessenger: messenger))
  }

  func testARewardReachesDartAsItsQuantity() {
    plugin.onReward(NSNumber(value: 260))

    XCTAssertEqual(messenger.messages(to: "onReward").count, 1)
    XCTAssertEqual(messenger.messages(to: "onReward").first?.first as? Int64, 260)
  }

  func testARewardWithNoQuantityIsDropped() {
    plugin.onReward(nil)

    XCTAssertTrue(messenger.messages(to: "onReward").isEmpty)
  }

  func testTheRewardCenterOpeningAndClosingReachDart() {
    plugin.onRewardCenterOpened()
    plugin.onRewardCenterClosed()

    XCTAssertEqual(messenger.messages(to: "onRewardCenterOpened").count, 1)
    XCTAssertEqual(messenger.messages(to: "onRewardCenterClosed").count, 1)
  }

  func testSurveyAvailabilityReachesDart() {
    plugin.theoremreachSurveyAvailable(true)
    plugin.theoremreachSurveyAvailable(false)

    XCTAssertEqual(messenger.messages(to: "onSurveyAvailable").compactMap { $0.first as? Bool }, [true, false])
  }
}
