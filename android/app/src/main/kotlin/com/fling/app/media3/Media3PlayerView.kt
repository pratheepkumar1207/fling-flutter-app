package com.fling.app.media3

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

// Backs SyncVideoPlayer/DriveVideoPlayer's native-player path (spec section
// 13-16's Media3Adapter) — one instance per Flutter AndroidView, its own
// ExoPlayer, its own pair of channels scoped by viewId so multiple players
// (e.g. a hidden background-continuity instance alongside the visible one,
// per persistent_room_audio.dart's existing pattern for the WebView-based
// players) never cross-talk.
//
// useController = false throughout: Flutter draws its own play/pause/seek/
// skip overlay (see room_play_pause_button.dart etc.) the same way it
// already does for the YouTube/webview players — PlayerView here is purely
// the video *surface*, never Media3's own on-screen controls.
class Media3PlayerView(
    context: Context,
    viewId: Int,
    creationParams: Map<*, *>?,
    messenger: BinaryMessenger,
) : PlatformView {
    private val playerView: PlayerView = PlayerView(context).apply {
        useController = false
        // MATCH_PARENT within whatever size Flutter's AndroidView box gives
        // this platform view — sizing itself is controlled from the Dart
        // side (a SizedBox/AspectRatio around the AndroidView widget), same
        // convention as the existing WebView-based players.
        layoutParams = android.view.ViewGroup.LayoutParams(
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            android.view.ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }

    private val exoPlayer: ExoPlayer = ExoPlayer.Builder(context).build().also {
        playerView.player = it
    }

    private val methodChannel = MethodChannel(messenger, "fling/media3_player_$viewId")
    private val eventChannel = EventChannel(messenger, "fling/media3_player_events_$viewId")
    private var eventSink: EventChannel.EventSink? = null

    private val tickHandler = Handler(Looper.getMainLooper())
    private val tickIntervalMs = 500L
    private val tickRunnable = object : Runnable {
        override fun run() {
            emitTick()
            tickHandler.postDelayed(this, tickIntervalMs)
        }
    }

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as? Map<*, *>
                    val url = args?.get("url") as? String
                    val type = args?.get("type") as? String ?: "direct"
                    @Suppress("UNCHECKED_CAST")
                    val headers = (args?.get("headers") as? Map<String, String>) ?: emptyMap()
                    if (url == null) {
                        result.error("bad_args", "initialize requires a url", null)
                    } else {
                        initialize(url, type, headers)
                        result.success(null)
                    }
                }
                "play" -> { exoPlayer.play(); result.success(null) }
                "pause" -> { exoPlayer.pause(); result.success(null) }
                "seekTo" -> {
                    val positionMs = (call.arguments as? Map<*, *>)?.get("positionMs") as? Number
                    if (positionMs == null) {
                        result.error("bad_args", "seekTo requires positionMs", null)
                    } else {
                        exoPlayer.seekTo(positionMs.toLong())
                        result.success(null)
                    }
                }
                "setPlaybackRate" -> {
                    val rate = (call.arguments as? Map<*, *>)?.get("rate") as? Number
                    if (rate == null) {
                        result.error("bad_args", "setPlaybackRate requires rate", null)
                    } else {
                        exoPlayer.playbackParameters = PlaybackParameters(rate.toFloat())
                        result.success(null)
                    }
                }
                "setVolume" -> {
                    val volume = (call.arguments as? Map<*, *>)?.get("volume") as? Number
                    if (volume == null) {
                        result.error("bad_args", "setVolume requires volume", null)
                    } else {
                        exoPlayer.volume = volume.toFloat().coerceIn(0f, 1f)
                        result.success(null)
                    }
                }
                "getPosition" -> result.success(exoPlayer.currentPosition)
                "getDuration" -> {
                    val duration = exoPlayer.duration
                    result.success(if (duration == androidx.media3.common.C.TIME_UNSET) null else duration)
                }
                // No explicit "dispose" method — Flutter's platform view
                // lifecycle already calls PlatformView.dispose() exactly
                // once when the AndroidView widget is removed from the
                // tree; a second, channel-triggered release() path here
                // would risk double-releasing the same ExoPlayer instance.
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
                tickHandler.post(tickRunnable)
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                tickHandler.removeCallbacks(tickRunnable)
            }
        })

        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                emitStateChange()
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                emitStateChange()
            }

            override fun onPlayerError(error: PlaybackException) {
                eventSink?.success(
                    mapOf(
                        "type" to "error",
                        "message" to (error.message ?: "Unknown player error"),
                        "errorCode" to error.errorCodeName,
                    ),
                )
            }
        })
    }

    private fun initialize(url: String, type: String, headers: Map<String, String>) {
        val mediaItem = MediaItem.fromUri(url)
        val httpDataSourceFactory = DefaultHttpDataSource.Factory().apply {
            if (headers.isNotEmpty()) setDefaultRequestProperties(headers)
        }
        val mediaSource: MediaSource = when (type) {
            "hls" -> HlsMediaSource.Factory(httpDataSourceFactory).createMediaSource(mediaItem)
            "dash" -> DashMediaSource.Factory(httpDataSourceFactory).createMediaSource(mediaItem)
            // "direct" (progressive MP4/etc.) is also the fallback for any
            // unrecognized type — ProgressiveMediaSource is the closest
            // thing Media3 has to "just try to play whatever this is."
            else -> ProgressiveMediaSource.Factory(httpDataSourceFactory).createMediaSource(mediaItem)
        }
        exoPlayer.setMediaSource(mediaSource)
        exoPlayer.prepare()
    }

    // Spec section 77's PlayerState enum, mapped from Media3's own
    // STATE_IDLE/BUFFERING/READY/ENDED + isPlaying (Media3 conflates "ready
    // but paused" and "playing" into one state, isPlaying is what actually
    // distinguishes them).
    private fun emitStateChange() {
        val state = when {
            exoPlayer.playbackState == Player.STATE_IDLE -> "idle"
            exoPlayer.playbackState == Player.STATE_BUFFERING -> "buffering"
            exoPlayer.playbackState == Player.STATE_ENDED -> "ended"
            exoPlayer.isPlaying -> "playing"
            else -> "paused"
        }
        eventSink?.success(
            mapOf(
                "type" to "stateChanged",
                "state" to state,
                "positionMs" to exoPlayer.currentPosition,
                "durationMs" to exoPlayer.duration.takeIf { it != androidx.media3.common.C.TIME_UNSET },
            ),
        )
    }

    private fun emitTick() {
        if (exoPlayer.playbackState == Player.STATE_IDLE) return
        eventSink?.success(
            mapOf(
                "type" to "tick",
                "positionMs" to exoPlayer.currentPosition,
                "bufferedPositionMs" to exoPlayer.bufferedPosition,
                "durationMs" to exoPlayer.duration.takeIf { it != androidx.media3.common.C.TIME_UNSET },
                "isPlaying" to exoPlayer.isPlaying,
            ),
        )
    }

    override fun getView(): View = playerView

    override fun dispose() {
        tickHandler.removeCallbacks(tickRunnable)
        eventSink = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        exoPlayer.release()
    }
}
