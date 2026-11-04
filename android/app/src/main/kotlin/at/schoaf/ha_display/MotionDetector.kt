package at.schoaf.ha_display

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Range
import kotlin.math.abs

// Watches the room through the front camera at a few frames per second and
// reports motion. Keeps running while the screen is off. Small block
// averages, compared relative to the frame's brightness, so camera noise and
// the screen's own light changing with each photo don't count; in a dark
// room nothing counts - nobody's there.
class MotionDetector(context: Context, private val onMotion: () -> Unit) {
    private val cameras = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var camera: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var previous: FloatArray? = null
    private var wasDark = true
    private var lastFrameMs = 0L
    private var lastMotionMs = 0L
    private var lastLogMs = 0L

    // Frames right after the screen switched are skipped - its light and
    // the camera's exposure settle first.
    @Volatile private var ignoreUntilMs = 0L

    var isRunning = false
        private set

    fun start() {
        if (isRunning) return
        isRunning = true
        val thread = HandlerThread("motion").also { it.start() }
        this.thread = thread
        handler = Handler(thread.looper)
        open()
    }

    fun stop() {
        isRunning = false
        mainHandler.removeCallbacksAndMessages(null)
        close()
        thread?.quitSafely()
        thread = null
        handler = null
    }

    fun ignoreForAWhile() {
        ignoreUntilMs = SystemClock.elapsedRealtime() + SETTLE_MS
    }

    @SuppressLint("MissingPermission") // Granted as device owner (Kiosk.enterLock).
    private fun open() {
        val handler = handler ?: return
        val id = cameras.cameraIdList.firstOrNull {
            cameras.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
        } ?: return
        try {
            cameras.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    Log.i(TAG, "camera opened")
                    camera = device
                    startCapture(id, device)
                }

                // E.g. the QR scanner in the settings took the camera.
                override fun onDisconnected(device: CameraDevice) = retryLater()

                override fun onError(device: CameraDevice, error: Int) = retryLater()
            }, handler)
        } catch (e: Exception) {
            retryLater()
        }
    }

    private fun startCapture(id: String, device: CameraDevice) {
        val characteristics = cameras.getCameraCharacteristics(id)
        val sizes = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?.getOutputSizes(ImageFormat.YUV_420_888)
            .orEmpty()
        val size = sizes.filter { it.width >= 320 }.minByOrNull { it.width * it.height }
            ?: sizes.minByOrNull { it.width * it.height }
            ?: return retryLater()
        val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 2)
        this.reader = reader
        reader.setOnImageAvailableListener({ onImage(it) }, handler)
        // The slowest frame rate the camera offers - a few frames are plenty.
        val fps = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            ?.minByOrNull { it.upper }
        try {
            @Suppress("DEPRECATION")
            device.createCaptureSession(listOf(reader.surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    this@MotionDetector.session = session
                    val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                        addTarget(reader.surface)
                        if (fps != null) set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(fps.lower, fps.upper))
                    }.build()
                    try {
                        session.setRepeatingRequest(request, null, handler)
                    } catch (e: Exception) {
                        retryLater()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) = retryLater()
            }, handler)
        } catch (e: Exception) {
            retryLater()
        }
    }

    private fun onImage(reader: ImageReader) {
        val image = reader.acquireLatestImage() ?: return
        val now = SystemClock.elapsedRealtime()
        if (now - lastFrameMs < FRAME_INTERVAL_MS) {
            image.close()
            return
        }
        lastFrameMs = now
        val plane = image.planes[0]
        val buffer = plane.buffer
        val width = image.width
        val height = image.height
        val blocks = FloatArray(GRID_X * GRID_Y)
        for (by in 0 until GRID_Y) {
            for (bx in 0 until GRID_X) {
                var sum = 0L
                var count = 0
                var y = by * height / GRID_Y
                val yEnd = (by + 1) * height / GRID_Y
                while (y < yEnd) {
                    var x = bx * width / GRID_X
                    val xEnd = (bx + 1) * width / GRID_X
                    while (x < xEnd) {
                        sum += buffer.get(y * plane.rowStride + x * plane.pixelStride).toInt() and 0xFF
                        count++
                        x += SAMPLE_STEP
                    }
                    y += SAMPLE_STEP
                }
                blocks[by * GRID_X + bx] = if (count == 0) 0f else sum.toFloat() / count
            }
        }
        image.close()
        process(blocks, now)
    }

    private fun process(blocks: FloatArray, now: Long) {
        val mean = blocks.average().toFloat()
        val isDark = mean < DARK_LEVEL
        val previous = previous
        this.previous = blocks
        val wasDark = this.wasDark
        this.wasDark = isDark
        if (isDark && now - lastLogMs >= LOG_INTERVAL_MS) {
            lastLogMs = now
            Log.d(TAG, "dark, mean ${mean.toInt()}")
        }
        if (isDark || now < ignoreUntilMs || previous == null) return
        // The light was switched on.
        if (wasDark) return report(now)
        val previousMean = previous.average().toFloat()
        var changed = 0
        for (i in blocks.indices) {
            val relative = abs(blocks[i] / mean - previous[i] / previousMean)
            val absolute = abs(blocks[i] - previous[i])
            if (relative > RELATIVE_CHANGE && absolute > ABSOLUTE_CHANGE) changed++
        }
        if (now - lastLogMs >= LOG_INTERVAL_MS) {
            lastLogMs = now
            Log.d(TAG, "mean ${mean.toInt()}, changed blocks $changed")
        }
        if (changed >= MIN_CHANGED_BLOCKS) report(now)
    }

    private fun report(now: Long) {
        if (now - lastMotionMs < REPORT_INTERVAL_MS) return
        lastMotionMs = now
        Log.i(TAG, "motion")
        mainHandler.post(onMotion)
    }

    private fun retryLater() {
        Log.w(TAG, "camera lost, retrying")
        close()
        if (!isRunning) return
        mainHandler.postDelayed({ if (isRunning) handler?.post { open() } }, RETRY_MS)
    }

    private fun close() {
        try {
            session?.close()
            camera?.close()
            reader?.close()
        } catch (e: Exception) {
            // Already gone.
        }
        session = null
        camera = null
        reader = null
        previous = null
    }

    private companion object {
        const val TAG = "Motion"
        const val LOG_INTERVAL_MS = 10_000L
        const val GRID_X = 16
        const val GRID_Y = 12
        const val SAMPLE_STEP = 4
        const val FRAME_INTERVAL_MS = 500L
        const val REPORT_INTERVAL_MS = 2_000L
        const val SETTLE_MS = 5_000L
        const val RETRY_MS = 60_000L

        // Mean brightness (0-255) below which the room counts as dark.
        const val DARK_LEVEL = 12f

        // A block counts as changed when it differs by this much relative
        // to the frame's brightness, and by this many levels.
        const val RELATIVE_CHANGE = 0.2f
        const val ABSOLUTE_CHANGE = 10f
        const val MIN_CHANGED_BLOCKS = 4
    }
}
