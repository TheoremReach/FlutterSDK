package com.theoremreach.flutter

import android.app.Activity
import android.app.Application
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.MockedStatic
import org.mockito.Mockito.atLeastOnce
import org.mockito.Mockito.clearInvocations
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.withSettings
import org.mockito.Mockito.`when`
import theoremreach.com.theoremreach.TheoremReach
import theoremreach.com.theoremreach.TheoremReachRewardListener
import theoremreach.com.theoremreach.TheoremReachSurveyAvailableListener
import theoremreach.com.theoremreach.TheoremReachSurveyListener

private const val FLUTTER_API = "dev.flutter.pigeon.theoremreach_sdk.TheoremReachFlutterApi"

class TheoremReachPluginTest {
  private lateinit var statics: MockedStatic<TheoremReach>
  private val sdk: TheoremReach = mock(TheoremReach::class.java)
  private val application: Application = mock(Application::class.java)
  private val activity: Activity = mock(Activity::class.java)
  private val messenger: BinaryMessenger = mock(BinaryMessenger::class.java)
  private val engine = mock(FlutterPlugin.FlutterPluginBinding::class.java)
  private val plugin = TheoremReachPlugin()

  @Before
  fun setUp() {
    statics = mockStatic(TheoremReach::class.java)
    statics.`when`<TheoremReach> { TheoremReach.getInstance() }.thenReturn(sdk)
    `when`(engine.binaryMessenger).thenReturn(messenger)
    plugin.onAttachedToEngine(engine)
    `when`(activity.application).thenReturn(application)
  }

  @After
  fun tearDown() {
    // The SDK's listener is one for the process, so every engine a test attached goes, as an app's would.
    engines.forEach { (plugin, binding) -> plugin.onDetachedFromEngine(binding) }
    plugin.onDetachedFromEngine(engine)
    statics.close()
  }

  private val engines = mutableListOf<Pair<TheoremReachPlugin, FlutterPlugin.FlutterPluginBinding>>()

  // A second engine's plugin, its messenger (which counts what its Dart hears), its activity, and the callbacks it
  // registered for that activity's pause and resume.
  private data class Engine(
    val plugin: TheoremReachPlugin,
    val messenger: BinaryMessenger,
    val activity: Activity,
    val callbacks: Application.ActivityLifecycleCallbacks,
  )

  // A second Flutter engine's plugin, started from its own activity: what a deep link to a singleTop activity under the
  // reward center makes, or an app that opens a FlutterActivity of its own per screen.
  private fun secondEngineStarted(): Engine {
    val other = TheoremReachPlugin()
    val otherMessenger = mock(BinaryMessenger::class.java)
    val otherEngine = mock(FlutterPlugin.FlutterPluginBinding::class.java)
    `when`(otherEngine.binaryMessenger).thenReturn(otherMessenger)
    other.onAttachedToEngine(otherEngine)
    engines.add(other to otherEngine)
    val otherActivity = mock(Activity::class.java)
    `when`(otherActivity.application).thenReturn(application)
    other.onAttachedToActivity(bindingFor(otherActivity))
    val callbacks = ArgumentCaptor.forClass(Application.ActivityLifecycleCallbacks::class.java)
    verify(application, atLeastOnce()).registerActivityLifecycleCallbacks(callbacks.capture())
    other.start("key", "user-1")
    return Engine(other, otherMessenger, otherActivity, callbacks.allValues.last())
  }

  private fun detachEngine(other: TheoremReachPlugin) {
    val entry = engines.first { it.first === other }
    other.onDetachedFromEngine(entry.second)
    engines.remove(entry)
  }

  private fun bindingFor(activity: Activity): ActivityPluginBinding {
    val binding = mock(ActivityPluginBinding::class.java)
    `when`(binding.activity).thenReturn(activity)
    return binding
  }

  // An activity that reports its lifecycle, as Flutter's and AndroidX's do, in the given state.
  private fun activityIn(state: Lifecycle.State): Activity {
    val activity = mock(Activity::class.java, withSettings().extraInterfaces(LifecycleOwner::class.java))
    val lifecycle = mock(Lifecycle::class.java)
    `when`(lifecycle.currentState).thenReturn(state)
    `when`((activity as LifecycleOwner).lifecycle).thenReturn(lifecycle)
    `when`(activity.application).thenReturn(application)
    return activity
  }

  // The callbacks the plugin registered with the application, which every activity's pause and resume reach.
  private fun attachActivity(): Application.ActivityLifecycleCallbacks {
    plugin.onAttachedToActivity(bindingFor(activity))
    val callbacks = ArgumentCaptor.forClass(Application.ActivityLifecycleCallbacks::class.java)
    verify(application, atLeastOnce()).registerActivityLifecycleCallbacks(callbacks.capture())
    return callbacks.allValues.last()
  }

  private fun started(): Application.ActivityLifecycleCallbacks {
    val callbacks = attachActivity()
    plugin.start("key", "user-1")
    return callbacks
  }

  // The listeners the SDK holds: the last ones a start gave it.
  private fun rewardListener(): TheoremReachRewardListener =
    ArgumentCaptor.forClass(TheoremReachRewardListener::class.java).also {
      verify(sdk, atLeastOnce()).setTheoremReachRewardListener(it.capture())
    }.value

  private fun surveyListener(): TheoremReachSurveyListener =
    ArgumentCaptor.forClass(TheoremReachSurveyListener::class.java).also {
      verify(sdk, atLeastOnce()).setTheoremReachSurveyListener(it.capture())
    }.value

  private fun surveyAvailableListener(): TheoremReachSurveyAvailableListener =
    ArgumentCaptor.forClass(TheoremReachSurveyAvailableListener::class.java).also {
      verify(sdk, atLeastOnce()).setTheoremReachSurveyAvailableListener(it.capture())
    }.value

  // The messages a plugin sent its Dart on one of the Flutter API's channels: the first engine's by default.
  private fun sentToDart(method: String, to: BinaryMessenger = messenger): Int =
    mockingDetails(to).invocations.count {
      it.method.name == "send" && it.arguments[0] == "$FLUTTER_API.$method"
    }

  @Test
  fun `start without an activity fails, and starts nothing`() {
    val error = assertThrows(FlutterError::class.java) { plugin.start("key", "user-1") }

    assertEquals("no_activity", error.code)
    statics.verify({ TheoremReach.initWithApiKeyAndUserIdAndActivityContext(any(), any(), any()) }, never())
  }

  @Test
  fun `start hands the SDK the activity, and listens`() {
    started()

    statics.verify { TheoremReach.initWithApiKeyAndUserIdAndActivityContext("key", "user-1", activity) }
    verify(sdk).onResume(activity)
    rewardListener()
    surveyListener()
    surveyAvailableListener()
  }

  @Test
  fun `start while the activity is paused takes the activity back from the SDK`() {
    attachActivity().onActivityPaused(activity)

    plugin.start("key", "user-1")

    verify(sdk).onPause()
    verify(sdk, never()).onResume(any())
  }

  @Test
  fun `the activity's pause and resume reach the SDK once it has started`() {
    val callbacks = attachActivity()
    callbacks.onActivityPaused(activity)
    callbacks.onActivityResumed(activity)
    verify(sdk, never()).onPause()

    plugin.start("key", "user-1")
    callbacks.onActivityPaused(activity)
    callbacks.onActivityResumed(activity)

    verify(sdk).onPause()
    verify(sdk, times(2)).onResume(activity)
  }

  @Test
  fun `showRewardCenter passes the placement, or an empty one`() {
    started()

    plugin.showRewardCenter("placement-1")
    plugin.showRewardCenter(null)

    verify(sdk).showRewardCenter("placement-1")
    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `showRewardCenter does nothing before a start`() {
    attachActivity()

    plugin.showRewardCenter(null)

    verify(sdk, never()).showRewardCenter(any())
  }

  @Test
  fun `showRewardCenter does nothing while the activity is paused, and works once it resumes`() {
    val callbacks = started()
    callbacks.onActivityPaused(activity)

    plugin.showRewardCenter(null)
    verify(sdk, never()).showRewardCenter(any())

    callbacks.onActivityResumed(activity)
    plugin.showRewardCenter(null)
    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `another activity's pause, such as the reward center's, doesn't count`() {
    val callbacks = started()

    callbacks.onActivityPaused(mock(Activity::class.java))
    plugin.showRewardCenter(null)

    verify(sdk, never()).onPause()
    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `a show right after the start, before the activity's first resume, opens`() {
    started()

    plugin.showRewardCenter(null)

    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `detaching the activity takes it back from the SDK, and stops the shows`() {
    started()

    plugin.onDetachedFromActivity()
    plugin.showRewardCenter(null)

    verify(application).unregisterActivityLifecycleCallbacks(any())
    verify(sdk).onPause()
    verify(sdk, never()).showRewardCenter(any())
  }

  @Test
  fun `an activity attached while it's paused, as a FlutterFragment's host can be, gets no show until it resumes`() {
    val host = activityIn(Lifecycle.State.STARTED)
    plugin.onAttachedToActivity(bindingFor(host))
    plugin.start("key", "user-1")

    plugin.showRewardCenter(null)
    verify(sdk, never()).showRewardCenter(any())

    val callbacks = ArgumentCaptor.forClass(Application.ActivityLifecycleCallbacks::class.java)
    verify(application).registerActivityLifecycleCallbacks(callbacks.capture())
    callbacks.value.onActivityResumed(host)
    plugin.showRewardCenter(null)
    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `an activity attached while it's resumed shows`() {
    plugin.onAttachedToActivity(bindingFor(activityIn(Lifecycle.State.RESUMED)))
    plugin.start("key", "user-1")

    plugin.showRewardCenter(null)

    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `after a configuration change, the new activity's pause and resume are the ones that count`() {
    val callbacks = started()
    plugin.onDetachedFromActivityForConfigChanges()
    val recreated = mock(Activity::class.java)
    `when`(recreated.application).thenReturn(application)
    plugin.onReattachedToActivityForConfigChanges(bindingFor(recreated))

    callbacks.onActivityResumed(activity)
    verify(sdk, never()).onResume(recreated)
    callbacks.onActivityPaused(recreated)
    plugin.showRewardCenter(null)
    verify(sdk, never()).showRewardCenter(any())
    callbacks.onActivityResumed(recreated)
    plugin.showRewardCenter(null)

    verify(application).unregisterActivityLifecycleCallbacks(callbacks)
    verify(sdk).onResume(recreated)
    verify(sdk).showRewardCenter("")
  }

  @Test
  fun `a reward that comes after the engine has gone stays with the SDK`() {
    started()
    val listener = rewardListener()

    plugin.onDetachedFromEngine(engine)

    // The SDK confirms a reward only once its listener returns, and keeps it for its next check when the listener
    // throws.
    assertThrows(IllegalStateException::class.java) { listener.onReward(260) }
    assertEquals(0, sentToDart("onReward"))
  }

  @Test
  fun `Dart hears one open for each close`() {
    started()
    val listener = surveyListener()

    listener.onRewardCenterOpened()
    listener.onRewardCenterOpened()
    assertEquals(1, sentToDart("onRewardCenterOpened"))

    listener.onRewardCenterClosed()
    listener.onRewardCenterOpened()
    assertEquals(1, sentToDart("onRewardCenterClosed"))
    assertEquals(2, sentToDart("onRewardCenterOpened"))
  }

  // On the Pixel (2026-11-09): with the reward center open, a deep link started a second activity, and its engine's
  // start took the SDK's listeners. Back and the X then left the first engine's Dart with the open and no close, and
  // no callback after.
  @Test
  fun `an engine that comes and goes while the reward center is open hands the callbacks back`() {
    started()
    surveyListener().onRewardCenterOpened()

    val (second, _) = secondEngineStarted()
    detachEngine(second)
    surveyListener().onRewardCenterClosed()
    surveyListener().onRewardCenterOpened()
    surveyListener().onRewardCenterClosed()

    assertEquals(2, sentToDart("onRewardCenterOpened"))
    assertEquals(2, sentToDart("onRewardCenterClosed"))
  }

  @Test
  fun `the close goes to the engine that heard the open`() {
    started()
    surveyListener().onRewardCenterOpened()
    val (_, secondMessenger) = secondEngineStarted()

    surveyListener().onRewardCenterClosed()

    assertEquals(1, sentToDart("onRewardCenterClosed"))
    assertEquals(0, sentToDart("onRewardCenterClosed", secondMessenger))
  }

  @Test
  fun `rewards and survey checks go to the latest engine that started, and back when it goes`() {
    started()
    val (second, secondMessenger) = secondEngineStarted()

    rewardListener().onReward(260)
    surveyAvailableListener().theoremreachSurveyAvailable(true)
    assertEquals(1, sentToDart("onReward", secondMessenger))
    assertEquals(1, sentToDart("onSurveyAvailable", secondMessenger))
    assertEquals(0, sentToDart("onReward"))

    detachEngine(second)
    rewardListener().onReward(500)
    surveyAvailableListener().theoremreachSurveyAvailable(false)
    assertEquals(1, sentToDart("onReward"))
    assertEquals(1, sentToDart("onSurveyAvailable"))

    // With no engine left the SDK keeps the reward, as before.
    plugin.onDetachedFromEngine(engine)
    assertThrows(IllegalStateException::class.java) { rewardListener().onReward(100) }
  }

  // Back from a second engine's activity: it pauses, the first resumes, and the second is destroyed after. The SDK
  // keeps one activity for the process, so the second's detach mustn't take the first's away: a show would open nothing.
  @Test
  fun `an engine whose activity paused before it went leaves the SDK the activity on screen`() {
    val callbacks = started()
    callbacks.onActivityPaused(activity)
    val second = secondEngineStarted()

    second.callbacks.onActivityPaused(second.activity)
    callbacks.onActivityResumed(activity)
    clearInvocations(sdk)
    second.plugin.onDetachedFromActivity()

    verify(sdk, never()).onPause()
  }

  // An app that keeps a second engine cached: it stays attached when its activity goes, and the first engine's show
  // is still the first engine's reward center.
  @Test
  fun `a show's open and close go to the engine that showed`() {
    started()
    val second = secondEngineStarted()
    second.plugin.onDetachedFromActivity()

    plugin.showRewardCenter(null)
    surveyListener().onRewardCenterOpened()
    surveyListener().onRewardCenterClosed()

    assertEquals(1, sentToDart("onRewardCenterOpened"))
    assertEquals(1, sentToDart("onRewardCenterClosed"))
    assertEquals(0, sentToDart("onRewardCenterOpened", second.messenger))
    assertEquals(0, sentToDart("onRewardCenterClosed", second.messenger))
  }

  @Test
  fun `a close whose open went to an engine that has gone reaches no other engine`() {
    started()
    val second = secondEngineStarted()
    surveyListener().onRewardCenterOpened()
    assertEquals(1, sentToDart("onRewardCenterOpened", second.messenger))

    detachEngine(second.plugin)
    surveyListener().onRewardCenterClosed()

    assertEquals(0, sentToDart("onRewardCenterClosed"))
  }

  @Test
  fun `rewards and survey checks reach Dart`() {
    started()

    rewardListener().onReward(260)
    surveyAvailableListener().theoremreachSurveyAvailable(true)

    assertEquals(1, sentToDart("onReward"))
    assertEquals(1, sentToDart("onSurveyAvailable"))
  }

  @Test
  fun `the setters and isSurveyAvailable reach the SDK only once it has started`() {
    `when`(sdk.getIsSurveyAvailable()).thenReturn(true)
    attachActivity()

    plugin.setNavigationBarText("Earn coins")
    assertFalse(plugin.isSurveyAvailable())
    verify(sdk, never()).setNavigationBarText(any())

    plugin.start("key", "user-1")
    plugin.setLoadingBarColor("#FC178D")
    plugin.setNavigationBarText("Earn coins")
    plugin.setNavigationBarColor("#0B3D91")
    plugin.setNavigationBarTextColor("#FFD60A")
    plugin.setMmpInstallId("apptrove", "install-1")

    assertTrue(plugin.isSurveyAvailable())
    verify(sdk).setLoadingBarColor("#FC178D")
    verify(sdk).setNavigationBarText("Earn coins")
    verify(sdk).setNavigationBarColor("#0B3D91")
    verify(sdk).setNavigationBarTextColor("#FFD60A")
    verify(sdk).setMmpInstallId("apptrove", "install-1")
  }
}
