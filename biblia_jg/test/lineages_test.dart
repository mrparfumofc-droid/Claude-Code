import 'dart:convert';
import 'dart:io';

import 'package:biblia_jg/screens/panorama_lineages.dart' show lineageCards;
import 'package:biblia_jg/services/lineages.dart';
import 'package:biblia_jg/services/portraits.dart';
import 'package:biblia_jg/services/stories.dart' show parseStoryReference;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = LineagesData.parse(File('assets/data/linhagens.json').readAsStringSync());
  LineageChart chart(String id) => data.byId(id)!;

  /// Segue as ligações de pai para filho a partir de [from] e devolve a cadeia até [to].
  List<String> chain(LineageChart c, String from, String to) {
    final out = [from];
    var at = from;
    while (at != to && out.length < 60) {
      final next = c.edges.firstWhere((e) => e.from.length == 1 && e.from.first == at && !e.horizontal,
          orElse: () => const LinEdge([], '', false, false, null));
      if (next.to.isEmpty) break;
      at = next.to;
      out.add(at);
    }
    return out;
  }

  test('linhagens: seis quadros, iguais aos cartões da entrada do Panorama', () {
    expect(data.version, greaterThan(0));
    expect([for (final c in data.charts) c.id], [for (final c in lineageCards) c.$1]);
    for (final card in lineageCards) {
      final c = chart(card.$1);
      expect(c.title, card.$4);
      expect(c.subtitle, card.$5);
      expect(c.cover, card.$6);
      expect(c.intro.split(RegExp(r'\s+')).length, greaterThan(30), reason: c.id);
    }
  });

  test('linhagens: nós, ligações, faixas e passos coerentes em todos os quadros', () {
    const types = {'destaque', 'pessoa', 'mini', 'marco', 'grupo', 'elo'};
    const links = {'', 'abraao', 'reis', 'historias', 'mapas'};
    for (final c in data.charts) {
      expect(c.byId.length, c.nodes.length, reason: '${c.id}: ids repetidos');
      expect(c.steps.length, inInclusiveRange(8, 20), reason: c.id);
      for (final n in c.nodes) {
        final where = '${c.id}/${n.id}';
        expect(types, contains(n.type), reason: where);
        expect(n.rect.left, greaterThanOrEqualTo(0), reason: where);
        expect(n.rect.top, greaterThanOrEqualTo(0), reason: where);
        expect(n.rect.right, lessThanOrEqualTo(c.width), reason: where);
        expect(n.rect.bottom, lessThanOrEqualTo(c.height), reason: where);
        if (n.type != 'elo') expect(n.text, isNotEmpty, reason: where);
        if (n.type == 'marco') expect(n.art, isNotNull, reason: where);
        for (final r in n.refs) {
          expect(parseStoryReference(r), isNotNull, reason: '$where: $r');
        }
        if (!links.contains(n.link)) {
          expect(n.link.startsWith('quadro:'), isTrue, reason: where);
          expect(data.byId(n.link.substring(7)), isNotNull, reason: where);
        }
      }
      // Nenhum nó em cima de outro.
      for (var i = 0; i < c.nodes.length; i++) {
        for (var j = i + 1; j < c.nodes.length; j++) {
          expect(c.nodes[i].rect.inflate(1).overlaps(c.nodes[j].rect.inflate(1)), isFalse,
              reason: '${c.id}: ${c.nodes[i].id} sobre ${c.nodes[j].id}');
        }
      }
      for (final e in c.edges) {
        expect(c.byId[e.to], isNotNull, reason: '${c.id}: ${e.to}');
        expect(e.from, isNotEmpty);
        for (final id in e.from) {
          expect(c.byId[id], isNotNull, reason: '${c.id}: $id');
        }
      }
      for (final pair in c.couples) {
        expect(pair.length, 2);
        for (final id in pair) {
          expect(c.byId[id], isNotNull, reason: '${c.id}: $id');
        }
      }
      for (final b in c.bands) {
        expect(b.rect.right, lessThanOrEqualTo(c.width), reason: c.id);
        expect(b.rect.bottom, lessThanOrEqualTo(c.height), reason: c.id);
      }
      for (final (i, s) in c.steps.indexed) {
        final where = '${c.id} passo ${i + 1}';
        expect(s.title, isNotEmpty, reason: where);
        expect(s.art, isNotNull, reason: where);
        expect(s.text.split(RegExp(r'\s+')).length, inInclusiveRange(38, 92), reason: where);
        expect(parseStoryReference(s.ref), isNotNull, reason: '$where: ${s.ref}');
        expect(s.nodes, isNotEmpty, reason: where);
        for (final id in s.nodes) {
          expect(c.byId[id], isNotNull, reason: '$where: $id');
        }
      }
    }
  });

  test('linhagens: toda ilustração existe nas histórias ou está na lista de novas', () {
    final stories = jsonDecode(File('assets/data/historias.json').readAsStringSync()) as Map<String, dynamic>;
    final existing = <String>{
      for (final s in stories['historias'] as List)
        for (final c in s['cenas'] as List)
          if (c['i'] == true) c['img'] as String,
    };
    final asked = <String>{
      for (final a in jsonDecode(File('tool/panorama/arte_linhagens.json').readAsStringSync()) as List) a['key'] as String,
    };
    expect(asked.length, lessThanOrEqualTo(30));
    expect(asked.every((k) => k.startsWith('lin-')), isTrue);
    expect(asked.intersection(existing), isEmpty);
    final used = <String>{};
    for (final c in data.charts) {
      for (final key in [c.cover, for (final n in c.nodes) n.art, for (final s in c.steps) s.art]) {
        if (key == null) continue;
        used.add(key);
        expect(existing.contains(key) || asked.contains(key), isTrue, reason: '${c.id}: $key');
      }
    }
    // Nada pedido à toa.
    expect(asked.difference(used), isEmpty);
  });

  test('linhagens: retratos não confundem homônimos', () {
    final portraits = Portraits.parse(File('assets/data/retratos.json').readAsStringSync());
    final jesus = chart('jesus');
    // O José do Egito e o patriarca Jacó têm retrato; o marido de Maria e o pai dele são outras pessoas.
    expect(portraits.idFor('José'), isNotNull);
    expect(jesus.byId['jose']!.portrait, 'José, marido de Maria');
    expect(jesus.byId['mt-jaco']!.portrait, isNull);
    expect(jesus.byId['rao']!.name, 'Rão'); // não é Arão, o sacerdote
    // Filipe, o apóstolo, não é Filipe, o evangelista (que já tem retrato).
    expect(portraits.idFor('Filipe'), isNotNull);
    expect(chart('apostolos').byId['filipe']!.portrait, 'Filipe, o apóstolo');
    // Quem usa retrato já publicado aponta para um nome que existe no índice.
    for (final (c, id) in [('jesus', 'abraao'), ('jesus', 'davi'), ('jesus', 'maria'), ('jesus', 'jesus'), ('adao', 'noe'),
        ('linhas', 'arao'), ('apostolos', 'pedro'), ('apostolos', 'joao'), ('paulo', 'paulo'), ('paulo', 'timoteo')]) {
      final name = chart(c).byId[id]!.portrait;
      expect(name, isNotNull, reason: '$c/$id');
      expect(portraits.idFor(name!), isNotNull, reason: '$c/$id: $name');
    }
  });

  test('genealogia de Jesus: catorze de Abraão a Davi e catorze de Salomão a Jeconias', () {
    final c = chart('jesus');
    final first = chain(c, 'abraao', 'davi');
    expect(first.length, 14);
    expect(first.sublist(0, 4), ['abraao', 'isaque', 'jaco', 'juda']);
    final second = chain(c, 'salomao', 'jeconias');
    expect(second.length, 14);
    final third = chain(c, 'salatiel', 'jose');
    expect(third.length, 12); // com Jeconias antes e Jesus depois, fecha o terceiro grupo
    // As mulheres citadas por Mateus.
    for (final id in ['tamar', 'raabe', 'rute', 'bate-seba', 'maria']) {
      expect(c.couples.any((p) => p.contains(id)), isTrue, reason: id);
    }
    // Heli (Lucas) e Jacó (Mateus) chegam a José; Jesus nasce de Maria.
    expect(c.edges.where((e) => e.to == 'jose').map((e) => e.from.single).toSet(), {'mt-jaco', 'heli'});
    expect(c.edges.singleWhere((e) => e.to == 'jesus').from, ['maria']);
  });

  test('de Adão a Abraão: dez gerações até Noé e dez de Sem a Abrão', () {
    final c = chart('adao');
    expect(chain(c, 'sete', 'lameque').length, 8); // com Adão e Noé, dez
    expect(chain(c, 'arfaxade', 'tera').length, 8); // com Sem e Abrão, dez
    expect(c.byId['matusalem']!.sub, contains('969'));
    expect(c.byId['abrao']!.link, 'abraao');
  });

  test('rei e sacerdote: as duas linhas chegam a Jesus', () {
    final c = chart('linhas');
    expect(c.edges.where((e) => e.from.contains('jaco')).map((e) => e.to).toSet(), {'juda', 'levi'});
    expect(c.edges.where((e) => e.to == 'jesus').map((e) => e.from.single).toSet(),
        {'jose-maria', 'melquisedeque', 'joao-batista'});
    expect(chain(c, 'boaz', 'zorobabel'), ['boaz', 'obede', 'jesse', 'davi', 'salomao', 'reis', 'zorobabel']);
  });

  test('apóstolos: doze em três grupos de quatro, mais Matias', () {
    final c = chart('apostolos');
    const twelve = ['pedro', 'andre', 'tiago', 'joao', 'filipe', 'bartolomeu', 'tome', 'mateus', 'tiago-alfeu', 'tadeu',
        'simao-zelote', 'judas'];
    final groups = c.bands.where((b) => b.title.isEmpty).toList();
    expect(groups.length, 3);
    for (final (i, g) in groups.indexed) {
      final inside = [for (final n in c.nodes) if (n.type == 'pessoa' && g.rect.contains(Offset(n.x, n.y))) n.id];
      expect(inside.toSet(), twelve.sublist(i * 4, i * 4 + 4).toSet());
    }
    expect(c.edges.singleWhere((e) => e.to == 'matias').from, ['judas']);
    expect(c.byId['paulo']!.link, 'quadro:paulo');
  });

  test('Paulo: treze cartas e catorze companheiros', () {
    final c = chart('paulo');
    final letters = [for (final n in c.nodes) if (n.type == 'mini') n.name];
    expect(letters.toSet(), {
      'Gálatas', '1 Tessalonicenses', '2 Tessalonicenses', '1 Coríntios', '2 Coríntios', 'Romanos', 'Efésios',
      'Filipenses', 'Colossenses', 'Filemom', '1 Timóteo', 'Tito', '2 Timóteo',
    });
    expect(letters.length, 13);
    final team = c.bands.singleWhere((b) => b.title.startsWith('Companheiros'));
    expect(c.nodes.where((n) => team.rect.contains(Offset(n.x, n.y))).length, 14);
  });

  test('Israel e Judá: um tronco, dois ramos e um só caminho depois do exílio', () {
    final c = chart('povos');
    expect(c.edges.where((e) => e.from.contains('divisao')).map((e) => e.to).toSet(), {'hn', 'hs'});
    expect(c.edges.where((e) => e.to == 'j-imperios').map((e) => e.from.single).toSet(), {'s-judeu', 'n-remanescente'});
    expect(chain(c, 'j-imperios', 'j-futuro').length, 8);
    expect(c.byId['n-queda']!.sub, '722 a.C.');
    expect(c.byId['s-queda']!.sub, '586 a.C.');
  });
}
