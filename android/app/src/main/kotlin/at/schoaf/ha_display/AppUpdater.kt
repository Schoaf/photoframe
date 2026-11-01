package at.schoaf.ha_display

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

// Installs a downloaded APK of this app. As device owner the install runs
// silently; Android itself refuses an APK signed with another key.
object AppUpdater {
    fun versionCode(context: Context): Long {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            .apply { setAppPackageName(context.packageName) }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            session.openWrite("update.apk", 0, apk.length()).use { out ->
                apk.inputStream().use { it.copyTo(out) }
                session.fsync(out)
            }
            val callback = PendingIntent.getBroadcast(
                context,
                sessionId,
                Intent(context, InstallResultReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT,
            )
            session.commit(callback.intentSender)
        }
    }
}

// Only logs failures - on success this process is replaced anyway.
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status != PackageInstaller.STATUS_SUCCESS) {
            android.util.Log.w(
                "HaDisplayUpdate",
                "Update failed: $status ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}",
            )
        }
    }
}

// Brings the display back right after an update replaced the app.
class UpdatedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.startActivity(
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
