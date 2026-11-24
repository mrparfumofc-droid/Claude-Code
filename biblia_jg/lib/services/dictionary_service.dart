import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/bible.dart' show normalizeForSearch;
import 'ai_service.dart' show supabaseUrl;

/// Um dicionário disponível na nuvem (bucket público "dicionarios").
class DictInfo {
  final String code;
  final String name;
  final String about;
  final int count;
  final String version;
  const DictInfo(this.code, this.name, this.about, this.count, this.version);

  factory DictInfo.fromJson(Map<String, dynamic> j) => DictInfo(
        j['code'] as String,
        j['name'] as String,
        j['about'] as String? ?? '',
        (j['count'] as num?)?.toInt() ?? 0,
        j['version']?.toString() ?? '1',
      );
  Map<String, dynamic> toJson() =>
      {'code': code, 'name': name, 'about': about, 'count': count, 'version': version};
}

class DictEntry {
  final String dict;
  final String term;
  final String english;
  final String text;
  final String _key;
  DictEntry(this.dict, this.term, this.english, this.text) : _key = normalizeForSearch(term);

  /// Identificador estável (para marcações e anotações).
  String get id => '$dict:$english';
  List<String> get paragraphs =>
      text.split(RegExp(r'\n\s*\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// Marcações de um verbete: favorito, cores por parágrafo e anotação.
class DictMark {
  bool favorite;
  Map<int, int> colors; // parágrafo -> índice da cor
  String note;
  DictMark({this.favorite = false, Map<int, int>? colors, this.note = ''}) : colors = colors ?? {};

  bool get isEmpty => !favorite && colors.isEmpty && note.trim().isEmpty;

  factory DictMark.fromJson(Map<String, dynamic> j) => DictMark(
        favorite: j['fav'] == true,
        colors: {
          for (final e in ((j['hl'] as Map?) ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt()
        },
        note: j['note'] as String? ?? '',
      );
  Map<String, dynamic> toJson() => {
        if (favorite) 'fav': true,
        if (colors.isNotEmpty) 'hl': {for (final e in colors.entries) '${e.key}': e.value},
        if (note.trim().isNotEmpty) 'note': note,
      };
}

/// Dicionários bíblicos (domínio público, traduzidos) baixados da nuvem e
/// guardados no app para ler sem internet, com busca, marcações e anotações.
class DictionaryService extends ChangeNotifier {
  static const _base = '$supabaseUrl/storage/v1/object/public/dicionarios';

  List<DictInfo> dicts = const [];
  final Map<String, List<DictEntry>> _entries = {};
  Map<String, DictMark> marks = {};
  bool loading = false;
  String? error;
  bool _marksLoaded = false;

  Future<Directory> _dir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'dicionarios'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  List<DictEntry>? entriesOf(String code) => _entries[code];

  /// Carrega a lista de dicionários e os que já estão no aparelho;
  /// baixa da nuvem os que mudaram.
  Future<void> init() async {
    await _loadMarks();
    if (dicts.isNotEmpty && _entries.length == dicts.length) return;
    loading = true;
    error = null;
    notifyListeners();
    final dir = await _dir();
    final localIndex = File(p.join(dir.path, 'index.json'));
    Map<String, String> localVersions = {};
    try {
      if (await localIndex.exists()) {
        final list = (jsonDecode(await localIndex.readAsString()) as List)
            .map((e) => DictInfo.fromJson((e as Map).cast()))
            .toList();
        dicts = list;
        localVersions = {for (final d in list) d.code: d.version};
      }
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('$_base/index.json')).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final remote = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
            .map((e) => DictInfo.fromJson((e as Map).cast()))
            .toList();
        for (final d in remote) {
          final f = File(p.join(dir.path, '${d.code}.json'));
          if (localVersions[d.code] != d.version || !await f.exists()) {
            final r = await http.get(Uri.parse('$_base/${d.code}.json')).timeout(const Duration(minutes: 3));
            if (r.statusCode == 200) await f.writeAsBytes(r.bodyBytes, flush: true);
          }
        }
        dicts = remote;
        await localIndex.writeAsString(jsonEncode(remote.map((d) => d.toJson()).toList()));
      }
    } catch (_) {
      if (dicts.isEmpty) error = 'Sem internet para baixar os dicionários pela primeira vez.';
    }
    for (final d in dicts) {
      try {
        final f = File(p.join(dir.path, '${d.code}.json'));
        if (!await f.exists()) continue;
        final raw = jsonDecode(await f.readAsString()) as List;
        _entries[d.code] = [
          for (final e in raw)
            DictEntry(d.code, (e['t'] ?? '') as String, (e['e'] ?? e['t'] ?? '') as String, (e['x'] ?? '') as String)
        ]..sort((a, b) => a._key.compareTo(b._key));
      } catch (_) {}
    }
    loading = false;
    notifyListeners();
  }

  /// Busca por termo (começa com / contém) e, se [inText], também no texto.
  List<DictEntry> search(String? code, String query, {bool inText = false}) {
    final q = normalizeForSearch(query.trim());
    final pools = code == null ? _entries.values : [?_entries[code]];
    final all = [for (final l in pools) ...l];
    if (q.isEmpty) return all;
    final starts = <DictEntry>[], contains = <DictEntry>[], text = <DictEntry>[];
    for (final e in all) {
      if (e._key.startsWith(q)) {
        starts.add(e);
      } else if (e._key.contains(q)) {
        contains.add(e);
      } else if (inText && normalizeForSearch(e.text).contains(q)) {
        text.add(e);
      }
    }
    return [...starts, ...contains, ...text.take(300)];
  }

  // ---------- Marcações ----------

  Future<File> _marksFile() async => File(p.join((await _dir()).path, 'marcacoes.json'));

  Future<void> _loadMarks() async {
    if (_marksLoaded) return;
    _marksLoaded = true;
    try {
      final f = await _marksFile();
      if (await f.exists()) importMarks(jsonDecode(await f.readAsString()) as Map<String, dynamic>, notify: false);
    } catch (_) {}
  }

  DictMark markOf(DictEntry e) => marks[e.id] ?? DictMark();

  Future<void> saveMark(DictEntry e, DictMark m) async {
    if (m.isEmpty) {
      marks.remove(e.id);
    } else {
      marks[e.id] = m;
    }
    notifyListeners();
    final f = await _marksFile();
    await f.writeAsString(jsonEncode(exportMarks()));
  }

  /// Marcações já carregadas do aparelho (para a sincronização não enviar vazio).
  Future<Map<String, dynamic>> loadedMarks() async {
    await _loadMarks();
    return exportMarks();
  }

  Map<String, dynamic> exportMarks() => {for (final e in marks.entries) e.key: e.value.toJson()};

  void importMarks(Map<String, dynamic> data, {bool notify = true}) {
    marks = {for (final e in data.entries) e.key: DictMark.fromJson((e.value as Map).cast())};
    if (notify) {
      notifyListeners();
      _marksFile().then((f) => f.writeAsString(jsonEncode(exportMarks())));
    }
  }

  /// Verbete a partir do id salvo (dicionário:termo em inglês).
  DictEntry? byId(String id) {
    final i = id.indexOf(':');
    if (i < 0) return null;
    final list = _entries[id.substring(0, i)];
    final en = id.substring(i + 1);
    for (final e in list ?? const <DictEntry>[]) {
      if (e.english == en) return e;
    }
    return null;
  }
}
