import 'package:biblia_jg/screens/pdf_reader_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('texto do PDF vira parágrafos corridos', () {
    final p = reflowPdfText([
      'LIÇÃO 1',
      'No princípio, Deus criou os céus e a terra, e viu que tudo o que tinha fei-',
      'to era muito bom. O homem foi criado à imagem de Deus para cuidar do jar-',
      'dim e andar com ele.',
      'Depois veio a queda, e com ela a promessa de um Salvador que esmagaria a',
      'cabeça da serpente no tempo determinado.',
      '',
      'Outro bloco depois de uma linha em branco.',
    ].join('\n'));
    expect(p.length, 4);
    expect(p[0], 'LIÇÃO 1');
    expect(p[1], startsWith('No princípio, Deus criou'));
    expect(p[1], contains('tinha feito era muito bom')); // palavra partida no fim da linha foi unida
    expect(p[1], endsWith('andar com ele.'));
    expect(p[2], startsWith('Depois veio a queda'));
    expect(p[3], 'Outro bloco depois de uma linha em branco.');
  });

  test('página sem texto dá lista vazia', () {
    expect(reflowPdfText(''), isEmpty);
    expect(reflowPdfText('\n \n'), isEmpty);
  });
}
