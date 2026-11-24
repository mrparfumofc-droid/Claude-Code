import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible.dart' show normalizeForSearch;
import 'account_service.dart';
import 'ai_service.dart' show supabaseAnonKey, supabaseUrl;

class Hymn {
  final String hymnal;
  final int? number;
  final String title;
  final String author;
  final List<String> stanzas;
  final String _search;
  Hymn(this.hymnal, this.number, this.title, this.author, this.stanzas)
      : _search = normalizeForSearch('$title ${stanzas.join(' ')}');

  String get id => '$hymnal:${number ?? title}';

  factory Hymn.fromJson(String hymnal, Map<String, dynamic> j) => Hymn(
        hymnal,
        (j['numero'] as num?)?.toInt(),
        j['titulo'] as String? ?? '',
        j['autor'] as String? ?? '',
        [for (final s in (j['estrofes'] as List? ?? const [])) '$s'],
      );

  Map<String, dynamic> toJson() =>
      {'numero': number, 'titulo': title, 'autor': author, 'estrofes': stanzas};
}

class Hymnal {
  final String id; // 'pd:Cantor Cristão' ou id do hinário importado
  final String name;
  final bool own;
  final List<Hymn> hymns;
  const Hymnal(this.id, this.name, this.own, this.hymns);
}

/// Hinário: hinos de domínio público (Cantor Cristão e tradicionais, do
/// Wikisource) e hinários importados pelo usuário (guardados na conta dele).
class HymnService extends ChangeNotifier {
  final AccountService account;
  HymnService(this.account);

  static const _pdUrl = '$supabaseUrl/storage/v1/object/public/hinos/hinos.json';
  List<Hymnal> hymnals = const [];
  Set<String> favorites = {};
  bool loading = false;
  String? error;
  bool _loaded = false;

  Future<File> _cache(String name) async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'hinario'));
    if (!await d.exists()) await d.create(recursive: true);
    return File(p.join(d.path, name));
  }

  Future<void> init({bool force = false}) async {
    if (_loaded && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    favorites = (prefs.getStringList('hymn.favorites') ?? const []).toSet();
    final list = <Hymnal>[];
    // Domínio público.
    List? pd;
    final pdFile = await _cache('dominio-publico.json');
    try {
      final r = await http.get(Uri.parse(_pdUrl)).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        await pdFile.writeAsBytes(r.bodyBytes, flush: true);
        pd = jsonDecode(utf8.decode(r.bodyBytes)) as List;
      }
    } catch (_) {}
    if (pd == null && await pdFile.exists()) pd = jsonDecode(await pdFile.readAsString()) as List;
    if (pd != null) {
      final bySource = <String, List<Hymn>>{};
      for (final j in pd) {
        final m = (j as Map).cast<String, dynamic>();
        final src = m['fonte'] as String? ?? 'Hinos';
        (bySource[src] ??= []).add(Hymn.fromJson('pd:$src', m));
      }
      for (final e in bySource.entries) {
        list.add(Hymnal('pd:${e.key}', e.key, false, e.value));
      }
    } else {
      error = 'Sem internet para baixar o hinário pela primeira vez.';
    }
    // Importados pelo usuário (nuvem; sem internet, a cópia local).
    list.addAll(await _loadOwn());
    hymnals = list;
    _loaded = true;
    loading = false;
    notifyListeners();
  }

  Future<List<Hymnal>> _loadOwn() async {
    final local = await _cache('meus-hinarios.json');
    List? rows;
    if (account.signedIn) {
      try {
        final r = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/user_hymnals?select=id,name,hymns&order=created_at'),
          headers: {'apikey': supabaseAnonKey, 'Authorization': 'Bearer ${await account.accessToken()}'},
        ).timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) {
          rows = jsonDecode(utf8.decode(r.bodyBytes)) as List;
          await local.writeAsString(jsonEncode(rows));
        }
      } catch (_) {}
    }
    if (rows == null && await local.exists()) {
      try {
        rows = jsonDecode(await local.readAsString()) as List;
      } catch (_) {}
    }
    return [
      for (final r in rows ?? const [])
        Hymnal(
          r['id'] as String,
          r['name'] as String,
          true,
          [for (final h in (r['hymns'] as List)) Hymn.fromJson(r['id'] as String, (h as Map).cast())],
        ),
    ];
  }

  /// Salva um hinário importado (na conta, se estiver conectado; senão só no tablet).
  Future<void> saveOwn(String name, List<Hymn> hymns) async {
    final data = [for (final h in hymns) h.toJson()];
    if (account.signedIn) {
      final r = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/user_hymnals'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${await account.accessToken()}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({'name': name, 'hymns': data}),
      );
      if (r.statusCode >= 300) throw 'Não consegui salvar na nuvem (${r.statusCode}).';
    } else {
      final local = await _cache('meus-hinarios.json');
      final rows = await local.exists() ? jsonDecode(await local.readAsString()) as List : [];
      rows.add({'id': 'local-${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'hymns': data});
      await local.writeAsString(jsonEncode(rows));
    }
    await init(force: true);
  }

  Future<void> deleteOwn(Hymnal h) async {
    if (!h.id.startsWith('local-') && account.signedIn) {
      await http.delete(
        Uri.parse('$supabaseUrl/rest/v1/user_hymnals?id=eq.${h.id}'),
        headers: {'apikey': supabaseAnonKey, 'Authorization': 'Bearer ${await account.accessToken()}'},
      );
    }
    final local = await _cache('meus-hinarios.json');
    if (await local.exists()) {
      final rows = (jsonDecode(await local.readAsString()) as List).where((r) => r['id'] != h.id).toList();
      await local.writeAsString(jsonEncode(rows));
    }
    await init(force: true);
  }

  List<Hymn> search(String? hymnalId, String query) {
    final pool = [
      for (final h in hymnals)
        if (hymnalId == null || h.id == hymnalId) ...h.hymns
    ];
    final q = query.trim();
    if (q.isEmpty) return pool;
    final n = int.tryParse(q);
    if (n != null) return pool.where((h) => h.number == n).toList();
    final k = normalizeForSearch(q);
    final title = pool.where((h) => normalizeForSearch(h.title).contains(k)).toList();
    final body = pool.where((h) => !title.contains(h) && h._search.contains(k)).toList();
    return [...title, ...body];
  }

  Future<void> toggleFavorite(Hymn h) async {
    if (!favorites.remove(h.id)) favorites.add(h.id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hymn.favorites', favorites.toList());
  }
}

/// Separa um texto (de PDF ou TXT) em hinos: cada hino começa com uma linha
/// "123 - Título", "123. Título" ou "123 Título"; as estrofes são separadas por
/// linha em branco (ou de 4 em 4 linhas, se o texto não tiver linhas em branco).
List<Hymn> parseHymnText(String hymnalId, String text) {
  final head = RegExp(r'^\s*(\d{1,4})\s*[-–.)º°:]?\s+(\S.{0,90})$');
  final lines = text.replaceAll('\r', '').split('\n');
  final hymns = <Hymn>[];
  int? num;
  String? title;
  var body = <String>[];
  var last = 0;

  void flush() {
    if (num == null || title == null) return;
    final raw = body.join('\n').trim();
    if (raw.isEmpty) return;
    var stanzas = raw.split(RegExp(r'\n\s*\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (stanzas.length == 1) {
      final ls = stanzas.first.split('\n');
      if (ls.length > 8) {
        stanzas = [for (var i = 0; i < ls.length; i += 4) ls.sublist(i, i + 4 > ls.length ? ls.length : i + 4).join('\n')];
      }
    }
    hymns.add(Hymn(hymnalId, num, title.trim(), '', stanzas));
  }

  for (final l in lines) {
    final m = head.firstMatch(l);
    final n = m == null ? null : int.parse(m.group(1)!);
    // Novo hino quando o número segue a sequência (evita confundir com versos numerados).
    if (m != null && n! > last && n <= last + 5) {
      flush();
      num = n;
      last = n;
      title = m.group(2);
      body = [];
    } else if (num != null) {
      body.add(l.trimRight());
    }
  }
  flush();
  return hymns;
}
