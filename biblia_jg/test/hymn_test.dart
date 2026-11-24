import 'package:biblia_jg/models/reference_parser.dart';
import 'package:biblia_jg/services/hymn_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('importa hinário numerado de texto', () {
    const text = '''
HINÁRIO
1 - Chuvas de Graça
Deus prometeu com certeza
Chuvas de graça mandar

Chuvas de graça,
Chuvas pedimos, Senhor

2. Grandioso És Tu
Senhor meu Deus, quando eu maravilhado
Contemplo a tua imensa criação

3 Rude Cruz
Rude cruz se erigiu
''';
    final hymns = parseHymnText('x', text);
    expect(hymns.map((h) => h.number), [1, 2, 3]);
    expect(hymns.first.title, 'Chuvas de Graça');
    expect(hymns.first.stanzas.length, 2);
  });

  test('localiza referências no texto do dicionário', () {
    final refs = locateReferences('Filho de Anrão (Êx 6:20; 1Cr 2:10) e irmão de Moisés.');
    expect(refs.length, 2);
    expect(refs.first.$3.chapter, 6);
  });
}
