package com.theoremreach.flutter

import android.app.Activity
import android.app.Application
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
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
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
  private val plugin = TheoremReachPlugin()

  @Before
  fun setUp() {
    statics = mockStatic(TheoremReach::class.java)
    statics.`when`<TheoremReach> { TheoremReach.getInstance() }.thenReturn(sdk)
    val engine = mock(FlutterPlugin.FlutterPluginBinding::class.java)
    `when`(engine.binaryMessenger).thenReturn(messenger)
    plugin.onAttachedToEngine(engine)
    `when`(activity.application).thenReturn(application)
  }

  @After
  fun tearDown() {
    statics.close()
  }

  // The callbacks the plugin registered with the application, which every activity's pause and resume reach.
  private fun attachActivity(): Application.ActivityLifecycleCallbacks {
    val binding = mock(ActivityPluginBinding::class.java)
    `when`(binding.activity).thenReturn(activity)
    plugin.onAttachedToActivity(binding)
    val callbacks = ArgumentCaptor.forClass(Application.ActivityLifecycleCallbacks::class.java)
    verify(application, atLeastOnce()).registerActivityLifecycleCallbacks(callbacks.capture())
    return callbacks.allValues.last()
  }

  private fun started(): Application.ActivityLifecycleCallbacks {
    val callbacks = attachActivity()
    plugin.start("key", "user-1")
    return callbacks
  }

  // The listeners the plugin gave the SDK at its start.
  private fun rewardListener(): TheoremReachRewardListener =
    ArgumentCaptor.forClass(TheoremReachRewardListener::class.java).also {
      verify(sdk).setTheoremReachRewardListener(it.capture())
    }.value

  private fun surveyListener(): TheoremReachSurveyListener =
    ArgumentCaptor.forClass(TheoremReachSurveyListener::class.java).also {
      verify(sdk).setTheoremReachSurveyListener(it.capture())
    }.value

  private fun surveyAvailableListener(): TheoremReachSurveyAvailableListener =
    ArgumentCaptor.forClass(TheoremReachSurveyAvailableListener::class.java).also {
      verify(sdk).setTheoremReachSurveyAvailableListener(it.capture())
    }.value

  // The messages the plugin sent Dart on one of the Flutter API's channels.
  private fun sentToDart(method: String): Int =
    mockingDetails(messenger).invocations.count {
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
