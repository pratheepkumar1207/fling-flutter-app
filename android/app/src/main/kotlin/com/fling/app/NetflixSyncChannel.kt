package com.fling.app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * "N2" test: what InSync can read from and control in another app's player
 * (Netflix) through Android's media sessions — the same controls as the
 * lock screen. Needs notification access (MediaListenerService).
 *
 * Methods on "com.fling.app/n2":
 *   hasAccess, openAccessSettings, openNetflix
 *   sessions -> [{package, title, state, positionMs, durationMs, speed, actions{...}}]
 *   control {package, action: play|pause|seekTo|rewind|fastForward, ms}
 */
class NetflixSyncChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val listener = ComponentName(activity, MediaListenerService::class.java)

    init {
        MethodChannel(messenger, "com.fling.app/n2").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "openAccessSettings" -> {
                        // Android 11+: straight to InSync's own switch; older: the list.
                        val direct = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString())
                        } else null
                        try {
                            activity.startActivity(direct ?: Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        } catch (_: Exception) {
                            activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        }
                        result.success(null)
                    }
                    "openNetflix" -> {
                        val launch = activity.packageManager.getLaunchIntentForPackage(NETFLIX)
                        if (launch == null) {
                            result.success(false)
                        } else {
                            activity.startActivity(launch)
                            result.success(true)
                        }
                    }
                    "sessions" -> result.success(if (hasAccess()) sessions().map(::describe) else emptyList())
                    "control" -> {
                        val pkg = call.argument<String>("package")
                        val c = sessions().firstOrNull { it.packageName == pkg }
                        if (c == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val t = c.transportControls
                        when (call.argument<String>("action")) {
                            "play" -> t.play()
                            "pause" -> t.pause()
                            "seekTo" -> t.seekTo((call.argument<Number>("ms") ?: 0).toLong())
                            "rewind" -> t.rewind()
                            "fastForward" -> t.fastForward()
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) {
                result.error("no_access", e.message, null)
            } catch (e: Exception) {
                result.error("n2", e.message, null)
            }
        }
    }

    private fun hasAccess(): Boolean {
        val enabled = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners").orEmpty()
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == listener }
    }

    private fun sessions(): List<MediaController> {
        val msm = activity.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        return msm.getActiveSessions(listener)
    }

    private fun describe(c: MediaController): Map<String, Any?> {
        val s = c.playbackState
        val meta = c.metadata
        // Position as of now: Android reports it at the last update time.
        var pos = s?.position ?: -1L
        if (s != null && s.state == PlaybackState.STATE_PLAYING && pos >= 0) {
            pos += ((SystemClock.elapsedRealtime() - s.lastPositionUpdateTime) * s.playbackSpeed).toLong()
        }
        val a = s?.actions ?: 0L
        fun has(flag: Long) = a and flag != 0L
        return mapOf(
            "package" to c.packageName,
            "title" to (meta?.getString(MediaMetadata.METADATA_KEY_TITLE)
                ?: meta?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)),
            "state" to stateName(s?.state),
            "positionMs" to pos,
            "durationMs" to (meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: -1L),
            "speed" to (s?.playbackSpeed ?: 0f).toDouble(),
            "actions" to mapOf(
                "play" to has(PlaybackState.ACTION_PLAY),
                "pause" to has(PlaybackState.ACTION_PAUSE),
                "playPause" to has(PlaybackState.ACTION_PLAY_PAUSE),
                "seekTo" to has(PlaybackState.ACTION_SEEK_TO),
                "rewind" to has(PlaybackState.ACTION_REWIND),
                "fastForward" to has(PlaybackState.ACTION_FAST_FORWARD),
                "skipNext" to has(PlaybackState.ACTION_SKIP_TO_NEXT),
            ),
        )
    }

    private fun stateName(state: Int?) = when (state) {
        PlaybackState.STATE_PLAYING -> "playing"
        PlaybackState.STATE_PAUSED -> "paused"
        PlaybackState.STATE_BUFFERING -> "buffering"
        PlaybackState.STATE_STOPPED -> "stopped"
        PlaybackState.STATE_NONE, null -> "none"
        else -> "other($state)"
    }

    private companion object {
        const val NETFLIX = "com.netflix.mediaclient"
    }
}
