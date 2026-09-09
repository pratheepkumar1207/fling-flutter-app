import 'package:flutter_test/flutter_test.dart';
import 'package:fling/core/playback/lifecycle_coordinator.dart';
import 'package:fling/core/playback/playback_adapter.dart';
import 'package:fling/core/playback/playback_session.dart';
import 'package:fling/core/playback/playback_session_manager.dart';
import 'package:fling/core/playback/playback_surface.dart';

/// Records every call made to it, so tests can assert on exactly which
/// methods a lifecycle transition invoked — the real behavior, not a
/// hardcoded literal (replaces the zip's original invariants_test.dart,
/// whose two assertions checked hardcoded values against themselves and
/// would pass even if LifecycleCoordinator called play()/pause() directly
/// on every lifecycle event).
class _RecordingAdapter implements PlaybackAdapter {
  final List<String> calls = [];
  final PlaybackCapabilities _capabilities;

  _RecordingAdapter({
    PlaybackCapabilities capabilities = const PlaybackCapabilities(
      foregroundVideo: true,
      backgroundAudio: true,
      pip: true,
      lockScreenControls: true,
      remoteControls: true,
    ),
  }) : _capabilities = capabilities;

  @override
  String get providerId => 'fake';

  @override
  PlaybackCapabilities get capabilities => _capabilities;

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> load(String mediaId) async => calls.add('load');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async => calls.add('seek');

  @override
  Future<Duration> position() async => Duration.zero;

  @override
  Future<void> setSurface(PlaybackSurface surface) async => calls.add('setSurface:${surface.name}');

  @override
  Future<PlaybackSession> snapshot() async => PlaybackSession.idle();

  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  late _RecordingAdapter adapter;
  late PlaybackSessionManager manager;
  late LifecycleCoordinator coordinator;

  setUp(() async {
    adapter = _RecordingAdapter();
    manager = PlaybackSessionManager();
    await manager.attach(adapter);
    adapter.calls.clear(); // drop the attach()-triggered initialize() call
    coordinator = LifecycleCoordinator(manager);
  });

  // This is the concrete regression test for the request's central bug
  // report: "never interpret APP PAUSED / SCREEN LOCKED / ENTERING PIP as
  // SHARED PARTY PLAYBACK PAUSED." If a future change wires a lifecycle
  // callback to call play()/pause() directly (the exact mistake described),
  // this test fails.
  for (final intent in [
    PlaybackIntent.enteringPip,
    PlaybackIntent.enteringBackground,
    PlaybackIntent.leavingPip,
    PlaybackIntent.returningForeground,
  ]) {
    test('$intent never calls play() or pause()', () async {
      await coordinator.handle(intent);
      expect(adapter.calls, isNot(contains('play')));
      expect(adapter.calls, isNot(contains('pause')));
    });
  }

  test('enteringPip calls setSurface(pip) exactly once', () async {
    await coordinator.handle(PlaybackIntent.enteringPip);
    expect(adapter.calls, ['setSurface:pip']);
    expect(manager.surface, PlaybackSurface.pip);
  });

  test('enteringBackground calls setSurface(backgroundAudio)', () async {
    await coordinator.handle(PlaybackIntent.enteringBackground);
    expect(adapter.calls, ['setSurface:backgroundAudio']);
    expect(manager.surface, PlaybackSurface.backgroundAudio);
  });

  test('leavingPip and returningForeground both call setSurface(foreground)', () async {
    await coordinator.handle(PlaybackIntent.leavingPip);
    expect(adapter.calls, ['setSurface:foreground']);
    adapter.calls.clear();
    await coordinator.handle(PlaybackIntent.returningForeground);
    expect(adapter.calls, ['setSurface:foreground']);
  });

  // Steady-states (not transitions) must be complete no-ops.
  for (final intent in [PlaybackIntent.active, PlaybackIntent.inPip, PlaybackIntent.background]) {
    test('$intent makes no adapter calls at all', () async {
      await coordinator.handle(intent);
      expect(adapter.calls, isEmpty);
    });
  }

  // Real-world case this guards: any webview/OTT "browse together" source
  // (FLING_AUDIT.md §4-5) reports pip:false — entering PiP for one of
  // those must stay a no-op rather than putting the manager into a `pip`
  // surface state the adapter never actually agreed to support.
  test('enterPip is a no-op when the adapter does not support pip', () async {
    final noPipAdapter = _RecordingAdapter(
      capabilities: const PlaybackCapabilities(
        foregroundVideo: true,
        backgroundAudio: false,
        pip: false,
        lockScreenControls: false,
        remoteControls: false,
      ),
    );
    final noPipManager = PlaybackSessionManager();
    await noPipManager.attach(noPipAdapter);
    noPipAdapter.calls.clear();

    await LifecycleCoordinator(noPipManager).handle(PlaybackIntent.enteringPip);

    expect(noPipAdapter.calls, isEmpty);
    expect(noPipManager.surface, PlaybackSurface.foreground);
  });
}
