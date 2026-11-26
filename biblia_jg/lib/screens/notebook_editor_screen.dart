import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bible.dart';
import '../models/reference_parser.dart';
import '../services/notebook_models.dart';
import '../services/notebook_store.dart';
import '../state/app_state.dart';
import '../widgets/ink_tools.dart' show DockSide;
import '../widgets/notebook_canvas.dart';
import '../widgets/notebook_painters.dart';
import '../widgets/notebook_tools.dart';
import 'reader_view.dart';

/// Caderno aberto: folhas uma abaixo da outra, barra de canetas, laço, formas, texto, versículos e a Bíblia ao lado.
class NotebookEditorScreen extends StatefulWidget {
  final NotebookStore store;
  final NbBook book;
  const NotebookEditorScreen({super.key, required this.store, required this.book});

  @override
  State<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends State<NotebookEditorScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _gap = 28.0;
  static const _side = 36.0;
  static const _cw = nbPagePx + 2 * _side;
  static const _ph = nbPagePx * nbPageRatio;

  NbSession? _session;
  final _tc = TransformationController();
  final _viewerKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _jump = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Animation<double>? _jumpY;
  Size _viewport = Size.zero;
  int _first = 0, _last = 0, _current = 0;
  bool _bibleOpen = false;
  bool _placed = false;
  bool _busy = false;
  double _pinchScale0 = 1;
  Offset _pinchScene = Offset.zero;

  NbBook get book => widget.book;
  int get _count => book.pageIds.length;
  double get _contentHeight => _gap + _count * (_ph + _gap);
  double _top(int i) => _gap + i * (_ph + _gap);
  double get _fit => _viewport.width <= 0 ? 1 : _viewport.width / _cw;
  double get _scale => _tc.value.storage[0];
  Offset get _offset => Offset(_tc.value.storage[12], _tc.value.storage[13]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tc.addListener(_onView);
    _jump.addListener(() {
      final y = _jumpY;
      if (y != null) _setView(_scale, Offset(_offset.dx, y.value));
    });
    _current = book.lastPage.clamp(0, _count - 1);
    NbToolbox.load().then((box) {
      if (!mounted) return;
      final s = NbSession(widget.store, book, box)
        ..onOpenVerse = _openVerse
        ..onPinchStart = (g) {
          _jump.stop();
          _pinchScale0 = _scale;
          _pinchScene = (_toViewport(g) - _offset) / _scale;
        }
        ..onPinchUpdate = (g, k) {
          final s1 = (_pinchScale0 * k).clamp(_fit, _fit * 6);
          _setView(s1, _toViewport(g) - _pinchScene * s1);
        };
      setState(() => _session = s);
      _onView();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_session?.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jump.dispose();
    _tc.dispose();
    final s = _session;
    if (s != null) {
      s.commitText();
      book.lastPage = _current;
      final store = widget.store;
      unawaited(s.flush().then((_) async {
        await store.saveBook(book, touch: false);
        s.box.dispose();
        s.dispose();
      }));
    }
    super.dispose();
  }

  // ------------------------------------------------------------------- vista

  Offset _toViewport(Offset global) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  /// Aplica zoom e posição, sem deixar a folha sair da tela.
  void _setView(double s, Offset t) {
    if (_viewport.isEmpty) return;
    final fit = _fit;
    s = s.clamp(fit, fit * 6);
    final w = _cw * s, h = _contentHeight * s;
    final tx = w <= _viewport.width ? (_viewport.width - w) / 2 : t.dx.clamp(_viewport.width - w, 0.0);
    final ty = h <= _viewport.height ? 0.0 : t.dy.clamp(_viewport.height - h, 0.0);
    _tc.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  /// Descobre quais folhas estão na tela (só elas são montadas) e qual é a página atual.
  void _onView() {
    final s = _session;
    if (s == null || _viewport.isEmpty || _count == 0) return;
    final scale = _scale, t = _offset;
    final top = -t.dy / scale, bottom = (-t.dy + _viewport.height) / scale;
    const step = _ph + _gap;
    final first = ((top - _gap) / step).floor().clamp(0, _count - 1);
    final last = ((bottom - _gap) / step).floor().clamp(0, _count - 1);
    final current = (((top + bottom) / 2 - _gap / 2) / step).floor().clamp(0, _count - 1);
    for (var i = math.max(0, first - 1); i <= math.min(_count - 1, last + 1); i++) {
      s.ensure(book.pageIds[i]);
    }
    if (first != _first || last != _last || current != _current) {
      setState(() {
        _first = first;
        _last = last;
        _current = current;
      });
    }
  }

  void _goTo(int i, {bool animate = true, bool refit = false}) {
    if (_viewport.isEmpty || _count == 0) return;
    i = i.clamp(0, _count - 1);
    final s = refit ? _fit : _scale;
    final target = -(_top(i) - _gap / 2) * s;
    _jump.stop();
    if (!animate || refit || MediaQuery.disableAnimationsOf(context)) {
      _setView(s, Offset(_offset.dx, target));
      return;
    }
    _jumpY = Tween<double>(begin: _offset.dy, end: target).animate(CurvedAnimation(parent: _jump, curve: Curves.easeOutCubic));
    _jump.forward(from: 0);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      final d = (ev as PointerScrollEvent).scrollDelta;
      _jump.stop();
      if (HardwareKeyboard.instance.isControlPressed) {
        final focal = _toViewport(ev.position);
        final s0 = _scale;
        final s1 = (s0 * math.exp(-d.dy / 400)).clamp(_fit, _fit * 6);
        _setView(s1, focal - (focal - _offset) / s0 * s1);
      } else {
        _setView(_scale, _offset - d);
      }
    });
  }

  String get _pageId => book.pageIds[_current.clamp(0, _count - 1)];

  /// Posição para um elemento novo: no meio do que está na tela, dentro da página atual.
  Offset _spot(double w, double h) {
    final sceneY = (-_offset.dy + _viewport.height / 2) / _scale;
    final rel = (sceneY - _top(_current)) / nbPagePx;
    return Offset(((1 - w) / 2).clamp(0.02, 0.9), (rel - h / 2).clamp(0.03, math.max(0.03, nbPageRatio - h - 0.03)));
  }

  // -------------------------------------------------------------------- ações

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: book.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do caderno'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => book.title = name.trim());
    await widget.store.saveBook(book);
  }

  Future<void> _addPage({NbPage? copyOf, int? after}) async {
    final s = _session;
    if (s == null) return;
    final at = after ?? _current;
    final ref = s.pages[book.pageIds[at.clamp(0, _count - 1)]];
    final pg = await widget.store.addPage(book, after: at, template: ref?.template, paper: ref?.paper, copyOf: copyOf);
    if (!mounted) return;
    s.pages[pg.id] = pg;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(at + 1);
    });
  }

  Future<void> _deletePage(int i) async {
    final s = _session;
    if (s == null || _count <= 1) return;
    final id = book.pageIds[i];
    final hasContent = s.pages[id]?.items.isNotEmpty ?? true;
    if (hasContent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Apagar a página ${i + 1}?'),
          content: const Text('Tudo o que está escrito nela será apagado.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    s.clearSelection();
    await widget.store.removePage(book, id);
    s.pages.remove(id);
    if (!mounted) return;
    setState(() => _current = _current.clamp(0, _count - 1));
    _setView(_scale, _offset);
    _onView();
  }

  Future<void> _paperSheet() async {
    final s = _session;
    final pg = s?.pages[_pageId];
    if (s == null || pg == null) return;
    var template = pg.template, paper = pg.paper, forNext = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Modelo da página ${_current + 1}', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                height: 178,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: NbTemplate.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final t = NbTemplate.values[i];
                    final on = t == template;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setSheet(() => template = t),
                      child: SizedBox(
                        width: 104,
                        child: Column(children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: on ? scheme.primary : scheme.outlineVariant, width: on ? 2.5 : 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: NbPageThumb(page: NbPage('m$i-${paper.index}', t, paper, const [], 0)),
                          ),
                          const SizedBox(height: 6),
                          Text(t.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text('Cor do papel'),
              const SizedBox(height: 6),
              SegmentedButton<NbPaper>(
                showSelectedIcon: false,
                segments: [for (final p in NbPaper.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {paper},
                onSelectionChanged: (v) => setSheet(() => paper = v.first),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Usar também nas próximas páginas deste caderno'),
                value: forNext,
                onChanged: (v) => setSheet(() => forNext = v ?? false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
              ),
            ]),
          ),
        );
      }),
    );
    if (ok != true || !mounted) return;
    s.setPaper(pg.id, template, paper);
    if (forNext) {
      book
        ..template = template
        ..paper = paper;
      await widget.store.saveBook(book);
    }
  }

  Future<void> _insertVerse() async {
    final s = _session;
    final app = context.read<AppState>();
    final bible = app.bible;
    if (s == null) return;
    if (bible == null) {
      _snack('Instale uma versão da Bíblia para inserir versículos.');
      return;
    }
    final now = app.currentBook;
    final ctrl = TextEditingController();
    String? error;
    final passage = await showDialog<Passage>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        void submit() {
          final p = parseReference(ctrl.text);
          if (p == null) {
            setLocal(() => error = 'Não entendi. Exemplos: Jo 3:16, Rm 8:28-30');
          } else if (p.verse == null) {
            setLocal(() => error = 'Diga também o versículo (ex.: Sl 23:1-3)');
          } else {
            Navigator.pop(ctx, p);
          }
        }

        return AlertDialog(
          title: const Text('Inserir versículo'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(hintText: 'Ex.: Jo 3:16 ou Rm 8:28-30', errorText: error, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Text('O texto entra na folha com a versão aberta (${bible.abbrev}). Depois, com a mão, toque nele para abrir na Bíblia.',
                  style: Theme.of(ctx).textTheme.bodySmall),
              if (now != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ctrl.text = '${now.name} ${app.chapter}:1',
                    child: Text('Estou lendo ${now.name} ${app.chapter}'),
                  ),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: submit, child: const Text('Inserir')),
          ],
        );
      }),
    );
    ctrl.dispose();
    if (passage == null || !mounted) return;
    final item = verseItem(bible, passage, textSize: s.box.textSize);
    if (item == null) {
      _snack('Não achei esse versículo na versão ${bible.abbrev}.');
      return;
    }
    final at = _spot(item.w, item.h);
    s.addItem(_pageId, item.copyWith(x: at.dx, y: at.dy));
  }

  Future<void> _insertImage() async {
    final s = _session;
    if (s == null) return;
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;
      setState(() => _busy = true);
      final bytes = await files.first.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.height / math.max(1, frame.image.width);
      frame.image.dispose();
      final name = files.first.name;
      final ext = name.contains('.') ? name.split('.').last : 'png';
      final file = await widget.store.addImage(book, bytes, ext);
      var w = 0.56, h = 0.56 * ratio;
      if (h > 0.8) {
        w *= 0.8 / h;
        h = 0.8;
      }
      if (!mounted) return;
      final at = _spot(w, h);
      s.addItem(_pageId, NbImage(nbShortId(), at.dx, at.dy, w, h, file));
    } catch (_) {
      if (mounted) _snack('Não consegui abrir essa imagem.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export({required bool share}) async {
    final s = _session;
    final pg = s?.pages[_pageId];
    if (s == null || pg == null) return;
    s.commitText();
    setState(() => _busy = true);
    try {
      final img = await nbRenderPage(pg, s.images);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      final bytes = data!.buffer.asUint8List();
      final safe = book.title.replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ]+'), '-');
      final name = '$safe-pagina-${_current + 1}.png';
      if (share && !kIsWeb) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
          fileNameOverrides: [name],
          text: '${book.title} · página ${_current + 1}',
        ));
      } else {
        final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'image/png');
        if (uri != null && mounted) _snack('Imagem salva');
      }
    } catch (_) {
      if (mounted) _snack('Não consegui gerar a imagem desta página.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmClear() async {
    final s = _session;
    if (s == null || (s.pages[_pageId]?.items.isEmpty ?? true)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Limpar a página ${_current + 1}?'),
        content: const Text('Dá para voltar atrás com o botão desfazer enquanto o caderno estiver aberto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (ok == true) s.clearPage(_pageId);
  }

  void _openVerse(NbText verse) {
    final app = context.read<AppState>();
    app.goTo(verse.refBook, verse.refChapter, verse: verse.refVerse);
    _showBible();
  }

  void _showBible() {
    if (MediaQuery.sizeOf(context).width >= 900) {
      if (!_bibleOpen) setState(() => _bibleOpen = true);
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.86, child: NotebookBiblePanel()),
      );
    }
  }

  Future<void> _selectionColor() async {
    final s = _session;
    if (s == null) return;
    var color = 0xFF1A1A1A;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cor do que está selecionado', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              NbColorPicker(
                box: s.box,
                color: color,
                onChanged: (c) {
                  setSheet(() => color = c);
                  s.recolorSelection(c);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- tela

  Widget _pagesDrawer(NbSession s) {
    final theme = Theme.of(context);
    return Drawer(
      width: 264,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              Expanded(child: Text('Páginas', style: theme.textTheme.titleLarge)),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Nova'),
                onPressed: () {
                  Navigator.pop(context);
                  _addPage();
                },
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text('Toque para ir. Segure e arraste para mudar a ordem.', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: _count,
                onReorderItem: (from, to) async {
                  final current = book.pageIds[_current];
                  setState(() {
                    book.pageIds.insert(to, book.pageIds.removeAt(from));
                    _current = book.pageIds.indexOf(current);
                  });
                  await widget.store.saveBook(book);
                  _goTo(_current, animate: false);
                  _onView();
                },
                itemBuilder: (context, i) {
                  final id = book.pageIds[i];
                  final pg = s.pages[id];
                  if (pg == null) s.ensure(id);
                  final on = i == _current;
                  return Padding(
                    key: ValueKey(id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 26,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${i + 1}', style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(context);
                            _goTo(i);
                          },
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: on ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: on ? 2.5 : 1),
                            ),
                            child: pg == null
                                ? const AspectRatio(aspectRatio: 1 / nbPageRatio, child: ColoredBox(color: Colors.white))
                                : NbPageThumb(page: pg, images: s.images),
                          ),
                        ),
                      ),
                      PopupMenuButton<int>(
                        tooltip: 'Opções da página ${i + 1}',
                        onSelected: (v) {
                          Navigator.pop(context);
                          if (v == 0) _addPage(copyOf: pg, after: i);
                          if (v == 1) _deletePage(i);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 0, child: Text('Duplicar')),
                          PopupMenuItem(value: 1, enabled: _count > 1, child: const Text('Apagar')),
                        ],
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _selectionBar(NbSession s) {
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.onInverseSurface, minimumSize: const Size(48, 48)),
          icon: Icon(icon, size: 20),
          label: Text(label),
          onPressed: onTap,
        );
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Center(
        child: Material(
          elevation: 6,
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s.selectedText != null) action(Icons.edit_outlined, 'Editar', s.editSelectedText),
                action(Icons.copy_all_outlined, 'Duplicar', s.duplicateSelection),
                action(Icons.palette_outlined, 'Cor', _selectionColor),
                action(Icons.delete_outline, 'Apagar', s.deleteSelection),
                IconButton(
                  tooltip: 'Soltar a seleção',
                  color: scheme.onInverseSurface,
                  icon: const Icon(Icons.check),
                  onPressed: s.clearSelection,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvas(NbSession s) => LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        if (size != _viewport) {
          final widthChanged = (size.width - _viewport.width).abs() > 0.5;
          _viewport = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!_placed) {
              _placed = true;
              _goTo(_current, refit: true);
            } else if (widthChanged) {
              _goTo(_current, refit: true);
            } else {
              _setView(_scale, _offset);
            }
            _onView();
          });
        }
        final fit = _fit;
        final from = math.max(0, _first - 1), to = math.min(_count - 1, _last + 1);
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                key: _viewerKey,
                transformationController: _tc,
                constrained: false,
                minScale: fit,
                maxScale: fit * 6,
                boundaryMargin: EdgeInsets.zero,
                onInteractionStart: (_) => _jump.stop(),
                child: Listener(
                  onPointerSignal: _onSignal,
                  child: SizedBox(
                    width: _cw,
                    height: _contentHeight,
                    child: Stack(children: [
                      for (var i = from; i <= to; i++)
                        Positioned(
                          key: ValueKey(book.pageIds[i]),
                          left: _side,
                          top: _top(i),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))],
                            ),
                            child: NbPageView(session: s, pageId: book.pageIds[i]),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            if (s.hasSelection) _selectionBar(s),
            if (_busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
          ]),
        );
      });

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor;
    if (s == null) {
      return Scaffold(appBar: AppBar(title: Text(book.title)), body: const Center(child: CircularProgressIndicator()));
    }
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.box]),
      builder: (context, _) {
        final box = s.box;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final dock = NbDock(
          box: box,
          vertical: box.side != DockSide.top,
          onEditPen: (i) => showNbPenEditor(context, box, i),
          onAddPen: () {
            final p = box.pen;
            box.pens.add(NbPenPreset(p.pen, p.color, p.width));
            box.selectPen(box.pens.length - 1);
            showNbPenEditor(context, box, box.pens.length - 1);
          },
          onEraserOptions: () => showNbEraserOptions(context, box, onClearPage: _confirmClear),
          onTextOptions: () => showNbTextOptions(context, box),
          onSettings: () => showNbSettings(context, box),
        );
        final canvas = _canvas(s);
        final Widget work = switch (box.side) {
          DockSide.top => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dock, Expanded(child: canvas)]),
          DockSide.left => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dock, Expanded(child: canvas)]),
          DockSide.right => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: canvas), dock]),
        };
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): s.undo,
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): s.redo,
          },
          child: Scaffold(
            key: _scaffoldKey,
            endDrawer: _pagesDrawer(s),
            appBar: AppBar(
              titleSpacing: 0,
              title: InkWell(
                onTap: _rename,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(book.title, overflow: TextOverflow.ellipsis),
                ),
              ),
              actions: [
                IconButton(tooltip: 'Desfazer', icon: const Icon(Icons.undo), onPressed: s.canUndo ? s.undo : null),
                IconButton(tooltip: 'Refazer', icon: const Icon(Icons.redo), onPressed: s.canRedo ? s.redo : null),
                TextButton(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text('Pág. ${_current + 1}/$_count'),
                ),
                IconButton(tooltip: 'Nova página depois desta', icon: const Icon(Icons.note_add_outlined), onPressed: _addPage),
                IconButton(
                  tooltip: 'Bíblia ao lado',
                  isSelected: _bibleOpen && wide,
                  icon: const Icon(Icons.menu_book),
                  onPressed: () {
                    if (wide && _bibleOpen) {
                      setState(() => _bibleOpen = false);
                    } else {
                      _showBible();
                    }
                  },
                ),
                PopupMenuButton<int>(
                  tooltip: 'Mais opções',
                  onSelected: (v) => switch (v) {
                    0 => _insertVerse(),
                    1 => _insertImage(),
                    2 => _paperSheet(),
                    3 => _export(share: true),
                    4 => _export(share: false),
                    _ => _confirmClear(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.format_quote), title: Text('Inserir versículo'))),
                    PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Inserir imagem'))),
                    PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.article_outlined), title: Text('Modelo e cor do papel'))),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 3, child: ListTile(leading: Icon(Icons.ios_share), title: Text('Compartilhar esta página'))),
                    PopupMenuItem(value: 4, child: ListTile(leading: Icon(Icons.download_outlined), title: Text('Salvar como imagem'))),
                    PopupMenuItem(value: 5, child: ListTile(leading: Icon(Icons.layers_clear), title: Text('Limpar a página'))),
                  ],
                ),
              ],
            ),
            body: Focus(
              autofocus: true,
              child: wide && _bibleOpen
                  ? Row(children: [
                      Expanded(child: work),
                      const VerticalDivider(width: 1),
                      const SizedBox(width: 420, child: NotebookBiblePanel()),
                    ])
                  : work,
            ),
          ),
        );
      },
    );
  }
}

/// Monta a caixa de texto de um versículo (ou de vários seguidos) com a referência embaixo.
/// Null se o trecho não existe nessa versão.
NbText? verseItem(Bible bible, Passage p, {double textSize = 0.026}) {
  final first = p.verse;
  if (first == null || p.book < 0 || p.book >= bible.books.length) return null;
  final chapters = bible.books[p.book].chapters;
  if (p.chapter < 1 || p.chapter > chapters.length) return null;
  final verses = chapters[p.chapter - 1];
  if (first < 1 || first > verses.length) return null;
  final last = (p.endVerse ?? first).clamp(first, verses.length);
  final many = last > first;
  final text = [
    for (var v = first; v <= last; v++) '${many ? '$v ' : ''}${plainVerse(verses[v - 1]).trim()}',
  ].join(' ');
  final shown = Passage(p.book, p.chapter, first, many ? last : null);
  final item = NbText(nbShortId(), 0.12, 0.1, 0.76, 0, textSize, 0xFF1A1A1A, '“$text”',
      cite: '${shown.label(bible)} · ${bible.abbrev}', refBook: p.book, refChapter: p.chapter, refVerse: first);
  return item.copyWith(h: nbMeasureText(item));
}

/// Bíblia ao lado do caderno: caixa "Ir para" e o leitor normal do app.
class NotebookBiblePanel extends StatefulWidget {
  const NotebookBiblePanel({super.key});

  @override
  State<NotebookBiblePanel> createState() => _NotebookBiblePanelState();
}

class _NotebookBiblePanelState extends State<NotebookBiblePanel> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(AppState app) {
    final p = parseReference(_ctrl.text);
    if (p == null) {
      setState(() => _error = 'Ex.: Jo 3:16, Salmos 23');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    app.goTo(p.book, p.chapter, verse: p.verse);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = app.currentBook;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Row(children: [
          Expanded(
            child: Text(b == null ? 'Bíblia' : '${b.name} ${app.chapter}',
                style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
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
          onSubmitted: (_) => _go(app),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Ir para (ex.: Jo 3:16)',
            errorText: _error,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(tooltip: 'Ir', icon: const Icon(Icons.arrow_forward), onPressed: () => _go(app)),
          ),
        ),
      ),
      const Divider(height: 12),
      Expanded(child: ReaderView(onScrollDirection: (_) {})),
    ]);
  }
}
