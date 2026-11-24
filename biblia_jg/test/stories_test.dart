import 'dart:io';

import 'package:biblia_jg/services/places.dart';
import 'package:biblia_jg/services/stories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('referências das cenas viram trecho da Bíblia', () {
    final a = parseStoryReference('At 20:1-3; Rm 15:22-29')!;
    expect((a.book, a.chapter, a.verse, a.endVerse), (43, 20, 1, 3));
    final b = parseStoryReference('Êx 1:8–2:10')!;
    expect((b.book, b.chapter, b.verse), (1, 1, 8));
    final c = parseStoryReference('Jn 1:17–2:10')!;
    expect((c.book, c.chapter, c.verse), (31, 1, 17));
    expect(parseStoryReference('2Tm 4:6-18')!.book, 54);
    expect(parseStoryReference('sem referência'), isNull);
  });

  test('histórias ilustradas: todas completas e com referências válidas', () {
    final data = StoriesData.parse(File('assets/data/historias.json').readAsStringSync());
    expect(data.version, greaterThan(0));
    expect(data.stories.length, greaterThanOrEqualTo(30));
    for (final (cat, _, _) in storyCategories) {
      expect(data.byCategory(cat), isNotEmpty, reason: cat);
    }
    final ids = <String>{};
    for (final s in data.stories) {
      expect(ids.add(s.id), isTrue, reason: 'id repetido: ${s.id}');
      expect(s.scenes.length, greaterThanOrEqualTo(4), reason: s.id);
      expect(s.summary, isNotEmpty, reason: s.id);
      expect(s.minutes, greaterThan(0));
      for (final c in s.scenes) {
        expect(c.title, isNotEmpty);
        expect(c.text.split(RegExp(r'\s+')).length, greaterThan(60), reason: '${s.id}: ${c.title}');
        expect(c.passage, isNotNull, reason: '${s.id}: ${c.reference}');
        if (c.point != null) {
          expect(c.point!.latitude, inInclusiveRange(20, 45));
          expect(c.point!.longitude, inInclusiveRange(10, 52));
          expect(c.place, isNotEmpty);
        }
      }
      if (s.route) expect(s.scenes.where((c) => c.point != null).length, greaterThanOrEqualTo(2), reason: s.id);
    }
    // As viagens de Paulo estão todas lá.
    for (final id in ['saulo', 'paulo1', 'paulo2', 'paulo3', 'paulo-preso', 'roma']) {
      expect(data.byId(id), isNotNull, reason: id);
    }
  });

  test('atlas: rotas de Paulo, tribos e referências', () async {
    final d = await PlacesData.load();
    final paulo = d.stories.firstWhere((s) => s.id == 'paulo-todas');
    expect(paulo.lines.length, 4);
    expect(paulo.lines.every((l) => l.points.length > 10), isTrue);
    expect(d.stories.firstWhere((s) => s.id == 'doze-tribos').regions.length, 13);
    for (final s in d.stories) {
      for (final step in s.steps) {
        if (step.reference.isNotEmpty) {
          expect(parseStoryReference(step.reference), isNotNull, reason: '${s.id}: ${step.reference}');
        }
      }
    }
  });
}
