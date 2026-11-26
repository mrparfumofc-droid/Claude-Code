import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notebook_models.dart';
import '../services/notebook_store.dart';
import 'ink_tools.dart' show DrawClaimRecognizer;
import 'notebook_painters.dart';
import 'notebook_tools.dart';

/// Elementos escolhidos com o laço. Enquanto a pessoa arrasta, só [shift] e [scale] mudam
/// (o desenho acompanha o dedo); ao soltar, a mudança é gravada nos elementos.
class NbSelection {
  final String pageId;
  List<NbItem> items;
  Rect box;
  Offset shift = Offset.zero;
  double scale = 1;
  NbSelection(this.pageId, this.items) : box = nbBoundsOf(items);

  Set<String> get ids => {for (final it in items) it.id};

  /// Moldura como aparece agora (com o arrasto em andamento).
  Rect get shown => Rect.fromLTWH(box.left + shift.dx, box.top + shift.dy, box.width * scale, box.height * scale);
}

/// O que está sendo desenhado neste instante. Avisa só a camada de cima da página:
/// nenhum widget é reconstruído enquanto a caneta anda.
class NbLive extends ChangeNotifier {
  String? pageId;
  NbStroke? stroke;
  NbShape? shape;
  Offset? eraser;
  List<Offset>? lasso;
  NbSelection? selection;

  void ping() => notifyListeners();
}

/// Texto sendo digitado numa página.
class NbTextEdit {
  final String pageId;
  final NbText item;
  final bool isNew;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  NbTextEdit(this.pageId, this.item, this.isNew) : controller = TextEditingController(text: item.text);

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _Edit {
  final String pageId;
  final List<NbItem> before;
  final List<NbItem> after;
  const _Edit(this.pageId, this.before, this.after);
}

enum _Drag { move, scale }

/// Uma sessão de escrita num caderno: páginas abertas, o traço em andamento, laço, desfazer/refazer
/// e o salvamento automático.
class NbSession extends ChangeNotifier {
  final NotebookStore store;
  final NbBook book;
  final NbToolbox box;
  NbSession(this.store, this.book, this.box);

  final live = NbLive();
  final pages = <String, NbPage>{};
  final images = <String, ui.Image>{};
  final _ticks = <String, ValueNotifier<int>>{};
  final _loading = <String>{};
  final _undo = <_Edit>[];
  final _redo = <_Edit>[];
  final _dirty = <String>{};
  Timer? _saveTimer;
  bool _disposed = false;

  NbTextEdit? editing;

  /// Toque num versículo com a ferramenta "mão".
  void Function(NbText verse)? onOpenVerse;

  /// Dois dedos na tela quando o dedo escreve: a tela do caderno move e amplia a página.
  void Function(Offset focal)? onPinchStart;
  void Function(Offset focal, double scale)? onPinchUpdate;
  VoidCallback? onPinchEnd;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasSelection => live.selection != null;

  /// Aviso de que a camada pronta de uma página precisa ser redesenhada.
  ValueNotifier<int> tick(String pageId) => _ticks[pageId] ??= ValueNotifier(0);

  /// Elementos que a camada pronta não desenha agora (estão no laço ou sendo editados).
  Set<String> skipFor(String pageId) {
    final sel = live.selection;
    final ed = editing;
    return {
      if (sel != null && sel.pageId == pageId) ...sel.ids,
      if (ed != null && ed.pageId == pageId && !ed.isNew) ed.item.id,
    };
  }

  // ------------------------------------------------------------ carregamento

  Future<void> ensure(String pageId) async {
    if (pages.containsKey(pageId) || !_loading.add(pageId)) return;
    try {
      final pg = await store.page(book, pageId);
      if (_disposed) return;
      pages[pageId] = pg;
      notifyListeners();
      unawaited(_loadImages(pg));
    } finally {
      _loading.remove(pageId);
    }
  }

  Future<void> _loadImages(NbPage pg) async {
    for (final it in pg.items) {
      if (it is! NbImage || images.containsKey(it.file)) continue;
      final bytes = await store.imageBytes(book.id, it.file);
      if (bytes == null || _disposed) continue;
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1400, allowUpscaling: false);
        final image = (await codec.getNextFrame()).image;
        if (_disposed) return;
        images[it.file] = image;
        tick(pg.id).value++;
        live.ping();
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------- alterações

  void _markDirty(String pageId) {
    _dirty.add(pageId);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () => unawaited(flush()));
  }

  /// Grava o que mudou (também chamado ao sair do caderno).
  Future<void> flush() async {
    _saveTimer?.cancel();
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      final pg = pages[id];
      if (pg != null) await store.savePage(book, pg);
    }
  }

  void _apply(String pageId, List<NbItem> next) {
    final pg = pages[pageId];
    if (pg == null) return;
    _undo.add(_Edit(pageId, pg.items, next));
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
    pg.items = next;
    tick(pageId).value++;
    _markDirty(pageId);
    notifyListeners();
  }

  void _restore(_Edit e, List<NbItem> items) {
    final pg = pages[e.pageId];
    if (pg == null) return;
    live.selection = null;
    pg.items = items;
    tick(e.pageId).value++;
    live.ping();
    _markDirty(e.pageId);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final e = _undo.removeLast();
    _redo.add(e);
    _restore(e, e.before);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final e = _redo.removeLast();
    _undo.add(e);
    _restore(e, e.after);
  }

  void clearPage(String pageId) {
    final pg = pages[pageId];
    if (pg == null || pg.items.isEmpty) return;
    clearSelection();
    _apply(pageId, const []);
  }

  /// Troca o modelo e a cor do papel de uma página.
  void setPaper(String pageId, NbTemplate template, NbPaper paper) {
    final pg = pages[pageId];
    if (pg == null) return;
    pg
      ..template = template
      ..paper = paper;
    tick(pageId).value++;
    live.ping();
    _markDirty(pageId);
    notifyListeners();
  }

  /// Põe um elemento novo na página e já o deixa selecionado, para a pessoa levar aonde quiser.
  void addItem(String pageId, NbItem item) {
    final pg = pages[pageId];
    if (pg == null) return;
    clearSelection();
    _apply(pageId, [...pg.items, item]);
    live.selection = NbSelection(pageId, [item]);
    box.setMode(NbMode.lasso);
    tick(pageId).value++;
    live.ping();
    notifyListeners();
    if (item is NbImage) unawaited(_loadImages(pg));
  }

  // -------------------------------------------------------------------- laço

  void clearSelection() {
    final sel = live.selection;
    if (sel == null) return;
    live.selection = null;
    tick(sel.pageId).value++;
    live.ping();
    notifyListeners();
  }

  void _select(String pageId, List<NbItem> items) {
    if (items.isEmpty) {
      clearSelection();
      return;
    }
    live.selection = NbSelection(pageId, items);
    tick(pageId).value++;
    live.ping();
    notifyListeners();
  }

  void _commitSelection() {
    final sel = live.selection;
    if (sel == null || (sel.shift == Offset.zero && sel.scale == 1)) return;
    final pg = pages[sel.pageId];
    if (pg == null) return;
    final changed = {
      for (final it in sel.items) it.id: it.transformed(origin: sel.box.topLeft, scale: sel.scale, shift: sel.shift)
    };
    sel
      ..items = changed.values.toList()
      ..box = nbBoundsOf(changed.values)
      ..shift = Offset.zero
      ..scale = 1;
    _apply(sel.pageId, [for (final it in pg.items) changed[it.id] ?? it]);
    live.ping();
  }

  void deleteSelection() {
    final sel = live.selection;
    final pg = sel == null ? null : pages[sel.pageId];
    if (sel == null || pg == null) return;
    final ids = sel.ids;
    live.selection = null;
    _apply(sel.pageId, [for (final it in pg.items) if (!ids.contains(it.id)) it]);
    live.ping();
  }

  void duplicateSelection() {
    final sel = live.selection;
    final pg = sel == null ? null : pages[sel.pageId];
    if (sel == null || pg == null) return;
    final copies = [for (final it in sel.items) it.transformed(shift: const Offset(0.025, 0.025), id: nbShortId())];
    _apply(sel.pageId, [...pg.items, ...copies]);
    live.selection = NbSelection(sel.pageId, copies);
    tick(sel.pageId).value++;
    live.ping();
  }

  void recolorSelection(int color) {
    final sel = live.selection;
    final pg = sel == null ? null : pages[sel.pageId];
    if (sel == null || pg == null) return;
    final changed = {for (final it in sel.items) it.id: it.recolored(color)};
    sel.items = changed.values.toList();
    _apply(sel.pageId, [for (final it in pg.items) changed[it.id] ?? it]);
    live.ping();
  }

  /// Texto digitado que está sozinho na seleção (dá para reabrir e corrigir).
  NbText? get selectedText {
    final sel = live.selection;
    if (sel == null || sel.items.length != 1) return null;
    final it = sel.items.single;
    return it is NbText && !it.isVerse ? it : null;
  }

  void editSelectedText() {
    final sel = live.selection;
    final it = selectedText;
    if (sel == null || it == null) return;
    box.setMode(NbMode.text);
    startText(sel.pageId, existing: it);
  }

  /// Elemento de cima no ponto tocado (texto, depois tinta, marca-texto e imagem).
  NbItem? _topAt(NbPage pg, Offset pos, double r) {
    bool Function(NbItem) layer(int n) => switch (n) {
          0 => (it) => it is NbText,
          1 => (it) => it is NbShape || (it is NbStroke && it.pen != NbPen.marker),
          2 => (it) => it is NbStroke && it.pen == NbPen.marker,
          _ => (it) => it is NbImage,
        };
    for (var n = 0; n < 4; n++) {
      final test = layer(n);
      for (final it in pg.items.reversed) {
        if (test(it) && it.hit(pos, r)) return it;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------- texto

  void startText(String pageId, {NbText? existing, Offset? at}) {
    commitText();
    clearSelection();
    NbText item;
    if (existing != null) {
      item = existing;
    } else {
      final p = at ?? const Offset(0.1, 0.1);
      final x = p.dx.clamp(0.02, 0.78);
      item = NbText(nbShortId(), x, (p.dy - box.textSize * 0.6).clamp(0.0, nbPageRatio - 0.05), math.min(0.66, 0.98 - x), 0,
          box.textSize, box.textColor, '',
          bold: box.textBold);
    }
    final ed = editing = NbTextEdit(pageId, item, existing == null);
    tick(pageId).value++;
    notifyListeners();
    // Abre o teclado já na caixa (depois que ela aparece na tela).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(editing, ed)) ed.focus.requestFocus();
    });
  }

  /// Fecha a caixa de texto aberta e grava o que foi digitado (vazio apaga a caixa).
  void commitText() {
    final ed = editing;
    if (ed == null) return;
    editing = null;
    final pg = pages[ed.pageId];
    final text = ed.controller.text.trimRight();
    WidgetsBinding.instance.addPostFrameCallback((_) => ed.dispose());
    if (pg != null) {
      if (text.trim().isEmpty) {
        if (!ed.isNew) _apply(ed.pageId, [for (final it in pg.items) if (it.id != ed.item.id) it]);
      } else if (ed.isNew || text != ed.item.text) {
        var item = ed.item.copyWith(text: text);
        item = item.copyWith(h: nbMeasureText(item));
        _apply(ed.pageId, ed.isNew ? [...pg.items, item] : [for (final it in pg.items) it.id == item.id ? item : it]);
      }
    }
    tick(ed.pageId).value++;
    notifyListeners();
  }

  /// O ponto está dentro da caixa de texto aberta? (esses toques são do cursor, não da caneta)
  bool inTextBox(String pageId, Offset pos) {
    final ed = editing;
    if (ed == null || ed.pageId != pageId) return false;
    final typed = ed.controller.text;
    final h = nbMeasureText(ed.item.copyWith(text: typed.isEmpty ? ' ' : typed));
    return Rect.fromLTWH(ed.item.x, ed.item.y, ed.item.w, h).inflate(0.016).contains(pos);
  }

  /// Toque com a ferramenta "mão": abre na Bíblia o versículo tocado.
  void tapInHand(String pageId, Offset pos) {
    final pg = pages[pageId];
    if (pg == null) return;
    for (final it in pg.items.reversed) {
      if (it is NbText && it.isVerse && it.hit(pos, 0.006)) {
        onOpenVerse?.call(it);
        return;
      }
    }
  }

  // ---------------------------------------------------------------- ponteiro

  int? _pointer;
  NbMode _mode = NbMode.pen; // ferramenta deste gesto (o botão ou a ponta de trás da caneta viram borracha)
  bool _pointerIsTouch = false;
  String? _pointerPage;
  Offset _downPos = Offset.zero;
  bool _moved = false;
  final _touches = <int, Offset>{};
  bool _pinching = false;
  double _pinchStart = 1;

  NbStreamline _stream = NbStreamline();
  Timer? _holdTimer;
  Offset _holdAnchor = Offset.zero;
  bool _snapped = false;

  List<NbItem>? _eraseBefore;
  Offset? _eraseLast;

  _Drag? _drag;
  Offset _dragStart = Offset.zero;
  Offset _shift0 = Offset.zero;
  double _scale0 = 1;

  double _speedPressure = 0.5;
  Offset _lastRaw = Offset.zero;
  int _lastTime = 0;

  static Offset _inPage(Offset p) => Offset(p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, nbPageRatio));

  /// Pressão da caneta (0 a 1). Com dedo ou mouse, traço rápido fica mais fino, como numa caneta de verdade.
  double _pressure(PointerEvent e, Offset pos) {
    if (NbToolbox.isStylus(e) && e.pressureMax > e.pressureMin) {
      return ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(0.05, 1.0);
    }
    final now = e.timeStamp.inMicroseconds;
    final dt = (now - _lastTime) / 1000.0;
    if (dt > 0 && dt < 120) {
      final speed = (pos - _lastRaw).distance / dt; // larguras de página por ms
      final target = (0.82 - speed * 260).clamp(0.22, 0.82);
      _speedPressure += (target - _speedPressure) * 0.25;
    }
    _lastRaw = pos;
    _lastTime = now;
    return _speedPressure;
  }

  void _armHold(Offset pos) {
    _holdTimer?.cancel();
    if (!box.holdToStraighten) return;
    _holdAnchor = pos;
    _holdTimer = Timer(const Duration(milliseconds: 520), _onHold);
  }

  /// A caneta ficou parada no fim do traço: endireita a linha ou arredonda a forma.
  void _onHold() {
    final s = live.stroke;
    if (s == null || _pointer == null || _snapped || _mode != NbMode.pen) return;
    final shape = nbRecognizeShape(s);
    if (shape == null) return;
    if (shape.kind == NbShapeKind.line) {
      final p = s.pressure(s.length ~/ 2);
      live.stroke = NbStroke(s.id, s.pen, s.color, s.width, [shape.a.dx, shape.a.dy, p, shape.b.dx, shape.b.dy, p]);
    } else if (s.pen == NbPen.marker) {
      return;
    } else {
      live
        ..stroke = null
        ..shape = shape;
    }
    _snapped = true;
    HapticFeedback.selectionClick();
    live.ping();
  }

  void _cancelActive() {
    _holdTimer?.cancel();
    final page = _pointerPage;
    if (_eraseBefore != null && page != null) {
      final pg = pages[page];
      if (pg != null && !identical(pg.items, _eraseBefore)) {
        pg.items = _eraseBefore!;
        tick(page).value++;
      }
    }
    _eraseBefore = null;
    final sel = live.selection;
    if (_drag != null && sel != null) {
      sel
        ..shift = Offset.zero
        ..scale = 1;
    }
    _drag = null;
    _pointer = null;
    live
      ..stroke = null
      ..shape = null
      ..eraser = null
      ..lasso = null
      ..ping();
  }

  void hover(PointerEvent e) {
    if (NbToolbox.isStylus(e)) box.lastStylus = DateTime.now();
  }

  void down(String pageId, PointerDownEvent e, Offset raw) {
    if (NbToolbox.isStylus(e)) box.sawStylus();
    final touch = e.kind == PointerDeviceKind.touch;
    if (touch) _touches[e.pointer] = e.position;
    if (!box.draws(e)) return;
    if (NbToolbox.isMouse(e) && e.buttons != kPrimaryButton) return;
    if (_pointer != null) {
      // Segundo dedo enquanto o dedo escreve: o traço começado é descartado e os dois dedos movem a página.
      if (touch && _pointerIsTouch && _touches.length >= 2 && !_pinching) {
        _cancelActive();
        final pts = _touches.values.toList();
        _pinching = true;
        _pinchStart = math.max(1, (pts[0] - pts[1]).distance);
        onPinchStart?.call((pts[0] + pts[1]) / 2);
      }
      return;
    }
    if (_pinching) return;
    final pg = pages[pageId];
    if (pg == null) return;
    final pos = _inPage(raw);
    if (editing != null) {
      if (inTextBox(pageId, raw)) return;
      commitText();
      if (box.mode == NbMode.text) return;
    }
    _pointer = e.pointer;
    _pointerIsTouch = touch;
    _pointerPage = pageId;
    _downPos = pos;
    _moved = false;
    final penEraser = e.kind == PointerDeviceKind.invertedStylus ||
        (e.kind == PointerDeviceKind.stylus && (e.buttons & (kPrimaryStylusButton | kSecondaryStylusButton)) != 0);
    _mode = penEraser ? NbMode.eraser : box.mode;
    switch (_mode) {
      case NbMode.hand:
        _pointer = null;
      case NbMode.pen:
        clearSelection();
        final preset = box.pen;
        _stream = NbStreamline(preset.pen == NbPen.marker ? math.min(box.smoothing, 0.2) : box.smoothing);
        _speedPressure = 0.5;
        _lastRaw = pos;
        _lastTime = e.timeStamp.inMicroseconds;
        _snapped = false;
        final p = _stream.next(pos);
        live
          ..pageId = pageId
          ..shape = null
          ..stroke = NbStroke(nbShortId(), preset.pen, preset.color, preset.width, [p.dx, p.dy, _pressure(e, pos)])
          ..ping();
        _armHold(pos);
      case NbMode.eraser:
        clearSelection();
        _eraseBefore = pg.items;
        _eraseLast = null;
        live
          ..pageId = pageId
          ..eraser = pos;
        _eraseTo(pageId, pos);
        live.ping();
      case NbMode.lasso:
        final sel = live.selection;
        _drag = null;
        if (sel != null && sel.pageId == pageId) {
          final shown = sel.shown;
          if ((pos - shown.bottomRight).distance < 0.04) {
            _drag = _Drag.scale;
          } else if (shown.inflate(0.012).contains(pos)) {
            _drag = _Drag.move;
          }
        }
        if (_drag != null) {
          _dragStart = pos;
          _shift0 = sel!.shift;
          _scale0 = sel.scale;
        } else {
          clearSelection();
          live
            ..pageId = pageId
            ..lasso = [pos]
            ..ping();
        }
      case NbMode.shape:
        clearSelection();
        final preset = box.pen;
        final width = preset.pen == NbPen.marker ? NbPenPreset.defaultWidth(NbPen.ball) : preset.width;
        live
          ..pageId = pageId
          ..stroke = null
          ..shape = NbShape(nbShortId(), box.shape, pos, pos, preset.color, width)
          ..ping();
      case NbMode.text:
        clearSelection();
    }
  }

  void move(String pageId, PointerMoveEvent e, Offset raw) {
    if (NbToolbox.isStylus(e)) box.lastStylus = DateTime.now();
    if (_touches.containsKey(e.pointer)) {
      _touches[e.pointer] = e.position;
      if (_pinching) {
        if (_touches.length >= 2) {
          final pts = _touches.values.toList();
          onPinchUpdate?.call((pts[0] + pts[1]) / 2, (pts[0] - pts[1]).distance / _pinchStart);
        }
        return;
      }
    }
    if (e.pointer != _pointer || pageId != _pointerPage) return;
    final pos = _inPage(raw);
    if ((pos - _downPos).distance > 0.008) _moved = true;
    switch (_mode) {
      case NbMode.pen:
        final s = live.stroke;
        if (_snapped) {
          // Depois de endireitada, a linha segue a ponta da caneta até soltar.
          if (s != null && s.length == 2) {
            s.pts[3] = pos.dx;
            s.pts[4] = pos.dy;
            live.ping();
          }
          return;
        }
        if (s == null) return;
        final pr = _pressure(e, pos);
        final p = _stream.next(pos);
        if ((p - s.at(s.length - 1)).distance < 0.0006) return;
        s.add(p, pr);
        live.ping();
        if ((pos - _holdAnchor).distance > 0.006) _armHold(pos);
      case NbMode.eraser:
        live.eraser = pos;
        _eraseTo(pageId, pos);
        live.ping();
      case NbMode.lasso:
        final sel = live.selection;
        if (_drag == _Drag.move && sel != null) {
          var shift = _shift0 + (pos - _dragStart);
          // A seleção não sai da folha.
          shift = Offset(shift.dx.clamp(-sel.box.left, math.max(-sel.box.left, 1 - sel.box.right)),
              shift.dy.clamp(-sel.box.top, math.max(-sel.box.top, nbPageRatio - sel.box.bottom)));
          sel.shift = shift;
          live.ping();
        } else if (_drag == _Drag.scale && sel != null) {
          final w = math.max(0.004, sel.box.width), h = math.max(0.004, sel.box.height);
          final from = _dragStart - sel.box.topLeft - sel.shift, to = pos - sel.box.topLeft - sel.shift;
          final f = math.max(to.dx / math.max(from.dx, 0.004), to.dy / math.max(from.dy, 0.004));
          final maxScale = math.min((1 - sel.box.left - sel.shift.dx) / w, (nbPageRatio - sel.box.top - sel.shift.dy) / h);
          sel.scale = (_scale0 * f).clamp(0.15, math.max(0.15, maxScale));
          live.ping();
        } else {
          final path = live.lasso;
          if (path != null && (pos - path.last).distance > 0.003) {
            path.add(pos);
            live.ping();
          }
        }
      case NbMode.shape:
        final sh = live.shape;
        if (sh != null) {
          live
            ..shape = NbShape(sh.id, sh.kind, sh.a, pos, sh.color, sh.width)
            ..ping();
        }
      case NbMode.hand:
      case NbMode.text:
        break;
    }
  }

  void up(String pageId, PointerEvent e, Offset raw, {bool cancel = false}) {
    _touches.remove(e.pointer);
    if (_pinching && _touches.length < 2) {
      _pinching = false;
      onPinchEnd?.call();
    }
    if (e.pointer != _pointer) return;
    if (cancel) {
      _cancelActive();
      return;
    }
    _pointer = null;
    _holdTimer?.cancel();
    final page = _pointerPage ?? pageId;
    final pg = pages[page];
    final pos = _inPage(raw);
    if (pg == null) return;
    switch (_mode) {
      case NbMode.pen:
        final s = live.stroke, shape = live.shape;
        live
          ..stroke = null
          ..shape = null;
        if (_snapped && shape != null) {
          _apply(page, [...pg.items, shape]);
        } else if (s != null) {
          // O último ponto é onde a caneta realmente saiu do papel (a suavização vinha um pouco atrás).
          if (!_snapped && s.length > 1 && (pos - s.at(s.length - 1)).distance > 0.0004) s.add(pos, s.pressure(s.length - 1));
          _apply(page, [...pg.items, s]);
        }
        live.ping();
      case NbMode.eraser:
        final before = _eraseBefore;
        _eraseBefore = null;
        live.eraser = null;
        if (before != null && !identical(before, pg.items)) {
          _undo.add(_Edit(page, before, pg.items));
          if (_undo.length > 80) _undo.removeAt(0);
          _redo.clear();
          _markDirty(page);
          notifyListeners();
        }
        live.ping();
      case NbMode.lasso:
        if (_drag != null) {
          _drag = null;
          _commitSelection();
          break;
        }
        final path = live.lasso;
        live.lasso = null;
        if (path == null || !_moved || path.length < 4) {
          final it = _topAt(pg, pos, 0.012);
          _select(page, [?it]);
        } else {
          _select(page, [
            for (final it in pg.items)
              if (_inside(it, path)) it
          ]);
        }
        live.ping();
      case NbMode.shape:
        final sh = live.shape;
        live.shape = null;
        if (sh != null && (sh.a - sh.b).distance > 0.008) _apply(page, [...pg.items, sh]);
        live.ping();
      case NbMode.text:
        if (!_moved) {
          final hit = _topAt(pg, pos, 0.006);
          if (hit is NbText && !hit.isVerse) {
            startText(page, existing: hit);
          } else {
            startText(page, at: pos);
          }
        }
      case NbMode.hand:
        break;
    }
  }

  static bool _inside(NbItem it, List<Offset> poly) {
    if (it is NbStroke) {
      var inside = 0;
      final n = it.length;
      final step = math.max(1, n ~/ 24);
      var seen = 0;
      for (var i = 0; i < n; i += step) {
        seen++;
        if (nbPointInPolygon(it.at(i), poly)) inside++;
      }
      return inside * 2 >= seen;
    }
    return nbPointInPolygon(it.bounds.center, poly);
  }

  /// Passa a borracha do último ponto até [pos] (sem deixar buracos quando a mão vai rápido).
  void _eraseTo(String pageId, Offset pos) {
    final pg = pages[pageId];
    if (pg == null) return;
    final r = box.eraserSize / 2;
    final from = _eraseLast ?? pos;
    final steps = math.max(1, ((pos - from).distance / (r * 0.8)).ceil());
    var items = pg.items;
    var changed = false;
    for (var k = 1; k <= steps; k++) {
      final c = Offset.lerp(from, pos, k / steps)!;
      List<NbItem>? out;
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        List<NbItem>? replace;
        if (it is NbStroke) {
          if (box.partialEraser) {
            replace = nbErasePartial(it, c, r);
          } else if (it.hit(c, r)) {
            replace = const [];
          }
        } else if (it is NbShape && it.hit(c, r)) {
          replace = const [];
        }
        if (replace != null) {
          out ??= items.sublist(0, i);
          out.addAll(replace);
        } else {
          out?.add(it);
        }
      }
      if (out != null) {
        items = out;
        changed = true;
      }
    }
    _eraseLast = pos;
    if (changed) {
      pg.items = items;
      tick(pageId).value++;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _holdTimer?.cancel();
    _saveTimer?.cancel();
    editing?.dispose();
    for (final t in _ticks.values) {
      t.dispose();
    }
    live.dispose();
    super.dispose();
  }
}

/// Camada de cima da página: o traço em andamento, a borracha, o laço e a seleção.
class NbLivePainter extends CustomPainter {
  final NbSession session;
  final String pageId;
  final Color accent;
  NbLivePainter(this.session, this.pageId, this.accent) : super(repaint: session.live);

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 8, metric.length)), paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final live = session.live;
    final pg = session.pages[pageId];
    if (pg == null) return;
    const w = nbPagePx;
    canvas.save();
    canvas.scale(size.width / w);
    final frame = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final sel = live.selection;
    if (sel != null && sel.pageId == pageId) {
      canvas.save();
      canvas.translate((sel.box.left + sel.shift.dx) * w, (sel.box.top + sel.shift.dy) * w);
      canvas.scale(sel.scale);
      canvas.translate(-sel.box.left * w, -sel.box.top * w);
      nbPaintItems(canvas, sel.items, pg.paper, session.images);
      canvas.restore();
      final r = sel.shown.inflate(0.008);
      final rect = Rect.fromLTRB(r.left * w, r.top * w, r.right * w, r.bottom * w);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = accent.withValues(alpha: 0.07));
      _dashed(canvas, Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6))), frame);
      canvas.drawCircle(rect.bottomRight, 11, Paint()..color = Colors.white);
      canvas.drawCircle(rect.bottomRight, 11, frame);
      canvas.drawCircle(rect.bottomRight, 4.5, Paint()..color = accent);
    }
    if (live.pageId == pageId) {
      final s = live.stroke;
      if (s != null) nbPaintStroke(canvas, s, pg.paper);
      final sh = live.shape;
      if (sh != null) nbPaintShape(canvas, sh, pg.paper);
      final lasso = live.lasso;
      if (lasso != null && lasso.length > 1) {
        final path = Path()..moveTo(lasso.first.dx * w, lasso.first.dy * w);
        for (final p in lasso.skip(1)) {
          path.lineTo(p.dx * w, p.dy * w);
        }
        _dashed(canvas, path, frame);
      }
      final er = live.eraser;
      if (er != null) {
        final c = er * w, r = session.box.eraserSize / 2 * w;
        canvas.drawCircle(c, r, Paint()..color = (pg.paper.isDark ? Colors.white : Colors.black).withValues(alpha: 0.12));
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = pg.paper.isDark ? Colors.white70 : Colors.black54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NbLivePainter old) => true;
}

/// Uma página do caderno com as camadas de desenho e a captura da caneta.
/// Sem ferramenta de escrita ("mão"), não segura nenhum toque: a folha só rola e amplia.
class NbPageView extends StatelessWidget {
  final NbSession session;
  final String pageId;
  const NbPageView({super.key, required this.session, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([session, session.box]),
      builder: (context, _) {
        final pg = session.pages[pageId];
        if (pg == null) {
          return const SizedBox(
            width: nbPagePx,
            height: nbPagePx * nbPageRatio,
            child: ColoredBox(color: Colors.white, child: Center(child: CircularProgressIndicator())),
          );
        }
        final ed = session.editing;
        final layers = Stack(children: [
          RepaintBoundary(
            child: CustomPaint(
              size: nbPageSize,
              isComplex: true,
              painter: NbPagePainter(pg, session.images, skip: () => session.skipFor(pageId), repaint: session.tick(pageId)),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(size: nbPageSize, willChange: true, painter: NbLivePainter(session, pageId, scheme.primary)),
          ),
          if (ed != null && ed.pageId == pageId) _TextBox(session: session, edit: ed, paper: pg.paper),
        ]);
        Offset unit(Offset local) => local / nbPagePx;
        final box = session.box;
        if (!box.drawing) {
          return SizedBox.fromSize(
            size: nbPageSize,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) => session.tapInHand(pageId, unit(d.localPosition)),
              child: layers,
            ),
          );
        }
        return SizedBox.fromSize(
          size: nbPageSize,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              DrawClaimRecognizer: GestureRecognizerFactoryWithHandlers<DrawClaimRecognizer>(
                () => DrawClaimRecognizer((e) => box.claims(e) && !session.inTextBox(pageId, unit(e.localPosition))),
                (_) {},
              ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: session.hover,
              onPointerDown: (e) => session.down(pageId, e, unit(e.localPosition)),
              onPointerMove: (e) => session.move(pageId, e, unit(e.localPosition)),
              onPointerUp: (e) => session.up(pageId, e, unit(e.localPosition)),
              onPointerCancel: (e) => session.up(pageId, e, unit(e.localPosition), cancel: true),
              child: layers,
            ),
          ),
        );
      },
    );
  }
}

/// Caixa de texto aberta para digitar, no lugar exato onde o texto fica na folha.
class _TextBox extends StatelessWidget {
  final NbSession session;
  final NbTextEdit edit;
  final NbPaper paper;
  const _TextBox({required this.session, required this.edit, required this.paper});

  @override
  Widget build(BuildContext context) {
    final it = edit.item;
    final scheme = Theme.of(context).colorScheme;
    const pad = 6.0;
    return Positioned(
      left: it.x * nbPagePx - pad,
      top: it.y * nbPagePx - pad,
      width: it.w * nbPagePx + pad * 2,
      child: Container(
        padding: const EdgeInsets.all(pad - 1.5),
        decoration: BoxDecoration(
          color: paper.color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: scheme.primary, width: 1.5),
        ),
        child: TextField(
          controller: edit.controller,
          focusNode: edit.focus,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: scheme.primary,
          onTapOutside: (_) => session.commitText(),
          style: TextStyle(
            color: nbInkColor(it.color, paper),
            fontSize: it.size * nbPagePx,
            height: 1.32,
            fontWeight: it.bold ? FontWeight.w700 : FontWeight.w400,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: 'Escreva aqui',
            hintStyle: TextStyle(color: nbInkColor(it.color, paper).withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
