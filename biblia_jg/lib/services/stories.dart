import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reference_parser.dart';
import 'ai_service.dart' show appKey, supabaseAnonKey, supabaseUrl;

/// Uma cena da história: ilustração, texto narrado e (se houver) o lugar no mapa.
class StoryScene {
  final String image; // chave da ilustração (img/<chave>.jpg)
  final String place;
  final LatLng? point;
  final double zoom;
  final String title;
  final String reference;
  final String text;
  /// Versão da narração gravada: 0 = não tem; 1 = arquivo original; maior = arquivo refeito (sufixo -vN).
  final int audioVersion;
  final bool hasImage; // a ilustração já está na nuvem
  const StoryScene(this.image, this.place, this.point, this.zoom, this.title, this.reference, this.text, this.audioVersion,
      [this.hasImage = true]);

  bool get audio => audioVersion > 0;

  /// Trecho que abre na Bíblia: a primeira referência, sem o "até outro capítulo".
  Passage? get passage => parseStoryReference(reference);
}

/// "At 20:1-3; Rm 15:22-29" -> Atos 20:1-3 · "Êx 1:8–2:10" -> Êxodo 1:8.
Passage? parseStoryReference(String reference) {
  var r = reference.split(';').first.trim();
  final cross = RegExp(r'^(.+?\d+:\d+)\s*[–-]\s*\d+:\d+$').firstMatch(r);
  if (cross != null) r = cross.group(1)!;
  final chapters = RegExp(r'^(.+?\d+)\s*[–-]\s*\d+$').firstMatch(r);
  if (chapters != null && !r.contains(':')) r = chapters.group(1)!;
  return parseReference(r);
}

class BibleStory {
  final String id;
  final String category; // at, jesus, igreja
  final String title;
  final String subtitle;
  final String reference;
  final String summary;
  final String application;
  final ui.Color color;
  final bool route;
  final List<StoryScene> scenes;
  const BibleStory(this.id, this.category, this.title, this.subtitle, this.reference, this.summary, this.application,
      this.color, this.route, this.scenes);

  bool get hasMap => scenes.any((s) => s.point != null);
  bool get hasCover => scenes.any((s) => s.hasImage);

  /// Capa: a primeira cena que já tem ilustração.
  String get cover => scenes.firstWhere((s) => s.hasImage, orElse: () => scenes.first).image;

  /// Duração aproximada da narração, em minutos.
  int get minutes {
    final words = scenes.fold<int>(0, (n, s) => n + s.text.split(RegExp(r'\s+')).length);
    return (words / 100).ceil().clamp(1, 99); // a narração gravada é pausada (~100 palavras/min)
  }
}

const storyCategories = <(String, String, String)>[
  ('igreja', 'Paulo e a igreja primitiva', 'Atos dos Apóstolos e Apocalipse'),
  ('jesus', 'A vida de Jesus', 'Os Evangelhos'),
  ('at', 'Antigo Testamento', 'De Gênesis a Neemias'),
];

/// Histórias ilustradas (texto no app; ilustrações e narração na nuvem, guardadas no aparelho).
class StoriesData {
  static StoriesData? _instance;
  static final revision = ValueNotifier<int>(0);
  final int version;
  final List<BibleStory> stories;
  StoriesData._(this.version, this.stories);

  List<BibleStory> byCategory(String cat) => [for (final s in stories) if (s.category == cat) s];
  BibleStory? byId(String id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  static StoriesData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final stories = <BibleStory>[];
    for (final s in j['historias'] as List) {
      final scenes = <StoryScene>[];
      for (final c in s['cenas'] as List) {
        final pt = c['c'] as List?;
        scenes.add(StoryScene(
          c['img'] as String,
          c['pt'] as String? ?? '',
          pt == null ? null : LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
          (c['z'] as num?)?.toDouble() ?? 8,
          c['t'] as String,
          c['r'] as String? ?? '',
          c['d'] as String? ?? '',
          switch (c['a']) { true => 1, final num n => n.toInt(), _ => 0 },
          c['i'] == true,
        ));
      }
      if (scenes.isEmpty) continue;
      stories.add(BibleStory(
        s['id'] as String,
        s['cat'] as String? ?? 'at',
        s['titulo'] as String,
        s['sub'] as String? ?? '',
        s['ref'] as String? ?? '',
        s['resumo'] as String? ?? '',
        s['aplicacao'] as String? ?? '',
        ui.Color(int.parse(s['cor'] as String? ?? 'FFC9A227', radix: 16)),
        s['rota'] != false,
        scenes,
      ));
    }
    return StoriesData._((j['versao'] as num?)?.toInt() ?? 0, stories);
  }

  /// Carrega do app (ou da cópia mais nova já baixada) e confere a nuvem em segundo plano.
  static Future<StoriesData> load() async {
    if (_instance != null) return _instance!;
    var data = parse(await rootBundle.loadString('assets/data/historias.json'));
    if (!kIsWeb) {
      try {
        final f = File('${(await StoryMedia.dir()).path}/historias.json');
        if (await f.exists()) {
          final cached = parse(await f.readAsString());
          if (cached.version > data.version) data = cached;
        }
      } catch (_) {}
    }
    _instance = data;
    refreshIfStale();
    return data;
  }

  static DateTime? _checked;

  /// Confere a nuvem de novo se a última conferência tem mais de 10 minutos
  /// (novas ilustrações e narrações chegam sem precisar atualizar o app).
  static void refreshIfStale() {
    final last = _checked;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) return;
    _checked = DateTime.now();
    unawaited(_refresh());
  }

  static Future<void> _refresh() async {
    try {
      final res = await http.get(Uri.parse(StoryMedia.url('historias.json'))).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final raw = utf8.decode(res.bodyBytes);
      final fresh = parse(raw);
      if (fresh.version <= (_instance?.version ?? 0) || fresh.stories.isEmpty) return;
      if (!kIsWeb) await File('${(await StoryMedia.dir()).path}/historias.json').writeAsString(raw);
      _instance = fresh;
      revision.value++;
    } catch (_) {}
  }

  // ---- Histórias já ouvidas até o fim ----
  static const _doneKey = 'stories.done';
  static Future<Set<String>> finished() async =>
      ((await SharedPreferences.getInstance()).getStringList(_doneKey) ?? const []).toSet();
  static Future<void> markFinished(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_doneKey) ?? const []).toSet()..add(id);
    await prefs.setStringList(_doneKey, set.toList());
  }
}

/// Voz do narrador: o dono ouve as amostras e escolhe; as narrações passam a ser gravadas com ela.
class NarratorVoices {
  static const _prefKey = 'stories.voz';

  /// Vozes com amostra na nuvem e a voz em uso (null se ainda não há amostras).
  static Future<(List<String>, String)?> load() async {
    try {
      final res = await http
          .get(Uri.parse('${StoryMedia.url('amostras/vozes.json')}?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final voices = [for (final v in j['vozes'] as List? ?? const []) '$v'];
      if (voices.isEmpty) return null;
      final chosen = (await SharedPreferences.getInstance()).getString(_prefKey);
      return (voices, chosen ?? '${j['padrao'] ?? voices.first}');
    } catch (_) {
      return null;
    }
  }

  static String sampleUrl(String voice) => StoryMedia.url('amostras/voz-${voice.toLowerCase()}.mp3');

  /// Registra a escolha (vale para as próximas gravações).
  static Future<bool> choose(String voice) async {
    try {
      final res = await http
          .post(Uri.parse('$supabaseUrl/functions/v1/historias-admin'),
              headers: {
                'Authorization': 'Bearer $supabaseAnonKey',
                'apikey': supabaseAnonKey,
                'x-app-key': appKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'voz': voice}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      await (await SharedPreferences.getInstance()).setString(_prefKey, voice);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Arquivos das histórias (ilustrações, mapas de profundidade e narração) no bucket público
/// "historias", com cópia no aparelho para abrir rápido e funcionar sem internet depois.
class StoryMedia {
  static const base = '$supabaseUrl/storage/v1/object/public/historias';
  static String url(String path) => '$base/$path';
  static String image(String key) => 'img/$key.jpg';
  static String depth(String key) => 'dep/$key.jpg';
  static String thumb(String key) => 'thumb/$key.jpg';
  static String narration(String storyId, int scene, [int version = 1]) =>
      version <= 1 ? 'audio/$storyId-${scene + 1}.mp3' : 'audio/$storyId-${scene + 1}-v$version.mp3';

  static Directory? _dir;
  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await getApplicationSupportDirectory()).path}/historias');
    await d.create(recursive: true);
    return _dir = d;
  }

  static final _memory = <String, Future<Uint8List?>>{};
  static final _order = <String>[];

  /// Bytes de um arquivo: memória, depois aparelho, depois nuvem (e guarda no aparelho).
  static Future<Uint8List?> bytes(String path) {
    final hit = _memory[path];
    if (hit != null) return hit;
    final f = _load(path);
    _memory[path] = f;
    // Miniaturas são pequenas e ficam todas na memória; as ilustrações grandes, só as últimas.
    if (!path.startsWith('thumb/')) {
      _order.add(path);
      while (_order.length > 16) {
        _memory.remove(_order.removeAt(0));
      }
    }
    f.then((b) {
      if (b == null) {
        _memory.remove(path);
        _order.remove(path);
      }
    });
    return f;
  }

  static File _local(Directory d, String path) => File('${d.path}/${path.replaceAll('/', '_')}');

  static Future<Uint8List?> _load(String path) async {
    try {
      File? local;
      if (!kIsWeb) {
        local = _local(await dir(), path);
        if (await local.exists() && await local.length() > 0) return await local.readAsBytes();
      }
      final res = await http.get(Uri.parse(url(path))).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      if (local != null) {
        final tmp = File('${local.path}.tmp');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        await tmp.rename(local.path);
      }
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Arquivo no aparelho (baixa se precisar). Null na web ou sem internet.
  static Future<File?> file(String path) async {
    if (kIsWeb) return null;
    try {
      final local = _local(await dir(), path);
      if (await local.exists() && await local.length() > 0) return local;
      final b = await _load(path);
      return b == null ? null : local;
    } catch (_) {
      return null;
    }
  }

  /// Adianta o download (próxima cena).
  static void warm(Iterable<String> paths) {
    for (final p in paths) {
      unawaited(bytes(p));
    }
  }

  static Future<ui.Image?> decode(String path) async {
    final b = await bytes(path);
    if (b == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(b);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }
}
