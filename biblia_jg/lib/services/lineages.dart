import 'dart:convert';

import 'package:flutter/services.dart';

/// Uma parte do quadro: pessoa, grupo ou marco no tempo.
class LinNode {
  final String id;
  final String name;

  /// destaque, pessoa, mini, marco, grupo ou elo (texto de ligação, como "outras gerações").
  final String type;
  final double x; // centro
  final double y;
  final double w;
  final double h;
  final String sub;
  final String text;
  final List<String> refs;

  /// Chave da ilustração (a mesma das histórias); null = ainda não há.
  final String? art;

  /// Nome exato do retrato no índice (null = sem retrato; nunca se procura pelo nome do nó,
  /// para não confundir homônimos como os dois Josés ou os dois Filipes).
  final String? portrait;
  final Color? color;

  /// Fatos curtos: (rótulo, valor), ex.: ("Ofício", "pescador").
  final List<(String, String)> facts;

  /// Atalho para outra tela: `abraao`, `reis`, `historias`, `mapas` ou `quadro:` seguido do id.
  final String link;
  const LinNode(this.id, this.name, this.type, this.x, this.y, this.w, this.h, this.sub, this.text, this.refs, this.art,
      this.portrait, this.color, this.facts, this.link);

  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: w, height: h);
}

class LinEdge {
  final List<String> from; // um nó ou o casal
  final String to;
  final bool dashed; // ligação que pula gerações ou não é de sangue
  final bool horizontal; // sai pela direita e entra pela esquerda

  /// Onde a linha dobra (y nas verticais, x nas horizontais); null = calculado.
  final double? mid;
  const LinEdge(this.from, this.to, this.dashed, this.horizontal, this.mid);
}

/// Faixa de fundo que agrupa uma parte do quadro e lhe dá título.
class LinBand {
  final Rect rect;
  final String title;
  final String sub;
  final Color color;
  final bool titleAtBottom;
  const LinBand(this.rect, this.title, this.sub, this.color, this.titleAtBottom);
}

/// Um passo da apresentação: o que iluminar, o que dizer e a ilustração que acompanha.
class LinStep {
  final List<String> nodes;
  final String title;
  final String text;
  final String ref;
  final String? art;
  const LinStep(this.nodes, this.title, this.text, this.ref, this.art);
}

/// Um quadro de linhagem (árvore ou linha de marcos) do Panorama bíblico.
class LineageChart {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final String? cover;
  final String intro;
  final double width;
  final double height;
  final List<LinNode> nodes;
  final List<LinEdge> edges;
  final List<List<String>> couples;
  final List<LinBand> bands;
  final List<LinStep> steps;
  final Map<String, LinNode> byId;
  LineageChart(this.id, this.title, this.subtitle, this.color, this.cover, this.intro, this.width, this.height, this.nodes,
      this.edges, this.couples, this.bands, this.steps)
      : byId = {for (final n in nodes) n.id: n};
}

/// Quadros de linhagens: genealogia de Jesus, de Adão a Abraão, as linhas real e sacerdotal,
/// os doze apóstolos, Paulo e os dois povos (Israel e Judá). Texto próprio do app; datas aproximadas.
class LineagesData {
  static LineagesData? _instance;
  final int version;
  final List<LineageChart> charts;
  LineagesData._(this.version, this.charts);

  LineageChart? byId(String id) {
    for (final c in charts) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Future<LineagesData> load() async =>
      _instance ??= parse(await rootBundle.loadString('assets/data/linhagens.json'));

  static List<String> _strings(dynamic v) => [for (final x in (v as List? ?? const [])) '$x'];
  static Color _color(String hex) => Color(int.parse(hex, radix: 16));
  static String? _opt(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

  static LineagesData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final charts = <LineageChart>[];
    for (final q in j['quadros'] as List) {
      final color = _color(q['cor'] as String);
      charts.add(LineageChart(
        q['id'] as String,
        q['titulo'] as String,
        q['sub'] as String? ?? '',
        color,
        _opt(q['capa']),
        q['intro'] as String? ?? '',
        (q['largura'] as num).toDouble(),
        (q['altura'] as num).toDouble(),
        [
          for (final n in q['nos'] as List)
            LinNode(
              n['id'] as String,
              n['nome'] as String,
              n['tipo'] as String? ?? 'pessoa',
              (n['x'] as num).toDouble(),
              (n['y'] as num).toDouble(),
              (n['w'] as num).toDouble(),
              (n['h'] as num).toDouble(),
              n['sub'] as String? ?? '',
              n['texto'] as String? ?? '',
              _strings(n['refs']),
              _opt(n['arte']),
              _opt(n['retrato']),
              n['cor'] == null ? null : _color(n['cor'] as String),
              [
                for (final f in n['fatos'] as List? ?? const [])
                  ('${(f as List)[0]}', '${f[1]}'),
              ],
              n['link'] as String? ?? '',
            ),
        ],
        [
          for (final e in q['ligacoes'] as List? ?? const [])
            LinEdge(_strings(e['de']), e['para'] as String, e['estilo'] == 'tracejada', e['forma'] == 'h',
                (e['meio'] as num?)?.toDouble()),
        ],
        [for (final c in q['casais'] as List? ?? const []) _strings(c)],
        [
          for (final b in q['faixas'] as List? ?? const [])
            LinBand(
              Rect.fromLTWH((b['x'] as num).toDouble(), (b['y'] as num).toDouble(), (b['w'] as num).toDouble(),
                  (b['h'] as num).toDouble()),
              b['titulo'] as String? ?? '',
              b['sub'] as String? ?? '',
              b['cor'] == null ? color : _color(b['cor'] as String),
              b['base'] == true,
            ),
        ],
        [
          for (final s in q['passos'] as List? ?? const [])
            LinStep(_strings(s['nos']), s['titulo'] as String? ?? '', s['texto'] as String, s['ref'] as String? ?? '',
                _opt(s['arte'])),
        ],
      ));
    }
    return LineagesData._((j['versao'] as num?)?.toInt() ?? 0, charts);
  }
}
