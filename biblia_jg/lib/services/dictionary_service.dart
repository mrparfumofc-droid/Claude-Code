import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/bible.dart' show normalizeForSearch;
import 'ai_service.dart' show AiService, AiTurn, supabaseUrl;

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

  /// O verbete ainda está no original em inglês (pode ser traduzido na hora pela IA).
  final bool untranslated;
  final String _key;
  DictEntry(this.dict, this.term, this.english, this.text, {this.untranslated = false}) : _key = normalizeForSearch(term);

  /// Texto normalizado para a busca "dentro do texto" (calculado uma vez só).
  late final String textKey = normalizeForSearch(text);

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

  Future<Directory> _dir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'dicionarios'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  List<DictEntry>? entriesOf(String code) => _entries[code];

  // ---- Tradução na hora dos verbetes que ainda estão em inglês ----
  final Map<String, DictEntry> _translated = {}; // id -> verbete traduzido neste aparelho
  final Set<String> translating = {};

  /// O verbete como deve ser mostrado: a tradução feita neste aparelho, se houver.
  DictEntry resolved(DictEntry e) => _translated[e.id] ?? e;

  Future<File> _translationsFile() async => File(p.join((await _dir()).path, 'traducoes.json'));

  Future<void> _loadTranslations() async {
    try {
      final f = await _translationsFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final e in j.entries) {
        final v = e.value as Map;
        final parts = e.key.split(':');
        _translated[e.key] =
            DictEntry(parts.first, '${v['t']}', parts.skip(1).join(':'), '${v['x']}');
      }
    } catch (_) {}
  }

  static List<String> _chunks(String text, int max) {
    final out = <String>[];
    var cur = '';
    for (final para in text.split(RegExp(r'\n\s*\n'))) {
      if (cur.isNotEmpty && cur.length + para.length > max) {
        out.add(cur);
        cur = '';
      }
      cur = cur.isEmpty ? para : '$cur\n\n$para';
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  /// Traduz um verbete em inglês com a IA e guarda no aparelho. Lança [AiException] se a IA falhar.
  Future<DictEntry> translate(DictEntry e) async {
    if (!e.untranslated) return e;
    final cached = _translated[e.id];
    if (cached != null) return cached;
    translating.add(e.id);
    notifyListeners();
    try {
      var term = e.term;
      final parts = <String>[];
      for (final (i, chunk) in _chunks(e.text, 4200).indexed) {
        final answer = await AiService.ask(task: 'chat', messages: [
          AiTurn(
              true,
              'Traduza para o português do Brasil este trecho do verbete "${e.english}" de um dicionário bíblico antigo '
              '(Easton, 1897). Tradução fiel e completa, sem resumir, sem comentar e sem Markdown. Use os nomes bíblicos '
              'como nas Bíblias Almeida e as referências no formato "Gn 1:1". '
              '${i == 0 ? 'Na primeira linha escreva "TERMO: " seguido do nome do verbete em português; depois uma linha em branco e a tradução.' : 'Escreva só a tradução.'}'
              '\n\n$chunk'),
        ]);
        var text = answer.replaceAll('**', '').trim();
        final m = RegExp(r'^TERMO:\s*(.+)\n', caseSensitive: false).firstMatch(text);
        if (m != null) {
          if (i == 0) term = m.group(1)!.trim();
          text = text.substring(m.end).trim();
        }
        parts.add(text);
      }
      final done = DictEntry(e.dict, term, e.english, parts.join('\n\n'));
      _translated[e.id] = done;
      try {
        final f = await _translationsFile();
        await f.writeAsString(jsonEncode({
          for (final t in _translated.entries) t.key: {'t': t.value.term, 'x': t.value.text},
        }));
      } catch (_) {}
      return done;
    } finally {
      translating.remove(e.id);
      notifyListeners();
    }
  }

  /// Carrega a lista de dicionários e os que já estão no aparelho;
  /// baixa da nuvem os que mudaram.
  Future<void> init() async {
    await _loadMarks();
    if (_translated.isEmpty) await _loadTranslations();
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
            DictEntry(d.code, (e['t'] ?? '') as String, (e['e'] ?? e['t'] ?? '') as String, (e['x'] ?? '') as String,
                untranslated: e['en'] == true)
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
      } else if (inText && e.textKey.contains(q)) {
        text.add(e);
      }
    }
    return [...starts, ...contains, ...text.take(300)];
  }

  // ---------- Marcações ----------

  Future<File> _marksFile() async => File(p.join((await _dir()).path, 'marcacoes.json'));

  Future<void>? _marksFuture;
  bool _marksOk = false;
  Future<void> _writeChain = Future.value();

  /// Lê as marcações uma única vez (quem chamar junto espera a mesma leitura).
  Future<void> _loadMarks() => _marksFuture ??= _readMarks();

  static Map<String, DictMark> _parseMarks(Map<String, dynamic> data) =>
      {for (final e in data.entries) e.key: DictMark.fromJson((e.value as Map).cast())};

  Future<void> _readMarks() async {
    try {
      final f = await _marksFile();
      if (await f.exists()) {
        final raw = await f.readAsString();
        if (raw.trim().isNotEmpty) marks = _parseMarks(jsonDecode(raw) as Map<String, dynamic>);
      }
      _marksOk = true;
    } catch (_) {
      _marksOk = false; // arquivo ilegível: não envia "vazio" por cima da nuvem
    }
  }

  /// Grava em fila (uma gravação por vez) e de forma atômica (temporário + renomear).
  void _persistMarks() {
    final data = jsonEncode(exportMarks());
    _writeChain = _writeChain.then((_) async {
      try {
        final f = await _marksFile();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(data, flush: true);
        await tmp.rename(f.path);
        _marksOk = true;
      } catch (_) {}
    });
  }

  DictMark markOf(DictEntry e) => marks[e.id] ?? DictMark();

  Future<void> saveMark(DictEntry e, DictMark m) async {
    await _loadMarks();
    if (m.isEmpty) {
      marks.remove(e.id);
    } else {
      marks[e.id] = m;
    }
    notifyListeners();
    _persistMarks();
  }

  /// Marcações do aparelho para a sincronização; null se o arquivo não pôde ser lido.
  Future<Map<String, dynamic>?> loadedMarks() async {
    await _loadMarks();
    return _marksOk ? exportMarks() : null;
  }

  Map<String, dynamic> exportMarks() => {for (final e in marks.entries) e.key: e.value.toJson()};

  /// Recebe marcações da nuvem. Com [merge], mantém as daqui e acrescenta as de lá.
  void importMarks(Map<String, dynamic> data, {bool merge = false}) {
    final incoming = _parseMarks(data);
    marks = merge ? {...incoming, ...marks} : incoming;
    notifyListeners();
    _persistMarks();
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
