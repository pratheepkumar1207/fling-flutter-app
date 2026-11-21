import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A poll in a group chat: the question, each option with its share of
/// votes, and a tick on yours. Tap an option to vote or change your vote;
/// tap your vote again to take it back.
class GroupPollBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  final void Function(int? option) onVote;
  const GroupPollBubble(
      {super.key,
      required this.message,
      required this.mine,
      required this.onVote});

  @override
  Widget build(BuildContext context) {
    final poll = Map<String, dynamic>.from(message['poll'] as Map? ?? {});
    final options = (poll['options'] as List? ?? const []).cast<dynamic>();
    final counts = [
      for (var i = 0; i < options.length; i++)
        ((message['pollCounts'] as List?)?.elementAtOrNull(i) as num?)
                ?.toInt() ??
            0
    ];
    final total = counts.fold<int>(0, (a, b) => a + b);
    final myVote = (message['myVote'] as num?)?.toInt();
    final fg = mine ? Colors.white : AppColors.text;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded,
              size: 16, color: mine ? Colors.white70 : AppColors.lilac),
          const SizedBox(width: 4),
          Text('Poll',
              style: TextStyle(
                  fontSize: 11,
                  color: mine ? Colors.white70 : AppColors.lilac,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(poll['question'] as String? ?? '',
            style: TextStyle(
                color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++)
          Semantics(
            button: true,
            selected: myVote == i,
            label:
                '${options[i]}, ${counts[i]} vote${counts[i] == 1 ? '' : 's'}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onVote(myVote == i ? null : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                            myVote == i
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: myVote == i
                                ? (mine ? Colors.white : AppColors.lilac)
                                : (mine ? Colors.white60 : AppColors.textFaint)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${options[i]}',
                              style: TextStyle(color: fg, fontSize: 13.5)),
                        ),
                        Text('${counts[i]}',
                            style: TextStyle(
                                color: mine ? Colors.white70 : AppColors.textDim,
                                fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : counts[i] / total,
                          minHeight: 5,
                          backgroundColor:
                              mine ? Colors.white24 : const Color(0xFF2A2733),
                          color: mine ? Colors.white : AppColors.lilac,
                        ),
                      ),
                    ]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
            total == 0
                ? 'No votes yet · tap to vote'
                : '$total vote${total == 1 ? '' : 's'} · tap to change yours',
            style: TextStyle(
                color: mine ? Colors.white60 : AppColors.textFaint,
                fontSize: 11)),
      ]),
    );
  }
}

/// Ask a question with 2 to 10 options. Returns {question, options}.
Future<Map<String, dynamic>?> showCreatePollSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15121D),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _CreatePoll(),
  );
}

class _CreatePoll extends StatefulWidget {
  const _CreatePoll();

  @override
  State<_CreatePoll> createState() => _CreatePollState();
}

class _CreatePollState extends State<_CreatePoll> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _send() {
    final q = _question.text.trim();
    final opts = [
      for (final o in _options)
        if (o.text.trim().isNotEmpty) o.text.trim()
    ];
    if (q.isEmpty) return setState(() => _error = 'Ask a question');
    if (opts.length < 2) return setState(() => _error = 'Add at least 2 options');
    Navigator.of(context).pop({'question': q, 'options': opts});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Create a poll',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _question,
              autofocus: true,
              maxLength: 200,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(hintText: 'Which film on Friday?'),
            ),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(
                  controller: _options[i],
                  maxLength: 80,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: 'Option ${i + 1}',
                    counterText: '',
                    suffixIcon: _options.length > 2
                        ? IconButton(
                            tooltip: 'Remove option',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() {
                              _options.removeAt(i).dispose();
                            }),
                          )
                        : null,
                  ),
                ),
              ),
            if (_options.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add option'),
                ),
              ),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            const SizedBox(height: 10),
            FilledButton(onPressed: _send, child: const Text('Send poll')),
          ]),
        ),
      ),
    );
  }
}

/// The six quick reactions.
const groupReactions = ['👍', '❤️', '😂', '🔥', '😮', '🙏'];

/// Reaction counts under a message; yours is highlighted.
class GroupReactionChips extends StatelessWidget {
  final Map<String, dynamic> message;
  final void Function(String emoji) onTap;
  const GroupReactionChips(
      {super.key, required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final counts = Map<String, dynamic>.from(message['reactions'] as Map? ?? {});
    if (counts.isEmpty) return const SizedBox.shrink();
    final mine = message['myReaction'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final e in counts.entries)
          Semantics(
            button: true,
            selected: mine == e.key,
            label: '${e.key} ${e.value}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onTap(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: mine == e.key
                      ? AppColors.lilac.withValues(alpha: 0.25)
                      : const Color(0xFF1F1C29),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: mine == e.key
                          ? AppColors.lilac
                          : const Color(0xFF2A2733)),
                ),
                child: Text('${e.key} ${e.value}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
      ]),
    );
  }
}
