import 'package:flutter/material.dart';

import '../../core/room_playback.dart';
import '../../core/room_prefs.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';

/// Opens the player's settings: a sheet from the bottom upright, a panel
/// from the right in full screen so the video stays in view. Either one
/// closes with its own button (or back); touching the video does nothing.
Future<void> showPlayerSettings(BuildContext context, WidgetBuilder builder) {
  final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
  if (!landscape) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheet,
      isScrollControlled: true,
      builder: builder,
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, __) {
      final width = MediaQuery.sizeOf(ctx).width;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.surface.withValues(alpha: 0.96),
          child: SizedBox(
            width: (width * 0.42).clamp(300.0, 420.0),
            height: double.infinity,
            child: Stack(children: [
              Positioned.fill(child: builder(ctx)),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const InIcon(InIcons.close,
                      size: 18, color: AppColors.inkMuted),
                ),
              ),
            ]),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
  );
}

/// Everyone's own player settings. Only what moves the video's time is
/// shared: play, pause, jumps and speed are the host's; quality, audio,
/// subtitles, volume and picture size change only this phone.
class PlayerSettingsSheet extends StatefulWidget {
  /// The site's name, e.g. "Netflix" or "YouTube".
  final String label;
  final bool isHost;

  /// The room's speed. Only the host can change it.
  final double rate;
  final ValueChanged<double>? onRate;

  /// Quality: a fixed note (YouTube picks it itself) or, with [onQuality],
  /// the site's own quality menu.
  final String qualityValue;
  final VoidCallback? onQuality;

  /// The site's own quality choices, when the room can pick them here.
  final List<Map> qualities;
  final ValueChanged<int>? onQualityPick;

  /// Audio tracks / subtitles the page reports; when it reports none, the
  /// row opens the site's own menu ([onSiteMenu]) instead.
  final List<Map> audio;
  final ValueChanged<int>? onAudio;
  final List<Map> text;
  final ValueChanged<int>? onText;

  /// Subtitle size, -1 (small) to 2 (largest); null where the site draws
  /// its own subtitles.
  final int? subtitleSize;
  final ValueChanged<int>? onSubtitleSize;

  /// 0–100, this phone only.
  final int? volume;
  final ValueChanged<int>? onVolume;

  /// How far this phone is from the host, in seconds (minus = behind),
  /// and a way to jump to the host's time. Viewers only.
  final double? offsetSec;
  final VoidCallback? onCatchUp;

  /// The site's own menu, for anything not listed here.
  final VoidCallback? onSiteMenu;

  /// The site's own quality/audio/subtitle lists are still being read.
  final bool loadingSiteLists;

  const PlayerSettingsSheet({
    super.key,
    required this.label,
    required this.isHost,
    required this.rate,
    this.onRate,
    this.qualityValue = 'Auto',
    this.onQuality,
    this.qualities = const [],
    this.onQualityPick,
    this.audio = const [],
    this.onAudio,
    this.text = const [],
    this.onText,
    this.subtitleSize,
    this.onSubtitleSize,
    this.volume,
    this.onVolume,
    this.offsetSec,
    this.onCatchUp,
    this.onSiteMenu,
    this.loadingSiteLists = false,
  });

  @override
  State<PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends State<PlayerSettingsSheet> {
  late double _rate = widget.rate;
  late int? _audio = _onIndex(widget.audio);
  late int _text = _onIndex(widget.text) ?? -1;
  late int? _quality = _onIndex(widget.qualities);
  late int? _size = widget.subtitleSize;
  late double _volume = (widget.volume ?? 100).toDouble();
  // Which list is open: null for the main settings list.
  String? _page;

  // The site's lists arrive after the sheet opens, and a pick moves the
  // tick: follow them.
  @override
  void didUpdateWidget(PlayerSettingsSheet old) {
    super.didUpdateWidget(old);
    if (old.audio != widget.audio) _audio = _onIndex(widget.audio);
    if (old.text != widget.text) _text = _onIndex(widget.text) ?? -1;
    if (old.qualities != widget.qualities) {
      _quality = _onIndex(widget.qualities);
    }
  }

  static const _sizes = {-1: 'Small', 0: 'Medium', 1: 'Large', 2: 'Largest'};

  static int? _onIndex(List<Map> list) {
    for (final m in list) {
      if (m['on'] == true) return (m['i'] as num).toInt();
    }
    return null;
  }

  String _labelOf(List<Map> list, int? i, String none) {
    for (final m in list) {
      if ((m['i'] as num).toInt() == i) return '${m['label']}';
    }
    return none;
  }

  void _close() => Navigator.of(context).maybePop();

  Widget _row(InIconData icon, String label, String value, VoidCallback? onTap,
          {bool locked = false}) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(children: [
            InIcon(locked ? InIcons.lock : icon,
                size: 18,
                color: locked ? AppColors.textFaint : AppColors.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: locked ? AppColors.textFaint : null)),
            ),
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 13)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const InIcon(InIcons.right, size: 16, color: AppColors.textFaint),
            ],
          ]),
        ),
      );

  Widget _pick(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: on
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                ),
                if (on)
                  const InIcon(InIcons.check, size: 18, color: AppColors.lilac),
              ]),
            ),
          ),
        ),
      );

  Widget _header(String title, {bool back = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 44, 8),
        child: Row(children: [
          if (back)
            IconButton(
              tooltip: 'Back',
              onPressed: () => setState(() => _page = null),
              icon: const InIcon(InIcons.back,
                  size: 18, color: AppColors.inkMuted),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: InIcon(InIcons.gear, size: 18, color: AppColors.lilac),
            ),
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (!back)
            const Text('Only on your phone',
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ]),
      );

  String get _offsetLabel {
    final o = widget.offsetSec;
    if (o == null) return '';
    final s = o.round();
    if (s.abs() < 1) return 'In sync';
    return s < 0 ? '${-s}s behind' : '${s}s ahead';
  }

  List<Widget> _main() {
    final fill = RoomPrefs.instance.fillScreen;
    return [
      _header('Your settings'),
      if (widget.loadingSiteLists) ...[
        _row(InIcons.tv, 'Quality', 'Loading…', null),
        _row(InIcons.lang, 'Audio language', 'Loading…', null),
        _row(InIcons.comment, 'Subtitles', 'Loading…', null),
      ] else if (widget.qualities.isNotEmpty && widget.onQualityPick != null)
        _row(
            InIcons.tv,
            'Quality',
            _labelOf(widget.qualities, _quality, 'Auto').split(' · ').first,
            () => setState(() => _page = 'quality'))
      else
        _row(
            InIcons.tv,
            'Quality',
            widget.onQuality != null
                ? 'On ${widget.label}'
                : widget.qualityValue,
            widget.onQuality),
      if (widget.loadingSiteLists)
        const SizedBox.shrink()
      else if (widget.audio.isNotEmpty && widget.onAudio != null)
        _row(
            InIcons.lang,
            'Audio language',
            _labelOf(widget.audio, _audio, 'Default'),
            widget.audio.length > 1
                ? () => setState(() => _page = 'audio')
                : null)
      else if (widget.onSiteMenu != null)
        _row(InIcons.lang, 'Audio language', 'On ${widget.label}',
            widget.onSiteMenu),
      if (widget.loadingSiteLists)
        const SizedBox.shrink()
      else if (widget.text.isNotEmpty && widget.onText != null)
        _row(InIcons.comment, 'Subtitles', _labelOf(widget.text, _text, 'Off'),
            () => setState(() => _page = 'text'))
      else if (widget.onSiteMenu != null)
        _row(InIcons.comment, 'Subtitles', 'On ${widget.label}',
            widget.onSiteMenu),
      if (_size != null && widget.onSubtitleSize != null)
        _row(InIcons.edit, 'Subtitle size', _sizes[_size] ?? 'Medium',
            () => setState(() => _page = 'size')),
      _row(
          InIcons.fillWidth,
          'Picture size in full screen',
          fill ? 'Fill screen' : 'Fit',
          () => setState(() => _page = 'picture')),
      if (widget.volume != null && widget.onVolume != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            InIcon(_volume == 0 ? InIcons.mute : InIcons.speaker,
                size: 18, color: AppColors.textDim),
            const SizedBox(width: 12),
            const Text('Volume',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _volume.clamp(0, 100),
                max: 100,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  setState(() => _volume = v);
                  widget.onVolume!(v.round());
                },
              ),
            ),
          ]),
        ),
      if (!widget.isHost && widget.onCatchUp != null)
        _row(InIcons.sync, 'Catch up with host', _offsetLabel, () {
          widget.onCatchUp!();
          _close();
        }),
      widget.isHost && widget.onRate != null
          ? _row(InIcons.play, 'Speed for everyone', rateLabel(_rate),
              () => setState(() => _page = 'speed'))
          : _row(
              InIcons.play, 'Speed', '${rateLabel(_rate)} · set by host', null,
              locked: true),
    ];
  }

  List<Widget> _speed() => [
        _header('Speed for everyone', back: true),
        for (final r in roomPlaybackRates)
          _pick(rateLabel(r), (_rate - r).abs() < 0.01, () {
            widget.onRate?.call(r);
            setState(() {
              _rate = r;
              _page = null;
            });
          }),
      ];

  List<Widget> _picture() => [
        _header('Picture size in full screen', back: true),
        _pick('Fill screen · no black bars', RoomPrefs.instance.fillScreen, () {
          RoomPrefs.instance.setFillScreen(true);
          setState(() => _page = null);
        }),
        _pick('Fit · show the whole picture', !RoomPrefs.instance.fillScreen,
            () {
          RoomPrefs.instance.setFillScreen(false);
          setState(() => _page = null);
        }),
      ];

  List<Widget> _sizePage() => [
        _header('Subtitle size', back: true),
        for (final e in _sizes.entries)
          _pick(e.value, _size == e.key, () {
            widget.onSubtitleSize?.call(e.key);
            setState(() {
              _size = e.key;
              _page = null;
            });
          }),
      ];

  List<Widget> _qualityPage() => [
        _header('Quality', back: true),
        for (final q in widget.qualities)
          _pick('${q['label']}', _quality == (q['i'] as num).toInt(), () {
            final i = (q['i'] as num).toInt();
            widget.onQualityPick?.call(i);
            setState(() {
              _quality = i;
              _page = null;
            });
          }),
      ];

  List<Widget> _audioPage() => [
        _header('Audio language', back: true),
        for (final a in widget.audio)
          _pick('${a['label']}', _audio == (a['i'] as num).toInt(), () {
            final i = (a['i'] as num).toInt();
            widget.onAudio?.call(i);
            setState(() {
              _audio = i;
              _page = null;
            });
          }),
      ];

  List<Widget> _textPage() => [
        _header('Subtitles', back: true),
        _pick('Off', _text == -1, () {
          widget.onText?.call(-1);
          setState(() {
            _text = -1;
            _page = null;
          });
        }),
        for (final s in widget.text)
          _pick('${s['label']}', _text == (s['i'] as num).toInt(), () {
            final i = (s['i'] as num).toInt();
            widget.onText?.call(i);
            setState(() {
              _text = i;
              _page = null;
            });
          }),
      ];

  @override
  Widget build(BuildContext context) {
    final children = switch (_page) {
      'speed' => _speed(),
      'audio' => _audioPage(),
      'text' => _textPage(),
      'size' => _sizePage(),
      'picture' => _picture(),
      'quality' => _qualityPage(),
      _ => _main(),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Column(
              key: ValueKey(_page),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      ),
    );
  }
}
