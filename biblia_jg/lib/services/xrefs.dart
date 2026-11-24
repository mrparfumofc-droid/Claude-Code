import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/reference_parser.dart';

/// Referências cruzadas do OpenBible.info (CC-BY), carregadas sob demanda.
class CrossReferences {
  static Map<String, String>? _data;

  static Future<Map<String, String>> _load() async {
    if (_data != null) return _data!;
    final raw = await rootBundle.loadString('assets/data/xrefs.json');
    _data = await compute(_decode, raw);
    return _data!;
  }

  static Map<String, String> _decode(String raw) =>
      (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();

  /// Referências do versículo (livro 0..65, capítulo e versículo começando em 1).
  static Future<List<Passage>> forVerse(int book, int chapter, int verse) async {
    final data = await _load();
    final s = data['$book:$chapter:$verse'];
    if (s == null || s.isEmpty) return const [];
    return s.split(';').map((t) {
      final dash = t.split('-');
      final p = dash[0].split(':').map(int.parse).toList();
      return Passage(p[0], p[1], p[2], dash.length > 1 ? int.parse(dash[1]) : null);
    }).toList();
  }

  static const attribution = 'Referências cruzadas: OpenBible.info (CC-BY)';
}
