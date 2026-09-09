import 'playback_adapter.dart';
import 'playback_session.dart';
import 'playback_surface.dart';

/// The one thing a Party's shared media actually plays through, kept
/// independent of any Flutter widget's lifecycle (spec Step 5) — a
/// PartySession owns one of these for as long as the Party exists, not a
/// screen for as long as it's mounted.
///
/// CRITICAL INVARIANT (do not weaken this): enterPip/enterBackground/
/// enterForeground below call ONLY adapter.setSurface(...). None of them
/// call play()/pause(). This is what makes "screen locked" / "entering
/// PiP" / "app minimized" structurally incapable of pausing shared Party
/// playback — see FLING_AUDIT.md §4 for confirmation that the existing
/// per-player lifecycle code already respects this; this manager is what
/// lets every future adapter get it for free instead of re-deriving it.
class PlaybackSessionManager {
  PlaybackAdapter? _adapter;
  PlaybackSurface _surface = PlaybackSurface.foreground;

  PlaybackAdapter? get adapter => _adapter;
  PlaybackSurface get surface => _surface;

  Future<void> attach(PlaybackAdapter adapter) async {
    if (_adapter?.providerId == adapter.providerId) return;
    await _adapter?.dispose();
    _adapter = adapter;
    await adapter.initialize();
    _surface = PlaybackSurface.foreground;
  }

  Future<void> play() => _adapter?.play() ?? Future.value();
  Future<void> pause() => _adapter?.pause() ?? Future.value();
  Future<void> seek(Duration position) => _adapter?.seek(position) ?? Future.value();

  // Guarded by capabilities.pip so a media source that can't actually PiP
  // (e.g. any webview/OTT "browse together" source per FLING_AUDIT.md §4)
  // silently stays on the foreground surface instead of the caller having
  // to check capabilities itself everywhere.
  Future<void> enterPip() async {
    final a = _adapter;
    if (a == null || !a.capabilities.pip) return;
    _surface = PlaybackSurface.pip;
    await a.setSurface(PlaybackSurface.pip);
  }

  Future<void> enterBackground() async {
    final a = _adapter;
    if (a == null || !a.capabilities.backgroundAudio) return;
    _surface = PlaybackSurface.backgroundAudio;
    await a.setSurface(PlaybackSurface.backgroundAudio);
  }

  Future<void> enterForeground() async {
    final a = _adapter;
    if (a == null) return;
    _surface = PlaybackSurface.foreground;
    await a.setSurface(PlaybackSurface.foreground);
  }

  Future<PlaybackSession?> snapshot() => _adapter?.snapshot() ?? Future.value();

  Future<void> dispose() async {
    await _adapter?.dispose();
    _adapter = null;
  }
}
