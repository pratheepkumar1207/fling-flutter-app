package com.fling.app

import android.content.Context
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Sounds around a call: the phone's own ringtone and vibration when one comes
 * in, following its silent and vibrate modes, and the ringing tone the caller
 * hears while waiting.
 */
class CallRingChannel(private val context: Context, messenger: BinaryMessenger) {
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var ringback: ToneGenerator? = null
    private val channel = MethodChannel(messenger, "com.fling.app/call_ring")

    /** A call opened from its notification, until Flutter collects it. */
    var pendingCall: Map<String, String?>? = null

    /** Tells a running app; a starting one collects it with "pendingCall". */
    fun announcePendingCall() {
        channel.invokeMethod("callOpened", null)
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pendingCall" -> {
                    result.success(pendingCall)
                    pendingCall = null
                    return@setMethodCallHandler
                }
                "callFinished" -> {
                    CallPushReceiver.cancel(context)
                    (context as? android.app.Activity)?.let {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                            it.setShowWhenLocked(false)
                            it.setTurnScreenOn(false)
                        }
                    }
                }
                "incoming" -> startIncoming()
                "ringback" -> startRingback()
                "stop" -> stop()
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }
    }

    private fun startIncoming() {
        stop()
        // In the background the notification is already ringing.
        if (!CallPushReceiver.inForeground) return
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (audio.ringerMode == AudioManager.RINGER_MODE_SILENT) return
        if (audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
            val uri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
            ringtone = uri?.let { RingtoneManager.getRingtone(context, it) }?.also {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) it.isLooping = true
                it.play()
            }
        }
        @Suppress("DEPRECATION")
        vibrator = (context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)?.also {
            val pattern = longArrayOf(0, 800, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(pattern, 0)
            }
        }
    }

    private fun startRingback() {
        stop()
        ringback = try {
            ToneGenerator(AudioManager.STREAM_VOICE_CALL, 80).also {
                it.startTone(ToneGenerator.TONE_SUP_RINGTONE)
            }
        } catch (_: RuntimeException) {
            null // No tone on this phone; the call itself still works.
        }
    }

    private fun stop() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
        ringback?.release()
        ringback = null
    }
}
