import '../../theme/insync_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ott_remote.dart';
import '../../theme/app_colors.dart';
import 'ott_sync_engine.dart';

/// Netflix / Prime Video rooms. Their video only plays in their own apps,
/// so instead of an embedded player this walks each person through getting
/// ready (app installed, signed in, Insync allowed to control it), then
/// keeps everyone's app in step with the host's:
///  - Host: whatever their Netflix does (play, pause, jumping around) is
///    sent to the room; the room's own play/pause controls drive their
///    Netflix too (see [OttSyncPanelState.hostCommand]).
///  - Everyone else: their Netflix is played/paused to match the room, and
///    jumped back in line when it's more than [_tolerance] seconds off.
/// Every phone reports its status so the host can see who's in sync.
class OttSyncPanel extends StatefulWidget {
  final String platform; // 'netflix' | 'amazon'
  final String label; // 'Netflix' | 'Prime Video'
  final String titleUrl;
  final bool isHost;
  final bool roomPlaying;
  final bool hasRoomState;
  final double Function() roomPosition;
  final void Function(double position) onPlay;
  final void Function(double position) onPause;
  final void Function(double position)? onSeek;
  final void Function(String status, double offsetSec)? onStatus;
  final Map<String, Map<String, dynamic>> statuses;
  final bool roomy;

  const OttSyncPanel({
    super.key,
    required this.platform,
    required this.label,
    required this.titleUrl,
    required this.isHost,
    required this.roomPlaying,
    required this.hasRoomState,
    required this.roomPosition,
    required this.onPlay,
    required this.onPause,
    this.onSeek,
    this.onStatus,
    this.statuses = const {},
    this.roomy = true,
  });

  @override
  State<OttSyncPanel> createState() => OttSyncPanelState();
}

enum _Step { checking, unsupported, install, allow, open, synced }

const _tolerance = OttSyncEngine.tolerance;

class OttSyncPanelState extends State<OttSyncPanel>
    with WidgetsBindingObserver {
  Timer? _timer;
  _Step _step = _Step.checking;
  OttPlayerState? _local;
  double _offset = 0;
  String? _lastSentStatus;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;

  String get _package => OttRemote.packages[widget.platform]!;

  late final _engine = OttSyncEngine(
    target: OttAppTarget(_package),
    isHost: () => widget.isHost,
    roomPlaying: () => widget.roomPlaying,
    hasRoomState: () => widget.hasRoomState,
    roomPosition: () => widget.roomPosition(),
    onPlay: (p) => widget.onPlay(p),
    onPause: (p) => widget.onPause(p),
    onSeek: widget.onSeek == null ? null : (p) => widget.onSeek!(p),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
  }

  // Coming back from Settings or the Netflix app: check again straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  Future<void> _tick() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await _sync();
    } finally {
      _busy = false;
    }
  }

  Future<void> _sync() async {
    if (!OttRemote.supported) return _setStep(_Step.unsupported, 'unsupported');
    if (!await OttRemote.isInstalled(_package)) {
      return _setStep(_Step.install, 'no_app');
    }
    if (!await OttRemote.hasAccess()) return _setStep(_Step.allow, 'no_access');
    final status = await _engine.tick();
    if (!mounted) return;
    _local = _engine.local;
    _offset = _engine.offset;
    if (status == 'not_playing') return _setStep(_Step.open, status);
    _setStep(_Step.synced, status);
  }

  void _setStep(_Step step, String status) {
    if (!mounted) return;
    if (step != _step) setState(() => _step = step);
    if (step == _Step.synced) setState(() {});
    // Report on change, and every few seconds so the host's list stays fresh.
    final now = DateTime.now();
    if (status != _lastSentStatus ||
        now.difference(_lastSentAt) > const Duration(seconds: 5)) {
      _lastSentStatus = status;
      _lastSentAt = now;
      widget.onStatus?.call(status, _offset);
    }
  }

  /// The host pressed play/pause or moved the room's clock in Insync: do
  /// the same to their own Netflix, so it doesn't get reported back as a
  /// change the other way.
  Future<void> hostCommand({required bool playing, double? seekTo}) async {
    if (!OttRemote.supported || _step != _Step.synced) return;
    await _engine.hostCommand(playing: playing, seekTo: seekTo);
  }

  Future<void> _install() async {
    final market = Uri.parse('market://details?id=$_package');
    if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
      await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=$_package'),
          mode: LaunchMode.externalApplication);
    }
  }

  // The same title, in the app itself where it's installed.
  Future<void> _openTitle() async {
    // Asks the app by name: phones can send these links to Chrome instead.
    var ok = await OttRemote.openTitle(_package, widget.titleUrl);
    if (!ok) ok = await OttRemote.launch(_package);
    if (!ok) {
      await launchUrl(Uri.parse(widget.titleUrl),
          mode: LaunchMode.externalApplication);
    }
  }

  /// The title's total length, once the app reports it.
  double? get durationSec => _local?.durationSec;

  void _showPeople() => showOttPeople(context, widget.statuses, widget.label);

  /// "In sync", "4s behind", "Needs the Netflix app", ...
  static String statusLabel(Map<String, dynamic> e, String label) {
    final off = ((e['offsetSec'] as num?) ?? 0).abs().round();
    return switch (e['status']) {
      'in_sync' => 'In sync',
      'behind' => '${off}s behind',
      'ahead' => '${off}s ahead',
      'not_playing' => 'Hasn’t started $label',
      'no_access' => 'Needs to allow sync',
      'no_app' => 'Needs the $label app',
      'unsupported' => 'Can’t sync (iPhone)',
      _ => 'Waiting',
    };
  }

  int get _inSyncCount =>
      widget.statuses.values.where((e) => e['status'] == 'in_sync').length;

  @override
  Widget build(BuildContext context) {
    final (
      InIconData icon,
      String title,
      String? sub,
      String? action,
      VoidCallback? onAction
    ) = switch (_step) {
      _Step.checking => (
          InIcons.hourglass,
          'Getting ${widget.label} ready…',
          null,
          null,
          null
        ),
      _Step.unsupported => (
          InIcons.external,
          '${widget.label} plays in its own app',
          'Press play there too. This room keeps time and chat.',
          'Open',
          _openTitle
        ),
      _Step.install => (
          InIcons.arrowdn,
          'Get the ${widget.label} app',
          'It plays in its own app, synced with this room.',
          'Install',
          _install
        ),
      _Step.allow => (
          InIcons.remote,
          'Let Insync play/pause ${widget.label}',
          'One-time Android permission: turn on Insync under Notification access.',
          'Allow',
          OttRemote.openAccessSettings
        ),
      _Step.open => (
          InIcons.play,
          '${widget.label} plays in its own app here',
          widget.isHost
              ? 'Open it, sign in if it asks, then play. Everyone follows you.'
              : 'Open it and sign in if it asks. It’ll follow the host.',
          'Open',
          _openTitle
        ),
      _Step.synced => widget.isHost
          ? (
              InIcons.sync,
              'Synced to your ${widget.label}',
              widget.statuses.isEmpty
                  ? 'Your play, pause and jumps move everyone.'
                  : '$_inSyncCount of ${widget.statuses.length} in sync',
              'People',
              _showPeople
            )
          : (
              _offset.abs() <= _tolerance ? InIcons.check : InIcons.info,
              _offset.abs() <= _tolerance
                  ? 'In sync with the host'
                  : '${_offset.abs().round()}s ${_offset < 0 ? 'behind' : 'ahead'}${(_local?.canSeek ?? false) ? ' · fixing' : ''}',
              (_local?.canSeek ?? true)
                  ? '${widget.label} follows the host automatically.'
                  : 'Move your ${widget.label} to the room timer below.',
              'Open',
              _openTitle
            ),
    };
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        children: [
          InIcon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
                if (sub != null && widget.roomy)
                  Text(sub,
                      // One line with large system text, so it still fits
                      // above the room's control strip.
                      maxLines: large ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact),
              child: Text(action, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

/// Host-only: who in the room is in sync, behind, or not ready.
void showOttPeople(BuildContext context,
    Map<String, Map<String, dynamic>> statuses, String label) {
  final entries = statuses.values.toList()
    ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who’s in sync',
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Everyone’s $label follows yours. Members appear here once Insync is open on their phone.',
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No one else has reported in yet.',
                    style: TextStyle(color: AppColors.textDim)),
              ),
            for (final e in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${e['name'] ?? 'Someone'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.text)),
                trailing: Text(OttSyncPanelState.statusLabel(e, label),
                    style: TextStyle(
                        color: e['status'] == 'in_sync'
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12.5)),
              ),
          ],
        ),
      ),
    ),
  );
}
