/// Spec section 77 — one player's own local state, distinct from the
/// party's shared PLAYING/PAUSED state (spec section 74/76): this is
/// "what is my ExoPlayer instance actually doing right now," which can
/// legitimately diverge from the party state for a moment (e.g. this
/// viewer is BUFFERING while the party itself is PLAYING — see spec
/// section 43).
enum PlayerLifecycleState { idle, loading, ready, playing, paused, buffering, ended, error, disposed }

class PlaybackStateSnapshot {
  final PlayerLifecycleState state;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final String? errorMessage;

  const PlaybackStateSnapshot({
    required this.state,
    required this.position,
    this.duration,
    this.bufferedPosition = Duration.zero,
    this.errorMessage,
  });

  factory PlaybackStateSnapshot.idle() => const PlaybackStateSnapshot(state: PlayerLifecycleState.idle, position: Duration.zero);
}
