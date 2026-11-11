/// Reading the room's shared playback state (playback:state and friends
/// from syncHandler.js): where the video is now and at what speed. Speed is
/// the host's, for everyone (playback:rate), so the position moves at that
/// speed between updates.
const roomPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

double roomRate(Map<String, dynamic>? p) {
  final r = (p?['rate'] as num?)?.toDouble() ?? 1;
  return r > 0 ? r : 1;
}

/// The room's position right now: the last reported one, moved on by the
/// time since, at the room's speed while it's playing.
double roomPosition(Map<String, dynamic>? p) {
  if (p == null) return 0;
  var position = (p['position'] as num?)?.toDouble() ?? 0;
  final updatedAt = p['updatedAt'] as num?;
  if (p['isPlaying'] == true && updatedAt != null) {
    final elapsed = (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
    if (elapsed > 0) position += elapsed * roomRate(p);
  }
  return position;
}

String rateLabel(double r) =>
    r == 1.0 ? 'Normal' : (r == r.roundToDouble() ? '${r.toInt()}x' : '${r}x');
