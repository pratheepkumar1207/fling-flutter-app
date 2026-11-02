import 'package:flutter/material.dart';

/// Picks when a post goes out: from a few minutes ahead, up to 30 days.
Future<DateTime?> pickPostTime(BuildContext context,
    {DateTime? initial}) async {
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: now,
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null || !context.mounted) return null;
  final picked =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (picked.isBefore(now.add(const Duration(minutes: 2)))) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time later than now.')));
    return null;
  }
  return picked;
}

/// "Goes out 3/11 at 6:30 PM", for showing the choice.
String postTimeLabel(BuildContext context, DateTime t) =>
    '${t.day}/${t.month} at ${TimeOfDay.fromDateTime(t).format(context)}';
