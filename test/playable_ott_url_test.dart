import 'package:flutter_test/flutter_test.dart';
import 'package:insync/core/title_page_list.dart';
import 'package:insync/core/ott_page_suggestions.dart';
import 'package:insync/screens/party/webview_room_player.dart';

void main() {
  test('Prime address after playback opens the player again', () {
    final u = Uri.parse(playableOttUrl(
        'https://www.primevideo.com/detail/0HLC92CSJJRAQFTTEWFIUPKB5C?ref_=atv_plr_detail_play'));
    expect(u.queryParameters['autoplay'], '1');
    expect(u.queryParameters['t'], '0');
    expect(u.queryParameters.containsKey('ref_'), isFalse);
  });

  test('Prime trailer link opens the title instead', () {
    final u = Uri.parse(playableOttUrl(
        'https://www.primevideo.com/detail/0GPE7W7O8MQLO2RIWAGVJTUOSH?autoplay=trailer'));
    expect(u.queryParameters['autoplay'], '1');
  });

  test('ready Prime links and other sites are left alone', () {
    const ready = 'https://www.primevideo.com/detail/X?autoplay=1&t=120&ref_=a';
    expect(playableOttUrl(ready), ready);
    const hotstar = 'https://www.hotstar.com/in/movies/x/123/watch';
    expect(playableOttUrl(hotstar), hotstar);
  });

  test('Netflix watch id is read from the room address', () {
    expect(
        TitlePageList.netflixWatchId(
            'https://www.netflix.com/watch/81011359?trackId=1'),
        '81011359');
    expect(
        TitlePageList.netflixWatchId(
            'https://www.netflix.com/in/watch/80994082'),
        '80994082');
    expect(
        TitlePageList.netflixWatchId('https://www.netflix.com/browse'), isNull);
  });

  test('Prime AVIF thumbnails are asked for as JPEG', () {
    expect(
        OttPageSuggestions.jpegThumbnail(
            'https://m.media-amazon.com/images/S/x._BR-6_AC_SX360_FMavif_PQ65_.jpg'),
        'https://m.media-amazon.com/images/S/x._BR-6_AC_SX360_FMjpg_PQ65_.jpg');
  });

  test('Hotstar watch address leads to its show or movie page', () {
    expect(
        TitlePageList.hotstarTitlePage(
            'https://www.hotstar.com/in/shows/bigg-boss/1971002586/bbhin-day-58/1271702358/watch'),
        'https://www.hotstar.com/in/shows/bigg-boss/1971002586');
    expect(
        TitlePageList.hotstarTitlePage(
            'https://www.hotstar.com/in/movies/some-film/1260000000/watch'),
        'https://www.hotstar.com/in/movies/some-film/1260000000');
    expect(TitlePageList.hotstarTitlePage('https://www.netflix.com/watch/1'),
        isNull);
  });

  test('Hotstar AVIF thumbnails are asked for as JPEG', () {
    expect(
        OttPageSuggestions.jpegThumbnail(
            'https://img10.hotstar.com/image/upload/f_auto,h_124/sources/x-h'),
        'https://img10.hotstar.com/image/upload/f_jpg,h_124/sources/x-h');
  });
}
