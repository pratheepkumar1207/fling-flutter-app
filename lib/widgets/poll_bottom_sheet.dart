import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

/// Live-poll voting/results sheet — Dart port of PollModal.jsx. Shows vote
/// buttons until the current user has voted, then a bar-fill results view.
Future<void> showPollBottomSheet(
  BuildContext context, {
  required Map<String, dynamic> poll,
  required String myUserId,
  required bool isHost,
  required ValueChanged<int> onVote,
  required VoidCallback onReset,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PollSheet(poll: poll, myUserId: myUserId, isHost: isHost, onVote: onVote, onReset: onReset),
  );
}

class _PollSheet extends StatelessWidget {
  final Map<String, dynamic> poll;
  final String myUserId;
  final bool isHost;
  final ValueChanged<int> onVote;
  final VoidCallback onReset;

  const _PollSheet({required this.poll, required this.myUserId, required this.isHost, required this.onVote, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final options = (poll['options'] as List? ?? []).cast<String>();
    final votes = Map<String, dynamic>.from(poll['votes'] as Map? ?? {});
    final counts = List.generate(options.length, (i) => votes.values.where((v) => v == i).length);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final myVoteRaw = votes[myUserId];
    final myVote = myVoteRaw is int ? myVoteRaw : null;
    final voted = myVote != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
            ),
            const Text('📊 Live poll', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(poll['question'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...List.generate(options.length, (i) {
              final pct = total > 0 ? ((counts[i] / total) * 100).round() : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: voted ? null : () => onVote(i),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      ),
                      if (voted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            widthFactor: pct / 100,
                            child: Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(options[i], style: TextStyle(color: myVote == i ? AppColors.primary : AppColors.text, fontWeight: myVote == i ? FontWeight.w700 : FontWeight.normal)),
                            if (voted) Text('$pct% · ${counts[i]}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Text('$total vote${total == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            if (isHost) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    onReset();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  child: const Text('End poll'),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
