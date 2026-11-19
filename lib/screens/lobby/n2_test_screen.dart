import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// "N2" — a test of syncing the Netflix app's player from InSync, before
/// building watch-together on it. Shows what Android's media controls let
/// us read (playing/paused, time, length) and do (play, pause, jump) for
/// whatever is playing, Netflix first. See NetflixSyncChannel.kt.
class N2TestScreen extends StatefulWidget {
  const N2TestScreen({super.key});

  @override
  State<N2TestScreen> createState() => _N2TestScreenState();
}

class _N2TestScreenState extends State<N2TestScreen>
    with WidgetsBindingObserver {
  static const _ch = MethodChannel('com.fling.app/n2');
  static const _netflix = 'com.netflix.mediaclient';

  bool? _access;
  List<Map> _sessions = const [];
  String? _error;
  Timer? _tick;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _tick = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _refresh(quiet: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool quiet = false}) async {
    try {
      final access = await _ch.invokeMethod<bool>('hasAccess') ?? false;
      final list = access
          ? (await _ch.invokeListMethod<Map>('sessions') ?? const <Map>[])
          : const <Map>[];
      if (!mounted) return;
      setState(() {
        _access = access;
        _sessions = list;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
    } on MissingPluginException {
      if (mounted) setState(() => _error = 'Only works on Android.');
    }
  }

  Future<void> _control(String pkg, String action, [int? ms]) async {
    final before = _find(pkg);
    final ok = await _ch.invokeMethod<bool>(
            'control', {'package': pkg, 'action': action, 'ms': ms}) ??
        false;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _refresh();
    final after = _find(pkg);
    final line =
        '${_time(DateTime.now())}  $action${ms != null ? ' ${_fmt(ms)}' : ''}'
        ' → ${ok ? 'sent' : 'no session'}; '
        '${before?['state']} ${_fmt(before?['positionMs'] as int? ?? -1)}'
        ' → ${after?['state']} ${_fmt(after?['positionMs'] as int? ?? -1)}';
    setState(() => _log.insert(0, line));
  }

  Map? _find(String pkg) {
    for (final s in _sessions) {
      if (s['package'] == pkg) return s;
    }
    return null;
  }

  static String _fmt(int ms) {
    if (ms < 0) return '—';
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final netflix = _find(_netflix);
    final others = _sessions.where((s) => s['package'] != _netflix).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('N2 · Netflix sync test')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Play something in the Netflix app, then come back here. This shows '
            'what InSync can read and control. Nothing is sent anywhere.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 14),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        _step(
          '1',
          'Allow InSync watch sync',
          _access == true
              ? 'Allowed'
              : 'Turn on "InSync watch sync" in the list that opens.',
          done: _access == true,
          action: _access == true
              ? null
              : FilledButton(
                  onPressed: () => _ch.invokeMethod('openAccessSettings'),
                  child: const Text('Open settings')),
        ),
        _step(
          '2',
          'Play something in Netflix',
          netflix == null
              ? 'Not seen yet. Start a show, then come back.'
              : 'Netflix seen',
          done: netflix != null,
          action: FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _ch.invokeMethod<bool>('openNetflix');
                if (ok != true) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Netflix isn’t installed on this phone.')));
                }
              },
              child: const Text('Open Netflix')),
        ),
        const SizedBox(height: 8),
        if (netflix != null) _sessionCard(netflix, highlight: true),
        for (final s in others) _sessionCard(s),
        if (_access == true && _sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nothing is playing in any app right now.',
                style: TextStyle(color: AppColors.textFaint)),
          ),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('What happened',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final l in _log.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l,
                  style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12,
                      fontFamily: 'monospace')),
            ),
        ],
      ]),
    );
  }

  Widget _step(String n, String title, String body,
      {required bool done, Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: done ? AppColors.success : AppColors.surface3,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(n, style: const TextStyle(color: AppColors.text)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600)),
            Text(body,
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ]),
        ),
        if (action != null) action,
      ]),
    );
  }

  Widget _sessionCard(Map s, {bool highlight = false}) {
    final pkg = s['package'] as String;
    final actions = Map<String, dynamic>.from(s['actions'] as Map? ?? {});
    final pos = s['positionMs'] as int? ?? -1;
    final dur = s['durationMs'] as int? ?? -1;
    Widget yesNo(String label, String key) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: actions[key] == true
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.danger.withValues(alpha: 0.15),
            label: Text('$label ${actions[key] == true ? 'yes' : 'no'}',
                style: const TextStyle(fontSize: 11, color: AppColors.text)),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
              color: highlight ? AppColors.lilac : AppColors.border,
              width: highlight ? 2 : 1),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(pkg == _netflix ? 'Netflix' : pkg,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        if ((s['title'] as String?)?.isNotEmpty == true)
          Text(s['title'] as String,
              style: const TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 8),
        Text(
            '${s['state']}   ${_fmt(pos)} / ${_fmt(dur)}   speed ${s['speed']}',
            style: const TextStyle(
                color: AppColors.text, fontSize: 16, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text(
            pos < 0
                ? 'Time: not shared by this app'
                : 'Time: shared (watch it count up while playing)',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(children: [
          yesNo('Play', 'play'),
          yesNo('Pause', 'pause'),
          yesNo('Jump to time', 'seekTo'),
          yesNo('Rewind', 'rewind'),
          yesNo('Forward', 'fastForward'),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: () => _control(pkg, 'play'),
              child: const Text('Play')),
          OutlinedButton(
              onPressed: () => _control(pkg, 'pause'),
              child: const Text('Pause')),
          OutlinedButton(
              onPressed: pos < 0
                  ? null
                  : () =>
                      _control(pkg, 'seekTo', (pos - 10000).clamp(0, 1 << 31)),
              child: const Text('−10 s')),
          OutlinedButton(
              onPressed:
                  pos < 0 ? null : () => _control(pkg, 'seekTo', pos + 30000),
              child: const Text('+30 s')),
          OutlinedButton(
              onPressed: () => _control(pkg, 'seekTo', 60000),
              child: const Text('Jump to 1:00')),
        ]),
      ]),
    );
  }
}
