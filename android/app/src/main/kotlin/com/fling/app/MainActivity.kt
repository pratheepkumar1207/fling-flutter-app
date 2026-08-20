package com.fling.app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import android.util.Rational
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service requires the host activity to extend AudioServiceActivity
// (a FlutterFragmentActivity subclass) instead of plain FlutterActivity —
// see background_audio_handler.dart for why (real lock-screen/background
// playback for Drive-hosted rooms).
//
// Also hosts the real Android Picture-in-Picture channel — see
// core/pip_service.dart. PiP is an Activity-level window mode change, not
// something a Flutter plugin channel alone can drive; entering/leaving it
// and reporting the transition back to Dart has to happen here.
class MainActivity : AudioServiceActivity() {
    private val pipChannelName = "com.fling.app/pip"
    private var pipChannel: MethodChannel? = null

    // Only auto-enter PiP on the home/recent-apps gesture while a room's
    // video is actually up — Flutter toggles this via the channel as
    // party_screen.dart mounts/unmounts, so backgrounding from any other
    // screen (Home, Feed, chat, ...) doesn't pop up a PiP window with
    // nothing worth watching in it.
    private var autoPipEnabled = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        pipChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAutoPipEnabled" -> {
                    autoPipEnabled = call.argument<Boolean>("enabled") ?: false
                    Log.d("FlingPip", "setAutoPipEnabled -> $autoPipEnabled")
                    result.success(null)
                }
                "enterPip" -> result.success(enterPip())
                "isPipSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                else -> result.notImplemented()
            }
        }
    }

    private fun enterPip(): Boolean {
        Log.d("FlingPip", "enterPip() called, sdkInt=${Build.VERSION.SDK_INT}")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val params = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build()
            val entered = enterPictureInPictureMode(params)
            Log.d("FlingPip", "enterPictureInPictureMode() returned $entered")
            entered
        } catch (e: Exception) {
            // IllegalStateException etc. if the window state doesn't allow it
            // right now — nothing more useful to do than stay in normal mode.
            Log.e("FlingPip", "enterPictureInPictureMode() threw", e)
            false
        }
    }

    // Called by Android right before the app is actually backgrounded via a
    // voluntary user action (home button, recents, switching to another
    // app) — NOT for e.g. the screen simply turning off. Exactly the
    // "user moved to another app" moment PIP is for.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d("FlingPip", "onUserLeaveHint(), autoPipEnabled=$autoPipEnabled")
        if (autoPipEnabled) enterPip()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        Log.d("FlingPip", "onPictureInPictureModeChanged -> $isInPictureInPictureMode")
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
