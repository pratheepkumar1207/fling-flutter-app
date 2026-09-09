/// Which physical presentation the current PlaybackSession is rendering
/// through right now. This is orthogonal to PlaybackStatus (playing/paused/
/// etc.) — a session can be `playing` on any of these three surfaces.
/// Deliberately just 3 values, matching what LifecycleCoordinator actually
/// distinguishes: it never needs to know *why* the surface changed, only
/// which one is current.
enum PlaybackSurface {
  foreground,
  pip,
  backgroundAudio,
}
