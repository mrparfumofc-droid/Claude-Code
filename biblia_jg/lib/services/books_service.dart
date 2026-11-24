import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'account_service.dart';
import 'ai_service.dart' show supabaseAnonKey, supabaseUrl;

/// Lição marcada numa revista da EBD.
class Lesson {
  final int page;
  final String title;
  const Lesson(this.page, this.title);
  factory Lesson.fromJson(Map<String, dynamic> j) =>
      Lesson((j['page'] as num).toInt(), j['title'] as String? ?? 'Lição');
  Map<String, dynamic> toJson() => {'page': page, 'title': title};
}

/// Livro ou revista (PDF guardado na nuvem, na conta do usuário).
class Book {
  final String id;
  final String kind; // 'livro' ou 'ebd'
  String title;
  String? folder;
  int? year;
  int? quarter;
  final String filePath;
  final int? bytes;
  int? pages;
  int lastPage;
  List<Lesson> lessons;

  Book({
    required this.id,
    required this.kind,
    required this.title,
    required this.filePath,
    this.folder,
    this.year,
    this.quarter,
    this.bytes,
    this.pages,
    this.lastPage = 1,
    this.lessons = const [],
  });

  bool get isEbd => kind == 'ebd';

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        folder: j['folder'] as String?,
        year: (j['year'] as num?)?.toInt(),
        quarter: (j['quarter'] as num?)?.toInt(),
        filePath: j['file_path'] as String,
        bytes: (j['bytes'] as num?)?.toInt(),
        pages: (j['pages'] as num?)?.toInt(),
        lastPage: (j['last_page'] as num?)?.toInt() ?? 1,
        lessons: [
          for (final l in (j['lessons'] as List? ?? const [])) Lesson.fromJson((l as Map).cast())
        ]..sort((a, b) => a.page.compareTo(b.page)),
      );
}

enum InkTool { pen, marker }

/// Traço feito à mão. Coordenadas e espessura relativas à página (0..1).
class Stroke {
  final InkTool tool;
  final Color color;
  final double width;
  final List<Offset> points;
  Stroke(this.tool, this.color, this.width, [List<Offset>? points]) : points = points ?? [];

  factory Stroke.fromJson(Map<String, dynamic> j) {
    final raw = (j['p'] as List).cast<num>();
    return Stroke(
      j['t'] == 'm' ? InkTool.marker : InkTool.pen,
      Color((j['c'] as num).toInt()),
      (j['w'] as num).toDouble(),
      [for (var i = 0; i + 1 < raw.length; i += 2) Offset(raw[i].toDouble(), raw[i + 1].toDouble())],
    );
  }

  Map<String, dynamic> toJson() => {
        't': tool == InkTool.marker ? 'm' : 'p',
        'c': color.toARGB32(),
        'w': double.parse(width.toStringAsFixed(5)),
        'p': [
          for (final o in points) ...[
            double.parse(o.dx.toStringAsFixed(4)),
            double.parse(o.dy.toStringAsFixed(4)),
          ]
        ],
      };
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Livros (PDF) e revistas da EBD na nuvem do usuário (bucket privado "livros").
/// O PDF fica numa cópia temporária no cache do app só para abrir rápido.
class BooksService extends ChangeNotifier {
  final AccountService account;
  BooksService(this.account);

  List<Book> books = const [];
  bool loading = false;
  String? error;

  Future<Map<String, String>> _headers({bool json = true}) async => {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer ${await account.accessToken()}',
        if (json) 'Content-Type': 'application/json',
      };

  Uri _rest(String path) => Uri.parse('$supabaseUrl/rest/v1/$path');

  static List<Book> _parseList(String body) =>
      [for (final j in jsonDecode(body) as List) Book.fromJson((j as Map).cast())];

  Future<File> _listFile() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'livros-${account.userId}.json'));

  Future<void> refresh() async {
    if (!account.signedIn) {
      books = const [];
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await http
          .get(_rest('books?select=*&order=year.desc.nullslast,quarter.desc.nullslast,title'),
              headers: await _headers())
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw 'erro ${res.statusCode}';
      final body = utf8.decode(res.bodyBytes);
      books = _parseList(body);
      try {
        await (await _listFile()).writeAsString(body);
      } catch (_) {}
    } catch (e) {
      // Sem internet: usa a lista guardada (os PDFs já baixados abrem normalmente).
      List<Book>? cached;
      try {
        final f = await _listFile();
        if (await f.exists()) cached = _parseList(await f.readAsString());
      } catch (_) {}
      if (cached != null) {
        books = cached;
        error = 'Sem internet: mostrando os livros já carregados neste tablet.';
      } else {
        error = e is SocketException || e is TimeoutException
            ? 'Sem internet para carregar seus livros.'
            : 'Não consegui carregar seus livros: $e';
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Envia um PDF para a nuvem e cria o livro/revista.
  Future<Book> add({
    required Uint8List bytes,
    required String title,
    required String kind,
    String? folder,
    int? year,
    int? quarter,
  }) async {
    final id = _uuid();
    final path = '${account.userId}/$id.pdf';
    final up = await http
        .post(Uri.parse('$supabaseUrl/storage/v1/object/livros/$path'),
            headers: {...await _headers(json: false), 'Content-Type': 'application/pdf'}, body: bytes)
        .timeout(const Duration(minutes: 5));
    if (up.statusCode >= 300) {
      throw up.statusCode == 413
          ? 'O PDF passa de 50 MB, o limite da nuvem grátis.'
          : 'Não consegui enviar o PDF (${up.statusCode}).';
    }
    final res = await http.post(_rest('books'),
        headers: {...await _headers(), 'Prefer': 'return=representation'},
        body: jsonEncode({
          'id': id,
          'kind': kind,
          'title': title,
          'folder': folder,
          'year': year,
          'quarter': quarter,
          'file_path': path,
          'bytes': bytes.length,
        }));
    if (res.statusCode >= 300) throw 'Não consegui salvar o livro (${res.statusCode}).';
    final book = Book.fromJson(((jsonDecode(utf8.decode(res.bodyBytes)) as List).first as Map).cast());
    final local = await _localFile(book);
    await local.writeAsBytes(bytes, flush: true);
    books = [...books, book];
    notifyListeners();
    return book;
  }

  Future<void> update(Book b, Map<String, dynamic> fields) async {
    final res = await http.patch(_rest('books?id=eq.${b.id}'),
        headers: await _headers(), body: jsonEncode({...fields, 'updated_at': DateTime.now().toUtc().toIso8601String()}));
    if (res.statusCode >= 300) throw 'Não consegui salvar (${res.statusCode}).';
    notifyListeners();
  }

  Future<void> saveLessons(Book b) =>
      update(b, {'lessons': b.lessons.map((l) => l.toJson()).toList()});

  Future<void> remove(Book b) async {
    await http.delete(Uri.parse('$supabaseUrl/storage/v1/object/livros/${b.filePath}'),
        headers: await _headers(json: false));
    final res = await http.delete(_rest('books?id=eq.${b.id}'), headers: await _headers());
    if (res.statusCode >= 300) throw 'Não consegui apagar (${res.statusCode}).';
    try {
      final f = await _localFile(b);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    books = books.where((x) => x.id != b.id).toList();
    notifyListeners();
  }

  Future<File> _localFile(Book b) async {
    final dir = Directory(p.join((await getApplicationCacheDirectory()).path, 'livros'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, '${b.id}.pdf'));
  }

  /// Caminho do PDF para abrir (baixa da nuvem se ainda não estiver no cache).
  Future<String> openPath(Book b, {void Function(double)? onProgress}) async {
    final f = await _localFile(b);
    if (await f.exists() && (b.bytes == null || await f.length() == b.bytes)) return f.path;
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse('$supabaseUrl/storage/v1/object/authenticated/livros/${b.filePath}'))
        ..headers.addAll(await _headers(json: false));
      final res = await client.send(req);
      if (res.statusCode != 200) throw 'Não consegui baixar o PDF (${res.statusCode}).';
      final total = res.contentLength ?? b.bytes ?? 0;
      final tmp = File('${f.path}.part');
      final sink = tmp.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call(got / total);
      }
      await sink.close();
      await tmp.rename(f.path);
      return f.path;
    } finally {
      client.close();
    }
  }

  // ---------- Anotações à mão ----------

  Future<Directory> _inkDir() async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'ink'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _inkFile(String bookId) async => File(p.join((await _inkDir()).path, '$bookId.json'));

  Future<File> _pendingFile(String bookId) async =>
      File(p.join((await _inkDir()).path, '$bookId.pendente.json'));

  /// Páginas riscadas neste aparelho que ainda não chegaram à nuvem.
  Future<Set<int>> _pending(String bookId) async {
    try {
      final f = await _pendingFile(bookId);
      if (await f.exists()) return {for (final n in jsonDecode(await f.readAsString()) as List) (n as num).toInt()};
    } catch (_) {}
    return {};
  }

  Future<void> _setPending(String bookId, Set<int> pages) async {
    try {
      await (await _pendingFile(bookId)).writeAsString(jsonEncode(pages.toList()));
    } catch (_) {}
  }

  static Map<int, List<Stroke>> _parseInk(Iterable<MapEntry<int, dynamic>> e) => {
        for (final x in e) x.key: [for (final s in (x.value as List)) Stroke.fromJson((s as Map).cast())]
      };

  /// Traços de todas as páginas. A nuvem vale, menos nas páginas riscadas aqui
  /// que ainda não foram enviadas (essas são mantidas e reenviadas).
  Future<Map<int, List<Stroke>>> loadInk(String bookId) async {
    var local = <int, List<Stroke>>{};
    try {
      final f = await _inkFile(bookId);
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        local = _parseInk(j.entries.map((e) => MapEntry(int.parse(e.key), e.value)));
      }
    } catch (_) {}
    final pending = await _pending(bookId);
    try {
      final res = await http
          .get(_rest('book_ink?book_id=eq.$bookId&select=page,strokes'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List;
        final merged = _parseInk(rows.map((r) => MapEntry((r['page'] as num).toInt(), r['strokes'])));
        for (final page in pending) {
          merged[page] = local[page] ?? [];
        }
        await _saveInkLocal(bookId, merged);
        for (final page in pending.toList()) {
          if (await _pushInkPage(bookId, page, merged[page] ?? const [])) pending.remove(page);
        }
        await _setPending(bookId, pending);
        return merged;
      }
    } catch (_) {}
    return local;
  }

  Future<void> _saveInkLocal(String bookId, Map<int, List<Stroke>> ink) async {
    final f = await _inkFile(bookId);
    await f.writeAsString(jsonEncode({
      for (final e in ink.entries) '${e.key}': e.value.map((s) => s.toJson()).toList(),
    }));
  }

  Future<bool> _pushInkPage(String bookId, int page, List<Stroke> strokes) async {
    try {
      final res = await http
          .post(_rest('book_ink?on_conflict=book_id,page'),
              headers: {...await _headers(), 'Prefer': 'resolution=merge-duplicates,return=minimal'},
              body: jsonEncode({
                'book_id': bookId,
                'page': page,
                'strokes': strokes.map((s) => s.toJson()).toList(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }))
          .timeout(const Duration(seconds: 20));
      return res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Salva os traços de uma página: no aparelho na hora e na nuvem em seguida.
  /// Se a nuvem falhar (sem internet), a página fica pendente e vai depois.
  Future<void> saveInkPage(String bookId, int page, Map<int, List<Stroke>> all) async {
    await _saveInkLocal(bookId, all);
    final ok = await _pushInkPage(bookId, page, all[page] ?? const []);
    final pending = await _pending(bookId);
    if (ok ? pending.remove(page) : pending.add(page)) await _setPending(bookId, pending);
  }
}
