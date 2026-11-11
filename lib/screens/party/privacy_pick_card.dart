import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/insync_icons.dart';

/// Right after creating a room: the host picks who can join, in the chat.
/// Nobody else can find the room until then; when the time runs out it
/// turns public on its own (the server does that too, see room.js).
class PrivacyPickCard extends StatefulWidget {
  final DateTime until;
  final int totalSeconds;
  final Future<void> Function(String visibility) onPick;
  final VoidCallback? onTimeUp;

  const PrivacyPickCard({
    super.key,
    required this.until,
    required this.onPick,
    this.totalSeconds = 15,
    this.onTimeUp,
  });

  @override
  State<PrivacyPickCard> createState() => _PrivacyPickCardState();
}

class _PrivacyPickCardState extends State<PrivacyPickCard> {
  static const _accent = Color(0xFF7F77DD);
  static const _accentText = Color(0xFFAFA9EC);
  Timer? _timer;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_left <= Duration.zero) {
        _timer?.cancel();
        widget.onTimeUp?.call();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _left => widget.until.difference(DateTime.now());

  Future<void> _pick(String v) async {
    if (_busy != null) return;
    setState(() => _busy = v);
    try {
      await widget.onPick(v);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _option(String value, String label, InIconData icon) {
    final picked = _busy == value;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _pick(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: value == 'public' || picked ? _accent : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: value == 'public' || picked
                      ? _accent
                      : Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InIcon(icon, size: 17, color: Colors.white),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final secs = (left.inMilliseconds / 1000).ceil().clamp(0, 99);
    final frac = (left.inMilliseconds / (widget.totalSeconds * 1000))
        .clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(children: [
              InIcon(InIcons.lock, size: 13, color: Color(0xFFB0ADC2)),
              SizedBox(width: 5),
              Flexible(
                child: Text('Room created. Hidden until you choose.',
                    style: TextStyle(color: Color(0xFFB0ADC2), fontSize: 12)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Who can join?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('No one can see this room yet',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
                const SizedBox(height: 9),
                Row(children: [
                  _option('public', 'Public', InIcons.globe),
                  const SizedBox(width: 6),
                  _option('friends', 'Friends', InIcons.users),
                  const SizedBox(width: 6),
                  _option('private', 'Private', InIcons.lock),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(_accentText),
                  ),
                ),
                const SizedBox(height: 5),
                Text('Goes public in ${secs}s',
                    style: const TextStyle(color: _accentText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
