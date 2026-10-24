package com.fling.app

import android.service.notification.NotificationListenerService

// Netflix/Prime watch-party sync. Android only lets an app see and control
// another app's media session (play/pause/seek, current position) while
// the person has granted that app "Notification access" — which is what
// declaring this service asks for. Nothing here reads notifications; the
// service only has to exist. See OttRemoteChannel.kt for the controls and
// core/ott_remote.dart for how rooms use them.
class MediaControlListener : NotificationListenerService()
