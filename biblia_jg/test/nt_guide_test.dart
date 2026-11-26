import 'dart:convert';
import 'dart:io';

import 'package:biblia_jg/models/bible.dart' show canonicalBooks;
import 'package:biblia_jg/models/reference_parser.dart' show Passage;
import 'package:biblia_jg/services/nt_guide.dart';
import 'package:biblia_jg/services/stories.dart' show parseStoryReference;
import 'package:biblia_jg/services/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

int _words(String s) => s.trim().split(RegExp(r'\s+')).length;

void main() {
  final timeline = TimelineData.parse(File('assets/data/linha_tempo.json').readAsStringSync());
  final guide = NtGuide.parse(File('assets/data/nt_livros.json').readAsStringSync());

  final index = jsonDecode(File('assets/data/historias.json').readAsStringSync()) as Map<String, dynamic>;
  final scenes = <String>{
    for (final h in index['historias'] as List)
      for (final c in (h as Map<String, dynamic>)['cenas'] as List)
        if ((c as Map<String, dynamic>)['i'] == true) '${c['img']}',
  };
  final stories = <String>{for (final h in index['historias'] as List) '${(h as Map<String, dynamic>)['id']}'};
  // Ilustrações novas (ainda sem imagem na nuvem): têm prefixo próprio e ficam listadas para serem geradas.
  final planned = <String>{
    for (final a in jsonDecode(File('tool/panorama/arte_nt.json').readAsStringSync()) as List)
      '${(a as Map<String, dynamic>)['key']}',
  };
  bool isNew(String key) => key.startsWith('hist-') || key.startsWith('nt-');

  void checkArt(String? key, String where) {
    if (key == null) return;
    if (isNew(key)) {
      expect(planned, contains(key), reason: '$where: $key');
    } else {
      expect(scenes, contains(key), reason: '$where: $key');
    }
  }

  // Capítulos e versículos de uma Bíblia do app, quando os textos estão na pasta (no CI são baixados antes dos testes).
  List<List<int>>? counts;
  for (final id in ['acf', 'arc', 'ara', 'nvi']) {
    final f = File('assets/bibles/$id.json');
    if (!f.existsSync()) continue;
    final raw = jsonDecode(f.readAsStringSync());
    final books = raw is Map ? raw['books'] as List : raw as List;
    counts = [
      for (final b in books) [for (final c in (b as Map)['chapters'] as List) (c as List).length],
    ];
    break;
  }

  Passage checkRef(String ref, String where) {
    final p = parseStoryReference(ref);
    expect(p, isNotNull, reason: '$where: $ref');
    final c = counts;
    if (c != null && p!.book < c.length) {
      expect(p.chapter, inInclusiveRange(1, c[p.book].length), reason: '$where: $ref');
      final verses = c[p.book][p.chapter - 1];
      if (p.verse != null) expect(p.verse, inInclusiveRange(1, verses), reason: '$where: $ref');
      if (p.endVerse != null) expect(p.endVerse, inInclusiveRange(p.verse!, verses), reason: '$where: $ref');
    }
    return p!;
  }

  test('ilustrações novas: no máximo 40, com descrição', () {
    final list = jsonDecode(File('tool/panorama/arte_nt.json').readAsStringSync()) as List;
    expect(list.length, lessThanOrEqualTo(40));
    expect(planned.length, list.length, reason: 'chave repetida');
    for (final a in list) {
      final m = a as Map<String, dynamic>;
      expect(isNew('${m['key']}'), isTrue, reason: '${m['key']}');
      expect('${m['descricao']}'.length, greaterThan(60), reason: '${m['key']}');
      expect(scenes, isNot(contains(m['key'])), reason: 'já existe: ${m['key']}');
    }
  });

  test('linha do tempo: épocas do Antigo e do Novo Testamento e da história da igreja', () {
    expect(timeline.version, greaterThan(0));
    expect(timeline.groups.map((g) => g.$1), ['at', 'nt', 'igreja']);
    expect(timeline.eras.length, greaterThanOrEqualTo(16));
    expect(timeline.eventCount, greaterThanOrEqualTo(180));
    expect(timeline.eras.map((e) => e.id).toSet().length, timeline.eras.length);
    // As épocas vêm agrupadas e na ordem: AT, NT, igreja.
    final order = timeline.eras.map((e) => ['at', 'nt', 'igreja'].indexOf(e.group)).toList();
    expect(order, [...order]..sort());
    for (final id in ['jesus', 'atos', 'cartas', 'reforma', 'avivamentos', 'hoje']) {
      expect(timeline.eras.any((e) => e.id == id), isTrue, reason: id);
    }
    for (final e in timeline.eras) {
      expect(e.title, isNotEmpty);
      expect(e.dates, isNotEmpty);
      expect(e.events.length, greaterThanOrEqualTo(5), reason: e.id);
      expect(['', 'arvore', 'tabernaculo', 'reis', 'historias', 'nt'], contains(e.link), reason: e.id);
      checkArt(e.art, e.id);
      for (final r in e.refs) {
        checkRef(r, e.id);
      }
      for (final v in e.events) {
        final where = '${e.id}: ${v.title}';
        expect(v.year, isNotEmpty, reason: where);
        expect(_words(v.text), inInclusiveRange(30, 85), reason: where);
        checkArt(v.art, where);
        for (final r in v.refs) {
          checkRef(r, where);
        }
        // Os acontecimentos bíblicos sempre apontam para o texto.
        if (e.group != 'igreja') expect(v.refs, isNotEmpty, reason: where);
        if (v.story != null) expect(stories, contains(v.story), reason: where);
        if (v.book != null) expect(guide.byNumber, contains(v.book), reason: where);
      }
    }
  });

  test('linha do tempo: os marcos pedidos estão lá', () {
    final all = [for (final e in timeline.eras) for (final v in e.events) '${v.year} ${v.title} ${v.text}'].join('\n');
    for (final mark in [
      'Pentecostes', 'concílio de Jerusalém', 'Romanos', 'Apocalipse', 'Niceia', 'Vulgata', 'Agostinho', 'Wycliffe',
      'Gutenberg', '95 teses', 'Tyndale', 'King James', 'Almeida', 'Wesley', 'Carey', 'Spurgeon', 'Azusa',
      'Assembleia de Deus', 'Mar Morto',
    ]) {
      expect(all, contains(mark), reason: mark);
    }
  });

  test('guia do Novo Testamento: os 27 livros, em partes que seguem os capítulos', () {
    expect(guide.version, greaterThan(0));
    expect(guide.books.map((b) => b.n), [for (var n = 40; n <= 66; n++) n]);
    expect(guide.chronological.map((b) => b.order), [for (var i = 1; i <= 27; i++) i]);
    expect(guide.chronological.last.n, 66);
    expect(guide.groups.length, 5);
    for (final b in guide.books) {
      final name = canonicalBooks[b.n - 1].name;
      expect(guide.groups.any((g) => g.id == b.group), isTrue, reason: name);
      for (final field in [b.theme, b.author, b.date, b.from, b.to, b.why]) {
        expect(field, isNotEmpty, reason: name);
      }
      checkArt(b.cover, name);
      // Os bilhetes de um capítulo só (Filemom, 2 e 3 João) têm três partes; os outros, de quatro a nove.
      expect(b.parts.length, inInclusiveRange(const [57, 63, 64].contains(b.n) ? 3 : 4, 9), reason: name);
      for (final p in b.parts) {
        final where = '$name ${p.chapters}';
        expect(p.title, isNotEmpty, reason: where);
        expect(p.label, isNotEmpty, reason: where);
        // Tamanho bom para ler e para a narração passo a passo.
        expect(_words(p.text), inInclusiveRange(50, 110), reason: where);
        checkArt(p.art, where);
        expect(p.refs, isNotEmpty, reason: where);
        for (final r in p.refs) {
          expect(checkRef(r, where).book, b.n - 1, reason: where);
        }
      }
      expect(b.keys.length, inInclusiveRange(2, 4), reason: name);
      for (final r in b.keys) {
        final p = checkRef(r, '$name (chave)');
        expect(p.book, b.n - 1, reason: name);
        expect(p.verse, isNotNull, reason: '$name: $r');
      }
      expect(b.lessons.length, 3, reason: name);
      expect(b.links, isNotEmpty, reason: name);
      for (final l in b.links) {
        expect(l.text, isNotEmpty, reason: name);
        for (final r in l.refs) {
          checkRef(r, '$name (ligação)');
        }
        if (l.book != null) {
          expect(l.book, inInclusiveRange(1, 66), reason: name);
          expect(l.book, isNot(b.n), reason: name);
        }
      }
      for (final s in b.stories) {
        expect(stories, contains(s), reason: name);
      }
    }
  });

  test('guia do Novo Testamento: rótulo das partes', () {
    expect(const NtPart('5–7', 't', 'x', [], 'a').label, 'caps. 5–7');
    expect(const NtPart('16', 't', 'x', [], 'a').label, 'cap. 16');
    expect(const NtPart('1:1-13', 't', 'x', [], 'a').label, '1:1-13');
    expect(const NtPart('v. 1-7', 't', 'x', [], 'a').label, 'v. 1-7');
  });
}
