/// Spec section 88 — metadata/capability description of what to play,
/// never the actual proprietary player. `type` selects which MediaSource
/// factory the native side builds (see Media3PlayerView.kt's
/// `initialize`): progressive MP4/etc, HLS, or DASH.
enum VideoSourceType { direct, hls, dash }

class VideoSource {
  final String url;
  final VideoSourceType type;
  final Map<String, String> headers;

  const VideoSource({
    required this.url,
    this.type = VideoSourceType.direct,
    this.headers = const {},
  });

  Map<String, Object?> toChannelArgs() => {
        'url': url,
        'type': type.name,
        'headers': headers,
      };
}
