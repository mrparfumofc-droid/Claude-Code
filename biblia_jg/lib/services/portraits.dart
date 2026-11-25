import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'stories.dart' show StoryMedia;

/// Retratos dos personagens (recortes das ilustrações das Histórias bíblicas), guardados na nuvem
/// em `retratos/<id>.jpg`. O índice diz quais nomes têm retrato; retratos novos chegam sem
/// precisar atualizar o app.
class Portraits {
  final int version;
  final Map<String, String> _byName; // nome em minúsculas e sem acento -> id do retrato
  Portraits._(this.version, this._byName);

  static Portraits? _instance;
  static Future<Portraits>? _loading;

  /// Soma 1 quando chega da nuvem um índice mais novo.
  static final revision = ValueNotifier<int>(0);

  static const _from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  static const _to = 'aaaaaeeeeiiiiooooouuuuc';

  /// "  Abraão " -> "abraao".
  static String normalize(String s) {
    final b = StringBuffer();
    for (final r in s.trim().toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final i = _from.indexOf(c);
      b.write(i < 0 ? c : _to[i]);
    }
    return b.toString();
  }

  static Portraits parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final byName = <String, String>{};
    (j['retratos'] as Map<String, dynamic>? ?? const {}).forEach((id, names) {
      for (final n in names as List) {
        byName[normalize('$n')] = id;
      }
    });
    return Portraits._((j['versao'] as num?)?.toInt() ?? 0, byName);
  }

  /// Id do retrato de um nome ("Abraão" -> "abraao"), ou null se não há retrato.
  /// Só vale o nome exato: "Jacó (Judá)" (a nação) não é o patriarca "Jacó".
  String? idFor(String name) => _byName[normalize(name)];

  /// Quantos retratos existem.
  int get count => _byName.values.toSet().length;

  static String path(String id) => 'retratos/$id.jpg';

  static Future<Portraits> load() => _loading ??= _load();

  static Future<Portraits> _load() async {
    var data = Portraits._(0, const {});
    try {
      data = parse(await rootBundle.loadString('assets/data/retratos.json'));
    } catch (_) {}
    if (!kIsWeb) {
      try {
        final f = File('${(await StoryMedia.dir()).path}/retratos.json');
        if (await f.exists()) {
          final cached = parse(await f.readAsString());
          if (cached.version > data.version) data = cached;
        }
      } catch (_) {}
    }
    _instance = data;
    unawaited(_refresh());
    return data;
  }

  static Future<void> _refresh() async {
    try {
      final res = await http.get(Uri.parse(StoryMedia.url('retratos.json'))).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final raw = utf8.decode(res.bodyBytes);
      final fresh = parse(raw);
      if (fresh.version <= (_instance?.version ?? 0) || fresh._byName.isEmpty) return;
      if (!kIsWeb) await File('${(await StoryMedia.dir()).path}/retratos.json').writeAsString(raw);
      _instance = fresh;
      _loading = Future.value(fresh);
      revision.value++;
    } catch (_) {}
  }
}
