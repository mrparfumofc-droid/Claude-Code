import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/bible.dart';

class Note {
  final int? id;
  final VerseRef ref;
  final String text;
  final DateTime created;
  final DateTime updated;
  Note({this.id, required this.ref, required this.text, required this.created, required this.updated});
}

class HistoryEntry {
  final int book;
  final int chapter;
  final DateTime at;
  HistoryEntry(this.book, this.chapter, this.at);
}

class Prayer {
  final int? id;
  final String text;
  final DateTime created;
  final DateTime? answered;
  final String? answer;
  Prayer({this.id, required this.text, required this.created, this.answered, this.answer});
}

class MemoryVerse {
  final VerseRef ref;
  final int level; // 0..5 (quanto maior, mais espaçada a revisão)
  final DateTime due;
  MemoryVerse(this.ref, this.level, this.due);
}

class Highlight {
  final VerseRef ref;
  final int color;
  final DateTime created;
  Highlight(this.ref, this.color, this.created);
}

/// Dados do usuário: marcações, favoritos, anotações, histórico e progresso.
/// As chaves de versículo independem da versão da Bíblia ("livro:cap:vers").
class UserDb {
  final Database db;
  UserDb._(this.db);

  static Future<UserDb> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'biblia_jg.db');
    final db = await f.openDatabase(dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: _create, onUpgrade: _upgrade));
    return UserDb._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute(
        'CREATE TABLE highlights (vkey TEXT PRIMARY KEY, color INTEGER NOT NULL, created INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE favorites (vkey TEXT PRIMARY KEY, created INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, vkey TEXT NOT NULL, text TEXT NOT NULL, created INTEGER NOT NULL, updated INTEGER NOT NULL)');
    await db.execute('CREATE INDEX notes_vkey ON notes(vkey)');
    await db.execute(
        'CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, book INTEGER NOT NULL, chapter INTEGER NOT NULL, at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE read_chapters (book INTEGER NOT NULL, chapter INTEGER NOT NULL, at INTEGER NOT NULL, PRIMARY KEY(book, chapter))');
    await _createV2(db);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) await _createV2(db);
  }

  /// Versão 2: constância (dias de leitura), diário de oração e memorização.
  static Future<void> _createV2(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS activity (day TEXT PRIMARY KEY, chapters INTEGER NOT NULL DEFAULT 0, seconds INTEGER NOT NULL DEFAULT 0)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS prayers (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, created INTEGER NOT NULL, answered INTEGER, answer TEXT)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS memory (vkey TEXT PRIMARY KEY, level INTEGER NOT NULL DEFAULT 0, due INTEGER NOT NULL, created INTEGER NOT NULL)');
  }

  // ---------- Constância (dias de leitura) ----------
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> addActivity({int chapters = 0, int seconds = 0}) async {
    final day = dayKey(DateTime.now());
    await db.execute('INSERT OR IGNORE INTO activity (day, chapters, seconds) VALUES (?, 0, 0)', [day]);
    await db.execute(
        'UPDATE activity SET chapters = MAX(0, chapters + ?), seconds = seconds + ? WHERE day = ?',
        [chapters, seconds, day]);
  }

  /// dia (aaaa-mm-dd) -> (capítulos lidos, segundos de leitura).
  Future<Map<String, (int, int)>> activity() async => {
        for (final r in await db.query('activity'))
          r['day'] as String: (r['chapters'] as int, r['seconds'] as int),
      };

  // ---------- Diário de oração ----------
  Future<List<Prayer>> prayers() async => [
        for (final r in await db.query('prayers', orderBy: 'created DESC'))
          Prayer(
            id: r['id'] as int,
            text: r['text'] as String,
            created: DateTime.fromMillisecondsSinceEpoch(r['created'] as int),
            answered: r['answered'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['answered'] as int),
            answer: r['answer'] as String?,
          ),
      ];

  Future<void> savePrayer(Prayer p) async {
    final data = {
      'text': p.text,
      'created': p.created.millisecondsSinceEpoch,
      'answered': p.answered?.millisecondsSinceEpoch,
      'answer': p.answer,
    };
    if (p.id == null) {
      await db.insert('prayers', data);
    } else {
      await db.update('prayers', data, where: 'id = ?', whereArgs: [p.id]);
    }
  }

  Future<void> deletePrayer(int id) => db.delete('prayers', where: 'id = ?', whereArgs: [id]);

  // ---------- Memorização ----------
  Future<List<MemoryVerse>> memoryVerses() async => [
        for (final r in await db.query('memory', orderBy: 'due'))
          MemoryVerse(VerseRef.fromKey(r['vkey'] as String), r['level'] as int,
              DateTime.fromMillisecondsSinceEpoch(r['due'] as int)),
      ];

  Future<void> setMemory(VerseRef r, int level, DateTime due) async {
    final old = await db.query('memory', where: 'vkey = ?', whereArgs: [r.key]);
    await db.insert(
        'memory',
        {
          'vkey': r.key,
          'level': level,
          'due': due.millisecondsSinceEpoch,
          'created': old.isEmpty ? _now() : old.first['created'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Adiciona à memorização sem zerar o progresso de quem já está na lista.
  Future<void> addMemory(VerseRef r) => db.insert(
      'memory', {'vkey': r.key, 'level': 0, 'due': _now(), 'created': _now()},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> removeMemory(VerseRef r) => db.delete('memory', where: 'vkey = ?', whereArgs: [r.key]);

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- Marcações ----------
  Future<void> setHighlight(VerseRef r, int? color) async {
    if (color == null) {
      await db.delete('highlights', where: 'vkey = ?', whereArgs: [r.key]);
    } else {
      await db.insert('highlights', {'vkey': r.key, 'color': color, 'created': _now()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<int, int>> highlightsForChapter(int book, int chapter) async {
    final rows = await db.query('highlights',
        where: 'vkey LIKE ?', whereArgs: ['$book:$chapter:%']);
    return {
      for (final r in rows)
        VerseRef.fromKey(r['vkey'] as String).verse: r['color'] as int
    };
  }

  Future<List<Highlight>> allHighlights() async {
    final rows = await db.query('highlights', orderBy: 'created DESC');
    return rows
        .map((r) => Highlight(VerseRef.fromKey(r['vkey'] as String), r['color'] as int,
            DateTime.fromMillisecondsSinceEpoch(r['created'] as int)))
        .toList();
  }

  // ---------- Favoritos ----------
  Future<void> setFavorite(VerseRef r, bool fav) async {
    if (fav) {
      await db.insert('favorites', {'vkey': r.key, 'created': _now()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete('favorites', where: 'vkey = ?', whereArgs: [r.key]);
    }
  }

  Future<Set<int>> favoritesForChapter(int book, int chapter) async {
    final rows = await db.query('favorites',
        where: 'vkey LIKE ?', whereArgs: ['$book:$chapter:%']);
    return {for (final r in rows) VerseRef.fromKey(r['vkey'] as String).verse};
  }

  Future<List<VerseRef>> allFavorites() async {
    final rows = await db.query('favorites', orderBy: 'created DESC');
    return rows.map((r) => VerseRef.fromKey(r['vkey'] as String)).toList();
  }

  // ---------- Anotações ----------
  Future<void> saveNote(Note n) async {
    final data = {
      'vkey': n.ref.key,
      'text': n.text,
      'created': n.created.millisecondsSinceEpoch,
      'updated': _now(),
    };
    if (n.id == null) {
      await db.insert('notes', data);
    } else {
      await db.update('notes', data, where: 'id = ?', whereArgs: [n.id]);
    }
  }

  Future<void> deleteNote(int id) =>
      db.delete('notes', where: 'id = ?', whereArgs: [id]);

  Note _noteFrom(Map<String, Object?> r) => Note(
        id: r['id'] as int,
        ref: VerseRef.fromKey(r['vkey'] as String),
        text: r['text'] as String,
        created: DateTime.fromMillisecondsSinceEpoch(r['created'] as int),
        updated: DateTime.fromMillisecondsSinceEpoch(r['updated'] as int),
      );

  Future<List<Note>> allNotes() async =>
      (await db.query('notes', orderBy: 'updated DESC')).map(_noteFrom).toList();

  Future<Map<int, List<Note>>> notesForChapter(int book, int chapter) async {
    final rows = await db.query('notes',
        where: 'vkey LIKE ?', whereArgs: ['$book:$chapter:%'], orderBy: 'created');
    final out = <int, List<Note>>{};
    for (final r in rows) {
      final n = _noteFrom(r);
      out.putIfAbsent(n.ref.verse, () => []).add(n);
    }
    return out;
  }

  // ---------- Histórico ----------
  Future<void> addHistory(int book, int chapter) async {
    final last = await db.query('history', orderBy: 'id DESC', limit: 1);
    if (last.isNotEmpty &&
        last.first['book'] == book &&
        last.first['chapter'] == chapter) {
      await db.update('history', {'at': _now()},
          where: 'id = ?', whereArgs: [last.first['id']]);
      return;
    }
    await db.insert('history', {'book': book, 'chapter': chapter, 'at': _now()});
    // Mantém só os 500 mais recentes.
    await db.execute(
        'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT 500)');
  }

  Future<List<HistoryEntry>> history() async =>
      (await db.query('history', orderBy: 'id DESC'))
          .map((r) => HistoryEntry(r['book'] as int, r['chapter'] as int,
              DateTime.fromMillisecondsSinceEpoch(r['at'] as int)))
          .toList();

  Future<void> clearHistory() => db.delete('history');

  // ---------- Progresso ----------
  Future<void> setChapterRead(int book, int chapter, bool read) async {
    if (read) {
      await db.insert('read_chapters', {'book': book, 'chapter': chapter, 'at': _now()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete('read_chapters',
          where: 'book = ? AND chapter = ?', whereArgs: [book, chapter]);
    }
  }

  Future<Set<String>> readChapters() async {
    final rows = await db.query('read_chapters');
    return {for (final r in rows) '${r['book']}:${r['chapter']}'};
  }

  // ---------- Backup ----------
  static const _v1Tables = {'highlights', 'favorites', 'notes', 'history', 'read_chapters'};
  static const _tables = ['highlights', 'favorites', 'notes', 'history', 'read_chapters', 'activity', 'prayers', 'memory'];

  Future<Map<String, dynamic>> exportAll() async => {
        'format': 'biblia-jg-backup',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        for (final t in _tables) t: await db.query(t),
      };

  /// Junta uma linha vinda de outro aparelho com a que já existe aqui.
  /// Retorna true se a linha já foi tratada (não precisa inserir).
  static Future<bool> _mergeExisting(Transaction tx, String t, Map<String, Object?> row) async {
    int n(Object? v) => v is int ? v : 0;
    switch (t) {
      case 'notes':
        final ex = await tx.query(t,
            where: 'vkey = ? AND created = ?', whereArgs: [row['vkey'], row['created']], limit: 1);
        if (ex.isEmpty) return false;
        if (n(row['updated']) > n(ex.first['updated'])) {
          await tx.update(t, row, where: 'id = ?', whereArgs: [ex.first['id']]);
        }
        return true;
      case 'history':
        final ex = await tx.query(t,
            where: 'book = ? AND chapter = ? AND at = ?',
            whereArgs: [row['book'], row['chapter'], row['at']],
            limit: 1);
        return ex.isNotEmpty;
      case 'prayers':
        final ex = await tx.query(t, where: 'created = ?', whereArgs: [row['created']], limit: 1);
        if (ex.isEmpty) return false;
        if (ex.first['answered'] == null && row['answered'] != null) {
          await tx.update(t, row, where: 'id = ?', whereArgs: [ex.first['id']]);
        }
        return true;
      case 'activity':
        final ex = await tx.query(t, where: 'day = ?', whereArgs: [row['day']], limit: 1);
        if (ex.isEmpty) return false;
        final c = n(row['chapters']), s = n(row['seconds']);
        await tx.update(
            t,
            {
              'chapters': c > n(ex.first['chapters']) ? c : n(ex.first['chapters']),
              'seconds': s > n(ex.first['seconds']) ? s : n(ex.first['seconds']),
            },
            where: 'day = ?',
            whereArgs: [row['day']]);
        return true;
      case 'memory':
        final ex = await tx.query(t, where: 'vkey = ?', whereArgs: [row['vkey']], limit: 1);
        return ex.isNotEmpty && n(ex.first['level']) >= n(row['level']);
      case 'highlights':
      case 'favorites':
        final ex = await tx.query(t, where: 'vkey = ?', whereArgs: [row['vkey']], limit: 1);
        return ex.isNotEmpty && n(ex.first['created']) >= n(row['created']);
      default:
        return false;
    }
  }

  /// Restaura um backup. Se [replace] for verdadeiro, apaga os dados atuais antes.
  Future<void> importAll(Map<String, dynamic> data, {bool replace = true}) async {
    if (data['format'] != 'biblia-jg-backup') {
      throw const FormatException('Este arquivo não é um backup da Bíblia JG.');
    }
    await db.transaction((tx) async {
      for (final t in _tables) {
        final rows = data[t];
        // Backups antigos não têm as tabelas novas (oração, memorização, constância):
        // nesse caso não apaga o que já existe nelas.
        if (rows is! List && !_v1Tables.contains(t)) continue;
        if (replace) await tx.delete(t);
        if (rows is! List) continue;
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map);
          if (t == 'notes' || t == 'history' || t == 'prayers') row.remove('id');
          // Ao juntar (sem substituir), não duplica o que já existe e fica com o mais completo.
          if (!replace && await _mergeExisting(tx, t, row)) continue;
          await tx.insert(t, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
