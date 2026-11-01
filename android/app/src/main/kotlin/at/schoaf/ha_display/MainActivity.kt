package at.schoaf.ha_display

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var kiosk: Kiosk

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Lets Home Assistant's "screen on" show the app right away.
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        kiosk = Kiosk(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ha_display/kiosk")
            .setMethodCallHandler(kiosk)
    }

    override fun onResume() {
        super.onResume()
        kiosk.enterLock()
    }
}
