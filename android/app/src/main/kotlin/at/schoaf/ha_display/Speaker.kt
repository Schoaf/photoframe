package at.schoaf.ha_display

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

// Android's text to speech, started at the first use.
class Speaker(private val context: Context) {
    private var engine: TextToSpeech? = null
    private var isReady = false
    private val waiting = mutableListOf<Pair<String, String>>()

    fun speak(text: String, languageTag: String) {
        if (isReady) return say(text, languageTag)
        waiting += text to languageTag
        if (engine != null) return
        engine = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isReady = true
                waiting.forEach { (text, languageTag) -> say(text, languageTag) }
            } else {
                Log.w(TAG, "text to speech unavailable: $status")
                dispose()
            }
            waiting.clear()
        }
    }

    private fun say(text: String, languageTag: String) {
        val engine = engine ?: return
        if (engine.setLanguage(Locale.forLanguageTag(languageTag)) < 0) {
            Log.w(TAG, "no voice for $languageTag")
        }
        engine.speak(text, TextToSpeech.QUEUE_ADD, null, text)
    }

    fun dispose() {
        engine?.shutdown()
        engine = null
        isReady = false
    }

    private companion object {
        const val TAG = "Speaker"
    }
}
