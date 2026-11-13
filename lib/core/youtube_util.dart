/// Mirrors src/lib/youtube.js's extractYouTubeId.
/// A YouTube watch address. With [playlistId] (a song picked from a
/// playlist or mix) it carries the list along, so Autoplay can carry on
/// with that list (syncHandler.js's tryAutoFillSuggestion).
String youtubeWatchUrl(Object? videoId, {Object? playlistId}) {
  final list = playlistId?.toString() ?? '';
  return 'https://www.youtube.com/watch?v=$videoId'
      '${list.isEmpty ? '' : '&list=${Uri.encodeQueryComponent(list)}'}';
}

/// The playlist/mix id in a YouTube address (`list=`), if any.
String? youtubeListId(String? url) {
  final m = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url ?? '');
  return m?.group(1);
}

String? extractYouTubeId(String? url) {
  if (url == null || url.isEmpty) return null;
  final match =
      RegExp(r'(?:v=|/embed/|\.be/)([a-zA-Z0-9_-]{11})').firstMatch(url);
  if (match != null) return match.group(1);
  return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url) ? url : null;
}
