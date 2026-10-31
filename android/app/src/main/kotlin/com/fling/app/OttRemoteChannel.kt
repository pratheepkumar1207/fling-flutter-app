package com.fling.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.media.MediaMetadata
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// Controls the Netflix / Prime Video app's own player from a watch-party
// room, through Android's standard media-session API (the same controls
// the lock screen and Bluetooth headphones use). Needs Notification access
// for this app — see MediaControlListener.kt. Dart side: core/ott_remote.dart.
class OttRemoteChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.fling.app/ott_remote")
    private val listener = ComponentName(context, MediaControlListener::class.java)

    init {
        channel.setMethodCallHandler { call, result ->
            val pkg = call.argument<String>("package")
            when (call.method) {
                "isInstalled" -> result.success(pkg != null && isInstalled(pkg))
                "hasAccess" -> result.success(hasAccess())
                "openAccessSettings" -> result.success(openAccessSettings())
                "launch" -> result.success(pkg != null && launch(pkg))
                "openTitle" -> result.success(pkg != null && openTitle(pkg, call.argument<String>("url")))
                "getState" -> result.success(pkg?.let { stateOf(it) })
                "play" -> result.success(pkg?.let { controller(it)?.transportControls?.play(); true } ?: false)
                "pause" -> result.success(pkg?.let { controller(it)?.transportControls?.pause(); true } ?: false)
                "seekTo" -> {
                    val ms = call.argument<Number>("positionMs")?.toLong()
                    val c = pkg?.let { controller(it) }
                    if (c != null && ms != null) {
                        c.transportControls.seekTo(ms)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: Exception) {
        false
    }

    private fun hasAccess(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)

    // Straight to this app's switch where Android allows it (11+), else the
    // Notification access list.
    private fun openAccessSettings(): Boolean = try {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString())
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e2: Exception) {
            false
        }
    }

    private fun launch(pkg: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    // The web address first, then the app's own link form.
    private fun openTitle(pkg: String, url: String?): Boolean {
        if (url == null) return false
        val links = listOf(url, url.replaceFirst(Regex("^https?://"), "nflx://"))
        for (link in links) {
            try {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(link))
                        .setPackage(pkg)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return true
            } catch (e: Exception) {
                // Not a link this app takes; try the next.
            }
        }
        return false
    }

    private fun controller(pkg: String): MediaController? {
        if (!hasAccess()) return null
        return try {
            val manager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
            manager.getActiveSessions(listener).firstOrNull { it.packageName == pkg }
        } catch (e: SecurityException) {
            null
        }
    }

    // null when the app isn't playing anything Insync can see.
    private fun stateOf(pkg: String): Map<String, Any?>? {
        val c = controller(pkg) ?: return null
        val s = c.playbackState ?: return null
        // A finished session isn't a player sitting at 0:00.
        if (s.state == PlaybackState.STATE_NONE ||
            s.state == PlaybackState.STATE_STOPPED ||
            s.state == PlaybackState.STATE_ERROR
        ) return null
        // Buffering isn't the person pausing: the room shouldn't pause for it.
        val playing = s.state == PlaybackState.STATE_PLAYING ||
            s.state == PlaybackState.STATE_BUFFERING ||
            s.state == PlaybackState.STATE_CONNECTING
        var position = s.position
        if (s.state == PlaybackState.STATE_PLAYING && s.lastPositionUpdateTime > 0) {
            position += ((SystemClock.elapsedRealtime() - s.lastPositionUpdateTime) * s.playbackSpeed).toLong()
        }
        return mapOf(
            "playing" to playing,
            "positionMs" to position.coerceAtLeast(0),
            "canSeek" to ((s.actions and PlaybackState.ACTION_SEEK_TO) != 0L),
            "title" to c.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
            "durationMs" to c.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION),
        )
    }
}
