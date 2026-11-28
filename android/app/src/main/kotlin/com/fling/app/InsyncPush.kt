package com.fling.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Shader
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Draws InSync's phone notifications (approved design, Nov 2026): the
 * sender's photo, the bars icon, one of four groups the user can mute on
 * their own (Lobby invites, Lobby requests, Gifts, Activity), buttons where
 * there's a next step (Join / Not now, Let in / No), and likes, follows and
 * mentions stacked into one "N new" notification instead of buzzing each
 * time. The server sends these as data-only pushes marked insync=1.
 */
object InsyncPush {
    private const val RED = 0xFFE8112D.toInt()
    private const val ACTIVITY_GROUP = "insync_activity"
    private const val SUMMARY_ID = 7400
    const val EXTRA_DATA = "insync_push"
    const val EXTRA_ACTION = "insync_action"
    const val EXTRA_NOTIFICATION_ID = "insync_notification_id"

    private data class Group(val id: String, val name: String, val importance: Int)

    private val INVITES = Group("lobby_invites", "Lobby invites", NotificationManager.IMPORTANCE_HIGH)
    private val REQUESTS = Group("lobby_requests", "Lobby requests", NotificationManager.IMPORTANCE_HIGH)
    private val GIFTS = Group("gifts", "Gifts", NotificationManager.IMPORTANCE_DEFAULT)
    private val ACTIVITY = Group("activity", "Activity", NotificationManager.IMPORTANCE_DEFAULT)

    private fun groupFor(type: String?) = when (type) {
        "room_invite", "blend_invite", "blend_watch", "friend_online", "event_reminder" -> INVITES
        "room_join_ask", "friend_request", "community_request" -> REQUESTS
        "gift", "gift_received", "new_subscriber", "cashout_requested" -> GIFTS
        else -> ACTIVITY
    }

    // FCM's own keys, not ours.
    private fun isOurs(key: String) =
        !key.startsWith("google.") && !key.startsWith("gcm.") && key != "from" && key != "collapse_key"

    fun show(context: Context, push: Intent, done: BroadcastReceiver.PendingResult) {
        Thread {
            try {
                post(context, push)
            } catch (_: Exception) {
            } finally {
                done.finish()
            }
        }.start()
    }

    private fun post(context: Context, push: Intent) {
        val data = JSONObject()
        push.extras?.keySet()?.filter(::isOurs)?.forEach { k ->
            push.extras?.getString(k)?.let { data.put(k, it) }
        }
        val type = data.optString("type")
        val group = groupFor(type)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            for (g in listOf(INVITES, REQUESTS, GIFTS, ACTIVITY)) {
                manager.createNotificationChannel(NotificationChannel(g.id, g.name, g.importance))
            }
        }
        val key = data.optString("notificationId").ifEmpty { "${type}:${data.optString("roomId")}:${data.optString("fromUserId")}:${System.currentTimeMillis()}" }
        val id = key.hashCode()
        val title = data.optString("title").ifEmpty { "InSync" }
        val body = data.optString("body")
        val fromName = data.optString("fromName").ifEmpty { data.optString("name") }

        val builder = NotificationCompat.Builder(context, group.id)
            .setSmallIcon(R.drawable.ic_stat_insync)
            .setColor(RED)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(if (group.importance == NotificationManager.IMPORTANCE_HIGH) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(openIntent(context, data, "open", id))
        photo(data.optString("fromAvatarUrl"), fromName)?.let { builder.setLargeIcon(it) }

        when (type) {
            "room_invite", "blend_invite", "blend_watch" -> {
                builder.addAction(0, "Join", openIntent(context, data, "join", id))
                builder.addAction(0, "Not now", dismissIntent(context, id))
            }
            "room_join_ask" -> {
                builder.addAction(0, "Let in", openIntent(context, data, "let_in", id))
                builder.addAction(0, "No", dismissIntent(context, id))
            }
        }
        if (group == ACTIVITY) builder.setGroup(ACTIVITY_GROUP)
        manager.notify(id, builder.build())
        if (group == ACTIVITY) postSummary(context, manager)
    }

    /** "4 new": one line per like, follow or mention that's still showing. */
    private fun postSummary(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val lines = manager.activeNotifications
            .filter { it.notification.group == ACTIVITY_GROUP && it.id != SUMMARY_ID }
            .sortedByDescending { it.postTime }
            .mapNotNull { it.notification.extras.getCharSequence(android.app.Notification.EXTRA_TITLE) }
        if (lines.size < 2) return
        val style = NotificationCompat.InboxStyle().setBigContentTitle("${lines.size} new")
        lines.take(6).forEach { style.addLine(it) }
        val summary = NotificationCompat.Builder(context, ACTIVITY.id)
            .setSmallIcon(R.drawable.ic_stat_insync)
            .setColor(RED)
            .setContentTitle("${lines.size} new")
            .setContentText(lines.first())
            .setStyle(style)
            .setGroup(ACTIVITY_GROUP)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setContentIntent(openIntent(context, JSONObject(), "open", SUMMARY_ID))
            .build()
        manager.notify(SUMMARY_ID, summary)
    }

    private fun openIntent(context: Context, data: JSONObject, action: String, id: Int): PendingIntent {
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_DATA, data.toString())
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_NOTIFICATION_ID, id)
        }
        return PendingIntent.getActivity(
            context, (id.toString() + action).hashCode(), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun dismissIntent(context: Context, id: Int): PendingIntent {
        val i = Intent(context, InsyncPushDismiss::class.java).putExtra(EXTRA_NOTIFICATION_ID, id)
        return PendingIntent.getBroadcast(
            context, (id.toString() + "dismiss").hashCode(), i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Their photo in a circle, or their first letter on red. */
    private fun photo(url: String, name: String): Bitmap? {
        val size = 128
        val src: Bitmap? = if (url.startsWith("http")) try {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 3000
            c.readTimeout = 3000
            c.inputStream.use { BitmapFactory.decodeStream(it) }
        } catch (_: Exception) { null } else null
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        if (src != null) {
            val side = minOf(src.width, src.height)
            val square = Bitmap.createBitmap(src, (src.width - side) / 2, (src.height - side) / 2, side, side)
            val scaled = Bitmap.createScaledBitmap(square, size, size, true)
            paint.shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
            return out
        }
        if (name.isBlank()) return null
        paint.color = RED
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.color = Color.WHITE
        paint.textSize = 56f
        paint.isFakeBoldText = true
        paint.textAlign = Paint.Align.CENTER
        val y = size / 2f - (paint.descent() + paint.ascent()) / 2
        canvas.drawText(name.trim().take(1).uppercase(), size / 2f, y, paint)
        return out
    }
}

/** "Not now" / "No": just clears the notification. */
class InsyncPushDismiss : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(InsyncPush.EXTRA_NOTIFICATION_ID, 0)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }
}
