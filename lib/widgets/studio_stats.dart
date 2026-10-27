import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/app_colors.dart';

/// Stat tiles and the gifts-by-day bars from GET /studio — shared by the
/// Live dashboard and Creator Studio.
class StudioStats extends StatelessWidget {
  final Map<String, dynamic> studio;
  const StudioStats({super.key, required this.studio});

  static String _change(num pct, String than) {
    if (pct == 0) return 'Same as $than';
    return '${pct > 0 ? '+' : ''}$pct% vs $than';
  }

  @override
  Widget build(BuildContext context) {
    final week = studio['days'] == 7;
    final than = week ? 'last week' : 'previous ${studio['days']} days';
    final gifts = Map<String, dynamic>.from(studio['gifts'] as Map);
    final live = Map<String, dynamic>.from(studio['live'] as Map);
    final followers = Map<String, dynamic>.from(studio['followers'] as Map);
    final byDay = (studio['giftsByDay'] as List).cast<Map>();
    final giftChange = (gifts['change'] as num?) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Tile(
        label: week ? 'Gifts this week' : 'Gifts · last ${studio['days']} days',
        value: formatNumber(gifts['coins']),
        note: _change(giftChange, than),
        noteColor: giftChange >= 0 ? AppColors.success : AppColors.pink,
        big: true,
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _Tile(label: 'Hours live', value: '${live['hours']}h')),
        const SizedBox(width: 10),
        Expanded(
            child: _Tile(
                label: 'Peak viewers', value: formatNumber(live['peakViewers']))),
        const SizedBox(width: 10),
        Expanded(
            child: _Tile(
                label: 'New followers',
                value: '+${formatNumber(followers['gained'])}')),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gifts by day',
              style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          _Bars(byDay),
        ]),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Color? noteColor;
  final bool big;
  const _Tile(
      {required this.label,
      required this.value,
      this.note,
      this.noteColor,
      this.big = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: big ? 26 : 19, fontWeight: FontWeight.w800)),
          ),
          if (note != null)
            Text(note!,
                style: TextStyle(
                    color: noteColor ?? AppColors.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Seven bars, oldest day first, labelled M T W…
class _Bars extends StatelessWidget {
  final List<Map> days;
  const _Bars(this.days);

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) ((d['coins'] as num?) ?? 0).toDouble()];
    final top = values.fold<double>(0, (m, v) => v > m ? v : m);
    return Semantics(
      label: 'Gifts by day: ${values.map((v) => v.round()).join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 96,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: top == 0 ? 3 : 3 + 66 * (values[i] / top),
                    decoration: BoxDecoration(
                        color: i == days.length - 1
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      _letters[(DateTime.tryParse('${days[i]['date']}')
                                  ?.toLocal()
                                  .weekday ??
                              1) -
                          1],
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 11)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
