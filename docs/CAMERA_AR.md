# Camera & AR/Effects

## Confirmed absent, not another "mostly already real" phase

Searched the whole app: the only camera-related dependency is `image_picker` (`pubspec.yaml`), which opens the OS's native camera app or gallery picker and hands back a finished file — it has no in-app live preview, no frame-by-frame access, and cannot support switching lenses mid-capture, zoom, flash toggling, a timer, speed ramping, filters, AR overlays, beauty smoothing, text/sticker/drawing overlays, or an editor. The existing camera usage in the app (`live_broadcast_controller.dart`, `call_screen.dart`) goes through Agora's own capture pipeline for live video calls/broadcasts — that's Agora managing the camera for a voice/video call, not a reusable `CameraEngine` for content creation. `photo_verification.dart`/`wallet_kyc_screen.dart` use a single-shot camera capture for identity verification, same limited scope.

## Why this wasn't built

Spec Steps 16-17 ask for a full creation camera (photo/video/Reel/Story/Karaoke/Duet/Live modes, camera switching, zoom, flash, timer, speed, filters, AR, beauty, text, stickers, drawing, music, voice effects, an editor, drafts) plus an AR effect registry with categories and moderation. This is one of the largest single asks in the whole spec, and two things make it unsafe to attempt here:

1. **Real-time camera preview and AR/beauty rendering cannot be verified without a physical device.** This isn't a "might be slightly risky" case like the earlier lifecycle work — it's categorical. A camera preview literally does not render in any tool available in this environment (confirmed repeatedly: no Android emulator, no system images installable, same virtualization limitation that blocks Docker). Writing hundreds of lines of native camera/shader/AR code with **zero way to see a single frame of output** is precisely the "claims completion because it compiles" failure mode this whole project has been built around avoiding — amplified here because visual correctness (does a beauty filter look right, does an AR overlay track a face correctly) can't even be partially inferred from code review the way a state machine's correctness can.
2. **AR/beauty effects need a real rendering pipeline** — either a dedicated third-party AR SDK (ARCore/ARKit plus face-tracking, or a commercial SDK) or substantial custom GPU shader work for face detection, landmark tracking, and real-time image filtering. This is a multi-week specialist undertaking on its own, independent of the device-testing problem.

## What would be safe to build first, when a device is available

- Wire the real `camera` Flutter package for basic preview + photo/video capture with switching/zoom/flash/timer — no filters or AR yet. This alone is meaningfully useful (a real capture flow for Reels/Stories) and is verifiable incrementally on a device without needing the AR pipeline at all.
- Layer simple, non-AR filters (color/contrast adjustments, applied as a shader or post-process on the captured file) next — still requires a device to confirm visually, but far lower risk than face-tracking AR.
- AR/beauty specifically should be scoped as its own dedicated effort with an explicit SDK decision, not bundled into a general camera pass.

None of this was started — not even the low-risk first step — because even basic camera preview code, written blind, would be an unverified guess about a real device API surface (permissions, lifecycle, orientation, aspect ratio handling all vary meaningfully by device and OS version) with no way to catch a mistake before it reaches a real phone.
