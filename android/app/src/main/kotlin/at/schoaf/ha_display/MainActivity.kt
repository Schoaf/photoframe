package at.schoaf.ha_display

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.PowerManager
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var kiosk: Kiosk

    // The power button - only reported to registered receivers.
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> kiosk.onScreenOff()
                Intent.ACTION_SCREEN_ON -> kiosk.onScreenOn()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Lets Home Assistant's "screen on" show the app right away.
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        registerReceiver(
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            },
        )
    }

    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        KeyService.setAppInFront(false)
        kiosk.dispose()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ha_display/kiosk")
        kiosk = Kiosk(this, channel)
        channel.setMethodCallHandler(kiosk)
    }

    override fun onResume() {
        super.onResume()
        KeyService.setAppInFront(true)
        kiosk.onResume()
    }

    override fun onPause() {
        super.onPause()
        // With the screen off the app is still what shows when it comes on.
        val power = getSystemService(POWER_SERVICE) as PowerManager
        if (power.isInteractive) KeyService.setAppInFront(false)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean =
        kiosk.blocksKey(event.keyCode) || super.dispatchKeyEvent(event)
}
