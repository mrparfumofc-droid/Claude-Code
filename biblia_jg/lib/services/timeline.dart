import 'dart:convert';

import 'package:flutter/services.dart';

/// Um acontecimento datado dentro de uma época.
class TimeEvent {
  final String year; // "c. 2091 a.C.", "Domingo", "1517"
  final String title;
  final String text;
  final List<String> people;
  final List<String> refs;

  /// Chave da ilustração (null = usa a da época).
  final String? art;

  /// Livro do Novo Testamento (40..66) com guia de estudo, quando o acontecimento é uma carta.
  final int? book;

  /// História ilustrada que conta este trecho.
  final String? story;
  const TimeEvent(this.year, this.title, this.text, this.people, this.refs, this.art, this.book, this.story);
}

/// Uma época da linha do tempo, com os seus acontecimentos.
class TimeEra {
  final String id;
  final String group; // at, nt, igreja
  final String title;
  final String dates;
  final String icon;
  final Color color;
  final String art;
  final String text;
  final List<String> people;
  final List<String> refs;
  final String books;

  /// Quadro relacionado: arvore, tabernaculo, reis, historias, nt (ou vazio).
  final String link;
  final List<TimeEvent> events;
  const TimeEra(this.id, this.group, this.title, this.dates, this.icon, this.color, this.art, this.text, this.people,
      this.refs, this.books, this.link, this.events);
}

/// Linha do tempo da Bíblia e da igreja (texto próprio do app; datas aproximadas).
class TimelineData {
  static TimelineData? _instance;
  final int version;

  /// Grupos de épocas: (id, nome).
  final List<(String, String)> groups;
  final List<TimeEra> eras;
  TimelineData._(this.version, this.groups, this.eras);

  int get eventCount => eras.fold(0, (n, e) => n + e.events.length);

  static Future<TimelineData> load() async =>
      _instance ??= parse(await rootBundle.loadString('assets/data/linha_tempo.json'));

  static List<String> _strings(dynamic v) => [for (final x in (v as List? ?? const [])) '$x'];

  static TimelineData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final eras = <TimeEra>[
      for (final e in j['epocas'] as List)
        TimeEra(
          e['id'] as String,
          e['grupo'] as String,
          e['titulo'] as String,
          e['datas'] as String,
          e['icone'] as String? ?? '',
          Color(0xFF000000 | int.parse(e['cor'] as String, radix: 16)),
          e['arte'] as String,
          e['texto'] as String,
          _strings(e['pessoas']),
          _strings(e['refs']),
          e['livros'] as String? ?? '',
          e['link'] as String? ?? '',
          [
            for (final v in e['eventos'] as List)
              TimeEvent(
                v['ano'] as String,
                v['titulo'] as String,
                v['texto'] as String,
                _strings(v['pessoas']),
                _strings(v['refs']),
                v['arte'] as String?,
                (v['livro'] as num?)?.toInt(),
                v['historia'] as String?,
              ),
          ],
        ),
    ];
    return TimelineData._(
      (j['versao'] as num?)?.toInt() ?? 0,
      [for (final g in j['grupos'] as List) (g['id'] as String, g['nome'] as String)],
      eras,
    );
  }
}
