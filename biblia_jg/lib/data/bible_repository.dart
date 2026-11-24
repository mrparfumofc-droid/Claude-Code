import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/bible.dart';

class VersionInfo {
  final String id;
  final String name;
  final String abbrev;
  final String source; // caminho do asset ou do arquivo
  final bool builtIn;
  const VersionInfo(this.id, this.name, this.abbrev, this.source, this.builtIn);
}

Bible _parseIsolate(List<String> args) =>
    Bible.parse(args[0], fallbackId: args[1], fallbackName: args[1].toUpperCase());

/// Carrega as versões da Bíblia que vêm dentro do app (assets/bibles/*.json)
/// e as que o usuário importou (pasta do app/bibles/*.json).
class BibleRepository {
  static const _indexAsset = 'assets/bibles/index.json';
  final Map<String, Bible> _cache = {};
  List<VersionInfo>? _versions;

  Future<Directory> _importDir() async {
    final d = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'bibles'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<VersionInfo>> versions({bool refresh = false}) async {
    if (_versions != null && !refresh) return _versions!;
    final out = <VersionInfo>[];
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    if (assets.contains(_indexAsset)) {
      // Índice gerado por tool/fetch_bibles.py: evita abrir todas as versões na inicialização.
      final index = jsonDecode(await rootBundle.loadString(_indexAsset)) as List;
      for (final e in index.cast<Map<String, dynamic>>()) {
        out.add(VersionInfo(e['id'] as String, e['name'] as String,
            e['abbrev'] as String, e['asset'] as String, true));
      }
    } else {
      final files = assets
          .where((a) => a.startsWith('assets/bibles/') && a.endsWith('.json'))
          .toList()
        ..sort();
      for (final a in files) {
        final b = await _load(a, builtIn: true);
        out.add(VersionInfo(b.id, b.name, b.abbrev, a, true));
      }
    }
    try {
      final dir = await _importDir();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (final f in files) {
        try {
          final b = await _load(f.path, builtIn: false);
          out.removeWhere((v) => v.id == b.id);
          out.add(VersionInfo(b.id, b.name, b.abbrev, f.path, false));
        } catch (e) {
          debugPrint('Versão inválida ignorada: ${f.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('Não foi possível ler as versões importadas: $e');
    }
    return _versions = out;
  }

  Future<Bible> _load(String source, {required bool builtIn}) async {
    final cached = _cache[source];
    if (cached != null) return cached;
    final text = builtIn
        ? await rootBundle.loadString(source, cache: false) // não segura vários MB na memória
        : await File(source).readAsString();
    final id = p.basenameWithoutExtension(source);
    final bible = await compute(_parseIsolate, [text, id]);
    // Guarda só a última versão aberta, para não ocupar memória com várias Bíblias.
    _cache
      ..clear()
      ..[source] = bible;
    return bible;
  }

  Future<Bible?> load(String versionId) async {
    final list = await versions();
    final v = list.where((v) => v.id == versionId).firstOrNull ?? list.firstOrNull;
    if (v == null) return null;
    return _load(v.source, builtIn: v.builtIn);
  }

  /// Valida e salva o conteúdo de um arquivo de versão na pasta do app.
  Future<VersionInfo> import(String text, String fileName) async {
    final id = p.basenameWithoutExtension(fileName).toLowerCase();
    final bible = await compute(_parseIsolate, [text, id]);
    if (bible.books.isEmpty) {
      throw const FormatException('A versão não tem livros.');
    }
    final dest = File(p.join((await _importDir()).path, '${bible.id}.json'));
    await dest.writeAsString(text);
    _cache.remove(dest.path);
    await versions(refresh: true);
    return VersionInfo(bible.id, bible.name, bible.abbrev, dest.path, false);
  }

  Future<void> remove(VersionInfo v) async {
    if (v.builtIn) return;
    final f = File(v.source);
    if (await f.exists()) await f.delete();
    _cache.remove(v.source);
    await versions(refresh: true);
  }
}
