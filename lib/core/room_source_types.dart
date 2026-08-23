/// sourceTypes rendered via the generic embedded-browser WebviewRoomPlayer
/// (see lobby/webview_browse_screen.dart for how these get created) — all
/// "browse together, no playback sync" platforms. Add a new streaming
/// platform here + to the source picker + to Room.js's sourceType ENUM to
/// support another one; nothing else needs to change.
///
/// Shared between party_screen.dart (picking which player widget to render)
/// and persistent_room_audio.dart (deciding whether there's anything worth
/// keeping alive in the background for the current queue item).
const webviewSourceTypes = {
  'netflix',
  'amazon',
  'youtube_surf',
  'hotstar',
  'aha',
  'sunnxt',
  'sonyliv',
  'airtel_xstream'
};
