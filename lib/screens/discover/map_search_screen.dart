import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/insync_icons.dart';
import '../party/party_screen.dart';
import 'discover_ui.dart';

/// What was picked: a place (move there) and/or a person (open their card).
class MapSearchResult {
  final LatLng? at;
  final String? personId;
  const MapSearchResult({this.at, this.personId});
}

/// Map search: places (cities people are in), people and live lobbies.
class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});
  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  bool _loading = false;
  Map<String, dynamic>? _r;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q.trim()));
    setState(() {});
  }

  Future<void> _run(String q) async {
    final mine = ++_seq;
    if (q.length < 2) {
      setState(() {
        _r = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiClient.get(
              '/discover/map/search?q=${Uri.encodeQueryComponent(q)}')
          as Map<String, dynamic>;
      if (mounted && mine == _seq) {
        setState(() {
          _r = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && mine == _seq) setState(() => _loading = false);
    }
  }

  LatLng? _at(Map m) => m['latitude'] == null
      ? null
      : LatLng(
          asNum(m['latitude']).toDouble(), asNum(m['longitude']).toDouble());

  @override
  Widget build(BuildContext context) {
    final places = (_r?['places'] as List?) ?? const [];
    final people = (_r?['people'] as List?) ?? const [];
    final lobbies = (_r?['lobbies'] as List?) ?? const [];
    final empty =
        _r != null && places.isEmpty && people.isEmpty && lobbies.isEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
            child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const InIcon(InIcons.back, color: Colors.white)),
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  onChanged: _changed,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search people or places',
                    filled: true,
                    fillColor: const Color(0xFF000000),
                    isDense: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child:
                          InIcon(InIcons.search, size: 18, color: DColors.dim),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _text.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _text.clear();
                              _changed('');
                            },
                            icon: const InIcon(InIcons.close,
                                size: 16, color: DColors.dim)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: DColors.red)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: DColors.red)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: DColors.red)),
                  ),
                ),
              ),
            ]),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2, color: DColors.red),
          Expanded(
            child: empty
                ? const Center(
                    child: Text('Nothing found',
                        style: TextStyle(color: DColors.dim)))
                : _r == null
                    ? const Center(
                        child: Text('Type a city, a name or a lobby',
                            style: TextStyle(color: DColors.dim)))
                    : ListView(children: [
                        if (places.isNotEmpty) const _Head('Places'),
                        for (final p in places)
                          ListTile(
                            leading:
                                const InIcon(InIcons.pin, color: Colors.white),
                            title: Text('${p['name']}'),
                            subtitle: Text('${p['people']} people',
                                style: const TextStyle(
                                    color: DColors.dim, fontSize: 12)),
                            onTap: () => Navigator.of(context)
                                .pop(MapSearchResult(at: _at(p as Map))),
                          ),
                        if (people.isNotEmpty) const _Head('People'),
                        for (final p in people)
                          ListTile(
                            leading: PersonFace(
                              avatarUrl: p['avatarUrl'] as String?,
                              name: '${p['name']}',
                              size: 36,
                              ring: p['relation'] == 'none'
                                  ? RingKind.stranger
                                  : RingKind.close,
                            ),
                            title: Text('${p['name']}'),
                            subtitle: Text(
                                [
                                  if (p['username'] != null)
                                    '@${p['username']}',
                                  if (p['relation'] == 'friend') 'friend',
                                  if (p['relation'] == 'match') 'match'
                                ].join(' · '),
                                style: const TextStyle(
                                    color: DColors.dim, fontSize: 12)),
                            onTap: () => Navigator.of(context).pop(
                                MapSearchResult(
                                    at: _at(p as Map),
                                    personId: p['id'] as String)),
                          ),
                        if (lobbies.isNotEmpty) const _Head('Lobbies'),
                        for (final l in lobbies)
                          ListTile(
                            leading: Container(
                              width: 40,
                              height: 30,
                              decoration: BoxDecoration(
                                color: DColors.redTint,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: DColors.red),
                              ),
                              child: const InIcon(InIcons.tv,
                                  size: 16, color: DColors.redSoft),
                            ),
                            title: Text('${l['title']}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${l['memberCount'] ?? 0} in it',
                                style: const TextStyle(
                                    color: DColors.dim, fontSize: 12)),
                            trailing: const DChip('Join',
                                tone: DTone.red, fontSize: 11),
                            onTap: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => PartyScreen(
                                        roomId: l['id'] as String))),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text,
            style: const TextStyle(
                color: DColors.dim, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
