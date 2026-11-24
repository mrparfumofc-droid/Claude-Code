import 'dart:async';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../models/reference_parser.dart';
import '../services/books_service.dart';
import '../services/ebd_reminder.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import 'ai_chat_screen.dart';
import 'reader_view.dart';

const _inkColors = <Color>[
  Color(0xFF1A1A1A),
  Color(0xFFD32F2F),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF7B1FA2),
  Color(0xFFF9A825),
];
const _markerColors = <Color>[
  Color(0xFFFFEB3B),
  Color(0xFF8BC34A),
  Color(0xFF4FC3F7),
  Color(0xFFFF8A80),
  Color(0xFFCE93D8),
  Color(0xFFFFB74D),
];

enum _Tool { pen, marker, eraser }

/// Estado das anotações à mão de um livro (todas as páginas).
class _Ink extends ChangeNotifier {
  final Map<int, List<Stroke>> pages;
  final Map<int, List<List<Stroke>>> _history = {};
  _Ink(this.pages);

  _Tool tool = _Tool.pen;
  Color penColor = _inkColors[1];
  Color markerColor = _markerColors[0];
  double penWidth = 0.004; // relativo à largura da página
  Stroke? active;
  int? activePage;

  /// Ponteiro (dedo/caneta) que está desenhando agora.
  int? pointer;

  /// Já apareceu uma caneta nesta sessão: o toque do dedo deixa de riscar.
  bool stylusSeen = false;

  List<Stroke> of(int page) => pages[page] ?? const [];

  void _snapshot(int page) {
    final h = _history[page] ??= [];
    h.add(List.of(of(page)));
    if (h.length > 40) h.removeAt(0);
  }

  bool canUndo(int page) => (_history[page]?.isNotEmpty ?? false);

  void start(int page, Offset p) {
    if (tool == _Tool.eraser) {
      _snapshot(page);
      erase(page, p);
      return;
    }
    final marker = tool == _Tool.marker;
    active = Stroke(
      marker ? InkTool.marker : InkTool.pen,
      marker ? markerColor : penColor,
      marker ? penWidth * 5 : penWidth,
      [p],
    );
    activePage = page;
    notifyListeners();
  }

  void move(int page, Offset p) {
    if (tool == _Tool.eraser) {
      erase(page, p);
      return;
    }
    if (active == null || activePage != page) return;
    final last = active!.points.last;
    if ((last - p).distance < 0.0015) return;
    active!.points.add(p);
    notifyListeners();
  }

  /// Termina o traço. Retorna true se algo mudou.
  bool end(int page) {
    if (tool == _Tool.eraser) return true;
    final s = active;
    active = null;
    activePage = null;
    if (s == null || s.points.length < 2) {
      notifyListeners();
      return false;
    }
    _snapshot(page);
    pages[page] = [...of(page), s];
    notifyListeners();
    return true;
  }

  void erase(int page, Offset p) {
    const r = 0.018;
    final before = of(page);
    final after = before.where((s) => !s.points.any((q) => (q - p).distance < r + s.width)).toList();
    if (after.length != before.length) {
      pages[page] = after;
      notifyListeners();
    }
  }

  bool undo(int page) {
    final h = _history[page];
    if (h == null || h.isEmpty) return false;
    pages[page] = h.removeLast();
    notifyListeners();
    return true;
  }

  void clear(int page) {
    if (of(page).isEmpty) return;
    _snapshot(page);
    pages[page] = [];
    notifyListeners();
  }
}

class _InkPainter extends CustomPainter {
  final _Ink ink;
  final int page;
  _InkPainter(this.ink, this.page) : super(repaint: ink);

  void _draw(Canvas canvas, Size size, Stroke s) {
    if (s.points.length < 2) return;
    final marker = s.tool == InkTool.marker;
    final paint = Paint()
      ..color = marker ? s.color.withValues(alpha: 0.35) : s.color
      ..strokeWidth = max(1.0, s.width * size.width)
      ..style = PaintingStyle.stroke
      ..strokeCap = marker ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = marker ? BlendMode.multiply : BlendMode.srcOver;
    final path = Path()..moveTo(s.points.first.dx * size.width, s.points.first.dy * size.height);
    for (final p in s.points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in ink.of(page)) {
      _draw(canvas, size, s);
    }
    if (ink.active != null && ink.activePage == page) _draw(canvas, size, ink.active!);
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}

/// Camada de desenho sobre uma página do PDF.
class _InkLayer extends StatelessWidget {
  final _Ink ink;
  final int page;
  final bool drawing;
  final void Function(int page) onChanged;
  const _InkLayer({required this.ink, required this.page, required this.drawing, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      Offset norm(Offset local) => Offset(
            (local.dx / c.maxWidth).clamp(0.0, 1.0),
            (local.dy / c.maxHeight).clamp(0.0, 1.0),
          );
      final paint = CustomPaint(painter: _InkPainter(ink, page), size: Size(c.maxWidth, c.maxHeight));
      if (!drawing) return IgnorePointer(child: paint);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.stylus) ink.stylusSeen = true;
          // Só um ponteiro desenha por vez; com caneta em uso, ignora a palma da mão.
          if (ink.pointer != null || (ink.stylusSeen && e.kind == PointerDeviceKind.touch)) return;
          ink.pointer = e.pointer;
          ink.start(page, norm(e.localPosition));
        },
        onPointerMove: (e) {
          if (e.pointer == ink.pointer) ink.move(page, norm(e.localPosition));
        },
        onPointerUp: (e) {
          if (e.pointer != ink.pointer) return;
          ink.pointer = null;
          if (ink.end(page)) onChanged(page);
        },
        onPointerCancel: (e) {
          if (e.pointer != ink.pointer) return;
          ink.pointer = null;
          ink.end(page);
        },
        child: paint,
      );
    });
  }
}

/// Leitor de PDF (livros e revistas da EBD) com anotação à mão e a Bíblia ao lado.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final _controller = PdfViewerController();
  late final BooksService _books = context.read<BooksService>();
  late final NotificationService _notifications = context.read<AppState>().notifications;
  String? _path;
  double? _progress;
  String? _error;
  _Ink? _ink;
  bool _drawing = false;
  bool _bibleOpen = false;
  int _page = 1;
  int _savedPage = 1;
  List<Passage> _pageRefs = const [];
  final Map<int, Timer> _saveTimers = {};
  Timer? _refsTimer;

  Book get book => widget.book;

  @override
  void initState() {
    super.initState();
    _page = _savedPage = book.lastPage;
    _bibleOpen = book.isEbd;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _books.openPath(book, onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        }),
        _books.loadInk(book.id),
      ]);
      if (!mounted) return;
      setState(() {
        _path = results[0] as String;
        _ink = _Ink(results[1] as Map<int, List<Stroke>>);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    final ink = _ink;
    if (ink != null) {
      for (final page in _saveTimers.keys) {
        _books.saveInkPage(book.id, page, ink.pages);
      }
    }
    _refsTimer?.cancel();
    if (_page != _savedPage) {
      book.lastPage = _page;
      _books.update(book, {'last_page': _page}).catchError((_) {});
    }
    super.dispose();
  }

  /// Página em que se desenhou por último (com duas páginas na tela, pode não ser a "atual").
  int? _inkPage;
  int get _inkTarget => _inkPage ?? _page;

  void _inkChanged(int page) {
    _inkPage = page;
    _saveTimers[page]?.cancel();
    _saveTimers[page] = Timer(const Duration(milliseconds: 1500), () {
      _saveTimers.remove(page);
      final ink = _ink;
      if (ink != null) _books.saveInkPage(book.id, page, ink.pages);
    });
    setState(() {}); // atualiza o botão desfazer
  }

  void _onPageChanged(int? n) {
    if (n == null || n == _page) return;
    setState(() {
      _page = n;
      _inkPage = null;
    });
    _refsTimer?.cancel();
    _refsTimer = Timer(const Duration(milliseconds: 400), _loadRefs);
  }

  Future<String> _pageText(int n) async {
    try {
      final doc = _controller.document;
      if (n < 1 || n > doc.pages.length) return '';
      return (await doc.pages[n - 1].loadStructuredText()).fullText;
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadRefs() async {
    final text = await _pageText(_page);
    if (!mounted) return;
    setState(() => _pageRefs = findReferences(text).take(30).toList());
  }

  Future<void> _openRef(Passage p) async {
    await context.read<AppState>().goTo(p.book, p.chapter, verse: p.verse);
    if (!mounted) return;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      setState(() => _bibleOpen = true);
    } else {
      _showBibleSheet();
    }
  }

  void _showBibleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.85,
        child: _BiblePanel(refs: _pageRefs, onRef: (p) => context.read<AppState>().goTo(p.book, p.chapter, verse: p.verse)),
      ),
    );
  }

  Future<void> _goToPageDialog() async {
    final ctrl = TextEditingController(text: '$_page');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ir para a página'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: book.pages == null ? null : 'De 1 a ${book.pages}'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('Ir')),
        ],
      ),
    );
    ctrl.dispose();
    if (n != null && n >= 1) await _controller.goToPage(pageNumber: n);
  }

  // ---------- Lições (EBD) ----------

  Future<void> _markLesson() async {
    final ctrl = TextEditingController(text: 'Lição ${book.lessons.length + 1}');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Marcar a página $_page como lição'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nome da lição')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Marcar')),
        ],
      ),
    );
    ctrl.dispose();
    if (title == null || title.isEmpty) return;
    book.lessons = [...book.lessons.where((l) => l.page != _page), Lesson(_page, title)]
      ..sort((a, b) => a.page.compareTo(b.page));
    setState(() {});
    await _books.saveLessons(book).then((_) => scheduleEbdReminders(_notifications, _books.books)).catchError((_) {});
  }

  Future<void> _findLessons() async {
    final messenger = ScaffoldMessenger.of(context);
    final total = _controller.document.pages.length;
    final re = RegExp(r'LI[ÇC][ÃA]O\s+(\d{1,2})\s*[:\-–.]?\s*([^\n]{0,70})', caseSensitive: false);
    final found = <int, Lesson>{};
    for (var n = 1; n <= total; n++) {
      final text = await _pageText(n);
      if (!mounted) return;
      // Página com várias "Lição N" é o sumário, não o começo de uma lição.
      if (re.allMatches(text).map((x) => x.group(1)).toSet().length >= 3) continue;
      final head = text.length > 400 ? text.substring(0, 400) : text;
      final m = re.firstMatch(head);
      if (m == null) continue;
      final num = int.parse(m.group(1)!);
      if (found.containsKey(num)) continue;
      final rest = m.group(2)!.trim();
      found[num] = Lesson(n, rest.isEmpty ? 'Lição $num' : 'Lição $num — $rest');
    }
    if (found.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Não achei "Lição 1, 2…" no texto. Marque as páginas pelo botão "Marcar lição".')));
      return;
    }
    book.lessons = found.values.toList()..sort((a, b) => a.page.compareTo(b.page));
    setState(() {});
    await _books.saveLessons(book).then((_) => scheduleEbdReminders(_notifications, _books.books)).catchError((_) {});
    messenger.showSnackBar(SnackBar(content: Text('${found.length} lições encontradas')));
  }

  /// Monta um plano de aula (IA) com o texto da lição aberta.
  Future<void> _prepareLesson() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final version = context.read<AppState>().bible?.abbrev;
    // Da página da lição atual até a véspera da próxima lição (no máximo 8 páginas).
    final current = book.lessons.where((l) => l.page <= _page).lastOrNull;
    final next = book.lessons.where((l) => l.page > _page).firstOrNull;
    final start = current?.page ?? _page;
    final total = _controller.document.pages.length;
    final end = [(next?.page ?? start + 8) - 1, start + 7, total].reduce((a, b) => a < b ? a : b);
    final buf = StringBuffer();
    for (var n = start; n <= end && buf.length < 11500; n++) {
      buf.writeln(await _pageText(n));
    }
    final text = buf.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.length < 200) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Não consegui ler o texto desta revista (o PDF é escaneado como imagem).')));
      return;
    }
    final head = text.length > 6000 ? text.substring(0, 6000) : text;
    final rest = text.length > 6000 ? text.substring(6000, text.length > 10800 ? 10800 : text.length) : '';
    navigator.push(MaterialPageRoute(
      builder: (_) => AiChatScreen(
        title: 'Preparar aula',
        task: 'chat',
        reference: '${book.title}${current == null ? '' : ' — ${current.title}'}',
        version: version,
        verseText: head,
        initialPrompt: 'Sou professor da Escola Bíblica Dominical. O texto acima é a lição da revista'
            '${rest.isEmpty ? '' : ' (continuação: $rest)'}. '
            'Monte um plano de aula de 1 página para 45 minutos, fiel à lição: objetivo da aula em 1 frase; '
            'versículo-chave; quebra-gelo de 2 minutos; desenvolvimento em 3 blocos com o tempo de cada um; '
            '5 perguntas para a classe (3 fáceis e 2 para aprofundar); e uma aplicação prática para a semana.',
        quickActions: const [
          ('Quiz para o WhatsApp', 'chat',
              'Crie 6 perguntas de múltipla escolha sobre esta lição, com o gabarito no final, em formato pronto para colar no WhatsApp da classe.'),
          ('Dinâmica para a classe', 'chat',
              'Sugira uma dinâmica simples de 5 minutos para fixar o tema desta lição, com poucos materiais.'),
          ('Para novos na fé', 'chat',
              'Explique o ponto central desta lição em linguagem bem simples, para alunos novos na fé.'),
        ],
      ),
    ));
  }

  Widget _lessonsDrawer() => Drawer(
        width: 360,
        child: SafeArea(
          child: ListView(children: [
            ListTile(
              title: Text(book.isEbd ? 'Lições' : 'Marcadores', style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: Text(book.isEbd ? 'Marcar esta página como lição' : 'Marcar esta página'),
              onTap: () {
                Navigator.pop(context);
                _markLesson();
              },
            ),
            if (book.isEbd)
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: const Text('Encontrar as lições sozinho'),
                subtitle: const Text('Procura "Lição 1, 2, 3…" nas páginas'),
                onTap: () {
                  Navigator.pop(context);
                  _findLessons();
                },
              ),
            if (book.isEbd)
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Preparar a aula com IA'),
                subtitle: const Text('Plano de aula de 1 página a partir desta lição'),
                onTap: () {
                  Navigator.pop(context);
                  _prepareLesson();
                },
              ),
            const Divider(),
            if (book.lessons.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma marcada ainda.')),
            for (final l in book.lessons)
              ListTile(
                leading: CircleAvatar(radius: 16, child: Text('${l.page}', style: const TextStyle(fontSize: 11))),
                title: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                selected: _page == l.page,
                onTap: () {
                  Navigator.pop(context);
                  _controller.goToPage(pageNumber: l.page);
                },
                trailing: IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    book.lessons = book.lessons.where((x) => x != l).toList();
                    setState(() {});
                    _books.saveLessons(book).then((_) => scheduleEbdReminders(_notifications, _books.books)).catchError((_) {});
                  },
                ),
              ),
          ]),
        ),
      );

  Widget _inkToolbar(_Ink ink) {
    final theme = Theme.of(context);
    final colors = ink.tool == _Tool.marker ? _markerColors : _inkColors;
    final current = ink.tool == _Tool.marker ? ink.markerColor : ink.penColor;
    return Material(
      elevation: 3,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          SegmentedButton<_Tool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Tool.pen, icon: Icon(Icons.edit), tooltip: 'Caneta'),
              ButtonSegment(value: _Tool.marker, icon: Icon(Icons.border_color), tooltip: 'Marca-texto'),
              ButtonSegment(value: _Tool.eraser, icon: Icon(Icons.auto_fix_normal), tooltip: 'Borracha'),
            ],
            selected: {ink.tool},
            onSelectionChanged: (v) => setState(() => ink.tool = v.first),
          ),
          const SizedBox(width: 12),
          if (ink.tool != _Tool.eraser)
            for (final c in colors)
              GestureDetector(
                onTap: () => setState(() {
                  if (ink.tool == _Tool.marker) {
                    ink.markerColor = c;
                  } else {
                    ink.penColor = c;
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: current == c ? 3 : 1,
                      color: current == c ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ),
                ),
              ),
          if (ink.tool != _Tool.eraser) ...[
            const SizedBox(width: 8),
            const Icon(Icons.line_weight, size: 18),
            SizedBox(
              width: 120,
              child: Slider(
                min: 0.002,
                max: 0.012,
                value: ink.penWidth,
                onChanged: (v) => setState(() => ink.penWidth = v),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Desfazer',
            icon: const Icon(Icons.undo),
            onPressed: ink.canUndo(_inkTarget)
                ? () {
                    if (ink.undo(_inkTarget)) _inkChanged(_inkTarget);
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Limpar a página',
            icon: const Icon(Icons.layers_clear),
            onPressed: ink.of(_inkTarget).isEmpty
                ? null
                : () {
                    final target = _inkTarget;
                    ink.clear(target);
                    _inkChanged(target);
                  },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final ink = _ink;
    Widget body;
    if (_error != null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    } else if (_path == null || ink == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 240, child: LinearProgressIndicator(value: _progress)),
          const SizedBox(height: 12),
          Text(_progress == null ? 'Abrindo…' : 'Baixando da nuvem… ${(_progress! * 100).round()}%'),
        ]),
      );
    } else {
      final viewer = PdfViewer.file(
        _path!,
        controller: _controller,
        initialPageNumber: book.lastPage,
        params: PdfViewerParams(
          panEnabled: !_drawing,
          scaleEnabled: !_drawing,
          backgroundColor: Colors.grey.shade300,
          onPageChanged: _onPageChanged,
          onViewerReady: (doc, controller) {
            if (book.pages != doc.pages.length) {
              book.pages = doc.pages.length;
              _books.update(book, {'pages': doc.pages.length}).catchError((_) {});
            }
            _loadRefs();
          },
          pageOverlaysBuilder: (context, rect, page) => [
            _InkLayer(ink: ink, page: page.pageNumber, drawing: _drawing, onChanged: _inkChanged),
          ],
        ),
      );
      final pdfColumn = Column(children: [
        if (_drawing) _inkToolbar(ink),
        Expanded(child: viewer),
        if (_pageRefs.isNotEmpty && !_drawing)
          Material(
            elevation: 2,
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 8),
                    child: Text('Nesta página:', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final p in _pageRefs)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.menu_book, size: 16),
                        label: Text(p.label(context.read<AppState>().bible)),
                        onPressed: () => _openRef(p),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ]);
      body = wide && _bibleOpen
          ? Row(children: [
              Expanded(child: pdfColumn),
              const VerticalDivider(width: 1),
              SizedBox(width: 440, child: _BiblePanel(refs: const [], onRef: _openRef)),
            ])
          : pdfColumn;
    }

    return Scaffold(
      endDrawer: _lessonsDrawer(),
      appBar: AppBar(
        title: Text(book.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_path != null) ...[
            TextButton(
              onPressed: _goToPageDialog,
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).appBarTheme.foregroundColor),
              child: Text('Pág. $_page${book.pages == null ? '' : '/${book.pages}'}'),
            ),
            IconButton(
              tooltip: _drawing ? 'Parar de anotar' : 'Anotar à mão',
              isSelected: _drawing,
              icon: Icon(_drawing ? Icons.edit_off : Icons.draw),
              onPressed: () => setState(() => _drawing = !_drawing),
            ),
            IconButton(
              tooltip: 'Bíblia ao lado',
              isSelected: _bibleOpen,
              icon: const Icon(Icons.menu_book),
              onPressed: () {
                if (wide) {
                  setState(() => _bibleOpen = !_bibleOpen);
                } else {
                  _showBibleSheet();
                }
              },
            ),
          ],
          Builder(
            builder: (ctx) => IconButton(
              tooltip: book.isEbd ? 'Lições' : 'Marcadores',
              icon: const Icon(Icons.list_alt),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Bíblia ao lado do PDF: caixa "Ir para" e o leitor normal do app.
class _BiblePanel extends StatefulWidget {
  final List<Passage> refs;
  final void Function(Passage) onRef;
  const _BiblePanel({required this.refs, required this.onRef});

  @override
  State<_BiblePanel> createState() => _BiblePanelState();
}

class _BiblePanelState extends State<_BiblePanel> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() {
    final p = parseReference(_ctrl.text);
    if (p == null) {
      setState(() => _error = 'Ex.: Jo 3:16, Salmos 23');
      return;
    }
    setState(() => _error = null);
    widget.onRef(p);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.currentBook;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          Expanded(
            child: Text(
              b == null ? 'Bíblia' : '${b.name} ${app.chapter}',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(tooltip: 'Capítulo anterior', icon: const Icon(Icons.chevron_left), onPressed: app.previousChapter),
          IconButton(tooltip: 'Próximo capítulo', icon: const Icon(Icons.chevron_right), onPressed: app.nextChapter),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Ir para (ex.: Jo 3:16)',
            errorText: _error,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _go),
          ),
        ),
      ),
      if (widget.refs.isNotEmpty)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              for (final p in widget.refs)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(label: Text(p.label(app.bible)), onPressed: () => widget.onRef(p)),
                ),
            ],
          ),
        ),
      const Divider(height: 8),
      Expanded(child: ReaderView(onScrollDirection: (_) {})),
    ]);
  }
}
