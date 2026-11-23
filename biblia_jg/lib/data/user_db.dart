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
        options: OpenDatabaseOptions(version: 1, onCreate: _create));
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
  }

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
  static const _tables = ['highlights', 'favorites', 'notes', 'history', 'read_chapters'];

  Future<Map<String, dynamic>> exportAll() async => {
        'format': 'biblia-jg-backup',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        for (final t in _tables) t: await db.query(t),
      };

  /// Restaura um backup. Se [replace] for verdadeiro, apaga os dados atuais antes.
  Future<void> importAll(Map<String, dynamic> data, {bool replace = true}) async {
    if (data['format'] != 'biblia-jg-backup') {
      throw const FormatException('Este arquivo não é um backup da Bíblia JG.');
    }
    await db.transaction((tx) async {
      for (final t in _tables) {
        if (replace) await tx.delete(t);
        final rows = data[t];
        if (rows is! List) continue;
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map);
          if (t == 'notes' || t == 'history') row.remove('id');
          await tx.insert(t, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
