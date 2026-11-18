package com.fling.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import com.snap.camerakit.support.app.CameraActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Snap Camera Kit lenses (real Snapchat lenses) through Snap's own camera
 * screen. These are the app's face filters: the "Lenses" button in the
 * camera opens them.
 *
 * The API token comes from android/local.properties (snap.camerakit.apiToken),
 * written into the manifest at build time; the lens group IDs come from Dart.
 * MainActivity is a plain FlutterActivity (no activity-result launchers), so
 * the screen opens with startActivityForResult and MainActivity hands the
 * result back through [onActivityResult].
 */
class SnapLensChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "com.fling.app/snap_lenses").setMethodCallHandler { call, result ->
            when (call.method) {
                "isConfigured" -> result.success(apiToken().isNotBlank())
                "open" -> {
                    val groups = call.argument<List<String>>("groupIds").orEmpty().filter { it.isNotBlank() }
                    if (apiToken().isBlank() || groups.isEmpty()) {
                        result.error("not_configured", "Snap Camera Kit token or lens groups missing", null)
                        return@setMethodCallHandler
                    }
                    if (pending != null) {
                        result.error("busy", "Snap camera already open", null)
                        return@setMethodCallHandler
                    }
                    pending = result
                    val config = CameraActivity.Configuration.WithLenses(
                        lensGroupIds = groups.toSet(),
                        cameraFacingFront = call.argument<Boolean>("frontCamera") ?: true,
                    )
                    activity.startActivityForResult(
                        CameraActivity.Capture.createIntent(activity, config), REQUEST_CODE
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** True when this was Snap's camera screen closing. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val reply = pending ?: return true
        pending = null
        when (val result = CameraActivity.Capture.parseResult(resultCode, data)) {
            // Snap saves the photo/video as a file in our cache and hands back its file:// Uri.
            is CameraActivity.Capture.Result.Success -> reply.success(
                mapOf(
                    "path" to result.uri.path,
                    "isVideo" to (result is CameraActivity.Capture.Result.Success.Video),
                )
            )
            is CameraActivity.Capture.Result.Failure ->
                reply.error("failed", result.exception.message, null)
            CameraActivity.Capture.Result.Cancelled -> reply.success(null)
        }
        return true
    }

    private fun apiToken(): String {
        val info = activity.packageManager.getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString("com.snap.camerakit.api.token").orEmpty()
    }

    private companion object {
        const val REQUEST_CODE = 0x5AA9
    }
}
