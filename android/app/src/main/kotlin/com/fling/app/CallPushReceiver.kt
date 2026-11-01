package com.fling.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Rings for a call while the app is closed or in the background. Handled here
 * rather than in Flutter because Flutter may not be running when the push
 * arrives. Opening the notification brings up the app's own incoming call
 * screen, where it's answered or declined.
 */
class CallPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getStringExtra("type")) {
            "call" -> {
                // Open on screen: the socket's call screen is already ringing.
                if (!inForeground) show(context, intent)
            }
            "call_end" -> {
                val channel = intent.getStringExtra("channelName")
                if (channel == null || channel == ringingChannel) cancel(context)
            }
        }
    }

    private fun show(context: Context, push: Intent) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply {
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 800, 800, 800, 800)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
            )
        }
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            for (key in FIELDS) putExtra("call_$key", push.getStringExtra(key))
            putExtra(EXTRA_CALL, true)
        }
        val tap = PendingIntent.getActivity(
            context, NOTIFICATION_ID, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val video = push.getStringExtra("mode") == "video"
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(push.getStringExtra("fromName") ?: "Someone")
            .setContentText(if (video) "Incoming video call" else "Incoming voice call")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))
            .setOngoing(true)
            .setAutoCancel(true)
            .setTimeoutAfter(RING_MS)
            .setContentIntent(tap)
            .setFullScreenIntent(tap, true)
            .build()
        // Keeps ringing until it's answered, cancelled or times out.
        notification.flags = notification.flags or android.app.Notification.FLAG_INSISTENT
        ringingChannel = push.getStringExtra("channelName")
        manager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val CHANNEL = "incoming_calls"
        private const val NOTIFICATION_ID = 7301
        private const val RING_MS = 45_000L
        const val EXTRA_CALL = "is_incoming_call"
        val FIELDS = listOf("callId", "channelName", "mode", "fromUserId", "fromName", "fromAvatarUrl", "sentAt")

        /** Set by MainActivity while it's on screen. */
        @Volatile
        var inForeground = false

        @Volatile
        private var ringingChannel: String? = null

        fun cancel(context: Context) {
            ringingChannel = null
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(NOTIFICATION_ID)
        }
    }
}
