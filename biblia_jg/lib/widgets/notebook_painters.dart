import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/notebook_models.dart';

const _w = nbPagePx;
const _h = nbPagePx * nbPageRatio;

/// Tamanho da página em pontos lógicos (antes do zoom).
const nbPageSize = Size(_w, _h);

/// Cor da tinta sobre o papel: no papel escuro, o preto vira quase branco para continuar legível.
Color nbInkColor(int argb, NbPaper paper) {
  final c = Color(argb);
  if (paper.isDark && c.computeLuminance() < 0.08) return Color.fromARGB((c.a * 255).round(), 0xF1, 0xF1, 0xEE);
  return c;
}

Color _lineColor(NbPaper paper) => paper.isDark ? const Color(0x2EFFFFFF) : const Color(0x2B1B2A49);
Color _labelColor(NbPaper paper) => paper.isDark ? const Color(0x8CFFFFFF) : const Color(0x991B2A49);

void _label(Canvas canvas, String text, Offset at, NbPaper paper, {double size = 15, double maxWidth = 600}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(color: _labelColor(paper), fontSize: size, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  tp.paint(canvas, at);
  tp.dispose();
}

void _rules(Canvas canvas, Paint line, double left, double right, double from, double to, [double step = 36]) {
  for (var y = from; y <= to + 0.5; y += step) {
    canvas.drawLine(Offset(left, y), Offset(right, y), line);
  }
}

/// Desenha o papel e o modelo da página (pauta, quadriculado, Cornell...). Tudo traçado aqui, sem imagens.
/// [scale] = tamanho em que a página aparece (1 = inteira): nas miniaturas as linhas engrossam para não sumir.
void nbPaintPaper(Canvas canvas, NbTemplate template, NbPaper paper, {double scale = 1}) {
  canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = paper.color);
  final small = scale < 0.3;
  final line = Paint()
    ..color = _lineColor(paper).withValues(alpha: small ? (paper.isDark ? 0.3 : 0.34) : null)
    ..strokeWidth = math.max(1.2, 0.5 / scale);
  final strong = Paint()
    ..color = _lineColor(paper).withValues(alpha: paper.isDark ? 0.34 : (small ? 0.42 : 0.3))
    ..strokeWidth = math.max(1.8, 0.8 / scale);
  final rule = small ? 72.0 : 36.0; // nas miniaturas, uma pauta sim, outra não
  const m = 56.0; // margem
  switch (template) {
    case NbTemplate.blank:
      break;
    case NbTemplate.ruled:
      canvas.drawLine(const Offset(m, 118), const Offset(_w - m, 118), strong);
      _rules(canvas, line, m, _w - m, 154, _h - 60, rule);
    case NbTemplate.grid:
      final step = small ? 50.0 : 25.0;
      for (var x = step; x < _w; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, _h), line);
      }
      for (var y = step; y < _h; y += step) {
        canvas.drawLine(Offset(0, y), Offset(_w, y), line);
      }
    case NbTemplate.dots:
      final dot = Paint()..color = _lineColor(paper).withValues(alpha: paper.isDark ? 0.36 : (small ? 0.5 : 0.4));
      final step = small ? 60.0 : 30.0;
      final radius = math.max(1.6, 0.9 / scale);
      for (var y = 30.0; y < _h; y += step) {
        for (var x = 20.0; x < _w; x += step) {
          canvas.drawCircle(Offset(x, y), radius, dot);
        }
      }
    case NbTemplate.cornell:
      const top = 128.0, side = 290.0, bottom = _h - 250;
      _label(canvas, 'Assunto', const Offset(m, 44), paper);
      _label(canvas, 'Data', const Offset(_w - 250, 44), paper);
      canvas.drawLine(const Offset(m, 96), const Offset(_w - 290, 96), line);
      canvas.drawLine(const Offset(_w - 250, 96), const Offset(_w - m, 96), line);
      canvas.drawLine(const Offset(m, top), const Offset(_w - m, top), strong);
      canvas.drawLine(const Offset(side, top), const Offset(side, bottom), strong);
      canvas.drawLine(const Offset(m, bottom), const Offset(_w - m, bottom), strong);
      _label(canvas, 'Tópicos e perguntas', const Offset(m, top + 12), paper, maxWidth: side - m - 12);
      _label(canvas, 'Anotações', const Offset(side + 18, top + 12), paper);
      _label(canvas, 'Resumo com as minhas palavras', const Offset(m, bottom + 12), paper);
      _rules(canvas, line, side + 18, _w - m, top + 76, bottom - 20, rule);
      _rules(canvas, line, m, _w - m, bottom + 76, _h - 60, rule);
    case NbTemplate.sermon:
      var y = 44.0;
      for (final (label, width) in const [('Tema', _w - 2 * m), ('Texto-base', 520.0)]) {
        _label(canvas, label, Offset(m, y), paper);
        canvas.drawLine(Offset(m, y + 56), Offset(m + width, y + 56), line);
        if (label == 'Texto-base') {
          _label(canvas, 'Data e local', Offset(m + 560, y), paper);
          canvas.drawLine(Offset(m + 560, y + 56), Offset(_w - m, y + 56), line);
        }
        y += 84;
      }
      canvas.drawLine(Offset(m, y + 4), Offset(_w - m, y + 4), strong);
      y += 22;
      for (final (label, lines) in const [
        ('Introdução', 4),
        ('1º ponto', 5),
        ('2º ponto', 5),
        ('3º ponto', 5),
        ('Conclusão e apelo', 4),
      ]) {
        _label(canvas, label, Offset(m, y), paper);
        _rules(canvas, line, m, _w - m, y + 60, y + 60 + (lines - 1) * 36.0, rule);
        y += 60 + lines * 36.0 + 12;
      }
    case NbTemplate.study:
      _label(canvas, 'Passagem', const Offset(m, 44), paper);
      canvas.drawLine(const Offset(m, 100), const Offset(_w - 320, 100), line);
      _label(canvas, 'Data', const Offset(_w - 280, 44), paper);
      canvas.drawLine(const Offset(_w - 280, 100), const Offset(_w - m, 100), line);
      var y = 132.0;
      for (final (label, lines) in const [
        ('O que o texto diz (observação)', 7),
        ('O que significa (interpretação)', 7),
        ('Como vou viver isso (aplicação)', 6),
        ('Oração', 4),
      ]) {
        canvas.drawLine(Offset(m, y), Offset(_w - m, y), strong);
        _label(canvas, label, Offset(m, y + 12), paper);
        _rules(canvas, line, m, _w - m, y + 76, y + 76 + (lines - 1) * 36.0, rule);
        y += 76 + lines * 36.0 + 8;
      }
  }
}

Path _smoothPath(NbStroke s) {
  final n = s.length;
  final path = Path();
  final p0 = s.at(0) * _w;
  path.moveTo(p0.dx, p0.dy);
  if (n == 2) {
    final p1 = s.at(1) * _w;
    path.lineTo(p1.dx, p1.dy);
    return path;
  }
  for (var i = 1; i + 1 < n; i++) {
    final c = s.at(i) * _w;
    final mid = (c + s.at(i + 1) * _w) / 2;
    path.quadraticBezierTo(c.dx, c.dy, mid.dx, mid.dy);
  }
  final last = s.at(n - 1) * _w;
  path.lineTo(last.dx, last.dy);
  return path;
}

/// Desenha um traço. O tinteiro engrossa com a pressão; as outras pontas têm espessura constante.
/// [minWidth] = espessura mínima (maior nas miniaturas, para o traço continuar visível).
void nbPaintStroke(Canvas canvas, NbStroke s, NbPaper paper, {double minWidth = 0.8}) {
  final n = s.length;
  if (n == 0) return;
  final base = nbInkColor(s.color, paper);
  final width = math.max(minWidth, s.width * _w);
  if (s.pen == NbPen.fountain) {
    final paint = Paint()
      ..color = base.withValues(alpha: 1)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final quads = Path();
    final dots = Path();
    Offset? prev;
    var prevR = 0.0;
    for (var i = 0; i < n; i++) {
      final p = s.at(i) * _w;
      final r = math.max(0.45, width * (0.28 + 1.25 * s.pressure(i)) / 2);
      dots.addOval(Rect.fromCircle(center: p, radius: r));
      if (prev != null) {
        final d = p - prev;
        final len = d.distance;
        if (len > 0.01) {
          final nrm = Offset(-d.dy, d.dx) / len;
          quads.addPolygon([prev - nrm * prevR, p - nrm * r, p + nrm * r, prev + nrm * prevR], true);
        }
      }
      prev = p;
      prevR = r;
    }
    canvas.drawPath(quads, paint);
    canvas.drawPath(dots, paint);
    return;
  }
  final marker = s.pen == NbPen.marker;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width
    ..isAntiAlias = true;
  if (marker) {
    paint
      ..color = base.withValues(alpha: (paper.isDark ? 0.45 : 0.38) * base.a)
      ..blendMode = paper.isDark ? BlendMode.srcOver : BlendMode.multiply;
  } else if (s.pen == NbPen.pencil) {
    paint.color = base.withValues(alpha: 0.78 * base.a);
  } else {
    paint.color = base;
  }
  if (n == 1) {
    final p = s.at(0) * _w;
    canvas.drawCircle(p, width / 2, paint..style = PaintingStyle.fill);
    return;
  }
  canvas.drawPath(_smoothPath(s), paint);
}

void nbPaintShape(Canvas canvas, NbShape s, NbPaper paper, {double minWidth = 0.8}) {
  final paint = Paint()
    ..color = nbInkColor(s.color, paper)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = math.max(minWidth, s.width * _w);
  final a = s.a * _w, b = s.b * _w;
  switch (s.kind) {
    case NbShapeKind.line:
      canvas.drawLine(a, b, paint);
    case NbShapeKind.arrow:
      canvas.drawLine(a, b, paint);
      final d = b - a;
      final len = d.distance;
      if (len > 1) {
        final u = d / len;
        final head = math.min(len * 0.4, 10 + paint.strokeWidth * 3.2);
        final nrm = Offset(-u.dy, u.dx);
        final back = b - u * head;
        canvas.drawPath(
            Path()
              ..moveTo(back.dx + nrm.dx * head * 0.5, back.dy + nrm.dy * head * 0.5)
              ..lineTo(b.dx, b.dy)
              ..lineTo(back.dx - nrm.dx * head * 0.5, back.dy - nrm.dy * head * 0.5),
            paint);
      }
    case NbShapeKind.rect:
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(a, b), const Radius.circular(2)), paint);
    case NbShapeKind.ellipse:
      canvas.drawOval(Rect.fromPoints(a, b), paint);
  }
}

/// Monta o texto de uma caixa (com a referência embaixo quando é um versículo).
TextPainter nbLayoutText(NbText t, NbPaper paper, {String? override}) {
  final color = nbInkColor(t.color, paper);
  final size = t.size * _w;
  final base = TextStyle(
    color: color,
    fontSize: size,
    height: 1.32,
    fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
    fontFamily: t.isVerse ? 'serif' : null,
  );
  final tp = TextPainter(
    text: TextSpan(style: base, children: [
      TextSpan(text: override ?? t.text),
      if (t.cite.isNotEmpty)
        TextSpan(
            text: '\n${t.cite}',
            style: TextStyle(
                fontSize: size * 0.82,
                fontWeight: FontWeight.w700,
                fontFamily: null,
                color: paper.isDark ? const Color(0xFFE2C25A) : const Color(0xFF8A6D10))),
    ]),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(40, t.w * _w));
  return tp;
}

/// Altura (relativa à largura da página) que o texto ocupa.
double nbMeasureText(NbText t) {
  final tp = nbLayoutText(t, NbPaper.white);
  final h = tp.height / _w;
  tp.dispose();
  return h;
}

/// Desenha os elementos da página: imagens, marca-texto (fica por baixo da tinta), traços e formas, textos.
void nbPaintItems(Canvas canvas, Iterable<NbItem> items, NbPaper paper, Map<String, ui.Image> images,
    {Set<String>? skip, double minWidth = 0.8}) {
  bool on(NbItem it) => skip == null || !skip.contains(it.id);
  for (final it in items) {
    if (it is NbImage && on(it)) {
      final rect = Rect.fromLTWH(it.x * _w, it.y * _w, it.w * _w, it.h * _w);
      final img = images[it.file];
      if (img == null) {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = _lineColor(paper));
      } else {
        canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), rect,
            Paint()..filterQuality = FilterQuality.medium);
      }
    }
  }
  for (final it in items) {
    if (it is NbStroke && it.pen == NbPen.marker && on(it)) nbPaintStroke(canvas, it, paper, minWidth: minWidth);
  }
  for (final it in items) {
    if (!on(it)) continue;
    if (it is NbStroke && it.pen != NbPen.marker) nbPaintStroke(canvas, it, paper, minWidth: minWidth);
    if (it is NbShape) nbPaintShape(canvas, it, paper, minWidth: minWidth);
  }
  for (final it in items) {
    if (it is NbText && on(it)) {
      final tp = nbLayoutText(it, paper);
      tp.paint(canvas, Offset(it.x * _w, it.y * _w));
      tp.dispose();
    }
  }
}

/// Camada pronta da página: papel, modelo e tudo o que já foi escrito. Só é refeita quando [repaint] avisa.
class NbPagePainter extends CustomPainter {
  final NbPage page;
  final Map<String, ui.Image> images;
  final Set<String> Function()? skip;

  // Estado da página quando este pintor foi criado: se mudou, a camada é refeita.
  final List<NbItem> _items;
  final NbTemplate _template;
  final NbPaper _paper;
  final int _imageCount;
  NbPagePainter(this.page, this.images, {this.skip, super.repaint})
      : _items = page.items,
        _template = page.template,
        _paper = page.paper,
        _imageCount = images.length;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = size.width / _w;
    canvas.scale(scale);
    nbPaintPaper(canvas, page.template, page.paper, scale: scale);
    nbPaintItems(canvas, page.items, page.paper, images, skip: skip?.call(), minWidth: math.max(0.8, 0.9 / scale));
    canvas.restore();
  }

  @override
  bool shouldRepaint(NbPagePainter old) =>
      old.page != page ||
      !identical(old._items, _items) ||
      old._template != _template ||
      old._paper != _paper ||
      old._imageCount != _imageCount;
}

/// Miniatura de uma página (mesmo desenho, reduzido).
class NbPageThumb extends StatelessWidget {
  final NbPage page;
  final Map<String, ui.Image> images;
  final Listenable? repaint;
  const NbPageThumb({super.key, required this.page, this.images = const {}, this.repaint});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1 / nbPageRatio,
        child: RepaintBoundary(
          child: CustomPaint(painter: NbPagePainter(page, images, repaint: repaint), isComplex: true),
        ),
      );
}

/// Gera a imagem de uma página (para compartilhar).
Future<ui.Image> nbRenderPage(NbPage page, Map<String, ui.Image> images, {double width = 1600}) {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final size = Size(width, width * nbPageRatio);
  NbPagePainter(page, images).paint(canvas, size);
  return rec.endRecording().toImage(size.width.round(), size.height.round());
}

/// Capas dos cadernos, desenhadas pelo app: tecido liso, com elástico, costurada ou em duas cores.
const nbCoverColors = <int>[
  0xFF1B2A49, 0xFF7A1F2B, 0xFF1F5B4A, 0xFF8A5A14, 0xFF4A3470, 0xFF2F4858, 0xFFB5651D, 0xFF3D3D3D, 0xFF0F6E84, 0xFF8C3B5E,
];
const nbCoverStyles = <String>['Tecido', 'Elástico', 'Costurada', 'Duas cores'];

class NbCoverPainter extends CustomPainter {
  final Color color;
  final int style;
  const NbCoverPainter(this.color, this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(Offset.zero & size,
        topLeft: const Radius.circular(4),
        bottomLeft: const Radius.circular(4),
        topRight: const Radius.circular(12),
        bottomRight: const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(r);
    final dark = Color.lerp(color, Colors.black, 0.28)!;
    final light = Color.lerp(color, Colors.white, 0.1)!;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [light, color, dark], const [0, 0.45, 1]));
    // Trama do tecido: fios finos na diagonal.
    final thread = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var d = -size.height; d < size.width; d += 5) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), thread);
    }
    const gold = Color(0xFFD9B95B);
    switch (style % nbCoverStyles.length) {
      case 1:
        final x = size.width * 0.84;
        canvas.drawRect(Rect.fromLTWH(x, 0, size.width * 0.06, size.height), Paint()..color = Colors.black.withValues(alpha: 0.42));
      case 2:
        final stitch = Paint()
          ..color = gold.withValues(alpha: 0.8)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final inset = size.width * 0.07;
        final rect = Rect.fromLTRB(inset + size.width * 0.04, inset, size.width - inset, size.height - inset);
        for (var x = rect.left; x < rect.right - 4; x += 9) {
          canvas.drawLine(Offset(x, rect.top), Offset(x + 5, rect.top), stitch);
          canvas.drawLine(Offset(x, rect.bottom), Offset(x + 5, rect.bottom), stitch);
        }
        for (var y = rect.top; y < rect.bottom - 4; y += 9) {
          canvas.drawLine(Offset(rect.left, y), Offset(rect.left, y + 5), stitch);
          canvas.drawLine(Offset(rect.right, y), Offset(rect.right, y + 5), stitch);
        }
      case 3:
        final y = size.height * 0.68;
        canvas.drawRect(Rect.fromLTRB(0, y, size.width, size.height), Paint()..color = Colors.black.withValues(alpha: 0.3));
        canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y),
            Paint()
              ..color = gold
              ..strokeWidth = 2);
      default:
        break;
    }
    // Dobra da lombada.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.045, size.height), Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawLine(Offset(size.width * 0.07, 0), Offset(size.width * 0.07, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.restore();
  }

  @override
  bool shouldRepaint(NbCoverPainter old) => old.color != color || old.style != style;
}
