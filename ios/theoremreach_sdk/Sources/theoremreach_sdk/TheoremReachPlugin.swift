import Flutter
import TheoremReachSDK
import UIKit

// Flutter calls the plugin on the main thread, where the SDK presents its reward center and calls back.
public final class TheoremReachPlugin: NSObject, FlutterPlugin, TheoremReachHostApi, TheoremReachRewardDelegate,
  TheoremReachSurveyDelegate, TheoremReachSurveyAvailableDelegate
{
  private let flutterApi: TheoremReachFlutterApi
  // Dart heard the reward center open and hasn't heard it close.
  private var rewardCenterOpen = false
  // The app's status bar style while the reward center is open, put back when it closes, and the reward center's that
  // the plugin set in its place.
  private var savedStatusBarStyle: UIStatusBarStyle?
  private var rewardCenterStatusBarStyle = UIStatusBarStyle.default

  init(flutterApi: TheoremReachFlutterApi) {
    self.flutterApi = flutterApi
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let plugin = TheoremReachPlugin(flutterApi: TheoremReachFlutterApi(binaryMessenger: messenger))
    TheoremReachHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    TheoremReachHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
  }

  func start(apiKey: String, userId: String) throws {
    // Starting the SDK forgets an open reward center, which then never reports its close, though it stays on screen
    // until the user closes it.
    reportUnreportedClose()
    TheoremReach.initWithApiKey(apiKey, userId: userId)
    guard let sdk = TheoremReach.getInstance() else {
      return
    }
    sdk.rewardListenerDelegate = self
    sdk.surveyListenerDelegate = self
    sdk.surveyAvailableDelegate = self
  }

  func showRewardCenter(placementId: String?) throws {
    // One reward center at a time: a second would open over the first (a timer or a deep link can call this while one
    // is open), and the first's close would then never reach Dart.
    if Self.rewardCenterOnScreen() {
      return
    }
    // None is on screen, so an open Dart heard with no close yet went without reporting it: UIKit took the reward
    // center away with the screen it was presented from, as when the app dismisses everything over its root.
    reportUnreportedClose()

    // The placement goes with every show, nil when there's none: the SDK clears it only when its reward center closes,
    // so one that never closed would hand its placement to the next.
    let placement = placementId?.isEmpty == false ? placementId : nil
    TheoremReach.showRewardCenter(placement, from: Self.presentingViewController())

    // The SDK reports the reward center open before presenting it. If UIKit refused the presentation (the presenter
    // was mid-transition, say, or the last reward center was still sliding out), no close will come.
    if !Self.rewardCenterOnScreen() {
      reportUnreportedClose()
    }
  }

  func isSurveyAvailable() throws -> Bool {
    TheoremReach.getIsSurveyAvailable()
  }

  func setLoadingBarColor(color: String) throws {
    TheoremReach.getInstance()?.loadingBarColor = color
  }

  func setMmpInstallId(provider: String, installId: String) throws {
    TheoremReach.getInstance()?.setMmpInstallId(provider: provider, installId: installId)
  }

  func setNavigationBarText(text: String) throws {
    TheoremReach.getInstance()?.navigationBarText = text
  }

  func setNavigationBarColor(color: String) throws {
    TheoremReach.getInstance()?.navigationBarColor = color
  }

  func setNavigationBarTextColor(color: String) throws {
    TheoremReach.getInstance()?.navigationBarTextColor = color
  }

  private static func rewardCenterOnScreen() -> Bool {
    TheoremReach.getInstance()?.rewardCenterViewController?.presentingViewController != nil
  }

  // The root view controller of the foreground scene's key window: the SDK presents from the top of what that one
  // presents. Flutter's registrar names its view controller only from Flutter 3.38. With no scene in the foreground,
  // it's nil, and the SDK finds its own.
  private static func presentingViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene =
      scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
    return (scene?.keyWindow ?? scene?.windows.first)?.rootViewController
  }

  // For a reward center whose close the SDK won't report: the app's style comes back, and Dart hears the close of the
  // open it heard now rather than never, since an app that paused its audio for the reward center would otherwise stay
  // paused.
  private func reportUnreportedClose() {
    restoreStatusBar()
    if rewardCenterOpen {
      rewardCenterOpen = false
      flutterApi.onRewardCenterClosed { _ in }
    }
  }

  // MARK: - The SDK's callbacks

  public func onReward(_ quantity: NSNumber!) {
    guard let quantity else {
      return
    }
    flutterApi.onReward(quantity: quantity.int64Value) { _ in }
  }

  // Called just before the SDK presents the reward center.
  public func onRewardCenterOpened() {
    useRewardCenterStatusBar()
    rewardCenterOpen = true
    flutterApi.onRewardCenterOpened { _ in }
  }

  public func onRewardCenterClosed() {
    restoreStatusBar()
    rewardCenterOpen = false
    flutterApi.onRewardCenterClosed { _ in }
  }

  public func theoremreachSurveyAvailable(_ surveyAvailable: Bool) {
    flutterApi.onSurveyAvailable(available: surveyAvailable) { _ in }
  }

  // Required by the SDK's survey delegate protocol; the plugin has nothing to do on either.
  public func onRewardCenterViewSet() {}

  public func onSessionIdSet() {}

  // MARK: - The status bar over the reward center

  // The reward center asks for a status bar that follows its title (the SDK's rewardCenterStatusBarStyle: dark under a
  // dark title, light under a light one). Flutter's iOS template turned view controller based status bar appearance
  // off before 3.13 (flutter/flutter#128970), and an app made then still has it off, so iOS never asks the reward
  // center: the app's own style would sit on its title bar. Such an app gets the reward center's style while it's open, set as Flutter's engine sets
  // the app's, through UIKit's app-wide style (deprecated for view controller based appearance, so the compiler warns).
  private static var appSetsStatusBar: Bool {
    let viewControllerBased = Bundle.main.object(forInfoDictionaryKey: "UIViewControllerBasedStatusBarAppearance")
    return (viewControllerBased as? Bool) == false
  }

  private func useRewardCenterStatusBar() {
    guard savedStatusBarStyle == nil, Self.appSetsStatusBar, let sdk = TheoremReach.getInstance() else {
      return
    }
    savedStatusBarStyle = UIApplication.shared.statusBarStyle
    rewardCenterStatusBarStyle = sdk.rewardCenterStatusBarStyle()
    UIApplication.shared.statusBarStyle = rewardCenterStatusBarStyle
  }

  private func restoreStatusBar() {
    guard let saved = savedStatusBarStyle else {
      return
    }
    savedStatusBarStyle = nil
    // A style the app set while the reward center was open stands.
    if UIApplication.shared.statusBarStyle == rewardCenterStatusBarStyle {
      UIApplication.shared.statusBarStyle = saved
    }
  }
}
