import 'package:biblia_jg/models/bible.dart';
import 'package:biblia_jg/models/reference_parser.dart';
import 'package:biblia_jg/screens/quiz_screen.dart';
import 'package:biblia_jg/screens/reading_plans_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseReference', () {
    test('formatos comuns', () {
      final a = parseReference('Jo 3:16')!;
      expect((a.book, a.chapter, a.verse), (42, 3, 16));
      final b = parseReference('Salmos 23')!;
      expect((b.book, b.chapter, b.verse), (18, 23, null));
      final c = parseReference('1 Co 13.4-7')!;
      expect((c.book, c.chapter, c.verse, c.endVerse), (45, 13, 4, 7));
      final d = parseReference('joão 1,1')!;
      expect((d.book, d.chapter, d.verse), (42, 1, 1));
      expect(parseReference('Jó 1:1')!.book, 17);
      expect(parseReference('Apocalipse 22:21')!.book, 65);
      expect(parseReference('I Samuel 17')!.book, 8);
    });

    test('rejeita texto que não é referência', () {
      expect(parseReference('olá mundo'), isNull);
      expect(parseReference('Xyz 3:16'), isNull);
    });
  });

  test('encontra referências dentro de um texto', () {
    final refs = findReferences(
        'Veja João 3:16 e também Romanos 5:8. Compare com 1 Coríntios 13:4-7 e Salmos 23:1.');
    expect(refs.map((p) => (p.book, p.chapter, p.verse)).toList(),
        [(42, 3, 16), (44, 5, 8), (45, 13, 4), (18, 23, 1)]);
    expect(refs[2].endVerse, 7);
  });

  test('lê o JSON das perguntas da IA', () {
    final q = parseQuiz('''```json
{"perguntas":[{"pergunta":"Quem construiu a arca?","opcoes":["Moisés","Noé","Davi","Abraão"],"correta":1,"referencia":"Gênesis 6:14","explicacao":"Deus mandou Noé construir a arca."}]}
```''');
    expect(q.single.correct, 1);
    expect(q.single.options[1], 'Noé');
  });

  test('plano de leitura cobre todos os capítulos uma vez', () {
    final bible = Bible(
      id: 't',
      name: 't',
      abbrev: 'T',
      copyright: '',
      books: [
        for (var i = 0; i < 66; i++)
          Book(index: i, abbrev: '$i', name: canonicalBooks[i].name, chapters: List.generate(3 + i % 5, (_) => ['x'])),
      ],
    );
    for (final plan in readingPlans) {
      final s = plan.schedule(bible);
      expect(s.length, plan.days, reason: plan.id);
      final all = s.expand((d) => d).toList();
      final expected = plan.books.fold<int>(0, (n, b) => n + bible.books[b].chapters.length);
      expect(all.length, expected, reason: plan.id);
      expect(all.toSet().length, expected, reason: plan.id);
    }
  });
}
