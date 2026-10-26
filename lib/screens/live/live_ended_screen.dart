import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../wallet/livestream_dashboard_screen.dart';

/// Shown to the host right after they end a live: how long it ran, how
/// many people watched and the peak, with a way into the live dashboard.
class LiveEndedScreen extends StatelessWidget {
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

  String get _length {
    final h = duration.inHours, m = duration.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
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
                  Text('$_length · $title',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _Stat('Watched', '$viewers')),
                    const SizedBox(width: 10),
                    Expanded(child: _Stat('Peak at once', '$peak')),
                    const SizedBox(width: 10),
                    Expanded(child: _Stat('Length', _length)),
                  ]),
                  const SizedBox(height: 14),
                  const Text(
                      'Gifts from this live show up in your wallet and live dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim, fontSize: 13)),
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
                    child: const Text('Live dashboard'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    child: const Text('Done'),
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
  const _Stat(this.label, this.value);

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
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
