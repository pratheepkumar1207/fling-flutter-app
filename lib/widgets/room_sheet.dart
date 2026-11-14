import 'package:flutter/material.dart';

import '../theme/insync_icons.dart';

// The room's black sheets (settings, your settings): they open under the
// video at [halfFraction] of the screen, swipe up for full screen and swipe
// down to close. The pieces below keep every row in the same style.

const kSheetTile = Color(0xFF141414);
const kSheetBorder = Color(0xFF262626);
const kSheetOn = Color(0xFF2A1D4A);
const kSheetOnBorder = Color(0xFF8B6CFF);
const kSheetDim = Color(0xB3FFFFFF);
const _kOnDot = Color(0xFF3AD17A);

/// Opens [builder]'s content as a black sheet over the room. [builder]
/// gets the sheet's scroll controller: hand it to the one ListView inside
/// so scrolling and dragging the sheet work together.
Future<T?> showRoomSheet<T>(
  BuildContext context, {
  double halfFraction = 0.62,
  required Widget Function(BuildContext context, ScrollController scroll)
      builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => _RoomSheet(half: halfFraction, builder: builder),
  );
}

class _RoomSheet extends StatefulWidget {
  final double half;
  final Widget Function(BuildContext, ScrollController) builder;
  const _RoomSheet({required this.half, required this.builder});

  @override
  State<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<_RoomSheet> {
  bool _closing = false;

  @override
  Widget build(BuildContext context) {
    final half = widget.half.clamp(0.3, 0.95);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          // Dragged well below the half sheet: close.
          if (!_closing && n.extent < half * 0.7) {
            _closing = true;
            Navigator.of(context).maybePop();
          }
          return false;
        },
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: half,
          minChildSize: half * 0.5,
          maxChildSize: 1,
          snap: true,
          snapSizes: [half],
          builder: (context, scroll) => Material(
            color: Colors.black,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                side: BorderSide(color: kSheetBorder)),
            clipBehavior: Clip.antiAlias,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: widget.builder(context, scroll),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small bar at the top of a room sheet.
class RoomSheetHandle extends StatelessWidget {
  const RoomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2)),
        ),
      );
}

/// A small grey title over a row ("MICS", "PLAYBACK").
class RoomSheetLabel extends StatelessWidget {
  final String text;
  const RoomSheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: kSheetDim,
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600)),
      );
}

/// One row of equal buttons, one of them picked (Mics: Off · Ask first ·
/// Open). Each option is (value, icon, label).
class RoomChoiceRow extends StatelessWidget {
  final List<(String, InIconData, String)> options;
  final String value;
  final ValueChanged<String>? onChanged;
  const RoomChoiceRow(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final (key, icon, label) in options)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Semantics(
              button: true,
              selected: value == key,
              child: Material(
                color: value == key ? kSheetOn : const Color(0xFF111111),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: value == key ? kSheetOnBorder : kSheetBorder)),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: onChanged == null || value == key
                      ? null
                      : () => onChanged!(key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      InIcon(icon,
                          size: 18,
                          color:
                              value == key ? Colors.white : Colors.white),
                      const SizedBox(height: 4),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: value == key
                                  ? Colors.white
                                  : Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// A square tile with a label under it (Boost, Theme, Chat on…). [on] null
/// is a plain button; true/false is a switch (purple with a dot when on).
class RoomQuickTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool? on;
  final VoidCallback? onTap;
  const RoomQuickTile(
      {super.key,
      required this.icon,
      required this.label,
      this.on,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final lit = on == true;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lit ? kSheetOn : kSheetTile,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lit ? kSheetOnBorder : kSheetBorder),
              ),
              child: Stack(children: [
                Center(child: icon),
                if (lit)
                  const Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(radius: 3.5, backgroundColor: _kOnDot)),
              ]),
            ),
            const SizedBox(height: 5),
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: on == false
                        ? const Color(0xFF888888)
                        : const Color(0xFFD8D8DE))),
          ]),
        ),
      ),
    );
  }
}

/// A bigger on/off card with its full name under the icon, for the grid of
/// personal settings.
class RoomToggleCard extends StatelessWidget {
  final InIconData icon;
  final String label;
  final bool on;
  final ValueChanged<bool> onChanged;
  const RoomToggleCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.on,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      button: true,
      label: label,
      child: Material(
        color: on ? kSheetOn : const Color(0xFF111111),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: on ? kSheetOnBorder : kSheetBorder)),
        child: InkWell(
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: () => onChanged(!on),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      InIcon(icon,
                          size: 20,
                          color: Colors.white),
                      const SizedBox(height: 6),
                      Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Colors.white)),
                    ]),
                  ),
                ),
                if (on)
                  const Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(radius: 3.5, backgroundColor: _kOnDot)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wide button at the bottom of a sheet (End room, Report room).
class RoomSheetButton extends StatelessWidget {
  final InIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const RoomSheetButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B75) : Colors.white;
    return Material(
      color: danger ? const Color(0xFF1A0A0C) : const Color(0xFF111111),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: danger ? const Color(0xFF5A1F24) : kSheetBorder)),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InIcon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
