import 'dart:io';

import 'package:biblia_jg/services/panorama.dart';
import 'package:biblia_jg/services/stories.dart' show parseStoryReference;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = PanoramaData.parse(File('assets/data/panorama.json').readAsStringSync());

  test('árvore de Abraão: doze tribos, ligações e passos válidos', () {
    final tree = data.tree;
    expect(tree.nodes.where((n) => n.type == 'tribo').length, 12);
    for (final e in tree.edges) {
      expect(tree.byId[e.to], isNotNull, reason: e.to);
      for (final id in e.from) {
        expect(tree.byId[id], isNotNull, reason: id);
      }
    }
    for (final s in tree.steps) {
      expect(s.text, isNotEmpty);
      expect(parseStoryReference(s.ref), isNotNull, reason: s.ref);
      for (final id in s.nodes) {
        expect(tree.byId[id], isNotNull, reason: id);
      }
    }
    for (final n in tree.nodes) {
      expect(n.x, inInclusiveRange(0, tree.width));
      expect(n.y, inInclusiveRange(0, tree.height));
      for (final r in n.refs) {
        expect(parseStoryReference(r), isNotNull, reason: '${n.id}: $r');
      }
    }
    // Judá é filho de Lia; Jesus aparece na linha de Judá.
    expect(tree.groupOf(tree.byId['juda']!), 'lia');
    expect(tree.nodes.any((n) => n.name == 'Jesus' && n.id.startsWith('juda-')), isTrue);
  });

  test('reis: três do reino unido, 19 de Israel e 20 de Judá, em ordem', () {
    final k = data.kings;
    expect((k.united.length, k.israel.length, k.judah.length), (3, 19, 20));
    for (final list in [k.israel, k.judah]) {
      expect(list.first.start, 930);
      for (final r in list) {
        expect(r.start, greaterThanOrEqualTo(r.end));
        expect(['bom', 'mau', 'misto'], contains(r.rating));
        expect(parseStoryReference(r.ref), isNotNull, reason: '${r.name}: ${r.ref}');
      }
    }
    expect(k.israel.last.end, 722);
    expect(k.judah.last.end, 586);
    expect(k.israel.every((r) => r.rating != 'bom'), isTrue);
  });

  test('profetas e fichas dos 66 livros', () {
    expect(data.prophets.length, 16);
    for (final p in data.prophets) {
      expect(['pre', 'exilio', 'pos'], contains(p.period));
      expect(parseStoryReference(p.ref)!.book, p.book, reason: p.name);
    }
    expect(data.books.length, 66);
    expect(data.groups.fold<int>(0, (s, g) => s + g.to - g.from + 1), 66);
    for (var n = 1; n <= 66; n++) {
      final b = data.books[n]!;
      expect(b.author, isNotEmpty);
      expect(b.people.length, greaterThanOrEqualTo(3));
      expect(b.events.length, greaterThanOrEqualTo(3));
      expect(parseStoryReference(b.key)!.book, n - 1, reason: 'chave do livro $n');
      for (final (title, ref) in b.events) {
        expect(parseStoryReference(ref)?.book, n - 1, reason: 'livro $n: $title ($ref)');
      }
    }
  });
}
