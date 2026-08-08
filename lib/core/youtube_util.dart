/// Mirrors src/lib/youtube.js's extractYouTubeId.
String? extractYouTubeId(String? url) {
  if (url == null || url.isEmpty) return null;
  final match = RegExp(r'(?:v=|/embed/|\.be/)([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (match != null) return match.group(1);
  return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url) ? url : null;
}
