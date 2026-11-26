import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um trecho do livro (um bloco de capítulos) explicado em texto corrido.
class NtPart {
  final String chapters; // "5–7", "1:1-13", "v. 1-7"
  final String title;
  final String text;
  final List<String> refs;
  final String art;
  const NtPart(this.chapters, this.title, this.text, this.refs, this.art);

  /// "caps. 5–7", "cap. 8", "1:1-13" ou "v. 1-7".
  String get label {
    if (chapters.startsWith('v.') || chapters.contains(':')) return chapters;
    return RegExp(r'^\d+$').hasMatch(chapters) ? 'cap. $chapters' : 'caps. $chapters';
  }
}

/// Como o livro se liga a outros trechos da Bíblia.
class NtLink {
  final String text;
  final List<String> refs;

  /// Outro livro (1..66) a que a ligação leva, quando há.
  final int? book;
  const NtLink(this.text, this.refs, this.book);
}

class NtGroup {
  final String id;
  final String name;
  final String sub;
  final Color color;
  const NtGroup(this.id, this.name, this.sub, this.color);
}

/// Guia de estudo de um livro do Novo Testamento.
class NtBook {
  final int n; // 40..66
  final String group;

  /// Posição na ordem aproximada em que os livros foram escritos (1..27).
  final int order;
  final String cover;
  final String theme;
  final String author;
  final String date;
  final String from;
  final String to;
  final String why;
  final List<String> stories;
  final List<NtPart> parts;
  final List<String> keys;
  final List<String> lessons;
  final List<NtLink> links;
  const NtBook(this.n, this.group, this.order, this.cover, this.theme, this.author, this.date, this.from, this.to,
      this.why, this.stories, this.parts, this.keys, this.lessons, this.links);
}

/// "Novo Testamento, livro por livro": contexto, partes, versículos-chave e lições dos 27 livros
/// (texto próprio do app; autoria e datas pela posição tradicional, aproximadas).
class NtGuide {
  static NtGuide? _instance;
  final int version;
  final List<NtGroup> groups;
  final List<NtBook> books;
  final Map<int, NtBook> byNumber;
  NtGuide._(this.version, this.groups, this.books) : byNumber = {for (final b in books) b.n: b};

  NtGroup groupOf(NtBook b) => groups.firstWhere((g) => g.id == b.group, orElse: () => groups.first);

  /// Os livros na ordem aproximada em que foram escritos.
  List<NtBook> get chronological => [...books]..sort((a, b) => a.order.compareTo(b.order));

  static Future<NtGuide> load() async =>
      _instance ??= parse(await rootBundle.loadString('assets/data/nt_livros.json'));

  static List<String> _strings(dynamic v) => [for (final x in (v as List? ?? const [])) '$x'];

  static NtGuide parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final groups = [
      for (final g in j['grupos'] as List)
        NtGroup(g['id'] as String, g['nome'] as String, g['sub'] as String? ?? '',
            Color(0xFF000000 | int.parse(g['cor'] as String, radix: 16))),
    ];
    final books = [
      for (final b in j['livros'] as List)
        NtBook(
          (b['n'] as num).toInt(),
          b['grupo'] as String,
          (b['ordem'] as num).toInt(),
          b['capa'] as String,
          b['tema'] as String,
          b['autor'] as String,
          b['data'] as String,
          b['de'] as String,
          b['para'] as String,
          b['porque'] as String,
          _strings(b['historias']),
          [
            for (final p in b['partes'] as List)
              NtPart(p['caps'] as String, p['titulo'] as String, p['texto'] as String, _strings(p['refs']),
                  p['arte'] as String),
          ],
          _strings(b['chaves']),
          _strings(b['licoes']),
          [
            for (final l in b['ligacoes'] as List? ?? const [])
              NtLink(l['texto'] as String, _strings(l['refs']), (l['livro'] as num?)?.toInt()),
          ],
        ),
    ];
    return NtGuide._((j['versao'] as num?)?.toInt() ?? 0, groups, books);
  }
}

/// Livros do guia que o leitor já marcou como estudados (guardado no aparelho).
class NtProgress {
  static const _key = 'nt.estudados';

  /// Avisa as telas abertas quando a marcação muda.
  static final revision = ValueNotifier<int>(0);

  static Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final s in prefs.getStringList(_key) ?? const <String>[]) int.tryParse(s) ?? 0}..remove(0);
  }

  static Future<void> set(int book, bool studied) async {
    final prefs = await SharedPreferences.getInstance();
    final all = {for (final s in prefs.getStringList(_key) ?? const <String>[]) s};
    final changed = studied ? all.add('$book') : all.remove('$book');
    if (!changed) return;
    await prefs.setStringList(_key, all.toList()..sort());
    revision.value++;
  }
}
