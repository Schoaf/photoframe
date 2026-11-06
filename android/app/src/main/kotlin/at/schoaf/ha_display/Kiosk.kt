package at.schoaf.ha_display

import android.app.Activity
import android.Manifest
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Native side of the `ha_display/kiosk` channel (lib/services/kiosk.dart).
class Kiosk(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {
    private val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val activityManager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val admin = ComponentName(activity, KioskAdminReceiver::class.java)
    private val prefs = activity.getSharedPreferences("kiosk", Context.MODE_PRIVATE)

    val isDeviceOwner get() = dpm.isDeviceOwnerApp(activity.packageName)

    // Survives restarts, so a reboot comes back up locked unless the menu
    // ended the kiosk.
    var isEnabled
        get() = prefs.getBoolean("enabled", true)
        private set(value) = prefs.edit().putBoolean("enabled", value).apply()

    // Child lock: the hardware keys do nothing, only Home Assistant switches
    // the screen. Survives restarts, so a reboot doesn't lift it.
    var isChildLocked
        get() = prefs.getBoolean("child_locked", false)
        private set(value) = prefs.edit().putBoolean("child_locked", value).apply()

    private val speaker = Speaker(activity)
    private val motion = MotionDetector(activity) { channel.invokeMethod("motion", null) }

    // What Home Assistant asked for last - the power button may disagree.
    private var isScreenWanted = true

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startLock" -> { isEnabled = true; enterLock(); result.success(null) }
            "stopLock" -> {
                isEnabled = false
                leaveLock()
                activity.moveTaskToBack(true)
                result.success(null)
            }
            "screenOff" -> result.success(screenOff())
            "screenOn" -> { screenOn(); result.success(null) }
            "setChildLock" -> { isChildLocked = call.argument<Boolean>("value") == true; result.success(null) }
            "isChildLocked" -> result.success(isChildLocked)
            "startMotion" -> {
                motion.darkLevel = call.argument<Int>("darkLevel")?.toFloat() ?: motion.darkLevel
                motion.start()
                result.success(null)
            }
            "stopMotion" -> { motion.stop(); result.success(null) }
            "speak" -> {
                speaker.speak(
                    call.argument<String>("text")!!,
                    call.argument<String>("languageTag")!!,
                    call.argument<Double>("volume")!!,
                )
                result.success(null)
            }
            "setBrightness" -> { setBrightness(call.argument<Double>("value")); result.success(null) }
            "pressKey" -> result.success(KeyService.press(call.argument<String>("key")!!))
            "mediaVolume" -> result.success(mediaVolume())
            "setMediaVolume" -> { setMediaVolume(call.argument<Int>("percent")!!); result.success(null) }
            "isAutoBrightness" -> result.success(isAutoBrightness())
            "setAutoBrightness" -> result.success(setAutoBrightness(call.argument<Boolean>("value") == true))
            "isDeviceOwner" -> result.success(isDeviceOwner)
            "versionCode" -> result.success(AppUpdater.versionCode(activity))
            "installUpdate" -> {
                AppUpdater.install(activity, java.io.File(call.argument<String>("path")!!))
                result.success(null)
            }
            "removeDeviceOwner" -> { removeDeviceOwner(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // Coming back to the front ends a "Kiosk beenden".
    fun onResume() {
        isEnabled = true
        enterLock()
    }

    // Lock task mode only starts from a foreground activity.
    private fun enterLock() {
        if (!isEnabled) return
        if (isDeviceOwner) {
            dpm.setLockTaskPackages(admin, arrayOf(activity.packageName))
            // Android 8.1 (the SM-T585) already blocks Home, Recents and the
            // notification shade in lock task mode; from 9 on it has to be
            // asked for explicitly.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
            }
            dpm.setKeyguardDisabled(admin, true)
            dpm.setStatusBarDisabled(admin, true)
            // The permission dialog can't open in lock task mode - grant
            // the camera (QR scanner) directly.
            dpm.setPermissionGrantState(
                admin,
                activity.packageName,
                Manifest.permission.CAMERA,
                DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED,
            )
            setAsHome()
        }
        if (activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) return
        // Without device owner Android shows its screen pinning prompt.
        try {
            activity.startLockTask()
        } catch (e: IllegalArgumentException) {
            // Not permitted (yet) - stays a normal full-screen app.
        }
    }

    private fun leaveLock() {
        try {
            activity.stopLockTask()
        } catch (e: IllegalStateException) {
            // Wasn't locked.
        }
        if (isDeviceOwner) {
            dpm.setKeyguardDisabled(admin, false)
            dpm.setStatusBarDisabled(admin, false)
            dpm.clearPackagePersistentPreferredActivities(admin, activity.packageName)
        }
    }

    // Home always returns here, and the tablet boots straight into the app.
    private fun setAsHome() {
        val filter = IntentFilter(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addCategory(Intent.CATEGORY_DEFAULT)
        }
        dpm.addPersistentPreferredActivity(admin, filter, ComponentName(activity, MainActivity::class.java))
    }

    // Returns false when the screen can't really be turned off (not device
    // owner) - Flutter then shows a black overlay instead.
    private fun screenOff(): Boolean {
        isScreenWanted = false
        motion.ignoreForAWhile()
        if (!isDeviceOwner) return false
        dpm.lockNow()
        return true
    }

    @Suppress("DEPRECATION")
    private fun screenOn() {
        isScreenWanted = true
        motion.ignoreForAWhile()
        // FULL_WAKE_LOCK + ACQUIRE_CAUSES_WAKEUP is deprecated but still the
        // only way to switch the panel on from the background; the keyguard
        // is disabled, so it lands right back in the app.
        val wakeLock = power.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "ha_display:wake",
        )
        wakeLock.acquire(3000)
        // After "Kiosk beenden" the screen comes on with what was open.
        if (!isEnabled) return
        activity.startActivity(
            Intent(activity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
        )
    }

    // The power button switched the panel off: under child lock straight
    // back on, unless Home Assistant wants it off.
    fun onScreenOff() {
        motion.ignoreForAWhile()
        if (isChildLocked && isScreenWanted) screenOn()
    }

    // The power button switched the panel on: under child lock straight
    // back off when Home Assistant wants it off.
    fun onScreenOn() {
        motion.ignoreForAWhile()
        if (isChildLocked && !isScreenWanted && isDeviceOwner) dpm.lockNow()
    }

    // Volume keys etc. do nothing under child lock.
    fun blocksKey(keyCode: Int) = isChildLocked && keyCode in BLOCKED_KEYS

    // value in 0..1, or null for the system brightness.
    private fun setBrightness(value: Double?) {
        val window = activity.window
        val params = window.attributes
        params.screenBrightness = value?.toFloat()
            ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = params
    }

    private fun mediaVolume(): Int {
        val maximum = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        return audio.getStreamVolume(AudioManager.STREAM_MUSIC) * 100 / maximum
    }

    private fun setMediaVolume(percent: Int) {
        val maximum = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, (percent * maximum + 50) / 100, 0)
    }

    private fun isAutoBrightness() = Settings.System.getInt(
        activity.contentResolver,
        Settings.System.SCREEN_BRIGHTNESS_MODE,
        Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL,
    ) == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC

    // false without the permission from the README's adb step.
    private fun setAutoBrightness(isOn: Boolean): Boolean {
        if (!Settings.System.canWrite(activity)) {
            Log.w(TAG, "may not change the brightness mode")
            return false
        }
        return Settings.System.putInt(
            activity.contentResolver,
            Settings.System.SCREEN_BRIGHTNESS_MODE,
            if (isOn) {
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            } else {
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            },
        )
    }

    fun dispose() {
        motion.stop()
        speaker.dispose()
    }

    @Suppress("DEPRECATION")
    private fun removeDeviceOwner() {
        leaveLock()
        isEnabled = false
        if (isDeviceOwner) dpm.clearDeviceOwnerApp(activity.packageName)
    }

    private companion object {
        const val TAG = "Kiosk"
        val BLOCKED_KEYS = setOf(
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE,
        )
    }
}
