package com.fling.app

import android.service.notification.NotificationListenerService

/**
 * Empty on purpose. Android only lets an app see and control other apps'
 * media sessions (e.g. Netflix's play/pause/position) if the person has
 * given it notification access, and that access is granted to a
 * NotificationListenerService. We never read notifications; see
 * NetflixSyncChannel.kt for what this is used for.
 */
class MediaListenerService : NotificationListenerService()
