import Flutter
import TheoremReachSDK
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

// The SDK's callbacks, as they reach Dart, and a start's effect on an open reward center. Showing needs the SDK's
// reward center on screen, so the integration test and the device passes cover it.
final class RunnerTests: XCTestCase {
  private var messenger: RecordingMessenger!
  private var plugin: TheoremReachPlugin!

  override func setUp() {
    super.setUp()
    messenger = RecordingMessenger()
    plugin = TheoremReachPlugin(flutterApi: TheoremReachFlutterApi(binaryMessenger: messenger))
    // The tests' starts ask TheoremReach for no user.
    TheoremReach.getInstance().doNotFetchAppuser = true
  }

  // Andy's iPhone (2026-11-09): a start for another user with the reward center open put the app's light status bar
  // back over the reward center's light title bar, and the SDK, which the start had told the reward center was closed,
  // reported no close at the X.
  func testAStartWithTheRewardCenterOnScreenLeavesItsCloseAndTheStatusBarToTheX() throws {
    let sdk = TheoremReach.getInstance()!
    UIApplication.shared.statusBarStyle = .lightContent
    sdk.navigationBarColor = "#F2F2F7"
    sdk.navigationBarTextColor = "#000000"
    plugin.rewardCenterOnScreen = { true }
    plugin.onRewardCenterOpened()
    XCTAssertEqual(UIApplication.shared.statusBarStyle, .darkContent)

    try plugin.start(apiKey: "key", userId: "user-2")

    XCTAssertEqual(UIApplication.shared.statusBarStyle, .darkContent)
    XCTAssertTrue(messenger.messages(to: "onRewardCenterClosed").isEmpty)
    XCTAssertTrue(sdk.rewardCenterOpen)

    plugin.onRewardCenterClosed()

    XCTAssertEqual(UIApplication.shared.statusBarStyle, .lightContent)
    XCTAssertEqual(messenger.messages(to: "onRewardCenterClosed").count, 1)
  }

  // UIKit took the reward center away with the screen it was presented from, so the SDK will never report its close.
  func testAStartAfterUIKitTookTheRewardCenterAwayReportsItsClose() throws {
    UIApplication.shared.statusBarStyle = .lightContent
    TheoremReach.getInstance().navigationBarColor = "#F2F2F7"
    TheoremReach.getInstance().navigationBarTextColor = "#000000"
    plugin.rewardCenterOnScreen = { false }
    plugin.onRewardCenterOpened()

    try plugin.start(apiKey: "key", userId: "user-2")

    XCTAssertEqual(UIApplication.shared.statusBarStyle, .lightContent)
    XCTAssertEqual(messenger.messages(to: "onRewardCenterClosed").count, 1)
    XCTAssertFalse(TheoremReach.getInstance().rewardCenterOpen)
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
