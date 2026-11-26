import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'account_service.dart';
import 'ai_service.dart' show supabaseAnonKey, supabaseUrl;
import 'notebook_models.dart';

/// Onde os cadernos ficam guardados (pasta do app no aparelho; memória na prévia web e nos testes).
abstract class NbDisk {
  Future<String?> read(String rel);
  Future<void> write(String rel, String text);
  Future<Uint8List?> readBytes(String rel);
  Future<void> writeBytes(String rel, Uint8List bytes);
  Future<void> delete(String rel);
  Future<void> deleteDir(String rel);
}

class NbMemoryDisk implements NbDisk {
  final files = <String, Uint8List>{};

  @override
  Future<String?> read(String rel) async => files[rel] == null ? null : utf8.decode(files[rel]!);
  @override
  Future<void> write(String rel, String text) async => files[rel] = Uint8List.fromList(utf8.encode(text));
  @override
  Future<Uint8List?> readBytes(String rel) async => files[rel];
  @override
  Future<void> writeBytes(String rel, Uint8List bytes) async => files[rel] = bytes;
  @override
  Future<void> delete(String rel) async => files.remove(rel);
  @override
  Future<void> deleteDir(String rel) async => files.removeWhere((k, _) => k.startsWith('$rel/'));
}

class _FileDisk implements NbDisk {
  final String root;
  _FileDisk(this.root);

  File _f(String rel) => File(p.joinAll([root, ...rel.split('/')]));

  @override
  Future<String?> read(String rel) async {
    final f = _f(rel);
    return await f.exists() ? await f.readAsString() : null;
  }

  @override
  Future<Uint8List?> readBytes(String rel) async {
    final f = _f(rel);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  /// Grava num arquivo temporário e troca: se o app fechar no meio, o arquivo antigo continua inteiro.
  Future<void> _atomic(String rel, Future<void> Function(File tmp) fill) async {
    final f = _f(rel);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await fill(tmp);
    await tmp.rename(f.path);
  }

  @override
  Future<void> write(String rel, String text) => _atomic(rel, (t) => t.writeAsString(text, flush: true));
  @override
  Future<void> writeBytes(String rel, Uint8List bytes) => _atomic(rel, (t) => t.writeAsBytes(bytes, flush: true));

  @override
  Future<void> delete(String rel) async {
    final f = _f(rel);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> deleteDir(String rel) async {
    final d = Directory(p.joinAll([root, ...rel.split('/')]));
    if (await d.exists()) await d.delete(recursive: true);
  }
}

int _now() => DateTime.now().millisecondsSinceEpoch;

/// Cadernos de anotação: guardados primeiro no aparelho e, com a conta Google, copiados para a nuvem
/// (tabelas `notebooks` e `notebook_pages`; imagens no bucket privado `livros`, pasta do usuário).
/// O que não conseguir subir fica numa fila e vai na próxima vez.
class NotebookStore extends ChangeNotifier {
  final AccountService? account;
  NbDisk? _disk;
  NotebookStore._(this.account, [this._disk]);

  static NotebookStore? _instance;
  static NotebookStore of(AccountService account) => _instance ??= NotebookStore._(account);

  /// Só na memória, sem nuvem (testes e prévia).
  factory NotebookStore.memory() => NotebookStore._(null, NbMemoryDisk());

  List<NbBook> books = [];
  bool loaded = false;
  bool syncing = false;
  DateTime? lastSync;
  String? syncError;

  final _pages = <String, NbPage>{};
  final _versions = <String, int>{}; // página no aparelho -> data da alteração
  final _pending = <String>{};
  final _stale = <String>{}; // páginas com cópia mais nova na nuvem
  Timer? _pushTimer;
  Future<void>? _flushing;

  bool get cloud => account?.signedIn ?? false;
  int get pendingCount => _pending.length;

  Future<NbDisk> _d() async {
    final d = _disk;
    if (d != null) return d;
    if (kIsWeb) return _disk = NbMemoryDisk();
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'cadernos'));
    await dir.create(recursive: true);
    return _disk = _FileDisk(dir.path);
  }

  Future<void> load() async {
    if (loaded) {
      unawaited(sync());
      return;
    }
    final d = await _d();
    try {
      final raw = await d.read('indice.json');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        books = [for (final b in j['books'] as List? ?? const []) NbBook.fromJson((b as Map).cast())];
        (j['v'] as Map? ?? const {}).forEach((k, v) => _versions['$k'] = (v as num).toInt());
        _pending.addAll([for (final x in j['pending'] as List? ?? const []) '$x']);
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
    unawaited(sync());
  }

  Future<void> _saveIndex() async {
    try {
      await (await _d()).write(
          'indice.json',
          jsonEncode({
            'books': [for (final b in books) b.toJson()],
            'v': _versions,
            'pending': _pending.toList(),
          }));
    } catch (_) {}
  }

  NbBook? byId(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<String> get folders => ({for (final b in books) if (b.folder.isNotEmpty) b.folder}.toList()..sort());

  // ---------------------------------------------------------------- cadernos

  Future<NbBook> create({
    required String title,
    required int coverColor,
    int coverStyle = 0,
    NbTemplate template = NbTemplate.ruled,
    NbPaper paper = NbPaper.white,
    String folder = '',
  }) async {
    final page = NbPage.empty(template, paper);
    final now = _now();
    final b = NbBook(
      id: nbUuid(),
      title: title.trim().isEmpty ? 'Caderno' : title.trim(),
      coverColor: coverColor,
      coverStyle: coverStyle,
      folder: folder.trim(),
      created: now,
      updated: now,
      pageIds: [page.id],
      template: template,
      paper: paper,
    );
    books = [b, ...books];
    await _writePage(b.id, page);
    _pending
      ..add('b:${b.id}')
      ..add('p:${b.id}/${page.id}');
    await _saveIndex();
    notifyListeners();
    _pushSoon();
    return b;
  }

  /// Guarda a capa, o título, a pasta e a ordem das páginas.
  Future<void> saveBook(NbBook b, {bool touch = true}) async {
    if (touch) b.updated = _now();
    _pending.add('b:${b.id}');
    await _saveIndex();
    notifyListeners();
    _pushSoon();
  }

  Future<void> deleteBook(NbBook b) async {
    books = [for (final x in books) if (x.id != b.id) x];
    _pages.removeWhere((k, _) => k.startsWith('${b.id}/'));
    _versions.removeWhere((k, _) => k.startsWith('${b.id}/'));
    _pending
      ..removeWhere((k) => k.substring(2).startsWith(b.id))
      ..add('d:${b.id}');
    try {
      await (await _d()).deleteDir(b.id);
    } catch (_) {}
    await _saveIndex();
    notifyListeners();
    _pushSoon();
  }

  Future<NbBook> duplicate(NbBook b) async {
    final now = _now();
    final copy = NbBook(
      id: nbUuid(),
      title: '${b.title} (cópia)',
      coverColor: b.coverColor,
      coverStyle: b.coverStyle,
      folder: b.folder,
      created: now,
      updated: now,
      pageIds: [],
      template: b.template,
      paper: b.paper,
    );
    final d = await _d();
    for (final id in b.pageIds) {
      final pg = (await page(b, id)).copy(id: nbShortId())..updated = now;
      for (final it in pg.items) {
        if (it is NbImage) {
          final bytes = await d.readBytes('${b.id}/${it.file}');
          if (bytes != null) {
            await d.writeBytes('${copy.id}/${it.file}', bytes);
            _pending.add('i:${copy.id}/${it.file}');
          }
        }
      }
      copy.pageIds.add(pg.id);
      await _writePage(copy.id, pg);
      _pending.add('p:${copy.id}/${pg.id}');
    }
    books = [copy, ...books];
    _pending.add('b:${copy.id}');
    await _saveIndex();
    notifyListeners();
    _pushSoon();
    return copy;
  }

  // ----------------------------------------------------------------- páginas

  Future<void> _writePage(String bookId, NbPage pg) async {
    final key = '$bookId/${pg.id}';
    _pages[key] = pg;
    _versions[key] = pg.updated;
    await (await _d()).write('$key.json', jsonEncode(pg.toJson()));
  }

  Future<NbPage?> _readPage(String bookId, String pageId) async {
    try {
      final raw = await (await _d()).read('$bookId/$pageId.json');
      if (raw == null) return null;
      return NbPage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Página do caderno: memória, aparelho ou nuvem (quando lá estiver mais nova).
  Future<NbPage> page(NbBook b, String pageId) async {
    final key = '${b.id}/$pageId';
    final stale = _stale.contains(key);
    if (!stale) {
      final hit = _pages[key];
      if (hit != null) return hit;
    }
    NbPage? pg;
    if (stale && cloud) {
      pg = await _fetchPage(b.id, pageId);
      if (pg != null) {
        _stale.remove(key);
        await _writePage(b.id, pg);
        unawaited(_saveIndex());
      }
    }
    pg ??= await _readPage(b.id, pageId);
    if (pg == null && cloud) {
      pg = await _fetchPage(b.id, pageId);
      if (pg != null) await _writePage(b.id, pg);
    }
    pg ??= NbPage(pageId, b.template, b.paper, [], 0);
    _pages[key] = pg;
    return pg;
  }

  /// Salva a página no aparelho na hora e agenda a cópia na nuvem.
  Future<void> savePage(NbBook b, NbPage pg) async {
    pg.updated = _now();
    b.updated = pg.updated;
    try {
      await _writePage(b.id, pg);
    } catch (_) {}
    _pending
      ..add('p:${b.id}/${pg.id}')
      ..add('b:${b.id}');
    await _saveIndex();
    _pushSoon();
  }

  /// Nova página depois da posição [after] (-1 = no começo); [copyOf] duplica uma página.
  Future<NbPage> addPage(NbBook b, {required int after, NbTemplate? template, NbPaper? paper, NbPage? copyOf}) async {
    final pg = copyOf != null ? copyOf.copy(id: nbShortId()) : NbPage.empty(template ?? b.template, paper ?? b.paper);
    pg.updated = _now();
    b.pageIds.insert((after + 1).clamp(0, b.pageIds.length), pg.id);
    await _writePage(b.id, pg);
    _pending.add('p:${b.id}/${pg.id}');
    await saveBook(b);
    return pg;
  }

  Future<void> removePage(NbBook b, String pageId) async {
    if (b.pageIds.length <= 1) return;
    b.pageIds.remove(pageId);
    final key = '${b.id}/$pageId';
    _pages.remove(key);
    _versions.remove(key);
    _pending
      ..remove('p:$key')
      ..add('x:$key');
    try {
      await (await _d()).delete('$key.json');
    } catch (_) {}
    await saveBook(b);
  }

  // ----------------------------------------------------------------- imagens

  /// Guarda uma imagem do caderno e devolve o nome do arquivo.
  Future<String> addImage(NbBook b, Uint8List bytes, String ext) async {
    final clean = ext.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final file = 'img-${nbShortId()}.${clean.isEmpty ? 'png' : clean}';
    await (await _d()).writeBytes('${b.id}/$file', bytes);
    _pending.add('i:${b.id}/$file');
    unawaited(_saveIndex());
    _pushSoon();
    return file;
  }

  Future<Uint8List?> imageBytes(String bookId, String file) async {
    final d = await _d();
    try {
      final local = await d.readBytes('$bookId/$file');
      if (local != null && local.isNotEmpty) return local;
    } catch (_) {}
    if (!cloud) return null;
    try {
      final res = await http
          .get(Uri.parse('$supabaseUrl/storage/v1/object/authenticated/livros/${_imagePath(bookId, file)}'),
              headers: await _headers(json: false))
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await d.writeBytes('$bookId/$file', res.bodyBytes);
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------- nuvem

  Future<Map<String, String>> _headers({bool json = true}) async => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer ${await account!.accessToken()}',
        if (json) 'Content-Type': 'application/json',
      };

  Uri _rest(String path) => Uri.parse('$supabaseUrl/rest/v1/$path');
  String _imagePath(String bookId, String file) => '${account!.userId}/cadernos/$bookId/$file';
  static String _iso() => DateTime.now().toUtc().toIso8601String();

  Future<bool> _upsert(String table, String conflict, Map<String, dynamic> row) async {
    final res = await http
        .post(_rest('$table?on_conflict=$conflict'),
            headers: {...await _headers(), 'Prefer': 'resolution=merge-duplicates,return=minimal'}, body: jsonEncode(row))
        .timeout(const Duration(seconds: 25));
    return res.statusCode < 300;
  }

  Future<NbPage?> _fetchPage(String bookId, String pageId) async {
    try {
      final res = await http
          .get(_rest('notebook_pages?notebook_id=eq.$bookId&page_id=eq.$pageId&select=data'), headers: await _headers())
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      if (rows.isEmpty) return null;
      return NbPage.fromJson(((rows.first as Map)['data'] as Map).cast());
    } catch (_) {
      return null;
    }
  }

  void _pushSoon() {
    if (!cloud) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 6), () => unawaited(flush()));
  }

  /// Envia o que está na fila (cadernos antes das páginas). O que falhar continua na fila.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final f = _flush().whenComplete(() => _flushing = null);
    _flushing = f;
    return f;
  }

  Future<void> _flush() async {
    if (!cloud || _pending.isEmpty) return;
    const order = 'bipxd';
    final queue = _pending.toList()..sort((a, b) => order.indexOf(a[0]).compareTo(order.indexOf(b[0])));
    final d = await _d();
    var changed = false;
    for (final item in queue) {
      final kind = item[0], key = item.substring(2);
      var ok = false;
      try {
        switch (kind) {
          case 'b':
            final b = byId(key);
            ok = b == null || await _upsert('notebooks', 'id', {'id': b.id, 'meta': b.toJson(), 'deleted': false, 'updated_at': _iso()});
          case 'i':
            final slash = key.indexOf('/');
            final bytes = await d.readBytes(key);
            if (bytes == null) {
              ok = true;
            } else {
              final res = await http
                  .post(
                      Uri.parse(
                          '$supabaseUrl/storage/v1/object/livros/${_imagePath(key.substring(0, slash), key.substring(slash + 1))}'),
                      headers: {...await _headers(json: false), 'Content-Type': 'application/octet-stream', 'x-upsert': 'true'},
                      body: bytes)
                  .timeout(const Duration(minutes: 2));
              ok = res.statusCode < 300 || res.statusCode == 409;
            }
          case 'p':
            final slash = key.indexOf('/');
            final bookId = key.substring(0, slash), pageId = key.substring(slash + 1);
            final pg = _pages[key] ?? await _readPage(bookId, pageId);
            ok = pg == null ||
                await _upsert('notebook_pages', 'notebook_id,page_id',
                    {'notebook_id': bookId, 'page_id': pageId, 'data': pg.toJson(), 'updated_at': _iso()});
          case 'x':
            final slash = key.indexOf('/');
            final res = await http
                .delete(_rest('notebook_pages?notebook_id=eq.${key.substring(0, slash)}&page_id=eq.${key.substring(slash + 1)}'),
                    headers: await _headers())
                .timeout(const Duration(seconds: 25));
            ok = res.statusCode < 300;
          case 'd':
            ok = await _upsert('notebooks', 'id', {'id': key, 'meta': <String, dynamic>{}, 'deleted': true, 'updated_at': _iso()});
          default:
            ok = true;
        }
      } catch (_) {
        ok = false;
      }
      if (ok) {
        _pending.remove(item);
        changed = true;
      } else if (kind == 'b') {
        break; // sem o caderno na nuvem as páginas dele não entram; tenta tudo de novo depois
      }
    }
    if (changed) {
      await _saveIndex();
      notifyListeners();
    }
  }

  /// Junta este aparelho com a nuvem: envia a fila, traz cadernos novos e marca as páginas
  /// que estão mais novas lá (são baixadas quando abertas).
  Future<void> sync() async {
    if (!cloud || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await flush();
      final res = await http.get(_rest('notebooks?select=id,meta,deleted'), headers: await _headers()).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) throw 'erro ${res.statusCode}';
      final remoteIds = <String>{};
      for (final raw in jsonDecode(utf8.decode(res.bodyBytes)) as List) {
        final r = (raw as Map).cast<String, dynamic>();
        final id = r['id'] as String;
        remoteIds.add(id);
        final local = byId(id);
        if (r['deleted'] == true) {
          if (local != null && !_pending.contains('b:$id')) {
            books = [for (final x in books) if (x.id != id) x];
            _pages.removeWhere((k, _) => k.startsWith('$id/'));
            _versions.removeWhere((k, _) => k.startsWith('$id/'));
            try {
              await (await _d()).deleteDir(id);
            } catch (_) {}
          }
          continue;
        }
        final meta = (r['meta'] as Map?)?.cast<String, dynamic>();
        if (meta == null || meta['id'] == null) continue;
        final remote = NbBook.fromJson(meta);
        if (local == null) {
          if (!_pending.contains('d:$id')) books = [...books, remote];
        } else if (remote.updated > local.updated && !_pending.contains('b:$id')) {
          books = [for (final x in books) x.id == id ? remote : x];
        }
      }
      final pr = await http
          .get(_rest('notebook_pages?select=notebook_id,page_id,u:data->>u'), headers: await _headers())
          .timeout(const Duration(seconds: 25));
      if (pr.statusCode == 200) {
        for (final raw in jsonDecode(utf8.decode(pr.bodyBytes)) as List) {
          final r = raw as Map;
          final key = '${r['notebook_id']}/${r['page_id']}';
          if (_pending.contains('p:$key')) continue;
          final remoteU = int.tryParse('${r['u']}') ?? 0;
          if (remoteU > (_versions[key] ?? -1)) _stale.add(key);
        }
      }
      // Cadernos feitos aqui antes de entrar na conta: sobem inteiros.
      for (final b in books) {
        if (remoteIds.contains(b.id)) continue;
        _pending.add('b:${b.id}');
        for (final id in b.pageIds) {
          _pending.add('p:${b.id}/$id');
        }
      }
      await _saveIndex();
      await flush();
      lastSync = DateTime.now();
    } catch (e) {
      syncError = e is SocketException || e is TimeoutException ? 'Sem internet: os cadernos ficam guardados neste tablet.' : 'Não consegui sincronizar agora.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
