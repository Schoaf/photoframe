package at.schoaf.ha_display

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.LinearLayout
import android.widget.TextView

// The tablet's keys sit behind the wall frame, and Android has no key bar of
// its own here. This service presses them for Home Assistant, and shows a
// bar of keys on screen while the app isn't in front. It reads nothing from
// other apps. Also keeps the process alive after the kiosk ended.
class KeyService : AccessibilityService() {
    private var bar: View? = null

    private val windows get() = getSystemService(WINDOW_SERVICE) as WindowManager

    override fun onServiceConnected() {
        instance = this
        updateBar()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        instance = null
        hideBar()
        super.onDestroy()
    }

    private fun updateBar() = if (isAppInFront) hideBar() else showBar()

    private fun showBar() {
        if (bar != null) return
        val row = LinearLayout(this).apply {
            setBackgroundColor(Color.argb(200, 0, 0, 0))
            addView(key("◀", "Back") { performGlobalAction(GLOBAL_ACTION_BACK) })
            addView(key("●", "Home") { performGlobalAction(GLOBAL_ACTION_HOME) })
            addView(key("■", "Recent apps") { performGlobalAction(GLOBAL_ACTION_RECENTS) })
            addView(key("PhotoFrame", "PhotoFrame") { openApp() })
        }
        windows.addView(
            row,
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL },
        )
        bar = row
    }

    private fun hideBar() {
        bar?.let(windows::removeView)
        bar = null
    }

    private fun key(label: String, description: String, onTap: () -> Unit) = TextView(this).apply {
        text = label
        contentDescription = description
        setTextColor(Color.WHITE)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, KEY_TEXT_SP)
        gravity = Gravity.CENTER
        minWidth = dp(KEY_SIZE_DP)
        minHeight = dp(KEY_SIZE_DP)
        setPadding(dp(KEY_PADDING_DP), 0, dp(KEY_PADDING_DP), 0)
        setOnClickListener { onTap() }
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    // Back in front the kiosk locks again (Kiosk.onResume).
    private fun openApp() {
        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    companion object {
        private const val TAG = "KeyService"
        private const val KEY_SIZE_DP = 72
        private const val KEY_PADDING_DP = 24
        private const val KEY_TEXT_SP = 24f
        private val actions = mapOf(
            "back" to GLOBAL_ACTION_BACK,
            "home" to GLOBAL_ACTION_HOME,
            "recents" to GLOBAL_ACTION_RECENTS,
        )
        private val mainHandler = Handler(Looper.getMainLooper())
        private var instance: KeyService? = null

        // Starts false, so the bar is there when the app crashed.
        private var isAppInFront = false

        fun setAppInFront(isInFront: Boolean) {
            mainHandler.post {
                isAppInFront = isInFront
                instance?.updateBar()
            }
        }

        fun press(key: String): Boolean {
            val service = instance
            val action = actions[key]
            if (service == null || action == null) {
                Log.w(TAG, "can't press $key - service running: ${service != null}")
                return false
            }
            return service.performGlobalAction(action)
        }
    }
}
