import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:biblia_jg/models/bible.dart';
import 'package:biblia_jg/models/reference_parser.dart';
import 'package:biblia_jg/screens/notebook_editor_screen.dart' show verseItem;
import 'package:biblia_jg/services/notebook_models.dart';
import 'package:biblia_jg/services/notebook_store.dart';
import 'package:biblia_jg/widgets/notebook_canvas.dart';
import 'package:biblia_jg/widgets/notebook_painters.dart';
import 'package:biblia_jg/widgets/notebook_tools.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

NbStroke _line(Offset a, Offset b, {int n = 20, NbPen pen = NbPen.ball}) => NbStroke('s${a.dx}-${b.dx}', pen, 0xFF1A1A1A, 0.003, [
      for (var i = 0; i <= n; i++) ...[a.dx + (b.dx - a.dx) * i / n, a.dy + (b.dy - a.dy) * i / n, 0.5],
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelo do caderno', () {
    test('página vai e volta do JSON com todos os tipos de elemento', () {
      final page = NbPage('p1', NbTemplate.cornell, NbPaper.cream, [
        _line(const Offset(0.1, 0.1), const Offset(0.4, 0.2), pen: NbPen.fountain),
        const NbShape('f1', NbShapeKind.arrow, Offset(0.2, 0.3), Offset(0.6, 0.5), 0xFFD32F2F, 0.004),
        const NbText('t1', 0.1, 0.6, 0.5, 0.08, 0.026, 0xFF1565C0, 'Graça e paz', bold: true),
        const NbText('t2', 0.1, 0.8, 0.7, 0.1, 0.026, 0xFF1A1A1A, '“Porque Deus amou…”',
            cite: 'João 3:16 · ARA', refBook: 42, refChapter: 3, refVerse: 16),
        const NbImage('i1', 0.3, 0.9, 0.4, 0.3, 'img-abc.png'),
      ], 123);
      final back = NbPage.fromJson(jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>);
      expect(back.id, 'p1');
      expect(back.template, NbTemplate.cornell);
      expect(back.paper, NbPaper.cream);
      expect(back.updated, 123);
      expect(back.items.map((e) => e.runtimeType).toList(), [NbStroke, NbShape, NbText, NbText, NbImage]);
      final s = back.items[0] as NbStroke;
      expect(s.pen, NbPen.fountain);
      expect(s.length, 21);
      expect(s.at(20).dx, closeTo(0.4, 1e-4));
      final verse = back.items[3] as NbText;
      expect(verse.isVerse, isTrue);
      expect((verse.refBook, verse.refChapter, verse.refVerse), (42, 3, 16));
      expect((back.items[2] as NbText).bold, isTrue);
      expect((back.items[4] as NbImage).file, 'img-abc.png');
    });

    test('elemento estragado no JSON é ignorado, o resto da página abre', () {
      final page = NbPage.fromJson({
        'id': 'p',
        'it': [
          {'k': 's', 'p': 'ruim'},
          {'k': '??'},
          {'k': 'f', 'f': 0, 'a': [0.1, 0.1], 'b': [0.2, 0.2]},
        ],
      });
      expect(page.items, hasLength(1));
      expect(page.items.single, isA<NbShape>());
    });

    test('mover e redimensionar mantém as proporções', () {
      final s = _line(const Offset(0.2, 0.2), const Offset(0.4, 0.2));
      final moved = s.transformed(origin: const Offset(0.2, 0.2), scale: 2, shift: const Offset(0.1, 0.05));
      expect(moved.at(0).dx, closeTo(0.3, 1e-9));
      expect(moved.at(0).dy, closeTo(0.25, 1e-9));
      expect(moved.at(20).dx, closeTo(0.7, 1e-9));
      expect(moved.width, closeTo(0.006, 1e-9));
      expect(moved.id, s.id);
      expect(s.transformed(id: 'novo').id, 'novo');
      const t = NbText('t', 0.2, 0.2, 0.4, 0.1, 0.02, 0xFF000000, 'oi');
      final big = t.transformed(origin: const Offset(0.2, 0.2), scale: 1.5);
      expect(big.size, closeTo(0.03, 1e-9));
      expect(big.w, closeTo(0.6, 1e-9));
    });

    test('caderno guarda capa, pasta e ordem das páginas', () {
      final b = NbBook(
          id: nbUuid(), title: 'Romanos', coverColor: 0xFF7A1F2B, coverStyle: 2, folder: 'EBD', favorite: true, created: 1, updated: 2,
          pageIds: ['a', 'b', 'c'], template: NbTemplate.study, paper: NbPaper.dark, lastPage: 2);
      final back = NbBook.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(back.title, 'Romanos');
      expect(back.pageIds, ['a', 'b', 'c']);
      expect((back.folder, back.favorite, back.coverStyle, back.template, back.paper, back.lastPage),
          ('EBD', true, 2, NbTemplate.study, NbPaper.dark, 2));
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(b.id), isTrue);
    });
  });

  group('geometria', () {
    test('toque acerta o traço e erra longe dele', () {
      final s = _line(const Offset(0.1, 0.5), const Offset(0.9, 0.5));
      expect(s.hit(const Offset(0.5, 0.505), 0.01), isTrue);
      expect(s.hit(const Offset(0.5, 0.6), 0.01), isFalse);
      const ell = NbShape('e', NbShapeKind.ellipse, Offset(0.2, 0.2), Offset(0.6, 0.4), 0xFF000000, 0.003);
      expect(ell.hit(const Offset(0.2, 0.3), 0.01), isTrue); // na borda
      expect(ell.hit(const Offset(0.4, 0.3), 0.01), isFalse); // no meio (é só contorno)
    });

    test('laço: ponto dentro e fora do polígono', () {
      const square = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
      expect(nbPointInPolygon(const Offset(0.5, 0.5), square), isTrue);
      expect(nbPointInPolygon(const Offset(1.5, 0.5), square), isFalse);
    });

    test('borracha parcial corta o traço em dois', () {
      final s = _line(const Offset(0.1, 0.5), const Offset(0.9, 0.5), n: 80);
      expect(nbErasePartial(s, const Offset(0.5, 0.8), 0.02), isNull);
      final parts = nbErasePartial(s, const Offset(0.5, 0.5), 0.03)!;
      expect(parts, hasLength(2));
      expect(parts[0].at(parts[0].length - 1).dx, lessThan(0.48));
      expect(parts[1].at(0).dx, greaterThan(0.52));
      expect(parts[0].id, isNot(s.id));
      // Apagar a ponta deixa um pedaço só.
      expect(nbErasePartial(s, const Offset(0.1, 0.5), 0.03), hasLength(1));
    });

    test('segurar no fim do traço: linha, círculo e retângulo', () {
      // Linha um pouco torta vira reta.
      final wobbly = NbStroke('w', NbPen.ball, 0xFF000000, 0.003, [
        for (var i = 0; i <= 30; i++) ...[0.1 + 0.02 * i, 0.3 + (i.isEven ? 0.002 : -0.002), 0.5],
      ]);
      final line = nbRecognizeShape(wobbly)!;
      expect(line.kind, NbShapeKind.line);
      expect(line.a.dx, closeTo(0.1, 1e-6));
      expect(line.b.dx, closeTo(0.7, 1e-6));

      final circle = NbStroke('c', NbPen.ball, 0xFF000000, 0.003, [
        for (var i = 0; i <= 60; i++) ...[
          0.5 + 0.2 * math.cos(i / 60 * 2 * math.pi),
          0.5 + 0.15 * math.sin(i / 60 * 2 * math.pi),
          0.5,
        ],
      ]);
      expect(nbRecognizeShape(circle)!.kind, NbShapeKind.ellipse);

      final pts = <double>[];
      void side(Offset a, Offset b) {
        for (var i = 0; i < 15; i++) {
          pts.addAll([a.dx + (b.dx - a.dx) * i / 15, a.dy + (b.dy - a.dy) * i / 15, 0.5]);
        }
      }

      side(const Offset(0.2, 0.2), const Offset(0.6, 0.2));
      side(const Offset(0.6, 0.2), const Offset(0.6, 0.5));
      side(const Offset(0.6, 0.5), const Offset(0.2, 0.5));
      side(const Offset(0.2, 0.5), const Offset(0.2, 0.2));
      final rect = nbRecognizeShape(NbStroke('r', NbPen.ball, 0xFF000000, 0.003, pts))!;
      expect(rect.kind, NbShapeKind.rect);
      expect(Rect.fromPoints(rect.a, rect.b).width, closeTo(0.4, 0.01));

      // Rabisco qualquer continua rabisco.
      final scribble = NbStroke('z', NbPen.ball, 0xFF000000, 0.003, [
        for (var i = 0; i <= 40; i++) ...[0.1 + 0.01 * i, 0.3 + (i % 4 < 2 ? 0.08 : -0.08), 0.5],
      ]);
      expect(nbRecognizeShape(scribble), isNull);
    });

    test('estabilizador aproxima do ponto sem ultrapassar', () {
      final st = NbStreamline(0.5);
      expect(st.next(const Offset(0, 0)), const Offset(0, 0));
      expect(st.next(const Offset(1, 0)).dx, closeTo(0.5, 1e-9));
      expect(st.next(const Offset(1, 0)).dx, closeTo(0.75, 1e-9));
    });
  });

  group('depósito (no aparelho, sem nuvem)', () {
    test('cria, escreve, reordena, duplica e apaga', () async {
      final store = NotebookStore.memory();
      await store.load();
      expect(store.books, isEmpty);
      expect(store.cloud, isFalse);

      final b = await store.create(title: '  Sermões  ', coverColor: 0xFF1B2A49, template: NbTemplate.sermon, folder: 'Púlpito');
      expect(b.title, 'Sermões');
      expect(b.pageIds, hasLength(1));
      expect(store.folders, ['Púlpito']);

      final first = await store.page(b, b.pageIds.first);
      expect(first.template, NbTemplate.sermon);
      first.items = [_line(const Offset(0.1, 0.1), const Offset(0.3, 0.3))];
      await store.savePage(b, first);

      final second = await store.addPage(b, after: 0, template: NbTemplate.grid);
      expect(b.pageIds, [first.id, second.id]);
      final copy = await store.addPage(b, after: 0, copyOf: first);
      expect(b.pageIds, [first.id, copy.id, second.id]);
      expect(copy.items, hasLength(1));
      expect(copy.items.single.id, isNot(first.items.single.id));

      await store.removePage(b, second.id);
      expect(b.pageIds, [first.id, copy.id]);

      final twin = await store.duplicate(b);
      expect(twin.id, isNot(b.id));
      expect(twin.pageIds, hasLength(2));
      expect((await store.page(twin, twin.pageIds.first)).items, hasLength(1));

      await store.deleteBook(b);
      expect(store.books.map((x) => x.id), [twin.id]);
      // A última página nunca é apagada.
      await store.removePage(twin, twin.pageIds.last);
      await store.removePage(twin, twin.pageIds.last);
      expect(twin.pageIds, hasLength(1));
    });
  });

  group('sessão de escrita', () {
    late NotebookStore store;
    late NbBook book;
    late NbSession s;
    late String page;
    var pointer = 100;

    PointerDownEvent down(Offset p) => PointerDownEvent(pointer: ++pointer, kind: PointerDeviceKind.stylus, position: p * 1000, pressure: 0.6, pressureMin: 0, pressureMax: 1);
    void stroke(List<Offset> pts) {
      final d = down(pts.first);
      s.down(page, d, pts.first);
      for (final p in pts.skip(1)) {
        s.move(page, PointerMoveEvent(pointer: d.pointer, kind: PointerDeviceKind.stylus, position: p * 1000, pressure: 0.6, pressureMin: 0, pressureMax: 1), p);
      }
      s.up(page, PointerUpEvent(pointer: d.pointer, kind: PointerDeviceKind.stylus, position: pts.last * 1000), pts.last);
    }

    setUp(() async {
      store = NotebookStore.memory();
      await store.load();
      book = await store.create(title: 'Teste', coverColor: 0xFF1B2A49);
      final box = NbToolbox.memory()
        ..smoothing = 0
        ..holdToStraighten = false;
      s = NbSession(store, book, box);
      page = book.pageIds.first;
      await s.ensure(page);
    });

    tearDown(() => s.dispose());

    test('escrever, desfazer e refazer', () {
      stroke([for (var i = 0; i <= 10; i++) Offset(0.2 + 0.03 * i, 0.3)]);
      expect(s.pages[page]!.items, hasLength(1));
      final made = s.pages[page]!.items.single as NbStroke;
      expect(made.length, greaterThanOrEqualTo(10));
      expect(made.pressure(3), closeTo(0.6, 1e-9));
      expect(s.live.stroke, isNull);
      expect(s.canUndo, isTrue);
      s.undo();
      expect(s.pages[page]!.items, isEmpty);
      expect(s.canRedo, isTrue);
      s.redo();
      expect(s.pages[page]!.items, hasLength(1));
    });

    test('borracha de traço inteiro e laço que move', () {
      stroke([for (var i = 0; i <= 10; i++) Offset(0.2 + 0.03 * i, 0.3)]);
      stroke([for (var i = 0; i <= 10; i++) Offset(0.2 + 0.03 * i, 0.8)]);
      expect(s.pages[page]!.items, hasLength(2));

      s.box.setMode(NbMode.eraser);
      stroke([const Offset(0.35, 0.25), const Offset(0.35, 0.3), const Offset(0.35, 0.35)]);
      expect(s.pages[page]!.items, hasLength(1));
      s.undo();
      expect(s.pages[page]!.items, hasLength(2));

      // Laço em volta do traço de cima.
      s.box.setMode(NbMode.lasso);
      stroke(const [Offset(0.1, 0.2), Offset(0.6, 0.2), Offset(0.6, 0.4), Offset(0.1, 0.4), Offset(0.1, 0.22)]);
      expect(s.live.selection?.items, hasLength(1));
      final before = (s.live.selection!.items.single as NbStroke).at(0);
      // Arrasta a seleção 0,1 para baixo.
      stroke(const [Offset(0.3, 0.3), Offset(0.3, 0.35), Offset(0.3, 0.4)]);
      final after = (s.live.selection!.items.single as NbStroke).at(0);
      expect(after.dy - before.dy, closeTo(0.1, 1e-6));
      expect(s.skipFor(page), hasLength(1));

      s.duplicateSelection();
      expect(s.pages[page]!.items, hasLength(3));
      s.deleteSelection();
      expect(s.pages[page]!.items, hasLength(2));
      expect(s.hasSelection, isFalse);
    });

    test('forma e salvamento automático', () async {
      s.box
        ..shape = NbShapeKind.rect
        ..setMode(NbMode.shape);
      stroke(const [Offset(0.2, 0.2), Offset(0.4, 0.3), Offset(0.5, 0.5)]);
      final shape = s.pages[page]!.items.single as NbShape;
      expect(shape.kind, NbShapeKind.rect);
      expect(shape.b, const Offset(0.5, 0.5));
      await s.flush();
      // Outro depósito de memória não enxerga; o mesmo depósito devolve a página gravada.
      expect((await store.page(book, page)).items, hasLength(1));
    });
  });

  test('versículo vira caixa de texto com referência', () {
    final bible = Bible(id: 't', name: 'Teste', abbrev: 'TST', copyright: '', books: [
      for (var i = 0; i < 43; i++)
        Book(index: i, name: canonicalBooks[i].name, abbrev: canonicalBooks[i].abbrev, chapters: [
          ['um', 'dois', 'três <J>quatro</J>'],
          ['a', 'b'],
        ]),
    ]);
    final one = verseItem(bible, parseReference('Jo 1:3')!)!;
    expect(one.text, '“três quatro”');
    expect(one.cite, contains('1:3'));
    expect(one.cite, contains('TST'));
    expect((one.refBook, one.refChapter, one.refVerse), (42, 1, 3));
    expect(one.h, greaterThan(0));
    final many = verseItem(bible, parseReference('Jo 1:1-2')!)!;
    expect(many.text, '“1 um 2 dois”');
    expect(verseItem(bible, parseReference('Jo 1:9')!), isNull);
    expect(verseItem(bible, parseReference('Jo 1')!), isNull);
  });

  test('tinta preta fica clara no papel escuro; texto mede altura', () {
    expect(nbInkColor(0xFF1A1A1A, NbPaper.dark).computeLuminance(), greaterThan(0.7));
    expect(nbInkColor(0xFF1A1A1A, NbPaper.white), const Color(0xFF1A1A1A));
    expect(nbInkColor(0xFFD32F2F, NbPaper.dark), const Color(0xFFD32F2F));
    const short = NbText('a', 0.1, 0.1, 0.5, 0, 0.026, 0xFF000000, 'Uma linha');
    final long = short.copyWith(text: List.filled(40, 'palavra').join(' '));
    expect(nbMeasureText(long), greaterThan(nbMeasureText(short) * 2));
  });
}
