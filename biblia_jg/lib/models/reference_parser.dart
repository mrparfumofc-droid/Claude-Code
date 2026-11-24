import 'bible.dart';

/// Trecho bíblico: livro, capítulo e versículos (opcional).
class Passage {
  final int book;
  final int chapter;
  final int? verse;
  final int? endVerse;
  const Passage(this.book, this.chapter, [this.verse, this.endVerse]);

  String label(Bible? bible) {
    final name = bible != null && book < bible.books.length
        ? bible.books[book].name
        : canonicalBooks[book].name;
    if (verse == null) return '$name $chapter';
    return endVerse == null ? '$name $chapter:$verse' : '$name $chapter:$verse-$endVerse';
  }
}

String _key(String s) => normalizeForSearch(s).replaceAll(RegExp(r'[\s.]'), '');

final Map<String, int> _bookIndex = () {
  final m = <String, int>{};
  for (var i = 0; i < canonicalBooks.length; i++) {
    final b = canonicalBooks[i];
    m[_key(b.name)] = i;
    m[_key(b.abbrev)] = i;
  }
  const extra = <String, String>{
    'gen': 'gn', 'exo': 'ex', 'exod': 'ex', 'lev': 'lv', 'num': 'nm', 'deut': 'dt', 'jos': 'js',
    'juizes': 'jz', 'jui': 'jz', 'rute': 'rt', 'sm1': '1sm', 'salmo': 'sl', 'sal': 'sl', 'ps': 'sl',
    'prov': 'pv', 'pr': 'pv', 'ecl': 'ec', 'cantares': 'ct', 'canticodoscanticos': 'ct',
    'canticos': 'ct', 'isa': 'is', 'jer': 'jr', 'lam': 'lm', 'eze': 'ez', 'dan': 'dn', 'oseias': 'os',
    'mal': 'ml', 'mat': 'mt', 'mar': 'mc', 'luc': 'lc', 'joa': 'jo', 'jao': 'jo', 'rom': 'rm',
    'gal': 'gl', 'efe': 'ef', 'fil': 'fp', 'col': 'cl', 'heb': 'hb', 'tia': 'tg', 'jud': 'jd',
    'apoc': 'ap', 'apo': 'ap', 'job': 'jó', 'filemon': 'fm', 'filem': 'fm',
  };
  extra.forEach((k, v) {
    final i = canonicalBooks.indexWhere((b) => b.abbrev == v);
    if (i >= 0) m[k] = i;
  });
  // "1 Samuel" escrito como "I Samuel".
  for (final entry in m.entries.toList()) {
    final k = entry.key;
    if (k.startsWith('1')) m.putIfAbsent('i${k.substring(1)}', () => entry.value);
    if (k.startsWith('2')) m.putIfAbsent('ii${k.substring(1)}', () => entry.value);
    if (k.startsWith('3')) m.putIfAbsent('iii${k.substring(1)}', () => entry.value);
  }
  return m;
}();

int? bookFromName(String name) {
  // "Jó" (com acento) é o livro de Jó; "Jo" sem acento é João.
  if (name.trim().toLowerCase().replaceAll('.', '') == 'jó') return 17;
  return _bookIndex[_key(name)];
}

final _refPattern = RegExp(
  r'^\s*((?:[1-3]|I{1,3})?\s*[A-Za-zÀ-ÿ\. ]+?)\s*(\d+)(?:\s*[:.,]\s*(\d+)(?:\s*[-–]\s*(\d+))?)?\s*$',
);

/// Interpreta "Jo 3:16", "João 3.16-18", "Salmos 23", "1 Co 13". Retorna null se não entender.
Passage? parseReference(String input) {
  final m = _refPattern.firstMatch(input);
  if (m == null) return null;
  final book = bookFromName(m.group(1)!);
  if (book == null) return null;
  final chapter = int.parse(m.group(2)!);
  final verse = m.group(3) == null ? null : int.parse(m.group(3)!);
  final end = m.group(4) == null ? null : int.parse(m.group(4)!);
  return Passage(book, chapter, verse, end != null && verse != null && end > verse ? end : null);
}

final _inTextPattern = RegExp(
  r'(?<![A-Za-zÀ-ÿ])((?:[1-3]\s?)?[A-ZÀ-Ý][a-zà-ÿ]+(?:\s(?:dos|de)\s[A-ZÀ-Ý][a-zà-ÿ]+)?)\.?\s(\d{1,3})[:.](\d{1,3})(?:\s?[-–]\s?(\d{1,3}))?',
);

/// Referências bíblicas com a posição no texto (início, fim, trecho), para virar link.
List<(int, int, Passage)> locateReferences(String text) {
  final out = <(int, int, Passage)>[];
  for (final m in _inTextPattern.allMatches(text)) {
    final book = bookFromName(m.group(1)!);
    if (book == null) continue;
    out.add((
      m.start,
      m.end,
      Passage(book, int.parse(m.group(2)!), int.parse(m.group(3)!),
          m.group(4) == null ? null : int.parse(m.group(4)!)),
    ));
  }
  return out;
}

/// Encontra referências bíblicas dentro de um texto (ex.: resposta da IA).
List<Passage> findReferences(String text) {
  final out = <Passage>[];
  final seen = <String>{};
  for (final m in _inTextPattern.allMatches(text)) {
    final book = bookFromName(m.group(1)!);
    if (book == null) continue;
    final p = Passage(book, int.parse(m.group(2)!), int.parse(m.group(3)!),
        m.group(4) == null ? null : int.parse(m.group(4)!));
    final k = '${p.book}:${p.chapter}:${p.verse}:${p.endVerse}';
    if (seen.add(k)) out.add(p);
  }
  return out;
}
