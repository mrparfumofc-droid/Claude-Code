import 'dart:math' as math;
import 'dart:ui';

/// Tipos de caneta do caderno.
enum NbPen { ball, fountain, pencil, marker }

/// Modelos de página (desenhados pelo próprio app).
enum NbTemplate { blank, ruled, grid, dots, cornell, sermon, study }

/// Cor do papel.
enum NbPaper { white, cream, dark }

enum NbShapeKind { line, arrow, rect, ellipse }

/// Altura da página em relação à largura (folha em pé).
const nbPageRatio = 1.4142;

/// Largura lógica da página: tudo é desenhado nela e ampliado pelo zoom.
const nbPagePx = 1000.0;

extension NbPenInfo on NbPen {
  String get label => switch (this) {
        NbPen.ball => 'Esferográfica',
        NbPen.fountain => 'Tinteiro',
        NbPen.pencil => 'Lápis',
        NbPen.marker => 'Marca-texto',
      };
}

extension NbTemplateInfo on NbTemplate {
  String get label => switch (this) {
        NbTemplate.blank => 'Em branco',
        NbTemplate.ruled => 'Pautada',
        NbTemplate.grid => 'Quadriculada',
        NbTemplate.dots => 'Pontilhada',
        NbTemplate.cornell => 'Cornell',
        NbTemplate.sermon => 'Esboço de sermão',
        NbTemplate.study => 'Estudo bíblico',
      };
}

extension NbPaperInfo on NbPaper {
  String get label => switch (this) { NbPaper.white => 'Branco', NbPaper.cream => 'Creme', NbPaper.dark => 'Escuro' };
  Color get color => switch (this) {
        NbPaper.white => const Color(0xFFFFFFFF),
        NbPaper.cream => const Color(0xFFFBF4DF),
        NbPaper.dark => const Color(0xFF20242B),
      };
  bool get isDark => this == NbPaper.dark;
}

extension NbShapeInfo on NbShapeKind {
  String get label => switch (this) {
        NbShapeKind.line => 'Linha',
        NbShapeKind.arrow => 'Seta',
        NbShapeKind.rect => 'Retângulo',
        NbShapeKind.ellipse => 'Elipse',
      };
}

final _rnd = math.Random.secure();

/// Identificador curto (itens e páginas).
String nbShortId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes([for (var i = 0; i < 10; i++) chars.codeUnitAt(_rnd.nextInt(chars.length))]);
}

/// UUID v4 (o caderno usa UUID porque é a chave na nuvem).
String nbUuid() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

double _r4(double v) => (v * 10000).roundToDouble() / 10000;
double _r5(double v) => (v * 100000).roundToDouble() / 100000;
double _num(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

Offset _tp(Offset p, Offset origin, double scale, Offset shift) => origin + (p - origin) * scale + shift;

/// Distância de [p] ao segmento [a]–[b].
double nbDistToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 < 1e-12) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// [p] está dentro do polígono (laço)?
bool nbPointInPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
  }
  return inside;
}

/// Um elemento da página: traço, forma, caixa de texto ou imagem.
/// Coordenadas e tamanhos relativos à LARGURA da página (x de 0 a 1; y de 0 a [nbPageRatio]).
sealed class NbItem {
  final String id;
  const NbItem(this.id);

  Rect get bounds;
  Map<String, dynamic> toJson();

  /// Cópia ampliada em volta de [origin] e deslocada por [shift] (mover, redimensionar, duplicar).
  NbItem transformed({Offset origin = Offset.zero, double scale = 1, Offset shift = Offset.zero, String? id});
  NbItem recolored(int color);

  /// O ponto [p] toca este elemento (com folga [r])?
  bool hit(Offset p, double r);

  static NbItem? fromJson(Map<String, dynamic> j) {
    try {
      return switch (j['k']) {
        's' => NbStroke.fromJson(j),
        'f' => NbShape.fromJson(j),
        't' => NbText.fromJson(j),
        'i' => NbImage.fromJson(j),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// Traço à mão: pontos (x, y, pressão) em sequência.
final class NbStroke extends NbItem {
  final NbPen pen;
  final int color;
  final double width;
  final List<double> pts;
  NbStroke(super.id, this.pen, this.color, this.width, this.pts);

  int get length => pts.length ~/ 3;
  Offset at(int i) => Offset(pts[i * 3], pts[i * 3 + 1]);
  double pressure(int i) => pts[i * 3 + 2];

  /// Acrescenta um ponto (só enquanto o traço está sendo feito).
  void add(Offset p, double pressure) {
    pts
      ..add(p.dx)
      ..add(p.dy)
      ..add(pressure);
    _bounds = null;
  }

  Rect? _bounds;

  @override
  Rect get bounds {
    final cached = _bounds;
    if (cached != null) return cached;
    if (pts.length < 3) return Rect.zero;
    var l = pts[0], t = pts[1], r = pts[0], b = pts[1];
    for (var i = 3; i + 1 < pts.length; i += 3) {
      l = math.min(l, pts[i]);
      r = math.max(r, pts[i]);
      t = math.min(t, pts[i + 1]);
      b = math.max(b, pts[i + 1]);
    }
    return _bounds = Rect.fromLTRB(l, t, r, b).inflate(width);
  }

  @override
  bool hit(Offset p, double r) {
    if (!bounds.inflate(r).contains(p)) return false;
    final reach = r + width / 2;
    final n = length;
    if (n == 1) return (at(0) - p).distance <= reach;
    for (var i = 0; i + 1 < n; i++) {
      if (nbDistToSegment(p, at(i), at(i + 1)) <= reach) return true;
    }
    return false;
  }

  @override
  NbStroke transformed({Offset origin = Offset.zero, double scale = 1, Offset shift = Offset.zero, String? id}) {
    final out = List<double>.filled(pts.length, 0);
    for (var i = 0; i + 2 < pts.length; i += 3) {
      final q = _tp(Offset(pts[i], pts[i + 1]), origin, scale, shift);
      out[i] = q.dx;
      out[i + 1] = q.dy;
      out[i + 2] = pts[i + 2];
    }
    return NbStroke(id ?? this.id, pen, color, width * scale, out);
  }

  @override
  NbStroke recolored(int color) => NbStroke(id, pen, color, width, pts);

  @override
  Map<String, dynamic> toJson() => {
        'k': 's',
        'i': id,
        't': pen.index,
        'c': color,
        'w': _r5(width),
        'p': [
          for (var i = 0; i + 2 < pts.length; i += 3) ...[_r4(pts[i]), _r4(pts[i + 1]), (pts[i + 2] * 100).roundToDouble() / 100]
        ],
      };

  factory NbStroke.fromJson(Map<String, dynamic> j) => NbStroke(
        j['i'] as String? ?? nbShortId(),
        NbPen.values[_int(j['t']).clamp(0, NbPen.values.length - 1)],
        _int(j['c'], 0xFF1A1A1A),
        _num(j['w'], 0.003),
        [for (final v in j['p'] as List) (v as num).toDouble()],
      );
}

/// Forma geométrica entre dois cantos.
final class NbShape extends NbItem {
  final NbShapeKind kind;
  final Offset a;
  final Offset b;
  final int color;
  final double width;
  const NbShape(super.id, this.kind, this.a, this.b, this.color, this.width);

  @override
  Rect get bounds => Rect.fromPoints(a, b).inflate(width + (kind == NbShapeKind.arrow ? 0.012 : 0));

  @override
  bool hit(Offset p, double r) {
    final reach = r + width / 2;
    switch (kind) {
      case NbShapeKind.line:
      case NbShapeKind.arrow:
        return nbDistToSegment(p, a, b) <= reach;
      case NbShapeKind.rect:
        final rc = Rect.fromPoints(a, b);
        return nbDistToSegment(p, rc.topLeft, rc.topRight) <= reach ||
            nbDistToSegment(p, rc.topRight, rc.bottomRight) <= reach ||
            nbDistToSegment(p, rc.bottomRight, rc.bottomLeft) <= reach ||
            nbDistToSegment(p, rc.bottomLeft, rc.topLeft) <= reach;
      case NbShapeKind.ellipse:
        final rc = Rect.fromPoints(a, b);
        final rx = rc.width / 2, ry = rc.height / 2;
        if (rx < 1e-6 || ry < 1e-6) return nbDistToSegment(p, a, b) <= reach;
        final d = p - rc.center;
        final k = math.sqrt((d.dx / rx) * (d.dx / rx) + (d.dy / ry) * (d.dy / ry));
        return (k - 1).abs() * math.min(rx, ry) <= reach;
    }
  }

  @override
  NbShape transformed({Offset origin = Offset.zero, double scale = 1, Offset shift = Offset.zero, String? id}) =>
      NbShape(id ?? this.id, kind, _tp(a, origin, scale, shift), _tp(b, origin, scale, shift), color, width * scale);

  @override
  NbShape recolored(int color) => NbShape(id, kind, a, b, color, width);

  @override
  Map<String, dynamic> toJson() => {
        'k': 'f',
        'i': id,
        'f': kind.index,
        'c': color,
        'w': _r5(width),
        'a': [_r4(a.dx), _r4(a.dy)],
        'b': [_r4(b.dx), _r4(b.dy)],
      };

  factory NbShape.fromJson(Map<String, dynamic> j) {
    final a = j['a'] as List, b = j['b'] as List;
    return NbShape(
      j['i'] as String? ?? nbShortId(),
      NbShapeKind.values[_int(j['f']).clamp(0, NbShapeKind.values.length - 1)],
      Offset(_num(a[0]), _num(a[1])),
      Offset(_num(b[0]), _num(b[1])),
      _int(j['c'], 0xFF1A1A1A),
      _num(j['w'], 0.003),
    );
  }
}

/// Caixa de texto. Com [cite], é um versículo inserido da Bíblia (livro [refBook], capítulo, versículo).
final class NbText extends NbItem {
  final double x;
  final double y;
  final double w;

  /// Altura medida na última edição (para o laço e o toque).
  final double h;
  final double size;
  final int color;
  final String text;
  final bool bold;
  final String cite;
  final int refBook;
  final int refChapter;
  final int refVerse;
  const NbText(super.id, this.x, this.y, this.w, this.h, this.size, this.color, this.text,
      {this.bold = false, this.cite = '', this.refBook = -1, this.refChapter = 0, this.refVerse = 0});

  bool get isVerse => cite.isNotEmpty && refBook >= 0;

  @override
  Rect get bounds => Rect.fromLTWH(x, y, w, math.max(h, size * 1.3));

  @override
  bool hit(Offset p, double r) => bounds.inflate(r).contains(p);

  NbText copyWith({double? x, double? y, double? w, double? h, double? size, int? color, String? text, bool? bold}) => NbText(
        id,
        x ?? this.x,
        y ?? this.y,
        w ?? this.w,
        h ?? this.h,
        size ?? this.size,
        color ?? this.color,
        text ?? this.text,
        bold: bold ?? this.bold,
        cite: cite,
        refBook: refBook,
        refChapter: refChapter,
        refVerse: refVerse,
      );

  @override
  NbText transformed({Offset origin = Offset.zero, double scale = 1, Offset shift = Offset.zero, String? id}) {
    final p = _tp(Offset(x, y), origin, scale, shift);
    return NbText(id ?? this.id, p.dx, p.dy, w * scale, h * scale, size * scale, color, text,
        bold: bold, cite: cite, refBook: refBook, refChapter: refChapter, refVerse: refVerse);
  }

  @override
  NbText recolored(int color) => copyWith(color: color);

  @override
  Map<String, dynamic> toJson() => {
        'k': 't',
        'i': id,
        'x': _r4(x),
        'y': _r4(y),
        'w': _r4(w),
        'h': _r4(h),
        's': _r5(size),
        'c': color,
        'x1': text,
        if (bold) 'b': true,
        if (cite.isNotEmpty) 'ct': cite,
        if (refBook >= 0) 'r': [refBook, refChapter, refVerse],
      };

  factory NbText.fromJson(Map<String, dynamic> j) {
    final r = j['r'] as List?;
    return NbText(
      j['i'] as String? ?? nbShortId(),
      _num(j['x']),
      _num(j['y']),
      _num(j['w'], 0.5),
      _num(j['h'], 0.05),
      _num(j['s'], 0.024),
      _int(j['c'], 0xFF1A1A1A),
      j['x1'] as String? ?? '',
      bold: j['b'] == true,
      cite: j['ct'] as String? ?? '',
      refBook: r == null ? -1 : _int(r[0], -1),
      refChapter: r == null ? 0 : _int(r[1]),
      refVerse: r == null ? 0 : _int(r[2]),
    );
  }
}

/// Imagem colada na página (o arquivo fica guardado junto do caderno).
final class NbImage extends NbItem {
  final double x;
  final double y;
  final double w;
  final double h;
  final String file;
  const NbImage(super.id, this.x, this.y, this.w, this.h, this.file);

  @override
  Rect get bounds => Rect.fromLTWH(x, y, w, h);

  @override
  bool hit(Offset p, double r) => bounds.inflate(r).contains(p);

  @override
  NbImage transformed({Offset origin = Offset.zero, double scale = 1, Offset shift = Offset.zero, String? id}) {
    final p = _tp(Offset(x, y), origin, scale, shift);
    return NbImage(id ?? this.id, p.dx, p.dy, w * scale, h * scale, file);
  }

  @override
  NbImage recolored(int color) => this;

  @override
  Map<String, dynamic> toJson() => {'k': 'i', 'i': id, 'x': _r4(x), 'y': _r4(y), 'w': _r4(w), 'h': _r4(h), 'f': file};

  factory NbImage.fromJson(Map<String, dynamic> j) => NbImage(
      j['i'] as String? ?? nbShortId(), _num(j['x']), _num(j['y']), _num(j['w'], 0.4), _num(j['h'], 0.3), j['f'] as String? ?? '');
}

/// Uma página do caderno.
class NbPage {
  final String id;
  NbTemplate template;
  NbPaper paper;
  List<NbItem> items;

  /// Última alteração (ms desde 1970): a cópia mais nova vence na sincronização.
  int updated;
  NbPage(this.id, this.template, this.paper, this.items, this.updated);

  factory NbPage.empty(NbTemplate template, NbPaper paper) =>
      NbPage(nbShortId(), template, paper, [], DateTime.now().millisecondsSinceEpoch);

  NbPage copy({String? id}) => NbPage(
      id ?? this.id, template, paper, [for (final it in items) it.transformed(id: id == null ? null : nbShortId())], updated);

  Map<String, dynamic> toJson() =>
      {'id': id, 'tpl': template.index, 'pp': paper.index, 'u': updated, 'it': [for (final it in items) it.toJson()]};

  factory NbPage.fromJson(Map<String, dynamic> j) => NbPage(
        j['id'] as String? ?? nbShortId(),
        NbTemplate.values[_int(j['tpl']).clamp(0, NbTemplate.values.length - 1)],
        NbPaper.values[_int(j['pp']).clamp(0, NbPaper.values.length - 1)],
        [
          for (final raw in (j['it'] as List? ?? const []))
            if (raw is Map)
              if (NbItem.fromJson(raw.cast<String, dynamic>()) case final NbItem it) it
        ],
        _int(j['u']),
      );
}

/// Um caderno: capa, pasta e a ordem das páginas.
class NbBook {
  final String id;
  String title;
  int coverColor;
  int coverStyle;
  String folder;
  bool favorite;
  final int created;
  int updated;
  List<String> pageIds;
  NbTemplate template;
  NbPaper paper;
  int lastPage;

  NbBook({
    required this.id,
    required this.title,
    required this.coverColor,
    this.coverStyle = 0,
    this.folder = '',
    this.favorite = false,
    required this.created,
    required this.updated,
    required this.pageIds,
    this.template = NbTemplate.ruled,
    this.paper = NbPaper.white,
    this.lastPage = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cc': coverColor,
        'cs': coverStyle,
        'folder': folder,
        'fav': favorite,
        'created': created,
        'u': updated,
        'pages': pageIds,
        'tpl': template.index,
        'pp': paper.index,
        'last': lastPage,
      };

  factory NbBook.fromJson(Map<String, dynamic> j) {
    final pages = [for (final p in (j['pages'] as List? ?? const [])) '$p'];
    return NbBook(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Caderno',
      coverColor: _int(j['cc'], 0xFF1B2A49),
      coverStyle: _int(j['cs']),
      folder: j['folder'] as String? ?? '',
      favorite: j['fav'] == true,
      created: _int(j['created']),
      updated: _int(j['u']),
      // Um caderno sempre tem pelo menos uma folha.
      pageIds: pages.isEmpty ? [nbShortId()] : pages,
      template: NbTemplate.values[_int(j['tpl'], 1).clamp(0, NbTemplate.values.length - 1)],
      paper: NbPaper.values[_int(j['pp']).clamp(0, NbPaper.values.length - 1)],
      lastPage: _int(j['last']),
    );
  }
}

// ---------------------------------------------------------------------------
// Geometria dos traços
// ---------------------------------------------------------------------------

/// Borracha parcial: tira do traço os pontos dentro do círculo e devolve os pedaços que sobram.
/// Null = o traço não foi tocado.
List<NbStroke>? nbErasePartial(NbStroke s, Offset center, double radius) {
  if (!s.bounds.inflate(radius).contains(center)) return null;
  final reach = radius + s.width / 2;
  final n = s.length;
  final out = <NbStroke>[];
  var run = <double>[];
  var touched = false;
  void flush() {
    if (run.length >= 6) out.add(NbStroke(nbShortId(), s.pen, s.color, s.width, run));
    run = <double>[];
  }

  for (var i = 0; i < n; i++) {
    final p = s.at(i);
    final near = (p - center).distance <= reach ||
        (i + 1 < n && nbDistToSegment(center, p, s.at(i + 1)) <= reach && (s.at(i + 1) - center).distance <= reach);
    if (near) {
      touched = true;
      flush();
    } else {
      run
        ..add(p.dx)
        ..add(p.dy)
        ..add(s.pressure(i));
    }
  }
  if (!touched) return null;
  flush();
  return out;
}

/// Reconhece o que a pessoa quis desenhar quando segura a caneta parada no fim do traço:
/// linha reta, elipse ou retângulo. Null = deixa o traço como está.
NbShape? nbRecognizeShape(NbStroke s) {
  final n = s.length;
  if (n < 6) return null;
  var length = 0.0;
  for (var i = 0; i + 1 < n; i++) {
    length += (s.at(i + 1) - s.at(i)).distance;
  }
  if (length < 0.03) return null;
  final first = s.at(0), last = s.at(n - 1);
  final chord = (last - first).distance;

  // Linha: o caminho quase não é maior que a distância entre as pontas.
  if (chord > 0.02 && length / chord < 1.18) {
    var dev = 0.0;
    for (var i = 1; i + 1 < n; i++) {
      dev = math.max(dev, nbDistToSegment(s.at(i), first, last));
    }
    if (dev / chord < 0.09) return NbShape(nbShortId(), NbShapeKind.line, first, last, s.color, s.width);
    return null;
  }

  // Forma fechada: as pontas se encontram (perto, comparado ao tamanho do desenho).
  var l = first.dx, t = first.dy, r = first.dx, b = first.dy;
  for (var i = 1; i < n; i++) {
    final p = s.at(i);
    l = math.min(l, p.dx);
    r = math.max(r, p.dx);
    t = math.min(t, p.dy);
    b = math.max(b, p.dy);
  }
  final rx = (r - l) / 2, ry = (b - t) / 2;
  if (rx < 0.01 || ry < 0.01) return null;
  if (chord > math.sqrt(rx * rx + ry * ry) * 0.6) return null;
  // Um rabisco que vai e volta é bem mais comprido que o contorno de uma forma.
  final around = 4 * (rx + ry), ellipse = math.pi * (3 * (rx + ry) - math.sqrt((3 * rx + ry) * (rx + 3 * ry)));
  if (length > around * 1.3 || length < ellipse * 0.75) return null;
  final c = Offset((l + r) / 2, (t + b) / 2);
  var eEllipse = 0.0, eRect = 0.0;
  for (var i = 0; i < n; i++) {
    final d = s.at(i) - c;
    final k = math.sqrt((d.dx / rx) * (d.dx / rx) + (d.dy / ry) * (d.dy / ry));
    eEllipse += (k - 1).abs();
    eRect += math.min((rx - d.dx.abs()).abs() / rx, (ry - d.dy.abs()).abs() / ry);
  }
  eEllipse /= n;
  eRect /= n;
  if (math.min(eEllipse, eRect) > 0.22) return null;
  return NbShape(nbShortId(), eRect < eEllipse ? NbShapeKind.rect : NbShapeKind.ellipse, Offset(l, t), Offset(r, b), s.color, s.width);
}

/// Suaviza o tremor da mão enquanto se escreve: cada ponto novo anda só parte do caminho até a caneta.
class NbStreamline {
  final double amount; // 0 = sem suavização; 0.6 = bem suave
  Offset? _last;
  NbStreamline([this.amount = 0.32]);

  void reset() => _last = null;

  Offset next(Offset raw) {
    final last = _last;
    if (last == null) return _last = raw;
    return _last = last + (raw - last) * (1 - amount);
  }
}

/// Retângulo que envolve vários elementos.
Rect nbBoundsOf(Iterable<NbItem> items) {
  Rect? r;
  for (final it in items) {
    r = r == null ? it.bounds : r.expandToInclude(it.bounds);
  }
  return r ?? Rect.zero;
}
