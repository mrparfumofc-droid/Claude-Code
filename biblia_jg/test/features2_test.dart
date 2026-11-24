import 'package:biblia_jg/data/user_db.dart';
import 'package:biblia_jg/models/bible.dart';
import 'package:biblia_jg/screens/memorize_screen.dart';
import 'package:biblia_jg/screens/needs_screen.dart';
import 'package:biblia_jg/screens/reading_plans_screen.dart';
import 'package:biblia_jg/services/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('memorização esconde mais palavras a cada nível', () {
    const text = 'Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito';
    int hidden(int level) => maskWords(text, level).where((w) => w.$2).length;
    expect(hidden(0), greaterThan(0));
    expect(hidden(2), greaterThan(hidden(0)));
    expect(hidden(5), greaterThan(hidden(2)));
    // Palavras muito curtas nunca são escondidas.
    expect(maskWords('o a de', 5).every((w) => !w.$2), isTrue);
  });

  test('temas de "Palavra para o momento" têm referências válidas', () {
    expect(needs.length, greaterThanOrEqualTo(12));
    for (final n in needs) {
      expect(n.refs, isNotEmpty);
      for (final r in n.refs) {
        expect(r.length, 4);
        expect(r[0], inInclusiveRange(0, 65));
        expect(r[1], greaterThan(0));
        expect(r[3], greaterThanOrEqualTo(r[2]));
      }
    }
  });

  test('plano flexível continua do primeiro dia não lido', () {
    final p = PlanProgress('marcos16', DateTime(2020), {0, 1, 3});
    expect(p.nextDay(16), 2);
    expect(p.finished(16), isFalse);
    expect(readingPlans.any((x) => x.id == 'marcos16' && x.days == 16), isTrue);
  });

  test('impressão digital da cópia ignora a data de exportação', () {
    final a = {'exportedAt': '2026-01-01', 'notes': [1, 2], 'settings': {'x': 1}};
    final b = {'exportedAt': '2027-05-05', 'notes': [1, 2], 'settings': {'x': 1}};
    final c = {'exportedAt': '2026-01-01', 'notes': [1, 3], 'settings': {'x': 1}};
    expect(snapshotHash(a), snapshotHash(b));
    expect(snapshotHash(a), isNot(snapshotHash(c)));
  });

  group('banco de dados v2', () {
    late UserDb db;
    setUp(() async {
      sqfliteFfiInit();
      db = await UserDb.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    });
    tearDown(() => db.db.close());

    test('constância, oração e memorização', () async {
      await db.addActivity(chapters: 2, seconds: 90);
      await db.addActivity(chapters: -5);
      final act = await db.activity();
      expect(act[UserDb.dayKey(DateTime.now())], (0, 90));

      await db.savePrayer(Prayer(text: 'Pela família', created: DateTime(2026, 1, 1)));
      final p = (await db.prayers()).single;
      await db.savePrayer(
          Prayer(id: p.id, text: p.text, created: p.created, answered: DateTime(2026, 2, 1), answer: 'Deus ouviu'));
      expect((await db.prayers()).single.answer, 'Deus ouviu');

      const ref = VerseRef(42, 3, 16);
      await db.addMemory(ref);
      await db.setMemory(ref, 3, DateTime(2030));
      await db.addMemory(ref); // não zera o progresso
      expect((await db.memoryVerses()).single.level, 3);
    });

    test('juntar cópias não duplica nem apaga', () async {
      final now = DateTime(2026, 3, 3);
      await db.saveNote(Note(ref: const VerseRef(0, 1, 1), text: 'minha nota', created: now, updated: now));
      await db.setFavorite(const VerseRef(0, 1, 2), true);
      await db.savePrayer(Prayer(text: 'Pedido', created: now));
      await db.saveSermon(Sermon(title: 'A graça', passage: 'Ef 2:8', body: 'Esboço', created: now, updated: now));
      final snap = await db.exportAll();

      // Aparelho novo: junta duas vezes a mesma cópia e acrescenta algo local.
      await db.importAll(snap, replace: false);
      await db.importAll(snap, replace: false);
      expect((await db.allNotes()).length, 1);
      expect((await db.prayers()).length, 1);
      expect((await db.sermons()).single.passage, 'Ef 2:8');
      expect((await db.allFavorites()).length, 1);

      // Backup antigo (sem as tabelas novas) não apaga orações.
      final old = Map<String, dynamic>.from(snap)
        ..remove('prayers')
        ..remove('memory')
        ..remove('activity');
      await db.importAll(old);
      expect((await db.prayers()).length, 1);
    });
  });
}
