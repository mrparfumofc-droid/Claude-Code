/// Modelos da Bíblia e formato de arquivo das versões.
///
/// Formato JSON aceito (formato próprio do app):
/// {
///   "id": "acf", "name": "Almeida Corrigida Fiel", "abbrev": "ACF",
///   "copyright": "...",
///   "books": [
///     {"abbrev": "gn", "name": "Gênesis",
///      "titles": {"1:1": "A criação"},          // opcional: "capítulo:versículo" -> título
///      "chapters": [["No princípio...", "..."], ...]}
///   ]
/// }
/// Palavras de Jesus podem vir marcadas com `<J>...</J>` dentro do texto.
///
/// Também aceita o formato comum "lista de livros":
/// [{"abbrev": "gn", "chapters": [["..."]]}, ...] (os nomes vêm da lista canônica).
library;

import 'dart:convert';

class BookInfo {
  final String abbrev;
  final String name;
  final bool newTestament;
  const BookInfo(this.abbrev, this.name, this.newTestament);
}

const List<BookInfo> canonicalBooks = [
  BookInfo('gn', 'Gênesis', false),
  BookInfo('ex', 'Êxodo', false),
  BookInfo('lv', 'Levítico', false),
  BookInfo('nm', 'Números', false),
  BookInfo('dt', 'Deuteronômio', false),
  BookInfo('js', 'Josué', false),
  BookInfo('jz', 'Juízes', false),
  BookInfo('rt', 'Rute', false),
  BookInfo('1sm', '1 Samuel', false),
  BookInfo('2sm', '2 Samuel', false),
  BookInfo('1rs', '1 Reis', false),
  BookInfo('2rs', '2 Reis', false),
  BookInfo('1cr', '1 Crônicas', false),
  BookInfo('2cr', '2 Crônicas', false),
  BookInfo('ed', 'Esdras', false),
  BookInfo('ne', 'Neemias', false),
  BookInfo('et', 'Ester', false),
  BookInfo('jó', 'Jó', false),
  BookInfo('sl', 'Salmos', false),
  BookInfo('pv', 'Provérbios', false),
  BookInfo('ec', 'Eclesiastes', false),
  BookInfo('ct', 'Cânticos', false),
  BookInfo('is', 'Isaías', false),
  BookInfo('jr', 'Jeremias', false),
  BookInfo('lm', 'Lamentações', false),
  BookInfo('ez', 'Ezequiel', false),
  BookInfo('dn', 'Daniel', false),
  BookInfo('os', 'Oséias', false),
  BookInfo('jl', 'Joel', false),
  BookInfo('am', 'Amós', false),
  BookInfo('ob', 'Obadias', false),
  BookInfo('jn', 'Jonas', false),
  BookInfo('mq', 'Miquéias', false),
  BookInfo('na', 'Naum', false),
  BookInfo('hc', 'Habacuque', false),
  BookInfo('sf', 'Sofonias', false),
  BookInfo('ag', 'Ageu', false),
  BookInfo('zc', 'Zacarias', false),
  BookInfo('ml', 'Malaquias', false),
  BookInfo('mt', 'Mateus', true),
  BookInfo('mc', 'Marcos', true),
  BookInfo('lc', 'Lucas', true),
  BookInfo('jo', 'João', true),
  BookInfo('at', 'Atos', true),
  BookInfo('rm', 'Romanos', true),
  BookInfo('1co', '1 Coríntios', true),
  BookInfo('2co', '2 Coríntios', true),
  BookInfo('gl', 'Gálatas', true),
  BookInfo('ef', 'Efésios', true),
  BookInfo('fp', 'Filipenses', true),
  BookInfo('cl', 'Colossenses', true),
  BookInfo('1ts', '1 Tessalonicenses', true),
  BookInfo('2ts', '2 Tessalonicenses', true),
  BookInfo('1tm', '1 Timóteo', true),
  BookInfo('2tm', '2 Timóteo', true),
  BookInfo('tt', 'Tito', true),
  BookInfo('fm', 'Filemom', true),
  BookInfo('hb', 'Hebreus', true),
  BookInfo('tg', 'Tiago', true),
  BookInfo('1pe', '1 Pedro', true),
  BookInfo('2pe', '2 Pedro', true),
  BookInfo('1jo', '1 João', true),
  BookInfo('2jo', '2 João', true),
  BookInfo('3jo', '3 João', true),
  BookInfo('jd', 'Judas', true),
  BookInfo('ap', 'Apocalipse', true),
];

class Book {
  final int index; // 0..65
  final String abbrev;
  final String name;
  final List<List<String>> chapters;
  final Map<String, String> titles;

  Book({
    required this.index,
    required this.abbrev,
    required this.name,
    required this.chapters,
    this.titles = const {},
  });

  bool get newTestament =>
      index < canonicalBooks.length ? canonicalBooks[index].newTestament : true;

  String? titleBefore(int chapter, int verse) => titles['$chapter:$verse'];
}

class Bible {
  final String id;
  final String name;
  final String abbrev;
  final String copyright;
  final List<Book> books;

  Bible({
    required this.id,
    required this.name,
    required this.abbrev,
    required this.copyright,
    required this.books,
  });

  int get totalChapters => books.fold(0, (s, b) => s + b.chapters.length);

  static Bible parse(String source, {String? fallbackId, String? fallbackName}) {
    // Remove BOM, se existir.
    if (source.isNotEmpty && source.codeUnitAt(0) == 0xFEFF) {
      source = source.substring(1);
    }
    final data = jsonDecode(source);
    if (data is List) {
      return _fromBookList(data,
          id: fallbackId ?? 'importada',
          name: fallbackName ?? 'Versão importada',
          abbrev: (fallbackId ?? 'IMP').toUpperCase(),
          copyright: '');
    }
    if (data is Map<String, dynamic>) {
      final books = data['books'];
      if (books is! List) {
        throw const FormatException('Arquivo sem a lista "books".');
      }
      final id = (data['id'] ?? fallbackId ?? 'importada').toString();
      return _fromBookList(books,
          id: id,
          name: (data['name'] ?? fallbackName ?? id).toString(),
          abbrev: (data['abbrev'] ?? id).toString().toUpperCase(),
          copyright: (data['copyright'] ?? '').toString());
    }
    throw const FormatException('Formato de Bíblia não reconhecido.');
  }

  static Bible _fromBookList(List list,
      {required String id,
      required String name,
      required String abbrev,
      required String copyright}) {
    final books = <Book>[];
    for (var i = 0; i < list.length; i++) {
      final b = list[i] as Map<String, dynamic>;
      final canon = i < canonicalBooks.length ? canonicalBooks[i] : null;
      final chapters = (b['chapters'] as List)
          .map((c) => (c as List).map((v) => v.toString()).toList())
          .toList();
      final titles = <String, String>{};
      final t = b['titles'];
      if (t is Map) {
        t.forEach((k, v) => titles[k.toString()] = v.toString());
      }
      books.add(Book(
        index: i,
        abbrev: (b['abbrev'] ?? canon?.abbrev ?? '$i').toString(),
        name: (b['name'] ?? canon?.name ?? 'Livro ${i + 1}').toString(),
        chapters: chapters,
        titles: titles,
      ));
    }
    return Bible(
        id: id, name: name, abbrev: abbrev, copyright: copyright, books: books);
  }
}

/// Referência a um versículo. Capítulo e versículo começam em 1.
class VerseRef {
  final int book; // índice 0..65
  final int chapter;
  final int verse;
  const VerseRef(this.book, this.chapter, this.verse);

  String get key => '$book:$chapter:$verse';

  static VerseRef fromKey(String key) {
    final p = key.split(':').map(int.parse).toList();
    return VerseRef(p[0], p[1], p[2]);
  }

  String label(Bible? bible) {
    final name = bible != null && book < bible.books.length
        ? bible.books[book].name
        : (book < canonicalBooks.length ? canonicalBooks[book].name : '?');
    return '$name $chapter:$verse';
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

/// Segmento de texto de um versículo (normal ou palavras de Jesus).
class VerseSegment {
  final String text;
  final bool jesus;
  const VerseSegment(this.text, this.jesus);
}

final _jesusTag = RegExp(r'<J>(.*?)</J>', dotAll: true);

List<VerseSegment> splitJesusWords(String text) {
  final out = <VerseSegment>[];
  var last = 0;
  for (final m in _jesusTag.allMatches(text)) {
    if (m.start > last) out.add(VerseSegment(text.substring(last, m.start), false));
    out.add(VerseSegment(m.group(1)!, true));
    last = m.end;
  }
  if (last < text.length) out.add(VerseSegment(text.substring(last), false));
  return out;
}

String plainVerse(String text) => text.replaceAll(RegExp(r'</?J>'), '');

/// Remove acentos e baixa a caixa para busca.
String normalizeForSearch(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final r in plainVerse(s).runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}
