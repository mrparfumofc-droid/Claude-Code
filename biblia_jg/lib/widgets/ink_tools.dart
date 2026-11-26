import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/books_service.dart' show InkTool;
import '../services/palm_guard.dart';

/// Tipo de ponta de uma caneta guardada.
enum PenKind { pen, pencil, marker }

/// Caneta guardada na barra: tipo, cor, espessura (relativa à largura da página) e intensidade.
class PenPreset {
  PenKind kind;
  Color color;
  double width;
  double opacity;
  PenPreset(this.kind, this.color, this.width, [this.opacity = 1]);

  InkTool get tool => kind == PenKind.marker ? InkTool.marker : InkTool.pen;

  /// Cor gravada no traço: a intensidade vai na transparência.
  Color get strokeColor => color.withValues(alpha: opacity.clamp(0.1, 1.0));

  String get name => switch (kind) { PenKind.pen => 'Caneta', PenKind.pencil => 'Lápis', PenKind.marker => 'Marca-texto' };
  IconData get icon =>
      switch (kind) { PenKind.pen => Icons.edit, PenKind.pencil => Icons.create_outlined, PenKind.marker => Icons.border_color };

  /// Número mostrado na barra (como nos apps de anotação): espessura em "pontos".
  String get sizeLabel => (width * 1000).toStringAsFixed(width * 1000 >= 10 ? 0 : 1);

  Map<String, dynamic> toJson() => {'k': kind.index, 'c': color.toARGB32(), 'w': width, 'o': opacity};
  factory PenPreset.fromJson(Map<String, dynamic> j) => PenPreset(
        PenKind.values[((j['k'] as num?)?.toInt() ?? 0).clamp(0, PenKind.values.length - 1)],
        Color((j['c'] as num).toInt()),
        (j['w'] as num).toDouble(),
        (j['o'] as num?)?.toDouble() ?? 1,
      );
}

const inkBaseColors = <Color>[
  Color(0xFF1A1A1A), Color(0xFF616161), Color(0xFFD32F2F), Color(0xFFE64A19), Color(0xFFF9A825), Color(0xFF2E7D32),
  Color(0xFF00897B), Color(0xFF1565C0), Color(0xFF3949AB), Color(0xFF7B1FA2), Color(0xFFC2185B), Color(0xFF6D4C41),
  Color(0xFFFFEB3B), Color(0xFF8BC34A), Color(0xFF4FC3F7), Color(0xFFFF8A80), Color(0xFFCE93D8), Color(0xFFFFB74D),
];

/// Onde fica a barra de ferramentas do leitor de PDF.
enum DockSide { top, left, right }

/// Quando o dedo também desenha.
enum FingerMode { auto, always, never }

/// Ferramentas de anotação à mão (canetas guardadas, cores do usuário e preferências), guardadas no aparelho.
/// Sem ferramenta escolhida, a caneta e o dedo só movem a página.
class InkToolbox extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<PenPreset> presets;
  List<Color> myColors;
  DockSide side;
  FingerMode finger;
  bool collapsed;

  /// Uma caneta física já foi usada neste aparelho: no modo automático o dedo deixa de riscar.
  bool stylusSeen;
  int? selected; // null = mão (mover a página)
  bool eraser = false;

  /// Último instante em que a caneta física esteve na tela ou perto dela (para ignorar a palma da mão).
  DateTime lastStylus = DateTime(2000);

  InkToolbox._(this._prefs, this.presets, this.myColors, this.side, this.finger, this.collapsed, this.stylusSeen);

  static List<PenPreset> _defaults() => [
        PenPreset(PenKind.pen, const Color(0xFF1A1A1A), 0.0030),
        PenPreset(PenKind.pen, const Color(0xFF1565C0), 0.0035),
        PenPreset(PenKind.pen, const Color(0xFFD32F2F), 0.0035),
        PenPreset(PenKind.pencil, const Color(0xFF424242), 0.0025, 0.75),
        PenPreset(PenKind.marker, const Color(0xFFFFEB3B), 0.020),
        PenPreset(PenKind.marker, const Color(0xFF8BC34A), 0.020),
      ];

  static Future<InkToolbox> load() async {
    final prefs = await SharedPreferences.getInstance();
    var presets = _defaults();
    try {
      final raw = prefs.getString('ink.presets');
      if (raw != null) {
        final list = [for (final j in jsonDecode(raw) as List) PenPreset.fromJson(Map<String, dynamic>.from(j as Map))];
        if (list.isNotEmpty) presets = list;
      }
    } catch (_) {}
    return InkToolbox._(
      prefs,
      presets,
      [for (final c in prefs.getStringList('ink.colors') ?? const <String>[]) Color(int.tryParse(c) ?? 0xFF000000)],
      DockSide.values[(prefs.getInt('ink.side') ?? 0).clamp(0, 2)],
      FingerMode.values[(prefs.getInt('ink.finger') ?? 0).clamp(0, 2)],
      prefs.getBool('ink.collapsed') ?? false,
      prefs.getBool('ink.stylus') ?? false,
    );
  }

  void save() {
    _prefs.setString('ink.presets', jsonEncode([for (final p in presets) p.toJson()]));
    _prefs.setStringList('ink.colors', [for (final c in myColors) '${c.toARGB32()}']);
    _prefs.setInt('ink.side', side.index);
    _prefs.setInt('ink.finger', finger.index);
    _prefs.setBool('ink.collapsed', collapsed);
    _prefs.setBool('ink.stylus', stylusSeen);
    notifyListeners();
  }

  bool get drawing => eraser || selected != null;
  PenPreset? get current => selected == null || selected! >= presets.length ? null : presets[selected!];

  bool get fingerDraws => switch (finger) { FingerMode.always => true, FingerMode.never => false, FingerMode.auto => !stylusSeen };

  bool get stylusNear => DateTime.now().difference(lastStylus) < const Duration(milliseconds: 1200);

  static bool isStylus(PointerEvent e) => e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  void sawStylus() {
    lastStylus = DateTime.now();
    if (!stylusSeen) {
      stylusSeen = true;
      _prefs.setBool('ink.stylus', true);
    }
  }

  /// Este toque desenha? (caneta física sempre; dedo conforme a preferência)
  bool draws(PointerEvent e) => drawing && (isStylus(e) || (fingerDraws && !stylusNear));

  /// Este toque deve ser tirado do visualizador (não mover a página)? Inclui a palma da mão
  /// enquanto a caneta está por perto.
  bool claims(PointerEvent e) => drawing && (isStylus(e) || fingerDraws || stylusNear);

  void select(int? index) {
    selected = index;
    eraser = false;
    notifyListeners();
  }

  void useEraser() {
    eraser = true;
    selected = null;
    notifyListeners();
  }

  void useHand() {
    eraser = false;
    selected = null;
    notifyListeners();
  }
}

/// Tira do visualizador de PDF os toques que são para desenhar (ele não rola nem dá zoom com eles).
class DrawClaimRecognizer extends EagerGestureRecognizer {
  final bool Function(PointerEvent) claims;
  DrawClaimRecognizer(this.claims);

  @override
  bool isPointerAllowed(PointerDownEvent event) => claims(event);
}

/// Barra de ferramentas do leitor: mão, canetas guardadas, borracha, desfazer, limpar, marcador e ajustes.
class InkDock extends StatelessWidget {
  final InkToolbox box;
  final bool vertical;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final bool bookmarked;
  final VoidCallback? onBookmark; // null = sem marcador de página
  final VoidCallback? onClose; // botão de sair (leitor da Bíblia)
  final void Function(int index) onEdit;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  const InkDock({
    super.key,
    required this.box,
    required this.vertical,
    required this.onUndo,
    required this.onClear,
    this.bookmarked = false,
    this.onBookmark,
    this.onClose,
    required this.onEdit,
    required this.onAdd,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tool({required IconData icon, required String tip, required bool on, VoidCallback? onTap, Color? color}) => Tooltip(
          message: tip,
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: on ? scheme.primaryContainer : null, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: onTap == null ? scheme.onSurface.withValues(alpha: 0.3) : (color ?? scheme.onSurface)),
            ),
          ),
        );

    final items = <Widget>[
      tool(
        icon: box.collapsed ? (vertical ? Icons.expand_more : Icons.chevron_right) : (vertical ? Icons.expand_less : Icons.chevron_left),
        tip: box.collapsed ? 'Mostrar as ferramentas' : 'Recolher as ferramentas',
        on: false,
        onTap: () {
          box.collapsed = !box.collapsed;
          box.save();
        },
      ),
      if (!box.collapsed) ...[
        tool(icon: Icons.pan_tool_alt_outlined, tip: 'Mover a página (sem riscar)', on: !box.drawing, onTap: box.useHand),
        for (var i = 0; i < box.presets.length; i++)
          _PenButton(
            preset: box.presets[i],
            selected: box.selected == i,
            vertical: vertical,
            onTap: () => box.selected == i ? onEdit(i) : box.select(i),
            onLongPress: () => onEdit(i),
          ),
        tool(icon: Icons.add, tip: 'Nova caneta', on: false, onTap: onAdd),
        tool(icon: Icons.auto_fix_normal, tip: 'Borracha', on: box.eraser, onTap: box.useEraser),
        tool(icon: Icons.undo, tip: 'Desfazer', on: false, onTap: onUndo),
        tool(icon: Icons.layers_clear, tip: 'Limpar a página', on: false, onTap: onClear),
        if (onBookmark != null)
          tool(
            icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
            tip: bookmarked ? 'Tirar o marcador desta página' : 'Marcar esta página',
            on: false,
            color: bookmarked ? scheme.primary : null,
            onTap: onBookmark,
          ),
        tool(icon: Icons.tune, tip: 'Posição da barra e opções', on: false, onTap: onSettings),
      ],
      if (onClose != null) tool(icon: Icons.close, tip: 'Sair da escrita', on: false, onTap: onClose),
    ];
    return Material(
      elevation: 3,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: vertical,
        left: vertical,
        right: vertical,
        child: SingleChildScrollView(
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          padding: const EdgeInsets.all(4),
          child: vertical ? Column(mainAxisSize: MainAxisSize.min, children: items) : Row(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

class _PenButton extends StatelessWidget {
  final PenPreset preset;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _PenButton(
      {required this.preset, required this.selected, required this.vertical, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '${preset.name} ${preset.sizeLabel}${selected ? ' · toque de novo para ajustar' : ''}',
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 26,
        child: Container(
          width: 44,
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(preset.icon, size: 22, color: preset.color.withValues(alpha: preset.kind == PenKind.marker ? 1 : preset.opacity.clamp(0.5, 1))),
            const SizedBox(height: 1),
            Container(
              width: 22,
              height: (preset.width * 600).clamp(2.0, 7.0),
              decoration: BoxDecoration(color: preset.color, borderRadius: BorderRadius.circular(3)),
            ),
            Text(preset.sizeLabel, style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, height: 1.3)),
          ]),
        ),
      ),
    );
  }
}

/// Ajustes de uma caneta guardada: tipo, espessura, intensidade e cor (com paleta e cores criadas).
/// Retorna true se a caneta foi excluída.
Future<bool> showPenEditor(BuildContext context, InkToolbox box, int index) async {
  final preset = box.presets[index];
  var mixing = false;
  var hsv = HSVColor.fromColor(preset.color);
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final theme = Theme.of(ctx);
      final marker = preset.kind == PenKind.marker;
      void change(VoidCallback f) {
        setSheet(f);
        box.save();
      }

      Widget swatch(Color c, {bool mine = false}) => GestureDetector(
            onTap: () => change(() {
              preset.color = c;
              hsv = HSVColor.fromColor(c);
            }),
            onLongPress: mine ? () => change(() => box.myColors.remove(c)) : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    width: preset.color.toARGB32() == c.toARGB32() ? 3.5 : 1,
                    color: preset.color.toARGB32() == c.toARGB32() ? theme.colorScheme.primary : Colors.grey),
              ),
            ),
          );

      Widget slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Row(children: [
            SizedBox(width: 92, child: Text(label)),
            Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged)),
          ]);

      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Ajustar a caneta', style: theme.textTheme.titleLarge)),
              if (box.presets.length > 1)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
            ]),
            const SizedBox(height: 8),
            SegmentedButton<PenKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PenKind.pen, icon: Icon(Icons.edit), label: Text('Caneta')),
                ButtonSegment(value: PenKind.pencil, icon: Icon(Icons.create_outlined), label: Text('Lápis')),
                ButtonSegment(value: PenKind.marker, icon: Icon(Icons.border_color), label: Text('Marca-texto')),
              ],
              selected: {preset.kind},
              onSelectionChanged: (v) => change(() {
                final k = v.first;
                if (k == PenKind.marker && preset.kind != PenKind.marker) preset.width = 0.020;
                if (k != PenKind.marker && preset.kind == PenKind.marker) preset.width = 0.0032;
                if (k == PenKind.pencil) preset.opacity = 0.75;
                if (k == PenKind.pen) preset.opacity = 1;
                preset.kind = k;
              }),
            ),
            const SizedBox(height: 12),
            // Amostra do traço.
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
              child: CustomPaint(painter: _PreviewPainter(preset)),
            ),
            const SizedBox(height: 8),
            slider('Espessura', preset.width, marker ? 0.008 : 0.001, marker ? 0.045 : 0.014, (v) => change(() => preset.width = v)),
            slider('Intensidade', preset.opacity, 0.15, 1, (v) => change(() => preset.opacity = v)),
            const SizedBox(height: 4),
            Text('Cores', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final c in inkBaseColors) swatch(c)]),
            if (box.myColors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Minhas cores (segure para apagar)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final c in box.myColors) swatch(c, mine: true)]),
            ],
            const SizedBox(height: 8),
            if (!mixing)
              OutlinedButton.icon(
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Criar uma cor'),
                onPressed: () => setSheet(() => mixing = true),
              )
            else ...[
              Text('Criar uma cor', style: theme.textTheme.titleSmall),
              // Faixa com todas as tonalidades.
              Container(
                height: 14,
                margin: const EdgeInsets.fromLTRB(104, 8, 12, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor()]),
                ),
              ),
              slider('Tom', hsv.hue, 0, 359, (v) => change(() {
                    hsv = hsv.withHue(v);
                    preset.color = hsv.toColor();
                  })),
              slider('Vivacidade', hsv.saturation, 0, 1, (v) => change(() {
                    hsv = hsv.withSaturation(v);
                    preset.color = hsv.toColor();
                  })),
              slider('Claridade', hsv.value, 0, 1, (v) => change(() {
                    hsv = hsv.withValue(v);
                    preset.color = hsv.toColor();
                  })),
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: preset.color, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: const Text('Guardar na minha paleta'),
                  onPressed: () => change(() {
                    final c = preset.color;
                    box.myColors.removeWhere((x) => x.toARGB32() == c.toARGB32());
                    box.myColors.insert(0, c);
                    if (box.myColors.length > 24) box.myColors.removeLast();
                  }),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Pronto')),
            ),
          ]),
        ),
      );
    }),
  );
  if (deleted == true && box.presets.length > 1) {
    box.presets.removeAt(index);
    box.selected = null;
    box.save();
    return true;
  }
  box.save();
  return false;
}

class _PreviewPainter extends CustomPainter {
  final PenPreset preset;
  _PreviewPainter(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    final marker = preset.kind == PenKind.marker;
    final paint = Paint()
      ..color = marker ? preset.color.withValues(alpha: 0.35 * preset.opacity) : preset.strokeColor
      ..strokeWidth = (preset.width * 900).clamp(1.0, 40.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = marker ? StrokeCap.square : StrokeCap.round;
    final path = Path()..moveTo(24, size.height * 0.6);
    path.cubicTo(size.width * 0.3, size.height * 0.1, size.width * 0.55, size.height * 0.95, size.width - 24, size.height * 0.4);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}

/// Opções da barra: onde ela fica e quando o dedo desenha.
Future<void> showDockSettings(BuildContext context, InkToolbox box) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Barra de ferramentas', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('Posição'),
              const SizedBox(height: 6),
              SegmentedButton<DockSide>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DockSide.top, icon: Icon(Icons.border_top), label: Text('Topo')),
                  ButtonSegment(value: DockSide.left, icon: Icon(Icons.border_left), label: Text('Esquerda')),
                  ButtonSegment(value: DockSide.right, icon: Icon(Icons.border_right), label: Text('Direita')),
                ],
                selected: {box.side},
                onSelectionChanged: (v) => setSheet(() {
                  box.side = v.first;
                  box.save();
                }),
              ),
              const SizedBox(height: 16),
              const Text('Desenhar com o dedo'),
              const SizedBox(height: 6),
              SegmentedButton<FingerMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: FingerMode.auto, label: Text('Automático')),
                  ButtonSegment(value: FingerMode.always, label: Text('Sempre')),
                  ButtonSegment(value: FingerMode.never, label: Text('Nunca')),
                ],
                selected: {box.finger},
                onSelectionChanged: (v) => setSheet(() {
                  box.finger = v.first;
                  box.save();
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Sem ferramenta escolhida (mão), a caneta e o dedo só movem a página. Com uma caneta, borracha ou marca-texto '
                'escolhidos, a caneta risca e o dedo continua movendo a página. No automático, o dedo só risca em aparelhos sem caneta.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const PalmModeSelector(),
            ]),
          ),
        ),
      ),
    );
