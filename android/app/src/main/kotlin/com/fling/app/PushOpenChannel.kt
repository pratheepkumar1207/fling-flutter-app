package com.fling.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Hands a tapped InSync notification (or its Join / Let in button) to
 * Flutter: a starting app collects it with "pending", a running one is told
 * with "opened".
 */
class PushOpenChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.fling.app/push_open")
    private var pending: Map<String, String>? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "pending") {
                result.success(pending)
                pending = null
            } else {
                result.notImplemented()
            }
        }
    }

    /** Takes the notification out of [intent], if it came from one. */
    fun take(intent: Intent?, announce: Boolean) {
        val data = intent?.getStringExtra(InsyncPush.EXTRA_DATA) ?: return
        val action = intent.getStringExtra(InsyncPush.EXTRA_ACTION) ?: "open"
        val id = intent.getIntExtra(InsyncPush.EXTRA_NOTIFICATION_ID, 0)
        intent.removeExtra(InsyncPush.EXTRA_DATA)
        intent.removeExtra(InsyncPush.EXTRA_ACTION)
        if (id != 0) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
        }
        pending = mapOf("action" to action, "data" to data)
        if (announce) channel.invokeMethod("opened", null)
    }
}
