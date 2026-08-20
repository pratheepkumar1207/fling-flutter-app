import 'package:intl/intl.dart';

/// Mirrors src/lib/format.js so both clients render the same way.
String initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+')).take(2);
  return parts.map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').join();
}

String formatRelativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().difference(value);
  final mins = diff.inMinutes;
  if (mins < 1) return 'just now';
  if (mins < 60) return '${mins}m';
  final hours = diff.inHours;
  if (hours < 24) return '${hours}h';
  final days = diff.inDays;
  if (days < 7) return '${days}d';
  return DateFormat.MMMd().format(value);
}

/// "10:21 PM" — chat message timestamps.
String formatClockTime(DateTime value) => DateFormat.jm().format(value);

// Accepts dynamic, not num — Postgres COUNT()/SUM()/DECIMAL results often
// arrive as JSON strings (driver precision-safety quirk — e.g. coinBalance
// "10.00", or a raw SUM() aggregate like leaderboards' totalCoins), so
// callers passing raw API response values straight through must not have to
// pre-cast to num themselves. Exported for call sites that need an actual
// num/double/int rather than just a formatted string.
num asNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}

String formatNumber(dynamic value) {
  final n = asNum(value);
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return NumberFormat.decimalPattern().format(n);
}

String formatRupees(dynamic value) {
  return '₹${NumberFormat.decimalPattern().format(asNum(value))}';
}
