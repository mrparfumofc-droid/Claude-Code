import 'dart:convert';
import 'dart:io';

import 'package:biblia_jg/services/chapter_audio.dart';
import 'package:biblia_jg/services/narration_cloud.dart';
import 'package:biblia_jg/services/quotes.dart';
import 'package:biblia_jg/widgets/focus_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frases: o arquivo do app tem todas as tradições e não repete', () {
    final d = QuotesData.parse(File('assets/data/frases.json').readAsStringSync());
    expect(d.quotes.length, greaterThanOrEqualTo(100));
    final ids = {for (final g in d.groups) g.$1};
    for (final id in ['reforma', 'anglicana', 'pentecostal']) {
      expect(ids, contains(id));
    }
    for (final id in ids) {
      expect(d.quotes.where((q) => q.group == id), isNotEmpty, reason: id);
    }
    for (final q in d.quotes) {
      expect(q.text.trim(), isNotEmpty);
      expect(q.author.trim(), isNotEmpty);
      expect(ids, contains(q.group), reason: q.text);
      expect(q.mine, isFalse);
    }
    expect({for (final q in d.quotes) q.id}.length, d.quotes.length);
    expect(d.groupName('reforma'), 'Reformadores');
    expect(d.groupName(Quote.mineGroup), 'Minhas frases');
    // Frase atribuída aparece marcada; frase com fonte mostra a fonte.
    expect(d.quotes.where((q) => q.attributed).every((q) => q.note.contains('atribuída')), isTrue);
    expect(d.quotes.firstWhere((q) => q.author == 'Agostinho de Hipona').note, contains('Confissões'));
  });

  test('frase do dia: muda a cada dia e passa por todas antes de repetir', () {
    final d = QuotesData.parse(File('assets/data/frases.json').readAsStringSync());
    final seen = <String>{};
    for (var i = 0; i < d.quotes.length; i++) {
      seen.add(d.ofDay(DateTime(2026, 11, 25 + i)).id);
    }
    expect(seen.length, d.quotes.length);
    expect(d.ofDay(DateTime(2026, 11, 25, 8)).id, d.ofDay(DateTime(2026, 11, 25, 23)).id);
    expect(d.ofDay(DateTime(2020, 1, 1)).text, isNotEmpty); // datas antigas também funcionam
  });

  test('frases do usuário: guardam e voltam iguais', () {
    const q = Quote('A graça basta.', 'Autor de teste', source: 'Sermão');
    final back = Quote.fromJson(jsonDecode(jsonEncode(q.toJson())))!;
    expect(back.text, q.text);
    expect(back.author, q.author);
    expect(back.source, q.source);
    expect(back.mine, isTrue);
    expect(back.id, q.id);
    expect(q.shareText, '“A graça basta.”\n— Autor de teste, Sermão');
    expect(Quote.fromJson({'t': '  ', 'a': 'x'}), isNull);
    expect(Quote.fromJson({'t': 'Só o texto'})!.author, 'Autor desconhecido');
  });

  test('narração: a chave do texto é igual à do gerador (narr.py)', () {
    expect(NarrationCloud.keyFor('abc'), '1a47e90b016d9863');
    expect(
      NarrationCloud.keyFor('  Deus chama Abraão\n e promete   abençoar todas as famílias da terra. '),
      '116a46919ab40585',
    );
    // Espaços a mais ou quebras de linha não mudam a chave.
    expect(NarrationCloud.keyFor('Deus chama Abraão e promete abençoar todas as famílias da terra.'), '116a46919ab40585');
    expect(NarrationCloud.parseIndex('{"versao":1,"voz":"Algieba","h":["aa","bb"]}'), {'aa', 'bb'});
    expect(NarrationCloud.parseIndex('{}'), isEmpty);
  });

  test('leitura gravada: acha o versículo pelo tempo e só aceita versões livres', () {
    final r = ChapterRecording.parse('leitura/blivre/19-23.ogg', '{"d":51470,"m":[2940,7180,12640,19000,31100,41400]}')!;
    expect(r.durationMs, 51470);
    expect(r.verseAt(Duration.zero), 1); // título falado antes do versículo 1
    expect(r.verseAt(const Duration(milliseconds: 7179)), 1);
    expect(r.verseAt(const Duration(milliseconds: 7180)), 2);
    expect(r.verseAt(const Duration(seconds: 50)), 6);
    expect(r.startOf(1), Duration.zero);
    expect(r.startOf(4), const Duration(milliseconds: 19000));
    expect(r.startOf(99), const Duration(milliseconds: 41400));
    expect(ChapterRecording.parse('x', '{"m":[]}'), isNull);
    expect(ChapterRecording.parse('x', 'isto não é json'), isNull);

    expect(ChapterAudio.supports('blivre'), isTrue);
    expect(ChapterAudio.supports('alm1911'), isTrue);
    expect(ChapterAudio.supports('nvi'), isFalse);
    expect(ChapterAudio.supports('ara'), isFalse);
    expect(ChapterAudio.key(18, 23), '19-23'); // livro pelo índice (Salmos = 18)
    expect(ChapterAudio.parseIndex('{"versao":2,"c":["19-23","43-3"]}'), {'19-23', '43-3'});
  });

  test('modo foco: o relógio conta, avisa uma vez e fica dentro da tela', () {
    final s = FocusSession()..restart(goal: 1);
    expect(s.label, '01:00');
    var rang = 0;
    for (var i = 0; i < 60; i++) {
      if (s.tick()) rang++;
    }
    expect(rang, 1);
    expect(s.done, isTrue);
    expect(s.label, '00:00');
    expect(s.tick(), isFalse);
    expect(s.label, '+00:01');
    s.extend(5);
    expect(s.alarmed, isFalse);
    expect(s.goal, 6);
    s.setGoal(0);
    expect(s.label, '01:01'); // sem limite: conta para a frente
    s.restart();
    expect(s.seconds, 0);

    const area = Size(1000, 700);
    expect(clampFocusClock(const Offset(5000, 5000), area, FocusClock.size, 40), const Offset(1000 - 104 - 8, 700 - 44 - 8));
    expect(clampFocusClock(const Offset(-50, -50), area, FocusClock.size, 40), const Offset(8, 48));
    expect(clampFocusClock(const Offset(300, 200), area, FocusClock.size, 40), const Offset(300, 200));
    // Passou da borda: anda só uma fração (resistência), sem travar seco.
    final rb = rubberBandFocusClock(const Offset(-100, 200), area, FocusClock.size, 40);
    expect(rb.dx, lessThan(8));
    expect(rb.dx, greaterThan(-100));
    expect(rb.dy, 200);
  });
}
