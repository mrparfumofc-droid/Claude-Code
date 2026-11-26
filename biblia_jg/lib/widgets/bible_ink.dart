import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ink_tools.dart';

/// Trecho do texto de um versículo dentro de um parágrafo desenhado na tela.
class InkRun {
  final int paraStart; // posição no texto do parágrafo
  final int verse;
  final int textStart; // posição no texto mostrado do versículo
  final int len;
  const InkRun(this.paraStart, this.verse, this.textStart, this.len);
}

/// Um parágrafo da leitura (um versículo, ou um bloco no layout clássico) e seus trechos.
class InkPara {
  final GlobalKey key;
  final List<InkRun> runs;
  InkPara(this.key, this.runs);

  RenderParagraph? get render {
    RenderParagraph? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderParagraph) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    final ro = key.currentContext?.findRenderObject();
    if (ro != null) visit(ro);
    return found;
  }
}

/// Monta os trechos de um parágrafo enquanto os spans são criados (conta a posição de cada um).
class InkSpanSink {
  final spans = <InlineSpan>[];
  final runs = <InkRun>[];
  int _offset = 0;

  void add(InlineSpan s) {
    spans.add(s);
    _offset += s is TextSpan ? (s.text?.length ?? 0) : 1;
  }

  void verseText(int verse, int textStart, TextSpan s) {
    final n = s.text?.length ?? 0;
    if (n > 0) runs.add(InkRun(_offset, verse, textStart, n));
    add(s);
  }
}

/// Posição no texto: versículo e caractere dentro do texto mostrado dele.
typedef TextPos = (int verse, int index);

int _cmp(TextPos a, TextPos b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;

/// Onde estão os versículos na tela (refeito a cada montagem da leitura).
class InkGeometry {
  final GlobalKey stackKey;
  final List<InkPara> paras;
  final Map<int, String> display;
  final double fontSize;
  InkGeometry(this.stackKey, this.paras, this.display, this.fontSize);

  RenderBox? get _stack => stackKey.currentContext?.findRenderObject() as RenderBox?;

  Iterable<(RenderParagraph, Offset, InkPara)> _laid() sync* {
    final stack = _stack;
    if (stack == null || !stack.hasSize) return;
    for (final p in paras) {
      final rp = p.render;
      if (rp == null || !rp.hasSize || !rp.attached) continue;
      yield (rp, rp.localToGlobal(Offset.zero, ancestor: stack), p);
    }
  }

  /// Caixas (no espaço da leitura) do texto entre [a] e [b].
  List<Rect> rects(TextPos a, TextPos b) {
    if (_cmp(a, b) > 0) (a, b) = (b, a);
    final out = <Rect>[];
    for (final (rp, origin, p) in _laid()) {
      for (final r in p.runs) {
        if (r.verse < a.$1 || r.verse > b.$1) continue;
        final s = r.verse == a.$1 ? math.max(a.$2, r.textStart) : r.textStart;
        final e = r.verse == b.$1 ? math.min(b.$2, r.textStart + r.len) : r.textStart + r.len;
        if (s >= e) continue;
        for (final box in rp.getBoxesForSelection(
            TextSelection(baseOffset: r.paraStart + s - r.textStart, extentOffset: r.paraStart + e - r.textStart))) {
          out.add(box.toRect().shift(origin));
        }
      }
    }
    return out;
  }

  /// Topo da primeira linha de cada versículo (âncora da escrita à mão).
  Map<int, double> verseTops() {
    final out = <int, double>{};
    for (final (rp, origin, p) in _laid()) {
      for (final r in p.runs) {
        if (out.containsKey(r.verse)) continue;
        final boxes = rp.getBoxesForSelection(TextSelection(baseOffset: r.paraStart, extentOffset: r.paraStart + 1));
        if (boxes.isNotEmpty) out[r.verse] = boxes.first.top + origin.dy;
      }
    }
    return out;
  }

  /// Caractere sob o ponto (ou o mais perto).
  TextPos? positionAt(Offset p) {
    (RenderParagraph, Offset, InkPara)? best;
    var bestD = double.infinity;
    for (final it in _laid()) {
      final rect = it.$2 & it.$1.size;
      final d = p.dy < rect.top ? rect.top - p.dy : (p.dy > rect.bottom ? p.dy - rect.bottom : 0.0);
      if (d < bestD) {
        bestD = d;
        best = it;
      }
      if (d == 0) break;
    }
    if (best == null) return null;
    final (rp, origin, para) = best;
    if (para.runs.isEmpty) return null;
    final off = rp.getPositionForOffset(p - origin).offset;
    for (final r in para.runs) {
      if (off < r.paraStart) return (r.verse, r.textStart);
      if (off <= r.paraStart + r.len) return (r.verse, r.textStart + off - r.paraStart);
    }
    final last = para.runs.last;
    return (last.verse, last.textStart + last.len);
  }

  bool _space(String s, int i) => i < 0 || i >= s.length || s.codeUnitAt(i) <= 32;

  /// Começo da palavra em [p].
  TextPos wordStart(TextPos p) {
    final s = display[p.$1] ?? '';
    var i = p.$2.clamp(0, s.length);
    while (i > 0 && !_space(s, i - 1)) {
      i--;
    }
    return (p.$1, i);
  }

  /// Fim da palavra em [p].
  TextPos wordEnd(TextPos p) {
    final s = display[p.$1] ?? '';
    var i = p.$2.clamp(0, s.length);
    while (i < s.length && !_space(s, i)) {
      i++;
    }
    return (p.$1, i);
  }
}

/// Marca-texto preso ao texto (acompanha o texto se a letra mudar de tamanho).
class TextMark {
  final TextPos a, b;
  final Color color;
  TextMark(this.a, this.b, this.color);

  List<int> toJson() => [a.$1, a.$2, b.$1, b.$2, color.toARGB32()];
  static TextMark? fromJson(Object? j) {
    if (j is! List || j.length < 5) return null;
    final v = [for (final x in j) (x as num).toInt()];
    return TextMark((v[0], v[1]), (v[2], v[3]), Color(v[4]));
  }
}

/// Escrita à mão presa a um versículo: x em fração da largura, y em "letras" a partir do topo dele.
class VerseStroke {
  final int verse;
  final Color color;
  final double width; // fração da largura do texto
  final List<Offset> pts;
  VerseStroke(this.verse, this.color, this.width, [List<Offset>? pts]) : pts = pts ?? [];

  Map<String, dynamic> toJson() => {
        'v': verse,
        'c': color.toARGB32(),
        'w': double.parse(width.toStringAsFixed(5)),
        'p': [
          for (final o in pts) ...[double.parse(o.dx.toStringAsFixed(4)), double.parse(o.dy.toStringAsFixed(3))]
        ],
      };

  static VerseStroke? fromJson(Object? j) {
    if (j is! Map) return null;
    final raw = (j['p'] as List? ?? const []).cast<num>();
    return VerseStroke((j['v'] as num).toInt(), Color((j['c'] as num).toInt()), (j['w'] as num).toDouble(), [
      for (var i = 0; i + 1 < raw.length; i += 2) Offset(raw[i].toDouble(), raw[i + 1].toDouble())
    ]);
  }
}

/// Marcações e escrita à mão de um capítulo (de uma versão), guardadas no aparelho.
class BibleInk extends ChangeNotifier {
  final SharedPreferences prefs;
  BibleInk(this.prefs);

  String _key = '';
  List<TextMark> marks = [];
  List<VerseStroke> strokes = [];
  final _history = <(List<TextMark>, List<VerseStroke>)>[];

  // Em andamento.
  TextMark? liveMark;
  VerseStroke? liveStroke;
  double liveTop = 0;
  Offset? eraserAt;

  bool get isEmpty => marks.isEmpty && strokes.isEmpty;
  bool get canUndo => _history.isNotEmpty;

  void open(String key) {
    if (key == _key) return;
    _key = key;
    marks = [];
    strokes = [];
    _history.clear();
    liveMark = null;
    liveStroke = null;
    try {
      final raw = prefs.getString('tinta.$key');
      if (raw != null) {
        final j = jsonDecode(raw) as Map;
        marks = [for (final m in j['m'] as List? ?? const []) ?TextMark.fromJson(m)];
        strokes = [for (final s in j['s'] as List? ?? const []) ?VerseStroke.fromJson(s)];
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() {
    if (_key.isEmpty) return;
    if (isEmpty) {
      prefs.remove('tinta.$_key');
    } else {
      prefs.setString(
          'tinta.$_key',
          jsonEncode({
            'm': [for (final m in marks) m.toJson()],
            's': [for (final s in strokes) s.toJson()],
          }));
    }
  }

  void snapshot() {
    _history.add((List.of(marks), List.of(strokes)));
    if (_history.length > 50) _history.removeAt(0);
  }

  void commit() {
    _save();
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    final (m, s) = _history.removeLast();
    marks = m;
    strokes = s;
    commit();
  }

  void clear() {
    if (isEmpty) return;
    snapshot();
    marks = [];
    strokes = [];
    commit();
  }

  void ping() => notifyListeners();
}

/// Desenha as marcações e a escrita sobre o texto.
class _BibleInkPainter extends CustomPainter {
  final BibleInk ink;
  final InkGeometry geo;
  final bool darkPage;
  _BibleInkPainter(this.ink, this.geo, this.darkPage) : super(repaint: ink);

  void _mark(Canvas canvas, TextMark m) {
    final c = m.color;
    final paint = Paint()
      ..color = darkPage ? c.withValues(alpha: 0.42 * c.a) : c.withValues(alpha: 0.55 * c.a)
      ..blendMode = darkPage ? BlendMode.srcOver : BlendMode.multiply;
    for (final r in geo.rects(m.a, m.b)) {
      canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(1).translate(0, 1), const Radius.circular(3)), paint);
    }
  }

  void _stroke(Canvas canvas, Size size, VerseStroke s, double top) {
    if (s.pts.length < 2) return;
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = math.max(1.0, s.width * size.width)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset at(Offset p) => Offset(p.dx * size.width, top + p.dy * geo.fontSize);
    final path = Path()..moveTo(at(s.pts.first).dx, at(s.pts.first).dy);
    for (var i = 1; i < s.pts.length; i++) {
      // Curvas entre os pontos médios deixam o traço macio.
      final p0 = at(s.pts[i - 1]), p1 = at(s.pts[i]);
      final mid = (p0 + p1) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    final last = at(s.pts.last);
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final m in ink.marks) {
      _mark(canvas, m);
    }
    if (ink.liveMark != null) _mark(canvas, ink.liveMark!);
    canvas.restore();
    if (ink.strokes.isNotEmpty) {
      final tops = geo.verseTops();
      for (final s in ink.strokes) {
        final top = tops[s.verse];
        if (top != null) _stroke(canvas, size, s, top);
      }
    }
    if (ink.liveStroke != null) _stroke(canvas, size, ink.liveStroke!, ink.liveTop);
    if (ink.eraserAt != null) {
      canvas.drawCircle(
          ink.eraserAt!,
          16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.grey);
    }
  }

  @override
  bool shouldRepaint(_BibleInkPainter old) => true;
}

/// Camada sobre o texto da Bíblia: marca-texto (preso às palavras), caneta e lápis (presos ao
/// versículo) e borracha. A caneta risca; o dedo continua rolando e selecionando versículos.
class BibleInkLayer extends StatefulWidget {
  final BibleInk ink;
  final InkToolbox? box; // null = só mostra (modo escrita desligado)
  final InkGeometry geo;
  final bool darkPage;
  const BibleInkLayer({super.key, required this.ink, required this.box, required this.geo, required this.darkPage});

  @override
  State<BibleInkLayer> createState() => _BibleInkLayerState();
}

class _BibleInkLayerState extends State<BibleInkLayer> {
  int? _pointer;
  TextPos? _anchor;
  bool _erasing = false;
  bool _marker = false;
  bool _changed = false;

  BibleInk get ink => widget.ink;
  InkGeometry get geo => widget.geo;

  void _down(PointerDownEvent e, Size size) {
    final box = widget.box!;
    if (InkToolbox.isStylus(e)) box.sawStylus();
    if (_pointer != null || !box.draws(e)) return;
    final penEraser = e.kind == PointerDeviceKind.invertedStylus ||
        (e.kind == PointerDeviceKind.stylus && (e.buttons & kSecondaryStylusButton) != 0);
    final p = e.localPosition;
    _pointer = e.pointer;
    _changed = false;
    _erasing = box.eraser || penEraser;
    if (_erasing) {
      ink.snapshot();
      _erase(p, size);
      return;
    }
    final preset = box.current;
    if (preset == null) {
      _pointer = null;
      return;
    }
    _marker = preset.kind == PenKind.marker;
    if (_marker) {
      final at = geo.positionAt(p);
      if (at == null) {
        _pointer = null;
        return;
      }
      _anchor = at;
      ink.liveMark = TextMark(geo.wordStart(at), geo.wordEnd(at), preset.color.withValues(alpha: preset.opacity));
    } else {
      // Âncora: o versículo cuja primeira linha começa acima do ponto.
      final tops = geo.verseTops();
      if (tops.isEmpty) {
        _pointer = null;
        return;
      }
      var verse = tops.keys.reduce(math.min);
      var top = tops[verse]!;
      tops.forEach((v, t) {
        if (t <= p.dy + 2 && t >= top) {
          verse = v;
          top = t;
        }
      });
      ink.liveTop = top;
      ink.liveStroke = VerseStroke(verse, preset.strokeColor, preset.width,
          [Offset(p.dx / size.width, (p.dy - top) / geo.fontSize)]);
    }
    ink.ping();
  }

  void _move(PointerMoveEvent e, Size size) {
    if (InkToolbox.isStylus(e)) widget.box?.lastStylus = DateTime.now();
    if (e.pointer != _pointer) return;
    final p = e.localPosition;
    if (_erasing) {
      _erase(p, size);
      return;
    }
    if (_marker) {
      final at = geo.positionAt(p);
      final a = _anchor, m = ink.liveMark;
      if (at == null || a == null || m == null) return;
      final forward = _cmp(at, a) >= 0;
      ink.liveMark = forward
          ? TextMark(geo.wordStart(a), geo.wordEnd(at), m.color)
          : TextMark(geo.wordStart(at), geo.wordEnd(a), m.color);
      ink.ping();
      return;
    }
    final s = ink.liveStroke;
    if (s == null) return;
    final q = Offset(p.dx / size.width, (p.dy - ink.liveTop) / geo.fontSize);
    final last = s.pts.last;
    if ((Offset((q.dx - last.dx) * size.width, (q.dy - last.dy) * geo.fontSize)).distance < 1.2) return;
    s.pts.add(q);
    ink.ping();
  }

  void _up(PointerEvent e, {bool cancel = false}) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    ink.eraserAt = null;
    if (_erasing) {
      _erasing = false;
      if (_changed) ink.commit();
      ink.ping();
      return;
    }
    final m = ink.liveMark, s = ink.liveStroke;
    ink.liveMark = null;
    ink.liveStroke = null;
    if (cancel) {
      ink.ping();
      return;
    }
    if (m != null && _cmp(m.a, m.b) < 0) {
      ink.snapshot();
      ink.marks = [...ink.marks, m];
      ink.commit();
    } else if (s != null && s.pts.length >= 2) {
      ink.snapshot();
      ink.strokes = [...ink.strokes, s];
      ink.commit();
    } else {
      ink.ping();
    }
  }

  void _erase(Offset p, Size size) {
    ink.eraserAt = p;
    const r = 16.0;
    final keepMarks = [
      for (final m in ink.marks)
        if (!geo.rects(m.a, m.b).any((rect) => rect.inflate(2).contains(p))) m
    ];
    final tops = geo.verseTops();
    final keepStrokes = [
      for (final s in ink.strokes)
        if (!(tops[s.verse] != null &&
            s.pts.any((q) => (Offset(q.dx * size.width, tops[s.verse]! + q.dy * geo.fontSize) - p).distance < r + s.width * size.width)))
          s
    ];
    if (keepMarks.length != ink.marks.length || keepStrokes.length != ink.strokes.length) {
      ink.marks = keepMarks;
      ink.strokes = keepStrokes;
      _changed = true;
    }
    ink.ping();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final paint = IgnorePointer(
        child: CustomPaint(painter: _BibleInkPainter(ink, geo, widget.darkPage), size: size),
      );
      if (box == null) return paint;
      return ListenableBuilder(
        listenable: box,
        builder: (context, _) {
          if (!box.drawing) return paint;
          return RawGestureDetector(
            // Translúcido: o dedo continua chegando ao texto (selecionar versículos, botões).
            behavior: HitTestBehavior.translucent,
            gestures: {
              DrawClaimRecognizer: GestureRecognizerFactoryWithHandlers<DrawClaimRecognizer>(
                () => DrawClaimRecognizer(box.claims),
                (_) {},
              ),
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerHover: (e) {
                if (InkToolbox.isStylus(e)) box.lastStylus = DateTime.now();
              },
              onPointerDown: (e) => _down(e, size),
              onPointerMove: (e) => _move(e, size),
              onPointerUp: _up,
              onPointerCancel: (e) => _up(e, cancel: true),
              child: paint,
            ),
          );
        },
      );
    });
  }
}
