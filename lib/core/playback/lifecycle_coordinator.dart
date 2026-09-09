import 'playback_session_manager.dart';

/// What the OS/app lifecycle is doing right now, translated from raw
/// Flutter `AppLifecycleState`/PiP-changed callbacks by whichever screen
/// owns those observers (party_screen.dart, or a future single owner —
/// see PLAYBACK.md for the wiring plan). Kept separate from
/// AppLifecycleState itself so this file has zero Flutter framework
/// dependency and stays trivially unit-testable.
enum PlaybackIntent {
  active,
  enteringPip,
  inPip,
  leavingPip,
  enteringBackground,
  background,
  returningForeground,
}

/// The only thing standing between a raw OS lifecycle event and
/// PlaybackSessionManager. Every branch below calls a *surface* method
/// (enterPip/enterBackground/enterForeground) — never play()/pause().
/// This is the concrete fix for the bug described in the inSync request:
/// "never interpret APP PAUSED / SCREEN LOCKED / ENTERING PIP as SHARED
/// PARTY PLAYBACK PAUSED." A lifecycle intent that should do nothing to
/// playback (active/inPip/background — i.e. steady-states, not
/// transitions) falls through with no call at all.
class LifecycleCoordinator {
  final PlaybackSessionManager playback;

  LifecycleCoordinator(this.playback);

  Future<void> handle(PlaybackIntent intent) async {
    switch (intent) {
      case PlaybackIntent.enteringPip:
        await playback.enterPip();
      case PlaybackIntent.leavingPip:
      case PlaybackIntent.returningForeground:
        await playback.enterForeground();
      case PlaybackIntent.enteringBackground:
        await playback.enterBackground();
      case PlaybackIntent.active:
      case PlaybackIntent.inPip:
      case PlaybackIntent.background:
        break;
    }
  }
}
