import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/live_extras.dart' show compactCount;
import '../shell/app_shell.dart';
import '../wallet/livestream_dashboard_screen.dart';

/// Shown to the host right after they end a live: length, viewers, peak,
/// diamonds earned, new followers and top gifters (GET /studio/live/last),
/// with the live dashboard and Back to Live.
class LiveEndedScreen extends StatefulWidget {
  final String title;
  final Duration duration;
  final int viewers;
  final int peak;
  const LiveEndedScreen(
      {super.key,
      required this.title,
      required this.duration,
      required this.viewers,
      required this.peak});

  @override
  State<LiveEndedScreen> createState() => _LiveEndedScreenState();
}

class _LiveEndedScreenState extends State<LiveEndedScreen> {
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The server finishes closing the stream a moment after we leave.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    try {
      final d = await ApiClient.get('/studio/live/last') as Map;
      if (mounted) setState(() => _summary = Map<String, dynamic>.from(d));
    } catch (_) {}
  }

  String get _length {
    final d = widget.duration;
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }

  void _backToLive() {
    AppShell.tabRequest.value = 2;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final s = _summary;
    final viewers = (s?['viewers'] as num?)?.toInt() ?? widget.viewers;
    final peak = (s?['peakViewers'] as num?)?.toInt() ?? widget.peak;
    final gifters = ((s?['topGifters'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1,
              colors: [Color(0xFF3A1A5A), AppColors.bg]),
        ),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: InIconButton(InIcons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Center(
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: FittedBox(
                        child: Avatar(
                            src: me?.avatarUrl,
                            name: me?.name,
                            size: AvatarSize.lg,
                            ring: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Live ended',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$_length · ${widget.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _Stat('Viewers', formatNumber(viewers))),
                    const SizedBox(width: 10),
                    Expanded(child: _Stat('Peak', formatNumber(peak))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _Stat('Diamonds earned',
                            s == null ? '…' : formatNumber(s['diamonds'] ?? 0),
                            color: AppColors.diamond)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat('New followers',
                            s == null ? '…' : '+${s['newFollowers'] ?? 0}')),
                  ]),
                  if (gifters.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 22, 4, 8),
                      child: Text('TOP GIFTERS',
                          style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                    for (final (i, g) in gifters.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(
                              width: 22,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.textDim,
                                      fontWeight: FontWeight.w700))),
                          Avatar(
                              src: g['avatarUrl'] as String?,
                              name: g['name'] as String?,
                              size: AvatarSize.sm),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(g['name'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const InIcon(InIcons.diamond,
                              size: 14, color: AppColors.diamond),
                          const SizedBox(width: 4),
                          Text(compactCount((g['coins'] as num?)?.toInt() ?? 0),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ] else if (s != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                          'No gifts this time. Gifts from your lives show up in your wallet and live dashboard.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const LivestreamDashboardScreen())),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    child: const FittedBox(child: Text('Live dashboard')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _backToLive,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    child: const FittedBox(child: Text('Back to Live')),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}
