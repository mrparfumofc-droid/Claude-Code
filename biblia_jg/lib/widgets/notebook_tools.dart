import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notebook_models.dart';
import '../services/palm_guard.dart';
import 'ink_tools.dart' show DockSide, FingerMode, inkBaseColors;
import 'notebook_painters.dart';

/// O que o toque faz na página.
enum NbMode { hand, pen, eraser, lasso, shape, text }

/// Caneta guardada na barra do caderno.
class NbPenPreset {
  NbPen pen;
  int color;
  double width; // relativa à largura da página
  NbPenPreset(this.pen, this.color, this.width);

  static double defaultWidth(NbPen pen) => switch (pen) {
        NbPen.ball => 0.0026,
        NbPen.fountain => 0.0042,
        NbPen.pencil => 0.0024,
        NbPen.marker => 0.022,
      };

  static (double, double) widthRange(NbPen pen) => pen == NbPen.marker ? (0.008, 0.05) : (0.0008, 0.014);

  IconData get icon => nbPenIcon(pen);
  String get sizeLabel => (width * 1000).toStringAsFixed(width * 1000 >= 10 ? 0 : 1);

  Map<String, dynamic> toJson() => {'p': pen.index, 'c': color, 'w': width};
  factory NbPenPreset.fromJson(Map<String, dynamic> j) => NbPenPreset(
      NbPen.values[((j['p'] as num?)?.toInt() ?? 0).clamp(0, NbPen.values.length - 1)],
      (j['c'] as num).toInt(),
      (j['w'] as num).toDouble());
}

IconData nbPenIcon(NbPen pen) => switch (pen) {
      NbPen.ball => Icons.edit,
      NbPen.fountain => Icons.history_edu,
      NbPen.pencil => Icons.create_outlined,
      NbPen.marker => Icons.border_color,
    };

IconData nbShapeIcon(NbShapeKind k) => switch (k) {
      NbShapeKind.line => Icons.horizontal_rule,
      NbShapeKind.arrow => Icons.arrow_right_alt,
      NbShapeKind.rect => Icons.crop_square,
      NbShapeKind.ellipse => Icons.circle_outlined,
    };

/// Ferramentas do caderno (canetas, borracha, laço, formas e texto) e preferências, guardadas no aparelho.
class NbToolbox extends ChangeNotifier {
  final SharedPreferences? _prefs;
  NbToolbox._(this._prefs);

  /// Sem gravar nada (testes).
  factory NbToolbox.memory() => NbToolbox._(null);

  NbMode mode = NbMode.pen;
  List<NbPenPreset> pens = _defaults();
  int penIndex = 0;
  bool partialEraser = false;
  double eraserSize = 0.02;
  NbShapeKind shape = NbShapeKind.line;
  double textSize = 0.026;
  bool textBold = false;
  int textColor = 0xFF1A1A1A;
  double smoothing = 0.3;
  bool holdToStraighten = true;
  DockSide side = DockSide.top;
  bool collapsed = false;
  FingerMode finger = FingerMode.auto;
  bool stylusSeen = false;
  List<int> myColors = [];

  /// Último instante em que a caneta física esteve na tela ou perto dela (para ignorar a palma da mão).
  DateTime lastStylus = DateTime(2000);

  /// Cores de troca rápida na barra (valem para a caneta escolhida).
  static const quickColors = <int>[0xFF1A1A1A, 0xFF1565C0, 0xFFD32F2F, 0xFF2E7D32, 0xFF7B1FA2];

  void setPenColor(int color) {
    pen.color = color;
    save();
  }

  static List<NbPenPreset> _defaults() => [
        NbPenPreset(NbPen.ball, 0xFF1A1A1A, NbPenPreset.defaultWidth(NbPen.ball)),
        NbPenPreset(NbPen.fountain, 0xFF1565C0, NbPenPreset.defaultWidth(NbPen.fountain)),
        NbPenPreset(NbPen.ball, 0xFFD32F2F, NbPenPreset.defaultWidth(NbPen.ball)),
        NbPenPreset(NbPen.pencil, 0xFF616161, NbPenPreset.defaultWidth(NbPen.pencil)),
        NbPenPreset(NbPen.marker, 0xFFFFEB3B, NbPenPreset.defaultWidth(NbPen.marker)),
      ];

  static Future<NbToolbox> load() async {
    final prefs = await SharedPreferences.getInstance();
    final box = NbToolbox._(prefs);
    try {
      final raw = prefs.getString('nb.tools');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final pens = [for (final p in j['pens'] as List? ?? const []) NbPenPreset.fromJson((p as Map).cast())];
        if (pens.isNotEmpty) box.pens = pens;
        box.penIndex = ((j['pen'] as num?)?.toInt() ?? 0).clamp(0, box.pens.length - 1);
        box.partialEraser = j['partial'] == true;
        box.eraserSize = (j['eraser'] as num?)?.toDouble() ?? box.eraserSize;
        box.shape = NbShapeKind.values[((j['shape'] as num?)?.toInt() ?? 0).clamp(0, NbShapeKind.values.length - 1)];
        box.textSize = (j['ts'] as num?)?.toDouble() ?? box.textSize;
        box.textBold = j['tb'] == true;
        box.textColor = (j['tc'] as num?)?.toInt() ?? box.textColor;
        box.smoothing = (j['smooth'] as num?)?.toDouble() ?? box.smoothing;
        box.holdToStraighten = j['hold'] != false;
        box.side = DockSide.values[((j['side'] as num?)?.toInt() ?? 0).clamp(0, DockSide.values.length - 1)];
        box.collapsed = j['collapsed'] == true;
        box.finger = FingerMode.values[((j['finger'] as num?)?.toInt() ?? 0).clamp(0, FingerMode.values.length - 1)];
        box.myColors = [for (final c in j['colors'] as List? ?? const []) (c as num).toInt()];
      }
      // A caneta física já usada no leitor de PDF vale aqui também.
      box.stylusSeen = prefs.getBool('ink.stylus') ?? false;
    } catch (_) {}
    return box;
  }

  void save() {
    _prefs?.setString(
        'nb.tools',
        jsonEncode({
          'pens': [for (final p in pens) p.toJson()],
          'pen': penIndex,
          'partial': partialEraser,
          'eraser': eraserSize,
          'shape': shape.index,
          'ts': textSize,
          'tb': textBold,
          'tc': textColor,
          'smooth': smoothing,
          'hold': holdToStraighten,
          'side': side.index,
          'collapsed': collapsed,
          'finger': finger.index,
          'colors': myColors,
        }));
    notifyListeners();
  }

  NbPenPreset get pen => pens[penIndex.clamp(0, pens.length - 1)];
  bool get drawing => mode != NbMode.hand;
  bool get fingerDraws => switch (finger) { FingerMode.always => true, FingerMode.never => false, FingerMode.auto => !stylusSeen };
  bool get stylusNear => DateTime.now().difference(lastStylus) < const Duration(milliseconds: 1200);

  static bool isStylus(PointerEvent e) => e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
  static bool isMouse(PointerEvent e) => e.kind == PointerDeviceKind.mouse;

  void sawStylus() {
    lastStylus = DateTime.now();
    if (!stylusSeen) {
      stylusSeen = true;
      _prefs?.setBool('ink.stylus', true);
    }
  }

  /// Este toque escreve? (caneta física e mouse sempre; dedo conforme a preferência)
  bool draws(PointerEvent e) => drawing && (isStylus(e) || isMouse(e) || (fingerDraws && !stylusNear));

  /// Este toque não deve mover a página? Inclui a palma da mão enquanto a caneta está por perto.
  bool claims(PointerEvent e) => drawing && (isStylus(e) || isMouse(e) || fingerDraws || stylusNear);

  void setMode(NbMode m) {
    if (mode == m) return;
    mode = m;
    notifyListeners();
  }

  void selectPen(int i) {
    penIndex = i.clamp(0, pens.length - 1);
    mode = NbMode.pen;
    save();
  }
}

// ---------------------------------------------------------------------------
// Barra de ferramentas
// ---------------------------------------------------------------------------

/// Barra do caderno: mão, canetas guardadas, borracha, laço, formas, texto e ajustes.
class NbDock extends StatelessWidget {
  final NbToolbox box;
  final bool vertical;
  final void Function(int index) onEditPen;
  final VoidCallback onAddPen;
  final VoidCallback onEraserOptions;
  final VoidCallback onTextOptions;
  final VoidCallback onSettings;
  const NbDock({
    super.key,
    required this.box,
    required this.vertical,
    required this.onEditPen,
    required this.onAddPen,
    required this.onEraserOptions,
    required this.onTextOptions,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tool({required IconData icon, required String tip, bool on = false, VoidCallback? onTap, VoidCallback? onLong}) => Tooltip(
          message: tip,
          child: InkResponse(
            onTap: onTap,
            onLongPress: onLong,
            radius: 26,
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(color: on ? scheme.primaryContainer : null, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 23, color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
          ),
        );
    Widget gap() => vertical
        ? SizedBox(width: 28, child: Divider(height: 9, color: scheme.outlineVariant))
        : SizedBox(height: 28, child: VerticalDivider(width: 9, color: scheme.outlineVariant));

    final items = <Widget>[
      tool(
        icon: box.collapsed ? (vertical ? Icons.expand_more : Icons.chevron_right) : (vertical ? Icons.expand_less : Icons.chevron_left),
        tip: box.collapsed ? 'Mostrar as ferramentas' : 'Recolher as ferramentas',
        onTap: () {
          box.collapsed = !box.collapsed;
          box.save();
        },
      ),
      if (!box.collapsed) ...[
        tool(
            icon: Icons.pan_tool_alt_outlined,
            tip: 'Mover a página (sem escrever)',
            on: box.mode == NbMode.hand,
            onTap: () => box.setMode(NbMode.hand)),
        gap(),
        for (var i = 0; i < box.pens.length; i++)
          _PenChip(
            preset: box.pens[i],
            selected: box.mode == NbMode.pen && box.penIndex == i,
            onTap: () => box.mode == NbMode.pen && box.penIndex == i ? onEditPen(i) : box.selectPen(i),
            onLongPress: () => onEditPen(i),
          ),
        if (box.pens.length < 8) tool(icon: Icons.add, tip: 'Guardar mais uma caneta', onTap: onAddPen),
        if (box.mode == NbMode.pen || box.mode == NbMode.shape) ...[
          gap(),
          for (final c in NbToolbox.quickColors)
            Tooltip(
              message: 'Trocar a cor da caneta',
              child: InkResponse(
                radius: 22,
                onTap: () => box.setPenColor(c),
                child: Container(
                  width: 38,
                  height: 46,
                  alignment: Alignment.center,
                  child: Container(
                    width: box.pen.color == c ? 28 : 22,
                    height: box.pen.color == c ? 28 : 22,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: box.pen.color == c ? scheme.primary : scheme.outlineVariant, width: box.pen.color == c ? 2.5 : 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
        gap(),
        tool(
            icon: Icons.auto_fix_normal,
            tip: box.mode == NbMode.eraser ? 'Borracha: toque de novo para ajustar' : 'Borracha',
            on: box.mode == NbMode.eraser,
            onTap: () => box.mode == NbMode.eraser ? onEraserOptions() : box.setMode(NbMode.eraser),
            onLong: onEraserOptions),
        tool(
            icon: Icons.highlight_alt,
            tip: 'Laço: contorne para selecionar, mover e redimensionar',
            on: box.mode == NbMode.lasso,
            onTap: () => box.setMode(NbMode.lasso)),
        PopupMenuButton<NbShapeKind>(
          tooltip: 'Formas',
          position: PopupMenuPosition.under,
          onSelected: (k) {
            box
              ..shape = k
              ..mode = NbMode.shape
              ..save();
          },
          itemBuilder: (_) => [
            for (final k in NbShapeKind.values)
              PopupMenuItem(value: k, child: Row(children: [Icon(nbShapeIcon(k)), const SizedBox(width: 12), Text(k.label)])),
          ],
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
                color: box.mode == NbMode.shape ? scheme.primaryContainer : null, borderRadius: BorderRadius.circular(14)),
            child: Icon(nbShapeIcon(box.shape),
                size: 23, color: box.mode == NbMode.shape ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          ),
        ),
        tool(
            icon: Icons.title,
            tip: box.mode == NbMode.text ? 'Texto: toque de novo para ajustar' : 'Texto: toque na página para escrever',
            on: box.mode == NbMode.text,
            onTap: () => box.mode == NbMode.text ? onTextOptions() : box.setMode(NbMode.text),
            onLong: onTextOptions),
        gap(),
        tool(icon: Icons.tune, tip: 'Posição da barra e opções da caneta', onTap: onSettings),
      ],
    ];
    return Material(
      elevation: 2,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: vertical,
        left: vertical,
        right: vertical,
        child: SingleChildScrollView(
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          padding: const EdgeInsets.all(4),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: items)
              : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: items),
        ),
      ),
    );
  }
}

class _PenChip extends StatelessWidget {
  final NbPenPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _PenChip({required this.preset, required this.selected, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(preset.color);
    return Tooltip(
      message: '${preset.pen.label} ${preset.sizeLabel}${selected ? ' · toque de novo para ajustar' : ''}',
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 26,
        child: Container(
          width: 48,
          height: 50,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(14),
            border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(preset.icon, size: 22, color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            const SizedBox(height: 3),
            Container(
              width: 24,
              height: preset.pen == NbPen.marker ? 7 : (preset.width * 900).clamp(2.5, 6.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: color.computeLuminance() > 0.8 ? Border.all(color: scheme.outline, width: 0.5) : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StrokePreview extends CustomPainter {
  final NbPenPreset preset;
  _StrokePreview(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    // Um traço em onda, mais forte no meio, para mostrar o efeito da pressão no tinteiro.
    final pts = <double>[];
    const n = 48;
    final unit = nbPagePx;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      pts
        ..add((20 + t * (size.width - 40)) / unit)
        ..add((size.height / 2 + math.sin(t * math.pi * 2) * size.height * 0.24) / unit)
        ..add(0.2 + 0.7 * math.sin(t * math.pi));
    }
    nbPaintStroke(canvas, NbStroke('p', preset.pen, preset.color, preset.width, pts), NbPaper.white);
  }

  @override
  bool shouldRepaint(_StrokePreview old) => true;
}

Widget _swatch(BuildContext context, int color, bool selected, VoidCallback onTap, {VoidCallback? onLongPress}) {
  final scheme = Theme.of(context).colorScheme;
  return Semantics(
    button: true,
    selected: selected,
    label: 'Cor',
    child: InkResponse(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 26,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Container(
          width: selected ? 38 : 32,
          height: selected ? 38 : 32,
          decoration: BoxDecoration(
            color: Color(color),
            shape: BoxShape.circle,
            border: Border.all(width: selected ? 3 : 1, color: selected ? scheme.primary : scheme.outlineVariant),
          ),
        ),
      ),
    ),
  );
}

/// Paleta de cores (prontas, do usuário e criador de cor). Usada pela caneta, pelo texto e pelo laço.
class NbColorPicker extends StatefulWidget {
  final NbToolbox box;
  final int color;
  final ValueChanged<int> onChanged;
  const NbColorPicker({super.key, required this.box, required this.color, required this.onChanged});

  @override
  State<NbColorPicker> createState() => _NbColorPickerState();
}

class _NbColorPickerState extends State<NbColorPicker> {
  bool _mixing = false;
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.color));

  void _mix(HSVColor c) {
    setState(() => _hsv = c);
    widget.onChanged(c.toColor().toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = widget.box;
    Widget slider(String label, double value, double max, ValueChanged<double> onChanged) => Row(children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(children: [
        for (final c in inkBaseColors)
          _swatch(context, c.toARGB32(), c.toARGB32() == widget.color, () {
            _hsv = HSVColor.fromColor(c);
            widget.onChanged(c.toARGB32());
          }),
      ]),
      if (box.myColors.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Minhas cores (segure para apagar)', style: theme.textTheme.labelLarge),
        Wrap(children: [
          for (final c in box.myColors)
            _swatch(context, c, c == widget.color, () {
              _hsv = HSVColor.fromColor(Color(c));
              widget.onChanged(c);
            }, onLongPress: () {
              box.myColors.remove(c);
              box.save();
              setState(() {});
            }),
        ]),
      ],
      const SizedBox(height: 4),
      if (!_mixing)
        TextButton.icon(
          icon: const Icon(Icons.palette_outlined),
          label: const Text('Criar uma cor'),
          onPressed: () => setState(() => _mixing = true),
        )
      else ...[
        Container(
          height: 14,
          margin: const EdgeInsets.fromLTRB(104, 8, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor()]),
          ),
        ),
        slider('Tom', _hsv.hue, 359, (v) => _mix(_hsv.withHue(v))),
        slider('Vivacidade', _hsv.saturation, 1, (v) => _mix(_hsv.withSaturation(v))),
        slider('Claridade', _hsv.value, 1, (v) => _mix(_hsv.withValue(v))),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add),
          label: const Text('Guardar na minha paleta'),
          onPressed: () {
            final c = _hsv.toColor().toARGB32();
            box.myColors
              ..remove(c)
              ..insert(0, c);
            if (box.myColors.length > 24) box.myColors.removeLast();
            box.save();
            setState(() {});
          },
        ),
      ],
    ]);
  }
}

/// Ajustes de uma caneta guardada: ponta, espessura e cor. Retorna true se ela foi excluída.
Future<bool> showNbPenEditor(BuildContext context, NbToolbox box, int index) async {
  final preset = box.pens[index];
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final theme = Theme.of(ctx);
      final (min, max) = NbPenPreset.widthRange(preset.pen);
      void change(VoidCallback f) {
        setSheet(f);
        box.save();
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Ajustar a caneta', style: theme.textTheme.titleLarge)),
              if (box.pens.length > 1)
                TextButton.icon(
                    icon: const Icon(Icons.delete_outline), label: const Text('Excluir'), onPressed: () => Navigator.pop(ctx, true)),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<NbPen>(
                showSelectedIcon: false,
                segments: [for (final p in NbPen.values) ButtonSegment(value: p, icon: Icon(nbPenIcon(p)), label: Text(p.label))],
                selected: {preset.pen},
                onSelectionChanged: (v) => change(() {
                  final wasMarker = preset.pen == NbPen.marker;
                  preset.pen = v.first;
                  if (wasMarker != (preset.pen == NbPen.marker)) preset.width = NbPenPreset.defaultWidth(preset.pen);
                }),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: CustomPaint(painter: _StrokePreview(preset)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 92, child: Text('Espessura')),
              Expanded(
                  child: Slider(
                      value: preset.width.clamp(min, max), min: min, max: max, onChanged: (v) => change(() => preset.width = v))),
            ]),
            if (preset.pen == NbPen.fountain)
              Text('O tinteiro engrossa quando você aperta mais a caneta.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Cor', style: theme.textTheme.titleSmall),
            NbColorPicker(box: box, color: preset.color, onChanged: (c) => change(() => preset.color = c)),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Pronto'))),
          ]),
        ),
      );
    }),
  );
  if (deleted == true && box.pens.length > 1) {
    box.pens.removeAt(index);
    box.penIndex = box.penIndex.clamp(0, box.pens.length - 1);
    box.save();
    return true;
  }
  box.save();
  return false;
}

/// Opções da borracha: apagar o traço inteiro ou só onde passa, tamanho e limpar a página.
Future<void> showNbEraserOptions(BuildContext context, NbToolbox box, {required VoidCallback onClearPage}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Borracha', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.gesture), label: Text('Traço inteiro')),
                  ButtonSegment(value: true, icon: Icon(Icons.auto_fix_normal), label: Text('Só onde passa')),
                ],
                selected: {box.partialEraser},
                onSelectionChanged: (v) => setSheet(() {
                  box.partialEraser = v.first;
                  box.save();
                }),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 92, child: Text('Tamanho')),
                Expanded(
                  child: Slider(
                    value: box.eraserSize.clamp(0.006, 0.06),
                    min: 0.006,
                    max: 0.06,
                    onChanged: (v) => setSheet(() {
                      box.eraserSize = v;
                      box.save();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.layers_clear),
                label: const Text('Limpar a página inteira'),
                onPressed: () {
                  Navigator.pop(ctx);
                  onClearPage();
                },
              ),
            ]),
          ),
        ),
      ),
    );

/// Opções do texto: tamanho, negrito e cor.
Future<void> showNbTextOptions(BuildContext context, NbToolbox box) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void change(VoidCallback f) {
            setSheet(f);
            box.save();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Texto digitado', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Row(children: [
                  const SizedBox(width: 92, child: Text('Tamanho')),
                  Expanded(
                      child: Slider(
                          value: box.textSize.clamp(0.014, 0.07),
                          min: 0.014,
                          max: 0.07,
                          onChanged: (v) => change(() => box.textSize = v))),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Negrito'),
                  value: box.textBold,
                  onChanged: (v) => change(() => box.textBold = v),
                ),
                Text('Cor', style: Theme.of(ctx).textTheme.titleSmall),
                NbColorPicker(box: box, color: box.textColor, onChanged: (c) => change(() => box.textColor = c)),
              ]),
            ),
          );
        },
      ),
    );

/// Opções gerais: onde fica a barra, quando o dedo escreve, estabilização e endireitar formas.
Future<void> showNbSettings(BuildContext context, NbToolbox box) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void change(VoidCallback f) {
            setSheet(f);
            box.save();
          }

          final theme = Theme.of(ctx);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Barra e caneta', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text('Posição da barra de ferramentas'),
                const SizedBox(height: 6),
                SegmentedButton<DockSide>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: DockSide.top, icon: Icon(Icons.border_top), label: Text('Topo')),
                    ButtonSegment(value: DockSide.left, icon: Icon(Icons.border_left), label: Text('Esquerda')),
                    ButtonSegment(value: DockSide.right, icon: Icon(Icons.border_right), label: Text('Direita')),
                  ],
                  selected: {box.side},
                  onSelectionChanged: (v) => change(() => box.side = v.first),
                ),
                const SizedBox(height: 16),
                const Text('Escrever com o dedo'),
                const SizedBox(height: 6),
                SegmentedButton<FingerMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: FingerMode.auto, label: Text('Automático')),
                    ButtonSegment(value: FingerMode.always, label: Text('Sempre')),
                    ButtonSegment(value: FingerMode.never, label: Text('Nunca')),
                  ],
                  selected: {box.finger},
                  onSelectionChanged: (v) => change(() => box.finger = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  'No automático, a caneta escreve e o dedo move a página; a palma da mão é ignorada. '
                  'Em aparelhos sem caneta o dedo escreve, e dois dedos movem e dão zoom.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const SizedBox(width: 132, child: Text('Estabilizar o traço')),
                  Expanded(child: Slider(value: box.smoothing.clamp(0, 0.7), max: 0.7, onChanged: (v) => change(() => box.smoothing = v))),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Segurar para endireitar'),
                  subtitle: const Text('Pare a caneta no fim do traço: a linha fica reta e o círculo, redondo.'),
                  value: box.holdToStraighten,
                  onChanged: (v) => change(() => box.holdToStraighten = v),
                ),
                const SizedBox(height: 8),
                const PalmModeSelector(),
              ]),
            ),
          );
        },
      ),
    );
