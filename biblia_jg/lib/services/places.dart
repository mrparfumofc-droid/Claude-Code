import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/bible.dart' show normalizeForSearch;

/// Lugar bíblico (OpenBible.info Bible Geocoding Data, CC BY 4.0).
class Place {
  final String id;
  final String name; // em português (como nas Bíblias Almeida)
  final String english;
  final String type;
  final LatLng point;
  final int score; // confiança da localização
  final List<String> verses; // OSIS, ex.: Gen.12.8
  final String _key;
  Place(this.id, this.name, this.english, this.type, this.point, this.score, this.verses)
      : _key = normalizeForSearch('$name $english');

  bool matches(String q) => _key.contains(q);

  String get typeLabel => switch (type) {
        'settlement' => 'cidade',
        'mountain' || 'hill' => 'monte',
        'river' || 'stream' => 'rio',
        'body of water' || 'sea' || 'lake' => 'mar/lago',
        'region' || 'territory' => 'região',
        'valley' => 'vale',
        'spring' || 'well' => 'fonte',
        'island' => 'ilha',
        _ => 'lugar',
      };
}

class StoryStep {
  final String place;
  final LatLng point;
  final double zoom;
  final String title;
  final String text;
  final String reference;
  const StoryStep(this.place, this.point, this.zoom, this.title, this.text, this.reference);
}

class StoryRegion {
  final String name;
  final Color color;
  final List<LatLng> points;
  final LatLng? labelAt;
  const StoryRegion(this.name, this.color, this.points, [this.labelAt]);

  LatLng get center {
    if (labelAt != null) return labelAt!;
    var lat = 0.0, lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }
}

class MapStory {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final bool route;
  final List<StoryStep> steps;
  final List<StoryRegion> regions;
  const MapStory(this.id, this.title, this.subtitle, this.color, this.route, this.steps, this.regions);
}

const _osisBooks = [
  'Gen', 'Exod', 'Lev', 'Num', 'Deut', 'Josh', 'Judg', 'Ruth', '1Sam', '2Sam', '1Kgs', '2Kgs', '1Chr', '2Chr',
  'Ezra', 'Neh', 'Esth', 'Job', 'Ps', 'Prov', 'Eccl', 'Song', 'Isa', 'Jer', 'Lam', 'Ezek', 'Dan', 'Hos', 'Joel',
  'Amos', 'Obad', 'Jonah', 'Mic', 'Nah', 'Hab', 'Zeph', 'Hag', 'Zech', 'Mal', 'Matt', 'Mark', 'Luke', 'John',
  'Acts', 'Rom', '1Cor', '2Cor', 'Gal', 'Eph', 'Phil', 'Col', '1Thess', '2Thess', '1Tim', '2Tim', 'Titus',
  'Phlm', 'Heb', 'Jas', '1Pet', '2Pet', '1John', '2John', '3John', 'Jude', 'Rev',
];

/// "Gen.12.8" -> (livro 0..65, capítulo, versículo).
(int, int, int)? osisToRef(String osis) {
  final parts = osis.split('.');
  if (parts.length < 3) return null;
  final b = _osisBooks.indexOf(parts[0]);
  final c = int.tryParse(parts[1]);
  final v = int.tryParse(parts[2]);
  if (b < 0 || c == null || v == null) return null;
  return (b, c, v);
}

/// Lugares e histórias dos mapas (carregados uma vez dos assets).
class PlacesData {
  static PlacesData? _instance;
  final List<Place> places;
  final List<MapStory> stories;
  final Map<String, List<Place>> _byVerse;
  PlacesData._(this.places, this.stories, this._byVerse);

  static Future<PlacesData> load() async {
    if (_instance != null) return _instance!;
    final places = <Place>[];
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/data/places.json')) as List;
      for (final j in raw) {
        final c = (j['c'] as List).cast<num>();
        places.add(Place(
          j['i'] as String,
          (j['n'] ?? j['en']) as String,
          j['en'] as String,
          j['t'] as String? ?? 'place',
          LatLng(c[0].toDouble(), c[1].toDouble()),
          (j['s'] as num?)?.toInt() ?? 0,
          [for (final v in (j['v'] as List? ?? const [])) '$v'],
        ));
      }
    } catch (_) {}
    final byVerse = <String, List<Place>>{};
    final bookIndex = {for (var i = 0; i < _osisBooks.length; i++) _osisBooks[i]: i};
    for (final p in places) {
      for (final v in p.verses) {
        final parts = v.split('.');
        if (parts.length < 3) continue;
        final b = bookIndex[parts[0]];
        if (b == null) continue;
        (byVerse['$b:${parts[1]}:${parts[2]}'] ??= []).add(p);
      }
    }
    final stories = <MapStory>[];
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/data/map_stories.json')) as List;
      for (final s in raw) {
        stories.add(MapStory(
          s['id'] as String,
          s['titulo'] as String,
          s['subtitulo'] as String? ?? '',
          Color(int.parse(s['cor'] as String, radix: 16)),
          s['rota'] != false,
          [
            for (final st in s['passos'] as List)
              StoryStep(
                st['pt'] as String,
                LatLng((st['c'][0] as num).toDouble(), (st['c'][1] as num).toDouble()),
                (st['z'] as num?)?.toDouble() ?? 7,
                st['t'] as String,
                st['d'] as String? ?? '',
                st['r'] as String? ?? '',
              ),
          ],
          [
            for (final r in (s['regioes'] as List? ?? const []))
              StoryRegion(
                r['nome'] as String,
                Color(int.parse(r['cor'] as String, radix: 16)),
                [for (final pt in r['pontos'] as List) LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble())],
                r['rotulo'] == null
                    ? null
                    : LatLng((r['rotulo'][0] as num).toDouble(), (r['rotulo'][1] as num).toDouble()),
              ),
          ],
        ));
      }
    } catch (_) {}
    return _instance = PlacesData._(places, stories, byVerse);
  }

  /// Lugares citados num versículo (livro 0..65, capítulo e versículo).
  List<Place> forVerse(int book, int chapter, int verse) => _byVerse['$book:$chapter:$verse'] ?? const [];

  List<Place> search(String query) {
    final q = normalizeForSearch(query.trim());
    if (q.isEmpty) return const [];
    return places.where((p) => p.matches(q)).take(50).toList();
  }
}
