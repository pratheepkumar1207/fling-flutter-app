import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Photos, videos and voice notes from the server come in two forms:
/// - a link to cloud storage (`https://…`) — everything new, once the
///   backend's storage is switched on;
/// - an older `data:` URI holding the file itself as text.
/// These helpers let players and viewers handle both.

bool isRemoteMedia(String? src) =>
    src != null && (src.startsWith('https://') || src.startsWith('http://'));

/// The file's bytes for a `data:` URI; null for links or bad data.
List<int>? dataUriBytes(String src) {
  if (!src.startsWith('data:')) return null;
  final comma = src.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(src.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// A local copy of [src] in the temp folder, for players and sharing that
/// need a real file. Links are downloaded once and reused.
Future<File?> mediaToFile(String src, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  if (await file.exists() && await file.length() > 0) return file;
  if (isRemoteMedia(src)) {
    final res = await http.get(Uri.parse(src));
    if (res.statusCode != 200) return null;
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }
  final bytes = dataUriBytes(src);
  if (bytes == null) return null;
  await file.writeAsBytes(bytes);
  return file;
}
