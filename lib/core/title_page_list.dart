import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Next episodes and similar titles for the title playing in the room, for
/// sites whose watch page carries neither (Netflix, Hotstar — unlike
/// Prime's, see webview_room_player.dart). Opens the title's own page in a
/// hidden view with this person's own login, reads what the page shows,
/// and closes it again. Video on that page stays silent: nothing there
/// plays without a tap.
class TitlePageList {
  TitlePageList._();

  static final _cache = <String, List<Map<String, dynamic>>>{};
  static final _running = <String, Future<List<Map<String, dynamic>>>>{};

  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static String? netflixWatchId(String? url) =>
      RegExp(r'netflix\.com/(?:[a-z-]+/)?watch/(\d+)')
          .firstMatch(url ?? '')
          ?.group(1);

  /// The show or movie page a Hotstar watch address belongs to, e.g.
  /// /in/shows/<name>/<id>/<episode>/<id>/watch → /in/shows/<name>/<id>.
  static String? hotstarTitlePage(String? url) {
    final u = Uri.tryParse(url ?? '');
    if (u == null || !u.host.contains('hotstar.com')) return null;
    final m = RegExp(r'^((?:/[a-z]{2})?/(?:shows|movies)/[^/]+/\d+)')
        .firstMatch(u.path);
    return m == null ? null : 'https://www.hotstar.com${m.group(1)}';
  }

  /// The list for a room address, or empty if the site isn't one of these
  /// or its page shows nothing to suggest.
  static Future<List<Map<String, dynamic>>> read(String roomUrl) {
    final nf = netflixWatchId(roomUrl);
    if (nf != null) {
      return _once('netflix:$nf', 'https://www.netflix.com/title/$nf',
          '$_netflixScript(${jsonEncode(nf)})', 'netflix');
    }
    final hs = hotstarTitlePage(roomUrl);
    if (hs != null) {
      final path = Uri.parse(roomUrl).path;
      return _once('hotstar:$path', hs, '$_hotstarScript(${jsonEncode(path)})',
          'hotstar');
    }
    return Future.value(const []);
  }

  static Future<List<Map<String, dynamic>>> _once(
      String key, String page, String script, String sourceType) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _running[key] ??= _read(page, script, sourceType).then((items) {
      if (items.isNotEmpty) _cache[key] = items;
      return items;
    }).whenComplete(() => _running.remove(key));
  }

  static Future<List<Map<String, dynamic>>> _read(
      String page, String script, String sourceType) async {
    final done = Completer<List<Map<String, dynamic>>>();
    Timer? poll;
    var tries = 0;
    void finish(List<Map<String, dynamic>> items) {
      poll?.cancel();
      if (!done.isCompleted) done.complete(items);
    }

    final view = HeadlessInAppWebView(
      initialSize: const Size(1280, 900),
      initialUrlRequest: URLRequest(url: WebUri(page)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
        userAgent: _desktopUa,
      ),
      onLoadStop: (controller, _) {
        poll ??= Timer.periodic(const Duration(milliseconds: 1500), (_) async {
          if (++tries > 16) return finish(const []);
          try {
            final raw = await controller.evaluateJavascript(source: script);
            if (raw is! String) return;
            finish([
              for (final e in (jsonDecode(raw) as List).whereType<Map>())
                {
                  'videoUrl': e['videoUrl'],
                  'title': e['title'] ?? '',
                  'thumbnail': e['thumbnail'],
                  'badge': e['badge'],
                  'sourceType': sourceType,
                }
            ]);
          } catch (_) {}
        });
      },
      onReceivedError: (_, request, __) {
        if (request.isForMainFrame ?? false) finish(const []);
      },
    );
    try {
      await view.run();
      return await done.future
          .timeout(const Duration(seconds: 35), onTimeout: () => const []);
    } catch (_) {
      return const [];
    } finally {
      poll?.cancel();
      unawaited(view.dispose());
    }
  }

  // Netflix's title popup: episodes after the one playing (by its id, or
  // Netflix's own "current" mark when the room started on the show), then
  // More Like This. Each card's Netflix id is in its tracking data.
  static const _netflixScript = r"""
(function(playing){
  var m = document.querySelector('.detail-modal'); if (!m) return null;
  function vid(card){ var e = card.querySelector('[data-ui-tracking-context]'); if (!e) return null; try { return String(JSON.parse(decodeURIComponent(e.getAttribute('data-ui-tracking-context'))).video_id); } catch(x) { return null; } }
  function pic(card){ var im = card.querySelector('img'); var s = im && (im.currentSrc || im.src) || ''; return /^https?:/.test(s) ? s : null; }
  var season = (m.querySelector('[class*="episodeSelector-dropdown"], [data-uia*="dropdown-toggle"]') || {}).textContent || '';
  var sn = (season.match(/\d+/) || ['1'])[0];
  var out = [], seen = {}; seen[playing] = 1;
  var eps = Array.from(m.querySelectorAll('.titleCardList--container.episode-item'));
  var cur = eps.findIndex(function(c){ return vid(c) === playing; });
  if (cur < 0) cur = eps.findIndex(function(c){ return c.classList.contains('current'); });
  eps.forEach(function(c, i){
    var id = vid(c); if (!id || seen[id]) return; seen[id] = 1;
    if (cur >= 0 && i <= cur) return;
    var n = (c.querySelector('.titleCard-title_index') || {}).textContent || String(i + 1);
    var t = (c.querySelector('.titleCard-title_text') || {}).textContent || c.getAttribute('aria-label') || 'Episode';
    out.push({videoUrl: 'https://www.netflix.com/watch/' + id, title: t.trim(), badge: 'S' + sn + ' E' + n.trim(), thumbnail: pic(c)});
  });
  m.querySelectorAll('.titleCard--container:not(.episode-item)').forEach(function(c){
    var id = vid(c); if (!id || seen[id]) return; seen[id] = 1;
    out.push({videoUrl: 'https://www.netflix.com/watch/' + id, title: c.getAttribute('aria-label') || 'Netflix', thumbnail: pic(c)});
  });
  return out.length ? JSON.stringify(out.slice(0, 40)) : null;
})""";

  // Hotstar's show/movie page: the episode cards are links; More Like This
  // cards aren't, so each is pressed with the page's own address change
  // caught and held back, which gives its address while the page stays.
  // Runs once in the background; later calls return its result.
  static const _hotstarScript = r"""
(function(playing){
  if (window.__insyncList !== undefined) return window.__insyncList;
  if (window.__insyncBusy) return null;
  var more = document.querySelector('[data-testid="scroll-section-More Like This"]');
  var cards = document.querySelectorAll('[data-testid="episode-card"]');
  if (!more) { window.scrollTo(0, document.body.scrollHeight); if (!cards.length) return null; }
  window.__insyncBusy = true;
  document.querySelectorAll('video').forEach(function(v){ v.muted = true; v.pause(); });
  function pic(el){ var im = el && el.querySelector('img'); var s = im && (im.currentSrc || im.src) || ''; return /^https?:/.test(s) ? s : null; }
  function wait(ms){ return new Promise(function(r){ setTimeout(r, ms); }); }
  (async function(){
    var out = [], seen = {}; seen[playing] = 1;
    var eps = [];
    document.querySelectorAll('[data-testid="episode-card"]').forEach(function(c){
      var a = c.closest('a') || c.querySelector('a'); if (!a) return;
      var u = new URL(a.getAttribute('href'), location.href);
      if (seen[u.pathname]) return; seen[u.pathname] = 1;
      var badge = null, s = 0, e = 0;
      c.querySelectorAll('span').forEach(function(sp){ var m = sp.textContent.trim().match(/^S(\d+)\s*E(\d+)$/); if (m) { badge = m[0]; s = +m[1]; e = +m[2]; } });
      var h = c.querySelector('h3');
      eps.push({videoUrl: u.origin + u.pathname, title: (h ? h.textContent.trim() : 'Episode').slice(0, 120), badge: badge, thumbnail: pic(c), n: s * 10000 + e});
    });
    var curN = -1;
    document.querySelectorAll('[data-testid="episode-card"]').forEach(function(c){
      var a = c.closest('a') || c.querySelector('a');
      if (a && new URL(a.getAttribute('href'), location.href).pathname === playing) {
        c.querySelectorAll('span').forEach(function(sp){ var m = sp.textContent.trim().match(/^S(\d+)\s*E(\d+)$/); if (m) curN = +m[1] * 10000 + +m[2]; });
      }
    });
    if (curN >= 0) eps = eps.filter(function(x){ return x.n > curN; }).sort(function(a, b){ return a.n - b.n; });
    eps.forEach(function(x){ delete x.n; out.push(x); });
    more = document.querySelector('[data-testid="scroll-section-More Like This"]');
    if (more) {
      more.scrollIntoView(); await wait(800);
      var push = history.pushState, replace = history.replaceState, nav = null;
      history.pushState = function(s, t, u){ nav = String(u); };
      history.replaceState = function(){};
      try {
        var tiles = Array.from(more.querySelectorAll('[data-testid="tray-card-default"]'));
        for (var i = 0; i < tiles.length && i < 20; i++) {
          var act = tiles[i].querySelector('[data-testid="action"]'); if (!act) continue;
          nav = null; act.click(); await wait(400);
          if (!nav) continue;
          var u = new URL(nav, location.href);
          var path = u.pathname.replace(/\/$/, '');
          if (seen[path] || !/\/(shows|movies)\//.test(path)) continue; seen[path] = 1;
          var label = (act.getAttribute('aria-label') || '').split(',')[0];
          out.push({videoUrl: u.origin + path + '/watch', title: label || 'Hotstar', thumbnail: pic(tiles[i])});
        }
      } finally { history.pushState = push; history.replaceState = replace; }
    }
    window.__insyncList = out.length ? JSON.stringify(out.slice(0, 40)) : null;
  })();
  return null;
})""";
}
