import 'package:biblia_jg/services/palm_guard.dart';
import 'package:biblia_jg/widgets/bible_ink.dart';
import 'package:biblia_jg/widgets/note_editor.dart';
import 'package:biblia_jg/widgets/reading_timer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('palma: com a caneta perto, o toque da mão é ignorado e a mão apoiada é cancelada', () async {
    SharedPreferences.setMockInitialValues({});
    PalmGuard.load(await SharedPreferences.getInstance());
    PalmGuard.setMode(1);
    Duration t(int ms) => Duration(milliseconds: ms);

    // Sem caneta usada no aparelho, o dedo passa sempre.
    expect(PalmGuard.filter(PointerDownEvent(timeStamp: t(0), pointer: 1, kind: PointerDeviceKind.touch)), hasLength(1));
    // A mão já está na tela quando a caneta chega: o toque dela é cancelado.
    final pen = PalmGuard.filter(PointerHoverEvent(timeStamp: t(100), kind: PointerDeviceKind.stylus));
    expect(pen.first, isA<PointerCancelEvent>());
    expect(pen.first.pointer, 1);
    expect(pen.last, isA<PointerHoverEvent>());
    expect(PalmGuard.stylusSeen, isTrue);
    // O resto desse toque não chega mais.
    expect(PalmGuard.filter(PointerUpEvent(timeStamp: t(150), pointer: 1, kind: PointerDeviceKind.touch)), isEmpty);
    // Toque novo com a caneta por perto: ignorado até o fim.
    expect(PalmGuard.filter(PointerDownEvent(timeStamp: t(300), pointer: 2, kind: PointerDeviceKind.touch)), isEmpty);
    expect(PalmGuard.filter(PointerMoveEvent(timeStamp: t(320), pointer: 2, kind: PointerDeviceKind.touch)), isEmpty);
    expect(PalmGuard.filter(PointerUpEvent(timeStamp: t(340), pointer: 2, kind: PointerDeviceKind.touch)), isEmpty);
    // Longe da caneta, o dedo volta a funcionar; palma grande não.
    expect(PalmGuard.filter(PointerDownEvent(timeStamp: t(5000), pointer: 3, kind: PointerDeviceKind.touch)), hasLength(1));
    expect(PalmGuard.filter(PointerUpEvent(timeStamp: t(5050), pointer: 3, kind: PointerDeviceKind.touch)), hasLength(1));
    expect(
        PalmGuard.filter(PointerDownEvent(timeStamp: t(6000), pointer: 4, kind: PointerDeviceKind.touch, radiusMajor: 40)),
        isEmpty);
    // Desligada: tudo passa.
    PalmGuard.setMode(0);
    expect(PalmGuard.filter(PointerDownEvent(timeStamp: t(6100), pointer: 5, kind: PointerDeviceKind.touch, radiusMajor: 40)),
        hasLength(1));
    PalmGuard.setMode(1);
  });

  test('cronômetro: conta para trás, avisa no fim e guarda cor e fundo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = ReadingTimer.instance..load(prefs);
    t.setMinutes(1);
    expect(t.label, '01:00');
    expect(t.active, isFalse);
    t.setLook(color: 2, opaque: true);
    expect(prefs.getInt('crono.cor'), 2);
    expect(prefs.getBool('crono.opaco'), isTrue);
    expect(t.tintOr(Colors.white), ReadingTimer.colors[2]);
    t.setLook(color: -1);
    expect(t.tintOr(Colors.white), Colors.white);
    final ends = <int>[];
    final sub = t.finished.stream.listen(ends.add);
    t.start();
    t.remaining = 1;
    t.pause();
    t.start();
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(t.running, isFalse);
    expect(ends, [1]);
    t.reset();
    await sub.cancel();
  });

  test('caixa da anotação fica dentro da tela e acima do teclado', () {
    const screen = Size(800, 1200), box = Size(520, 330);
    expect(clampNoteBox(const Offset(-200, -50), screen, box), const Offset(8, 24));
    expect(clampNoteBox(const Offset(900, 2000), screen, box), const Offset(272, 862));
    expect(clampNoteBox(const Offset(100, 900), screen, box, bottomInset: 400).dy, 462);
  });

  test('marcações da Bíblia: palavras e escrita guardadas por capítulo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ink = BibleInk(prefs)..open('blivre:0:1');
    ink.snapshot();
    ink.marks = [TextMark((1, 0), (1, 5), const Color(0xFFFFEB3B))];
    ink.strokes = [VerseStroke(2, const Color(0xFF1565C0), 0.003, [const Offset(0.1, 0.5), const Offset(0.4, 0.6)])];
    ink.commit();
    final again = BibleInk(prefs)..open('blivre:0:1');
    expect(again.marks.single.b, (1, 5));
    expect(again.strokes.single.verse, 2);
    expect(again.strokes.single.pts.last, const Offset(0.4, 0.6));
    again.undo(); // sem histórico nesta instância: nada muda
    expect(again.marks, hasLength(1));
    again.clear();
    expect(prefs.getString('tinta.blivre:0:1'), isNull);
    again.undo();
    expect(again.marks, hasLength(1));

    final geo = InkGeometry(GlobalKey(), const [], {1: 'No princípio criou Deus'}, 20);
    expect(geo.wordStart((1, 5)), (1, 3));
    expect(geo.wordEnd((1, 5)), (1, 12));
  });
}
