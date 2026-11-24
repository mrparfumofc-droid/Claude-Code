import 'dart:io';

import 'package:biblia_jg/data/bible_repository.dart';
import 'package:biblia_jg/models/daily.dart';
import 'package:flutter_test/flutter_test.dart';

/// Confere as versões geradas por tool/fetch_bibles.py (só roda se elas existirem).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hasIndex = File('assets/bibles/index.json').existsSync();

  test('versões incluídas no app abrem e têm 66 livros', () async {
    final repo = BibleRepository();
    final versions = await repo.versions();
    expect(versions.first.id, 'kja', reason: 'KJA é a versão padrão');
    expect(versions.length, greaterThanOrEqualTo(12));
    for (final v in versions) {
      final b = (await repo.load(v.id))!;
      expect(b.books.length, 66, reason: v.id);
      expect(b.totalChapters, greaterThan(1180), reason: v.id);
      // Todos os versículos do dia existem nas versões em português.
      if (['kja', 'acf', 'arc', 'ara', 'naa', 'nvi'].contains(v.id)) {
        for (final r in dailyVerses) {
          expect(verseText(b, r), isNotNull, reason: '${v.id} ${r.key}');
        }
      }
    }
  }, skip: hasIndex ? false : 'rode tool/fetch_bibles.py antes', timeout: const Timeout(Duration(minutes: 3)));
}
