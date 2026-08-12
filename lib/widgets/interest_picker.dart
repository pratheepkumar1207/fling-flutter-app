import 'package:flutter/material.dart';
import '../core/interest_options.dart';
import '../theme/app_colors.dart';

/// Hinge/Bumble-style multi-select interest chips — Dart port of
/// InterestPicker.jsx. [selected] holds display labels (same strings
/// User.interests has always stored), so existing free-text values from
/// before this picker existed still render as unselected chips instead of
/// silently vanishing.
class InterestPicker extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Same chip UI backs both interests and languages — pass
  /// `kLanguageOptions` (see language_options.dart) to reuse this for the
  /// language picker instead of duplicating the widget.
  final List<List<String>> options;

  const InterestPicker({super.key, required this.selected, required this.onChanged, this.options = kInterestOptions});

  void _toggle(String label) {
    if (selected.contains(label)) {
      onChanged(selected.where((s) => s != label).toList());
    } else {
      onChanged([...selected, label]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final label = o[1];
        final active = selected.contains(label);
        return GestureDetector(
          onTap: () => _toggle(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? AppColors.primary : AppColors.border),
            ),
            child: Text('${o[2]} $label', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.primary : AppColors.textDim)),
          ),
        );
      }).toList(),
    );
  }
}
