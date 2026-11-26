import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart' show appKey, supabaseAnonKey, supabaseUrl;
import 'stories.dart' show StoryMedia;

/// Gravação de um capítulo: o arquivo e o instante em que cada versículo começa.
class ChapterRecording {
  /// Caminho do áudio no bucket.
  final String path;

  /// Início de cada versículo, em milissegundos (o 1º vem depois do título falado).
  final List<int> marks;
  final int durationMs;
  const ChapterRecording(this.path, this.marks, this.durationMs);

  /// Onde começar para ouvir a partir de [verse] (do começo, com o título, se for o 1º).
  Duration startOf(int verse) =>
      verse <= 1 || marks.isEmpty ? Duration.zero : Duration(milliseconds: marks[(verse - 1).clamp(0, marks.length - 1)]);

  /// Versículo que está sendo lido em [pos] (1..n).
  int verseAt(Duration pos) {
    final ms = pos.inMilliseconds;
    var lo = 0, hi = marks.length - 1, at = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (marks[mid] <= ms) {
        at = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return at + 1;
  }

  static ChapterRecording? parse(String path, String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final marks = [for (final m in j['m'] as List) (m as num).toInt()];
      if (marks.isEmpty) return null;
      return ChapterRecording(path, marks, (j['d'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }
}

/// Leitura da Bíblia com a voz padrão do app (Algieba).
///
/// Só as versões de domínio público ou de licença livre são gravadas (o texto das outras pertence
/// às editoras). As gravações são feitas no PC do dono, capítulo a capítulo, conforme o leitor pede:
/// ficam em `leitura/<versão>/<livro>-<capítulo>.ogg`, com os tempos em `.json` e a lista em `index.json`.
class ChapterAudio {
  static const voice = 'Algieba';

  /// Versões que podem ser gravadas.
  static const freeVersions = {'blivre', 'alm1911', 'tb', 'kjv'};
  static bool supports(String bibleId) => freeVersions.contains(bibleId);

  /// [book] é o índice do livro (0..65).
  static String key(int book, int chapter) => '${book + 1}-$chapter';

  static final _index = <String, (DateTime, Set<String>)>{};

  static Set<String> parseIndex(String raw) {
    final j = jsonDecode(raw);
    return {for (final k in ((j is Map ? j['c'] : null) as List? ?? const [])) '$k'};
  }

  /// Capítulos já gravados desta versão (conferido na nuvem no máximo a cada 5 minutos).
  static Future<Set<String>> available(String bibleId) async {
    final hit = _index[bibleId];
    if (hit != null && DateTime.now().difference(hit.$1) < const Duration(minutes: 5)) return hit.$2;
    try {
      final res = await http
          .get(Uri.parse(
              '${StoryMedia.url('leitura/$bibleId/index.json')}?t=${DateTime.now().millisecondsSinceEpoch ~/ 300000}'))
          .timeout(const Duration(seconds: 6));
      final set = res.statusCode == 200 ? parseIndex(utf8.decode(res.bodyBytes)) : <String>{};
      _index[bibleId] = (DateTime.now(), set);
      return set;
    } catch (_) {
      return hit?.$2 ?? const {};
    }
  }

  /// A gravação do capítulo, ou null se não existe (ou sem internet na 1ª vez).
  static Future<ChapterRecording?> load(String bibleId, int book, int chapter) async {
    if (!supports(bibleId)) return null;
    final k = key(book, chapter);
    if (!(await available(bibleId)).contains(k)) return null;
    final raw = await StoryMedia.bytes('leitura/$bibleId/$k.json');
    if (raw == null) return null;
    return ChapterRecording.parse('leitura/$bibleId/$k.ogg', utf8.decode(raw));
  }

  /// Pede a gravação de um capítulo (entra na fila que o PC do dono atende).
  static Future<bool> request(String bibleId, int book, int chapter) async {
    if (!supports(bibleId)) return false;
    try {
      final res = await http
          .post(Uri.parse('$supabaseUrl/functions/v1/historias-admin'),
              headers: {
                'Authorization': 'Bearer $supabaseAnonKey',
                'apikey': supabaseAnonKey,
                'x-app-key': appKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'quero': {'v': bibleId, 'b': book + 1, 'c': chapter},
              }))
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
