package at.schoaf.ha_display

import android.app.admin.DeviceAdminReceiver

// Made device owner once via
// `adb shell dpm set-device-owner at.schoaf.ha_display/.KioskAdminReceiver`
// (see README). Grants lock task mode without the pinning prompt.
class KioskAdminReceiver : DeviceAdminReceiver()
