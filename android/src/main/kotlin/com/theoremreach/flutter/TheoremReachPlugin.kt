package com.theoremreach.flutter

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import theoremreach.com.theoremreach.TheoremReach
import theoremreach.com.theoremreach.TheoremReachRewardListener
import theoremreach.com.theoremreach.TheoremReachSurveyAvailableListener
import theoremreach.com.theoremreach.TheoremReachSurveyListener

// Flutter calls the plugin on the main thread, where the activity's lifecycle reaches it too, so the SDK's calls keep
// the order Dart made them in. The SDK calls its listeners on the main thread as well.
class TheoremReachPlugin : FlutterPlugin, ActivityAware, TheoremReachHostApi {

  private var flutterApi: TheoremReachFlutterApi? = null
  private var activity: Activity? = null
  // The activity paused and hasn't resumed since. The SDK forgets its activity in onPause, and a show then reports an
  // open that no reward center follows, so the plugin doesn't show until the activity resumes. That covers a show while
  // the reward center is open too, since it pauses the activity under it.
  private var paused = false
  private var started = false
  // Dart heard the reward center open and hasn't heard it close. The SDK reports an open for every show it's asked for,
  // so Dart hears one open for each close.
  private var rewardCenterOpen = false

  // The activity's own pause and resume, which the SDK needs: it opens the reward center from the activity. (Flutter's
  // lifecycle for plugins is a FlutterFragment's, in an app that embeds one.)
  private val activityCallbacks = object : Application.ActivityLifecycleCallbacks {
    override fun onActivityResumed(resumed: Activity) {
      if (resumed !== activity) {
        return
      }
      paused = false
      if (started) {
        TheoremReach.getInstance().onResume(resumed)
      }
    }

    override fun onActivityPaused(pausedActivity: Activity) {
      if (pausedActivity !== activity) {
        return
      }
      paused = true
      if (started) {
        TheoremReach.getInstance().onPause()
      }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}

    override fun onActivityStarted(activity: Activity) {}

    override fun onActivityStopped(activity: Activity) {}

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    override fun onActivityDestroyed(activity: Activity) {}
  }

  // The SDK's listener is an object of its own, off the plugin's type: an app's generated registrant compiles against
  // the plugin's class, and can't see the SDK's classes.
  private val sdkListener = object :
    TheoremReachRewardListener,
    TheoremReachSurveyListener,
    TheoremReachSurveyAvailableListener {
    // The SDK confirms a reward with TheoremReach once this returns, and keeps it for its next check when this throws.
    // So with no engine to hand it to (the app's activity finished during the check, say), it stays with the SDK.
    override fun onReward(quantity: Int) {
      val flutterApi = flutterApi ?: throw IllegalStateException("No Flutter engine to hand the reward to")
      flutterApi.onReward(quantity.toLong()) {}
    }

    override fun onRewardCenterOpened() {
      if (rewardCenterOpen) {
        return
      }
      rewardCenterOpen = true
      flutterApi?.onRewardCenterOpened {}
    }

    override fun onRewardCenterClosed() {
      rewardCenterOpen = false
      flutterApi?.onRewardCenterClosed {}
    }

    override fun theoremreachSurveyAvailable(surveyAvailable: Boolean) {
      flutterApi?.onSurveyAvailable(surveyAvailable) {}
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    TheoremReachHostApi.setUp(binding.binaryMessenger, this)
    flutterApi = TheoremReachFlutterApi(binding.binaryMessenger)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    TheoremReachHostApi.setUp(binding.binaryMessenger, null)
    flutterApi = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

  override fun onDetachedFromActivityForConfigChanges() = detach()

  override fun onDetachedFromActivity() = detach()

  // An activity that reports its lifecycle starts paused unless it's resumed: a FlutterFragment can attach to a host
  // that's paused. One that's being created resumes in the same step, before the platform takes any call from Dart.
  private fun attach(binding: ActivityPluginBinding) {
    val activity = binding.activity
    this.activity = activity
    paused = (activity as? LifecycleOwner)?.lifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED) == false
    activity.application.registerActivityLifecycleCallbacks(activityCallbacks)
  }

  private fun detach() {
    activity?.application?.unregisterActivityLifecycleCallbacks(activityCallbacks)
    activity = null
    if (started) {
      TheoremReach.getInstance().onPause()
    }
  }

  override fun start(apiKey: String, userId: String) {
    // The SDK's start reads the device's connection and carrier from the activity.
    val activity = activity ?: throw FlutterError(
      "no_activity",
      "TheoremReach.initialize needs the app's activity, and none is attached yet.",
    )
    TheoremReach.initWithApiKeyAndUserIdAndActivityContext(apiKey, userId, activity)
    val sdk = TheoremReach.getInstance()
    // The start hands the SDK the activity. A paused one it takes back until the activity resumes.
    if (paused) {
      sdk.onPause()
    } else {
      sdk.onResume(activity)
    }
    sdk.setTheoremReachRewardListener(sdkListener)
    sdk.setTheoremReachSurveyListener(sdkListener)
    sdk.setTheoremReachSurveyAvailableListener(sdkListener)
    started = true
  }

  // The placement goes with every show, empty when there's none (the SDK leaves an empty one out of the URL): the SDK
  // clears it only when its reward center closes, so one destroyed from outside would hand its placement to the next.
  override fun showRewardCenter(placementId: String?) {
    if (!started || activity == null || paused) {
      return
    }
    TheoremReach.getInstance().showRewardCenter(placementId.orEmpty())
  }

  override fun isSurveyAvailable(): Boolean = started && TheoremReach.getInstance().getIsSurveyAvailable()

  override fun setLoadingBarColor(color: String) = whenStarted { it.setLoadingBarColor(color) }

  override fun setMmpInstallId(provider: String, installId: String) =
    whenStarted { it.setMmpInstallId(provider, installId) }

  override fun setNavigationBarText(text: String) = whenStarted { it.setNavigationBarText(text) }

  override fun setNavigationBarColor(color: String) = whenStarted { it.setNavigationBarColor(color) }

  override fun setNavigationBarTextColor(color: String) = whenStarted { it.setNavigationBarTextColor(color) }

  // Dart calls only after initialize, so a call here before a start means the start failed, and Dart has its error.
  private inline fun whenStarted(call: (TheoremReach) -> Unit) {
    if (started) {
      call(TheoremReach.getInstance())
    }
  }
}
