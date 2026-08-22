import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

/// Live-poll voting/results sheet. Matches PollVotingDark.dc.html: a plain
/// surface sheet (no glass card), the question itself as the title, a
/// filled-vs-bar-percentage row per option (checkmark circle for the
/// leading pick), and a voter-avatar stack using the room's real roster —
/// the mockup's "18s left" countdown is dropped since polls here have no
/// duration/expiry field at all, just an open-ended host-controlled "End
/// poll".
Future<void> showPollBottomSheet(
  BuildContext context, {
  required Map<String, dynamic> poll,
  required String myUserId,
  required bool isHost,
  required List<RosterEntry> roster,
  required ValueChanged<int> onVote,
  required VoidCallback onReset,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PollSheet(
        poll: poll,
        myUserId: myUserId,
        isHost: isHost,
        roster: roster,
        onVote: onVote,
        onReset: onReset),
  );
}

class _PollSheet extends StatelessWidget {
  final Map<String, dynamic> poll;
  final String myUserId;
  final bool isHost;
  final List<RosterEntry> roster;
  final ValueChanged<int> onVote;
  final VoidCallback onReset;

  const _PollSheet(
      {required this.poll,
      required this.myUserId,
      required this.isHost,
      required this.roster,
      required this.onVote,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    final options = (poll['options'] as List? ?? []).cast<String>();
    final votes = Map<String, dynamic>.from(poll['votes'] as Map? ?? {});
    final counts = List.generate(
        options.length, (i) => votes.values.where((v) => v == i).length);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final myVoteRaw = votes[myUserId];
    final myVote = myVoteRaw is int ? myVoteRaw : null;
    final voted = myVote != null;
    final leadingIndex = total == 0
        ? -1
        : counts.indexOf(counts.reduce((a, b) => a > b ? a : b));
    final rosterById = {for (final r in roster) r.userId: r};
    final voterIds = votes.keys.toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999))),
            ),
            Text(poll['question'] as String? ?? '',
                style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 4),
            Text('$total vote${total == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 11.5)),
            for (var i = 0; i < options.length; i++)
              _optionRow(i, options[i], counts[i], total, myVote,
                  i == leadingIndex, voted),
            if (voterIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: voterIds.length > 1
                        ? 26.0 + (voterIds.take(3).length - 1) * 16
                        : 26,
                    height: 26,
                    child: Stack(
                      children: [
                        for (var i = 0; i < voterIds.take(3).length; i++)
                          Positioned(
                            left: i * 16.0,
                            child: Container(
                              width: 26,
                              height: 26,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.surface, width: 2),
                                  color: AppColors.surface3),
                              child: rosterById[voterIds[i]]?.avatarUrl != null
                                  ? AppImage(
                                      source:
                                          rosterById[voterIds[i]]!.avatarUrl,
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    voterIds.length > 3
                        ? 'and ${voterIds.length - 3} others voted'
                        : '${voterIds.length} voted',
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11.5),
                  ),
                ],
              ),
            ],
            if (isHost) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    onReset();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger)),
                  child: const Text('End poll'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _optionRow(int i, String label, int count, int total, int? myVote,
      bool leading, bool voted) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    final selected = myVote == i;
    final accentColor = leading ? AppColors.accent2 : AppColors.textFaint;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: voted ? null : () => onVote(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: leading && voted ? AppColors.accent2 : AppColors.border,
                width: 1.5),
          ),
          child: Stack(
            children: [
              if (voted)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: Container(
                        color: leading
                            ? AppColors.accent2.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.accent2 : null,
                          border: selected
                              ? null
                              : Border.all(color: AppColors.border, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 11)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                  if (voted)
                    Text('$pct%',
                        style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
