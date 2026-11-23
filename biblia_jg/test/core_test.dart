import 'dart:convert';

import 'package:biblia_jg/data/user_db.dart';
import 'package:biblia_jg/models/bible.dart';
import 'package:biblia_jg/models/daily.dart';
import 'package:biblia_jg/models/reader_settings.dart';
import 'package:biblia_jg/screens/reader_view.dart';
import 'package:biblia_jg/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const sampleJson = '''
{
  "id": "teste", "name": "Versão de Teste", "abbrev": "tst", "copyright": "Domínio público",
  "books": [
    {"abbrev": "gn", "name": "Gênesis", "titles": {"1:1": "A criação"},
     "chapters": [[" No princípio era o céu.", "E a terra estava vazia."], ["Capítulo dois."]]},
    {"abbrev": "ex", "chapters": [["Êxodo um."]]}
  ]
}
''';

void main() {
  group('Bible.parse', () {
    test('formato próprio do app', () {
      final b = Bible.parse(sampleJson);
      expect(b.id, 'teste');
      expect(b.abbrev, 'TST');
      expect(b.books.length, 2);
      expect(b.books[0].titleBefore(1, 1), 'A criação');
      expect(b.books[1].name, 'Êxodo'); // nome vem da lista canônica
      expect(b.totalChapters, 3);
    });

    test('formato lista de livros', () {
      final list = jsonEncode([
        {'abbrev': 'gn', 'chapters': [['a', 'b']]},
      ]);
      final b = Bible.parse(list, fallbackId: 'acf', fallbackName: 'ACF');
      expect(b.books.single.name, 'Gênesis');
      expect(b.id, 'acf');
    });

    test('aceita BOM no início do arquivo', () {
      expect(Bible.parse('﻿$sampleJson').books.length, 2);
    });

    test('rejeita arquivo inválido', () {
      expect(() => Bible.parse('{"x": 1}'), throwsFormatException);
    });
  });

  test('palavras de Jesus', () {
    final segs = splitJesusWords('Disse: <J>Eu sou</J> o caminho');
    expect(segs.map((s) => s.jesus), [false, true, false]);
    expect(plainVerse('<J>Amai</J>-vos'), 'Amai-vos');
  });

  test('busca sem acento e frase exata', () {
    final b = Bible.parse(sampleJson);
    expect(searchBible(b, 'principio CEU', SearchScope.all, 0).length, 1);
    expect(searchBible(b, '"terra estava"', SearchScope.all, 0).single.ref,
        const VerseRef(0, 1, 2));
    expect(searchBible(b, 'exodo', SearchScope.oldTestament, 0).length, 1);
    expect(searchBible(b, 'exodo', SearchScope.newTestament, 0), isEmpty);
  });

  test('intervalos de versículos', () {
    expect(verseRanges([1, 2, 3, 5, 7, 8]), '1-3, 5, 7-8');
  });

  test('versículo do dia é estável no mesmo dia', () {
    expect(verseOfDay(DateTime(2026, 11, 23, 1)), verseOfDay(DateTime(2026, 11, 23, 23)));
    for (final r in dailyVerses) {
      expect(r.book, inInclusiveRange(0, 65));
    }
  });

  test('configurações ida e volta em JSON', () {
    const s = ReaderSettings(
      fontSize: 30,
      align: TextAlign.justify,
      font: FontKind.monospace,
      pageColor: PageColor.sepia,
      verseOfDayTime: TimeOfDay(hour: 14, minute: 30),
      jesusColor: Color(0xFF1565C0),
    );
    final back = ReaderSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(back.fontSize, 30);
    expect(back.align, TextAlign.justify);
    expect(back.font, FontKind.monospace);
    expect(back.pageColor, PageColor.sepia);
    expect(back.verseOfDayTime, const TimeOfDay(hour: 14, minute: 30));
    expect(back.jesusColor.toARGB32(), 0xFF1565C0);
    // Chaves ausentes usam o padrão.
    expect(ReaderSettings.fromJson({}).fontSize, const ReaderSettings().fontSize);
  });

  group('UserDb', () {
    late UserDb db;
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await UserDb.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    });
    tearDown(() => db.db.close());

    test('marcações, favoritos, anotações e progresso', () async {
      const r = VerseRef(42, 3, 16);
      await db.setHighlight(r, 0xFFFFF176);
      await db.setFavorite(r, true);
      await db.saveNote(Note(ref: r, text: 'Amor', created: DateTime.now(), updated: DateTime.now()));
      await db.setChapterRead(42, 3, true);
      await db.addHistory(42, 3);
      await db.addHistory(42, 3); // repetido não duplica

      expect(await db.highlightsForChapter(42, 3), {16: 0xFFFFF176});
      expect(await db.favoritesForChapter(42, 3), {16});
      expect((await db.notesForChapter(42, 3))[16]!.single.text, 'Amor');
      expect(await db.readChapters(), {'42:3'});
      expect((await db.history()).length, 1);
      // Capítulo 31 não pode "vazar" para o capítulo 3.
      await db.setFavorite(const VerseRef(42, 31, 1), true);
      expect(await db.favoritesForChapter(42, 3), {16});
    });

    test('backup exporta e restaura', () async {
      await db.setFavorite(const VerseRef(18, 23, 1), true);
      await db.saveNote(Note(
          ref: const VerseRef(18, 23, 1), text: 'Pastor', created: DateTime.now(), updated: DateTime.now()));
      final backup = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      final other = await UserDb.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
      // banco em memória é compartilhado pelo caminho; limpa e restaura
      await other.importAll({'format': 'biblia-jg-backup'});
      expect(await other.allFavorites(), isEmpty);
      await other.importAll(backup);
      expect(await other.allFavorites(), [const VerseRef(18, 23, 1)]);
      expect((await other.allNotes()).single.text, 'Pastor');
      expect(() => other.importAll({'format': 'outro'}), throwsFormatException);
    });
  });
}
