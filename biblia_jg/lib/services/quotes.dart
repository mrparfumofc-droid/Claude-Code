import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma frase de um autor cristão (ou uma frase que o próprio usuário guardou).
class Quote {
  final String text;
  final String author;

  /// Anos de vida ("1483–1546") ou o ano do documento.
  final String life;

  /// Id do grupo (tradição); "minhas" para as frases do usuário.
  final String group;

  /// Obra ou ocasião.
  final String source;

  /// A tradição atribui ao autor, sem fonte escrita segura.
  final bool attributed;

  const Quote(this.text, this.author, {this.life = '', this.group = mineGroup, this.source = '', this.attributed = false});

  static const mineGroup = 'minhas';
  bool get mine => group == mineGroup;

  /// Identificador estável (não muda entre aparelhos nem entre versões do app).
  String get id {
    var h = 0x811c9dc5;
    for (final c in '$author|$text'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  /// "Martinho Lutero (1483–1546)".
  String get byline => life.isEmpty ? author : '$author ($life)';

  /// "95 Teses (1517), tese 1" ou "atribuída".
  String get note => [if (source.isNotEmpty) source, if (attributed) 'atribuída'].join(' · ');

  /// Texto pronto para copiar ou compartilhar.
  String get shareText => '“$text”\n— $author${source.isEmpty ? '' : ', $source'}';

  Map<String, dynamic> toJson() => {'t': text, 'a': author, if (source.isNotEmpty) 'f': source};

  static Quote? fromJson(dynamic j, {String group = mineGroup}) {
    if (j is! Map) return null;
    final t = '${j['t'] ?? ''}'.trim(), a = '${j['a'] ?? ''}'.trim();
    if (t.isEmpty) return null;
    return Quote(t, a.isEmpty ? 'Autor desconhecido' : a,
        life: '${j['v'] ?? ''}', group: '${j['g'] ?? group}', source: '${j['f'] ?? ''}', attributed: j['x'] == 1 || j['x'] == true);
  }
}

/// Frases que vêm com o app (assets/data/frases.json, gerado por tool/frases/build_frases.py):
/// autores em domínio público, com tradução própria.
class QuotesData {
  static QuotesData? _instance;

  /// (id, nome) de cada tradição, na ordem de exibição.
  final List<(String, String)> groups;
  final List<Quote> quotes;
  const QuotesData(this.groups, this.quotes);

  String groupName(String id) {
    for (final g in groups) {
      if (g.$1 == id) return g.$2;
    }
    return id == Quote.mineGroup ? 'Minhas frases' : id;
  }

  static QuotesData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return QuotesData(
      [for (final g in j['grupos'] as List) ('${g['id']}', '${g['nome']}')],
      [for (final q in j['frases'] as List) ?Quote.fromJson(q)],
    );
  }

  static Future<QuotesData> load() async =>
      _instance ??= parse(await rootBundle.loadString('assets/data/frases.json'));

  /// Frase do dia: muda a cada dia e passa por todas as tradições antes de repetir.
  Quote ofDay(DateTime day) {
    final n = quotes.length;
    var step = 37;
    while (_gcd(step, n) != 1) {
      step++;
    }
    final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026, 1, 1)).inDays;
    return quotes[(days * step) % n];
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}

/// O que é do usuário: favoritas e frases próprias (entram na cópia da conta).
class MyQuotes {
  static const favKey = 'frases.fav';
  static const mineKey = 'frases.minhas';

  static Set<String> favorites(SharedPreferences p) => (p.getStringList(favKey) ?? const []).toSet();

  static Future<Set<String>> toggleFavorite(SharedPreferences p, String id) async {
    final set = favorites(p);
    if (!set.remove(id)) set.add(id);
    await p.setStringList(favKey, set.toList());
    return set;
  }

  /// Cada item da lista é uma frase em JSON (assim a sincronização junta as listas sem perder nada).
  static List<Quote> mine(SharedPreferences p) {
    final out = <Quote>[];
    for (final raw in p.getStringList(mineKey) ?? const <String>[]) {
      try {
        final q = Quote.fromJson(jsonDecode(raw));
        if (q != null) out.add(q);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> save(SharedPreferences p, List<Quote> quotes) =>
      p.setStringList(mineKey, [for (final q in quotes) jsonEncode(q.toJson())]);
}
