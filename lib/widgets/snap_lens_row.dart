import 'package:flutter/material.dart';

import '../core/snap_lens_engine.dart';
import '../theme/app_colors.dart';

/// A lens's round picture (or a plain sparkle while it loads).
class SnapLensIcon extends StatelessWidget {
  final SnapLens? lens;
  final double size;
  final bool selected;
  const SnapLensIcon(this.lens,
      {super.key, this.size = 48, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final icon = lens?.icon;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: selected ? 3 : 1),
      ),
      child: lens == null
          ? const Icon(Icons.block_rounded, color: Colors.white70)
          : icon != null && icon.startsWith('http')
              ? Image.network(icon,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white70))
              : const Icon(Icons.auto_awesome_rounded, color: Colors.white70),
    );
  }
}

/// Swipeable lens circles that sit behind the shutter, Snapchat style:
/// "none" first, then every lens. The one in the middle is on.
class SnapLensCarousel extends StatefulWidget {
  final List<SnapLens> lenses;
  final SnapLens? selected;
  final ValueChanged<SnapLens?> onChanged;
  final Widget shutter;
  final bool locked;
  const SnapLensCarousel(
      {super.key,
      required this.lenses,
      required this.selected,
      required this.onChanged,
      required this.shutter,
      this.locked = false});

  @override
  State<SnapLensCarousel> createState() => _SnapLensCarouselState();
}

class _SnapLensCarouselState extends State<SnapLensCarousel> {
  late final PageController _pages = PageController(
      viewportFraction: 0.2, initialPage: _indexOf(widget.selected));

  int _indexOf(SnapLens? l) =>
      l == null ? 0 : widget.lenses.indexWhere((x) => x.id == l.id) + 1;

  @override
  void didUpdateWidget(covariant SnapLensCarousel old) {
    super.didUpdateWidget(old);
    final want = _indexOf(widget.selected);
    if (_pages.hasClients && _pages.page?.round() != want) {
      _pages.jumpToPage(want);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (sel != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            child: Text(sel.name,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      SizedBox(
        height: 84,
        child: Stack(alignment: Alignment.center, children: [
          PageView.builder(
            controller: _pages,
            physics:
                widget.locked ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.lenses.length + 1,
            onPageChanged: (i) =>
                widget.onChanged(i == 0 ? null : widget.lenses[i - 1]),
            itemBuilder: (_, i) => Center(
              child: Semantics(
                button: true,
                label: i == 0 ? 'No lens' : widget.lenses[i - 1].name,
                child: GestureDetector(
                  onTap: () => _pages.animateToPage(i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut),
                  child: SnapLensIcon(i == 0 ? null : widget.lenses[i - 1],
                      size: 50),
                ),
              ),
            ),
          ),
          IgnorePointer(ignoring: false, child: widget.shutter),
        ]),
      ),
    ]);
  }
}

/// A small lens row for calls and live rooms.
class SnapLensStrip extends StatelessWidget {
  final List<SnapLens> lenses;
  final SnapLens? selected;
  final ValueChanged<SnapLens?> onChanged;
  final VoidCallback? onMore;
  const SnapLensStrip(
      {super.key,
      required this.lenses,
      required this.selected,
      required this.onChanged,
      this.onMore});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final l in [null, ...lenses])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: l?.id == selected?.id,
                label: l == null ? 'No lens' : l.name,
                child: GestureDetector(
                  onTap: () => onChanged(l),
                  child: SnapLensIcon(l,
                      size: 46, selected: l?.id == selected?.id),
                ),
              ),
            ),
          if (onMore != null)
            IconButton(
              tooltip: 'All lenses',
              onPressed: onMore,
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

/// Every lens in a sheet: search, saved ones first tab, long-press to save.
/// Returns the chosen lens (or null with [cleared] set when "None" is picked).
Future<({SnapLens? lens, bool picked})> showSnapLensPicker(
    BuildContext context, SnapLens? current) async {
  final result = await showModalBottomSheet<({SnapLens? lens})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15121D),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _LensPicker(current: current),
  );
  return (lens: result?.lens, picked: result != null);
}

class _LensPicker extends StatefulWidget {
  final SnapLens? current;
  const _LensPicker({required this.current});

  @override
  State<_LensPicker> createState() => _LensPickerState();
}

class _LensPickerState extends State<_LensPicker> {
  String _query = '';
  bool _savedOnly = false;
  Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    SnapLensEngine.instance.savedIds().then((s) {
      if (mounted) setState(() => _saved = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = SnapLensEngine.instance.lenses;
    final q = _query.toLowerCase();
    final shown = all
        .where((l) =>
            (!_savedOnly || _saved.contains(l.id)) &&
            (q.isEmpty || l.name.toLowerCase().contains(q)))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search lenses',
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            ChoiceChip(
                label: const Text('All'),
                selected: !_savedOnly,
                onSelected: (_) => setState(() => _savedOnly = false)),
            const SizedBox(width: 8),
            ChoiceChip(
                label: const Text('Saved'),
                selected: _savedOnly,
                onSelected: (_) => setState(() => _savedOnly = true)),
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(context, (lens: null)),
                child: const Text('No lens')),
          ]),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                        _savedOnly
                            ? 'Long-press a lens to save it here.'
                            : 'No lenses match.',
                        style: const TextStyle(color: AppColors.textFaint)))
                : GridView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.78),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final l = shown[i];
                      final saved = _saved.contains(l.id);
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, (lens: l)),
                        onLongPress: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await SnapLensEngine.instance.toggleSaved(l.id);
                          final s = await SnapLensEngine.instance.savedIds();
                          if (!mounted) return;
                          setState(() => _saved = s);
                          messenger.showSnackBar(SnackBar(
                              content: Text(saved
                                  ? 'Removed from saved'
                                  : 'Saved ${l.name}')));
                        },
                        child: Column(children: [
                          Stack(children: [
                            SnapLensIcon(l,
                                size: 56, selected: l.id == widget.current?.id),
                            if (saved)
                              const Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Icon(Icons.bookmark_rounded,
                                      color: AppColors.lilac, size: 16)),
                          ]),
                          const SizedBox(height: 4),
                          Text(l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
