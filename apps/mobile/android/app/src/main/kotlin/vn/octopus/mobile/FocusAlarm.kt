package vn.octopus.mobile

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

class FocusAlarm(context: Context) {
    private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    private var tone: ToneGenerator? = null
    private var loudMode: Boolean? = null

    fun pulse(loud: Boolean, vibrate: Boolean) {
        try {
            if (tone == null || loudMode != loud) {
                tone?.release()
                tone = ToneGenerator(if (loud) AudioManager.STREAM_ALARM else AudioManager.STREAM_MUSIC, if (loud) 95 else 45)
                loudMode = loud
            }
            tone?.startTone(if (loud) ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD else ToneGenerator.TONE_PROP_BEEP2, if (loud) 800 else 250)
            if (vibrate && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(250, VibrationEffect.DEFAULT_AMPLITUDE))
                else @Suppress("DEPRECATION") vibrator.vibrate(250)
            }
        } catch (_: RuntimeException) { /* The visual protection remains available. */ }
    }

    fun stop() { tone?.stopTone(); vibrator.cancel() }
    fun close() { stop(); tone?.release(); tone = null }
}
