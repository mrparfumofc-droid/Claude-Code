import 'dart:convert';

import 'package:flutter/services.dart';

/// Pessoa (ou grupo) na árvore da família de Abraão.
class TreeNode {
  final String id;
  final String name;
  final String type; // patriarca, mae, filho, tribo, descendente
  final double x; // centro
  final double y;
  final String sub;
  final String text;
  final List<String> refs;
  const TreeNode(this.id, this.name, this.type, this.x, this.y, this.sub, this.text, this.refs);

  double get halfWidth => type == 'patriarca' ? 66 : (type == 'descendente' ? 56 : 58);
  double get halfHeight => type == 'patriarca' ? 27 : (type == 'descendente' ? 14 : 23);
}

class TreeEdge {
  final List<String> from; // um pai/mãe ou o casal
  final String to;
  final int list; // > 0: coluna de descendentes abaixo da tribo
  const TreeEdge(this.from, this.to, this.list);
}

class TreeStep {
  final List<String> nodes;
  final String text;
  final String ref;
  const TreeStep(this.nodes, this.text, this.ref);
}

class FamilyTree {
  final double width;
  final double height;
  final List<TreeNode> nodes;
  final List<TreeEdge> edges;
  final List<List<String>> couples;
  final List<TreeStep> steps;
  final Map<String, TreeNode> byId;
  FamilyTree(this.width, this.height, this.nodes, this.edges, this.couples, this.steps)
      : byId = {for (final n in nodes) n.id: n};

  /// Mãe de cada tribo (para a cor) e tribo de cada descendente.
  String groupOf(TreeNode n) {
    if (n.type == 'descendente') return groupOf(byId[n.id.split('-').first]!);
    if (n.type != 'tribo') return n.id;
    for (final e in edges) {
      if (e.to == n.id && e.from.length == 1) return e.from.first;
    }
    return n.id;
  }
}

class King {
  final String name;
  final int start; // a.C.
  final int end;
  final String years;
  final String rating; // bom, mau, misto
  final String note;
  final String ref;
  final String prophets;
  const King(this.name, this.start, this.end, this.years, this.rating, this.note, this.ref, this.prophets);

  String get dates => start == end ? '$start a.C.' : '$start–$end a.C.';
}

class TimeMark {
  final int year;
  final String title;
  final String ref;
  const TimeMark(this.year, this.title, this.ref);
}

class KingsData {
  final List<King> united;
  final List<King> israel;
  final List<King> judah;
  final List<TimeMark> marks;
  const KingsData(this.united, this.israel, this.judah, this.marks);
}

class Prophet {
  final String name;
  final int book; // livro 0..65
  final String date;
  final int year;
  final String period; // pre, exilio, pos
  final List<String> audience;
  final String kings;
  final String message;
  final String ref;
  const Prophet(this.name, this.book, this.date, this.year, this.period, this.audience, this.kings, this.message, this.ref);
}

class BookGroup {
  final String name;
  final int from; // 1..66
  final int to;
  final Color color;
  const BookGroup(this.name, this.from, this.to, this.color);
}

/// Ficha de um livro da Bíblia.
class BookSheet {
  final int n; // 1..66
  final String author;
  final String authorNote;
  final String date;
  final String theme;
  final String summary;
  final String key; // referência do versículo-chave
  final bool narrative; // "acontecimentos" (true) ou "assuntos"
  final List<(String, String)> people; // nome, nota
  final List<(String, String)> events; // título, referência
  final String christ;
  const BookSheet(this.n, this.author, this.authorNote, this.date, this.theme, this.summary, this.key, this.narrative,
      this.people, this.events, this.christ);
}

/// Quadros de estudo do "Panorama bíblico" (texto próprio do app; datas aproximadas).
class PanoramaData {
  static PanoramaData? _instance;
  final FamilyTree tree;
  final KingsData kings;
  final List<Prophet> prophets;
  final List<BookGroup> groups;
  final Map<int, BookSheet> books;
  PanoramaData._(this.tree, this.kings, this.prophets, this.groups, this.books);

  BookGroup groupOf(int n) => groups.firstWhere((g) => n >= g.from && n <= g.to, orElse: () => groups.first);

  static Future<PanoramaData> load() async =>
      _instance ??= parse(await rootBundle.loadString('assets/data/panorama.json'));

  static List<String> _strings(dynamic v) => [for (final x in (v as List? ?? const [])) '$x'];

  static PanoramaData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final t = j['arvore'] as Map<String, dynamic>;
    final tree = FamilyTree(
      (t['largura'] as num).toDouble(),
      (t['altura'] as num).toDouble(),
      [
        for (final n in t['nos'] as List)
          TreeNode(n['id'] as String, n['nome'] as String, n['tipo'] as String, (n['x'] as num).toDouble(),
              (n['y'] as num).toDouble(), n['sub'] as String? ?? '', n['texto'] as String? ?? '', _strings(n['refs'])),
      ],
      [
        for (final e in t['ligacoes'] as List)
          TreeEdge(_strings(e['de']), e['para'] as String, (e['lista'] as num?)?.toInt() ?? 0),
      ],
      [for (final c in t['casais'] as List) _strings(c)],
      [for (final s in t['passos'] as List) TreeStep(_strings(s['nos']), s['texto'] as String, s['ref'] as String? ?? '')],
    );
    King king(dynamic k) => King(k['nome'] as String, (k['ini'] as num).toInt(), (k['fim'] as num).toInt(),
        k['anos'] as String? ?? '', k['aval'] as String? ?? 'mau', k['nota'] as String? ?? '', k['ref'] as String? ?? '',
        k['profetas'] as String? ?? '');
    final r = j['reis'] as Map<String, dynamic>;
    final kings = KingsData(
      [for (final k in r['unido'] as List) king(k)],
      [for (final k in r['israel'] as List) king(k)],
      [for (final k in r['juda'] as List) king(k)],
      [for (final m in r['marcos'] as List) TimeMark((m['ano'] as num).toInt(), m['titulo'] as String, m['ref'] as String? ?? '')],
    );
    final prophets = [
      for (final p in j['profetas'] as List)
        Prophet(p['nome'] as String, (p['livro'] as num).toInt(), p['data'] as String, (p['ano'] as num).toInt(),
            p['periodo'] as String, _strings(p['para']), p['reis'] as String? ?? '', p['mensagem'] as String, p['ref'] as String),
    ];
    final groups = [
      for (final g in j['grupos'] as List)
        BookGroup(g['nome'] as String, (g['de'] as num).toInt(), (g['ate'] as num).toInt(),
            Color(int.parse(g['cor'] as String, radix: 16))),
    ];
    final books = <int, BookSheet>{};
    for (final b in j['livros'] as List? ?? const []) {
      final n = (b['n'] as num).toInt();
      books[n] = BookSheet(
        n,
        b['autor'] as String? ?? '',
        b['autor_nota'] as String? ?? '',
        b['data'] as String? ?? '',
        b['tema'] as String? ?? '',
        b['resumo'] as String? ?? '',
        b['chave'] as String? ?? '',
        b['rotulo'] != 'assuntos',
        [for (final p in b['personagens'] as List? ?? const []) (p['nome'] as String, p['nota'] as String? ?? '')],
        [for (final e in b['acontecimentos'] as List? ?? const []) (e['titulo'] as String, e['ref'] as String? ?? '')],
        b['cristo'] as String? ?? '',
      );
    }
    return PanoramaData._(tree, kings, prophets, groups, books);
  }
}
