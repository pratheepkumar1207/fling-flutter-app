import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// Computer players (server: src/games/bots.js). Bots sit in a game's
/// players list with a `bot:` userId.
bool isBotId(String? id) => id != null && id.startsWith('bot:');

/// Games that have computer players.
const kComputerGames = {'tictactoe', 'uno', 'ludo'};

const _purple = Color(0xFF534AB7);
const _purpleDeep = Color(0xFF26215C);

/// The round robot face shown in a computer's seat.
class BotAvatar extends StatelessWidget {
  final double size;
  const BotAvatar({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            color: _purpleDeep, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('🤖', style: TextStyle(fontSize: size * 0.5)),
      );
}

/// Easy / Normal / Hard. Remembers the last pick; Normal by default.
Future<String?> showComputerLevelSheet(BuildContext context,
    {String title = 'Computer level'}) async {
  String last = 'normal';
  try {
    last = (await SharedPreferences.getInstance())
            .getString('computer_level') ??
        'normal';
  } catch (_) {}
  if (!context.mounted) return null;
  final level = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF16151B),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final (id, emoji, label, sub, bg) in const [
              ('easy', '🙂', 'Easy', 'Makes mistakes, good for starting out',
                  Color(0xFF085041)),
              ('normal', '🤖', 'Normal', 'Plays like a casual player',
                  _purpleDeep),
              ('hard', '🔥', 'Hard', 'Best move every turn', Color(0xFF712B13)),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFF1F1E26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: id == last ? const Color(0xFF7F77DD) : AppColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(sheet).pop(id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration:
                              BoxDecoration(color: bg, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(sub,
                                    style: const TextStyle(
                                        color: AppColors.textDim,
                                        fontSize: 12)),
                              ]),
                        ),
                        if (id == last)
                          const InIcon(InIcons.check,
                              color: Color(0xFFAFA9EC), size: 18),
                      ]),
                    ),
                  ),
                ),
              ),
            const Text('Games with a computer give no coins or points.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
          ],
        ),
      ),
    ),
  );
  if (level != null) {
    try {
      (await SharedPreferences.getInstance()).setString('computer_level', level);
    } catch (_) {}
  }
  return level;
}

/// A one-line banner over the board with up to two actions.
class GameComputerBanner extends StatelessWidget {
  final String text;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const GameComputerBanner({
    super.key,
    required this.text,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7F77DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const BotAvatar(size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (secondaryLabel != null)
                    TextButton(
                      onPressed: onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.text,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12.5),
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    child: Text(primaryLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// Shown to a host sitting alone: after 30 s with nobody joining it offers
/// a computer, so nobody is left staring at an empty table.
class ComputerOfferBanner extends StatefulWidget {
  final VoidCallback onAccept;
  final Duration wait;
  const ComputerOfferBanner(
      {super.key, required this.onAccept, this.wait = const Duration(seconds: 30)});

  @override
  State<ComputerOfferBanner> createState() => _ComputerOfferBannerState();
}

class _ComputerOfferBannerState extends State<ComputerOfferBanner> {
  Timer? _timer;
  bool _show = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.wait, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show || _dismissed) return const SizedBox.shrink();
    return GameComputerBanner(
      text: 'No one’s joined yet. Start with a computer?',
      primaryLabel: 'Play with a computer',
      onPrimary: widget.onAccept,
      secondaryLabel: 'Keep waiting',
      onSecondary: () => setState(() => _dismissed = true),
    );
  }
}

/// The lilac used for a computer's "thinking…" line.
const kComputerAccent = Color(0xFFAFA9EC);
