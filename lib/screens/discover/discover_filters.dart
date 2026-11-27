import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/language_options.dart';
import '../../widgets/interest_picker.dart';
import 'discover_ui.dart';

/// What the Discover deck is filtered by.
class DiscoverFilters {
  String? gender; // female / male / null = everyone
  int minAge = 18;
  int maxAge = 60; // 60 = no upper limit
  int maxKm = 200; // 200 = anywhere
  String? lookingFor;
  List<String> languages = [];
  bool onlineOnly = false;
  bool inLobbyOnly = false;
  bool verifiedOnly = false;

  static const ageTop = 60;
  static const kmTop = 200;

  DiscoverFilters copy() => DiscoverFilters()
    ..gender = gender
    ..minAge = minAge
    ..maxAge = maxAge
    ..maxKm = maxKm
    ..lookingFor = lookingFor
    ..languages = [...languages]
    ..onlineOnly = onlineOnly
    ..inLobbyOnly = inLobbyOnly
    ..verifiedOnly = verifiedOnly;

  int get activeCount => [
        gender != null,
        minAge > 18 || maxAge < ageTop,
        maxKm < kmTop,
        lookingFor != null,
        languages.isNotEmpty,
        onlineOnly,
        inLobbyOnly,
        verifiedOnly,
      ].where((x) => x).length;

  Map<String, String> toQuery() => {
        if (gender != null) 'gender': gender!,
        if (minAge > 18) 'minAge': '$minAge',
        if (maxAge < ageTop) 'maxAge': '$maxAge',
        if (maxKm < kmTop) 'maxKm': '$maxKm',
        if (lookingFor != null) 'lookingFor': lookingFor!,
        if (languages.isNotEmpty) 'languages': languages.join(','),
        if (onlineOnly) 'onlineOnly': 'true',
        if (inLobbyOnly) 'inLobbyOnly': 'true',
        if (verifiedOnly) 'verifiedOnly': 'true',
      };

  String get queryString => toQuery()
      .entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
}

/// The filter sheet. Returns the new filters, or null when closed.
Future<DiscoverFilters?> showDiscoverFilters(
    BuildContext context, DiscoverFilters current) {
  return showModalBottomSheet<DiscoverFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _FiltersSheet(start: current.copy()),
  );
}

class _FiltersSheet extends StatefulWidget {
  final DiscoverFilters start;
  const _FiltersSheet({required this.start});
  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late DiscoverFilters f = widget.start;
  int? _count;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(VoidCallback fn) {
    setState(fn);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _recount);
  }

  Future<void> _recount() async {
    final mine = ++_seq;
    try {
      final q = f.queryString;
      final r = await ApiClient.get('/discover/count${q.isEmpty ? '' : '?$q'}')
          as Map;
      if (mounted && mine == _seq) {
        setState(() => _count = (r['count'] as num?)?.toInt());
      }
    } catch (_) {
      if (mounted && mine == _seq) setState(() => _count = null);
    }
  }

  Widget _choices(List<(String?, String)> options, String? value,
      void Function(String?) pick) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        DChip(o.$2,
            tone: value == o.$1 ? DTone.white : DTone.plain,
            fontSize: 13,
            onTap: () => _changed(() => pick(o.$1))),
    ]);
  }

  Widget _toggle(String label, bool value, void Function(bool) set) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Switch(
          value: value,
          onChanged: (v) => _changed(() => set(v)),
          activeTrackColor: DColors.red,
          activeThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFF000000),
          inactiveThumbColor: const Color(0xFFFFFFFF),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: DColors.red,
      inactiveTrackColor: const Color(0xFF000000),
      thumbColor: Colors.white,
      overlayColor: DColors.red.withValues(alpha: 0.15),
      trackHeight: 4,
    );
    final ageText =
        '${f.minAge} – ${f.maxAge >= DiscoverFilters.ageTop ? '${DiscoverFilters.ageTop}+' : f.maxAge}';
    final kmText =
        f.maxKm >= DiscoverFilters.kmTop ? 'Anywhere' : 'Up to ${f.maxKm} km';
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Expanded(
                  child: Text('Filters',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () => _changed(() => f = DiscoverFilters()),
                child: const Text('Reset',
                    style: TextStyle(color: DColors.redSoft)),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  const DLabel('Show me'),
                  _choices(const [
                    ('female', 'Women'),
                    ('male', 'Men'),
                    (null, 'Everyone')
                  ], f.gender, (v) => f.gender = v),
                  DLabel('Age $ageText'),
                  SliderTheme(
                    data: sliderTheme,
                    child: RangeSlider(
                      min: 18,
                      max: DiscoverFilters.ageTop.toDouble(),
                      divisions: DiscoverFilters.ageTop - 18,
                      values:
                          RangeValues(f.minAge.toDouble(), f.maxAge.toDouble()),
                      onChanged: (v) => _changed(() {
                        f.minAge = v.start.round();
                        f.maxAge = v.end.round();
                      }),
                    ),
                  ),
                  DLabel('Distance · $kmText'),
                  SliderTheme(
                    data: sliderTheme,
                    child: Slider(
                      min: 1,
                      max: DiscoverFilters.kmTop.toDouble(),
                      value: f.maxKm.toDouble(),
                      onChanged: (v) => _changed(() => f.maxKm = v.round()),
                    ),
                  ),
                  const DLabel('Looking for'),
                  _choices(const [
                    (null, 'Any'),
                    ('friends', 'Friends'),
                    ('short_term', 'Short term'),
                    ('long_term', 'Long term'),
                    ('not_sure', 'Not sure yet'),
                  ], f.lookingFor, (v) => f.lookingFor = v),
                  const DLabel('Languages'),
                  InterestPicker(
                    selected: f.languages,
                    onChanged: (v) => _changed(() => f.languages = v),
                    options: kLanguageOptions,
                  ),
                  const SizedBox(height: 10),
                  _toggle('Online now', f.onlineOnly, (v) => f.onlineOnly = v),
                  _toggle('In a lobby now', f.inLobbyOnly,
                      (v) => f.inLobbyOnly = v),
                  _toggle('Verified only', f.verifiedOnly,
                      (v) => f.verifiedOnly = v),
                ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: DButton(
              _count == null
                  ? 'Show people'
                  : _count == 0
                      ? 'No one matches yet'
                      : 'Show $_count ${_count == 1 ? 'person' : 'people'}',
              onPressed: () => Navigator.of(context).pop(f),
            ),
          ),
        ]),
      ),
    );
  }
}
