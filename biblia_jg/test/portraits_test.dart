import 'dart:convert';
import 'dart:io';

import 'package:biblia_jg/screens/panorama_art.dart';
import 'package:biblia_jg/services/portraits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retratos: acha pelo nome sem acento e só pelo nome exato', () {
    final p = Portraits.parse('{"versao":7,"retratos":{"abraao":["Abraão"],"pedro":["Pedro","Pedro (Cefas)"],"jaco":["Jacó"]}}');
    expect(p.version, 7);
    expect(p.count, 3);
    expect(p.idFor(' ABRAÃO '), 'abraao');
    expect(p.idFor('Pedro (Cefas)'), 'pedro');
    expect(p.idFor('Jacó'), 'jaco');
    // A nação "Jacó (Judá)" dos profetas não é o patriarca.
    expect(p.idFor('Jacó (Judá)'), isNull);
    expect(p.idFor('Zorobabel'), isNull);
    expect(Portraits.path('abraao'), 'retratos/abraao.jpg');
  });

  test('retratos: o índice que vai no app tem os personagens principais', () {
    final p = Portraits.parse(File('assets/data/retratos.json').readAsStringSync());
    expect(p.version, greaterThan(0));
    expect(p.count, greaterThanOrEqualTo(50));
    for (final name in ['Abraão', 'Moisés', 'Rei Davi', 'Profeta Daniel', 'Ester', 'Jesus', 'Pedro', 'Paulo (Saulo)', 'os doze']) {
      expect(p.idFor(name), isNotNull, reason: name);
    }
  });

  test('panorama: toda ilustração usada existe no índice das histórias', () {
    final index = jsonDecode(File('assets/data/historias.json').readAsStringSync()) as Map<String, dynamic>;
    final keys = <String>{
      for (final h in index['historias'] as List)
        for (final c in (h as Map<String, dynamic>)['cenas'] as List)
          if ((c as Map<String, dynamic>)['i'] == true) '${c['img']}',
    };
    expect(bookArt.keys.every((n) => n >= 1 && n <= 66), isTrue);
    expect(hubArt.length, greaterThanOrEqualTo(6));
    // (A arte da linha do tempo e do guia do Novo Testamento é conferida em nt_guide_test.dart.)
    for (final art in [...bookArt.values, ...hubArt]) {
      expect(keys, contains(art), reason: art);
    }
  });
}
