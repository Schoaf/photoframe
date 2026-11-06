package at.schoaf.ha_display

import android.content.Context
import android.media.AudioManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.roundToInt

// Android's text to speech, started at the first use. The tablet's keys may
// be out of reach, so each text brings its own volume: the media volume is
// set for it and goes back after the last text.
class Speaker(private val context: Context) {
    private class Speech(val text: String, val languageTag: String, val volume: Double)

    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var engine: TextToSpeech? = null
    private var isReady = false
    private val waiting = mutableListOf<Speech>()
    private val speaking = AtomicInteger(0)
    private var nextUtterance = 0

    @Volatile private var volumeBefore = 0

    fun speak(text: String, languageTag: String, volume: Double) {
        val speech = Speech(text, languageTag, volume)
        if (isReady) return say(speech)
        waiting += speech
        if (engine != null) return
        engine = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isReady = true
                engine?.setOnUtteranceProgressListener(onProgress)
                waiting.forEach(::say)
            } else {
                Log.w(TAG, "text to speech unavailable: $status")
                dispose()
            }
            waiting.clear()
        }
    }

    private fun say(speech: Speech) {
        val engine = engine ?: return
        if (engine.setLanguage(Locale.forLanguageTag(speech.languageTag)) < 0) {
            Log.w(TAG, "no voice for ${speech.languageTag}")
        }
        if (speaking.getAndIncrement() == 0) {
            volumeBefore = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
        }
        val maximum = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, (maximum * speech.volume).roundToInt(), 0)
        val result = engine.speak(speech.text, TextToSpeech.QUEUE_ADD, null, "speech${nextUtterance++}")
        if (result != TextToSpeech.SUCCESS) onSpoken()
    }

    private val onProgress = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) = Unit

        override fun onDone(utteranceId: String?) = onSpoken()

        @Deprecated("Still abstract in the framework")
        override fun onError(utteranceId: String?) = onSpoken()
    }

    private fun onSpoken() {
        if (speaking.decrementAndGet() == 0) {
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, volumeBefore, 0)
        }
    }

    fun dispose() {
        if (speaking.getAndSet(0) > 0) {
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, volumeBefore, 0)
        }
        engine?.shutdown()
        engine = null
        isReady = false
    }

    private companion object {
        const val TAG = "Speaker"
    }
}
