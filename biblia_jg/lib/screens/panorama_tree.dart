import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/panorama.dart';
import '../services/step_narrator.dart';
import '../services/stories.dart' show parseStoryReference;
import '../services/tts.dart';
import '../theme.dart';
import 'dictionary_screen.dart' show showBiblePassage;

const _navy = Color(0xFF1B2A4A);
const _groupColors = {
  'lia': Color(0xFF3949AB),
  'zilpa': Color(0xFF00897B),
  'bila': Color(0xFFEF6C00),
  'raquel': Color(0xFF8E24AA),
};

/// Abre na Bíblia a referência de um quadro do Panorama.
void openPanoramaRef(BuildContext context, String ref) {
  final p = parseStoryReference(ref);
  if (p != null) showBiblePassage(context, p);
}

/// Botão com a referência bíblica.
class RefChip extends StatelessWidget {
  final String reference;
  final Color? color;
  const RefChip(this.reference, {super.key, this.color});

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(Icons.menu_book, size: 15, color: color),
        label: Text(reference, style: const TextStyle(fontSize: 12.5)),
        visualDensity: VisualDensity.compact,
        tooltip: 'Ler na Bíblia',
        onPressed: () => openPanoramaRef(context, reference),
      );
}

Color _nodeColor(FamilyTree tree, TreeNode n) {
  switch (n.type) {
    case 'patriarca':
      return _navy;
    case 'filho':
      return const Color(0xFF546E7A);
    case 'mae':
      return _groupColors[n.id] ?? const Color(0xFFC2185B);
    default:
      return _groupColors[tree.groupOf(n)] ?? const Color(0xFF546E7A);
  }
}

/// Árvore da família de Abraão até as doze tribos, com os descendentes mais conhecidos.
/// Dá para explorar (arrastar, aproximar, tocar) ou assistir à apresentação passo a passo.
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Animation<Matrix4>? _camera;
  FamilyTree? _tree;
  StepNarrator? _narrator;
  Size _view = Size.zero;
  bool _placed = false;
  int? _step; // null = explorando livremente
  bool _playing = false;
  bool _voice = true;
  Timer? _gap;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final c = _camera;
      if (c != null) _tc.value = c.value;
    });
    PanoramaData.load().then((d) {
      if (mounted) setState(() => _tree = d.tree);
    });
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _voice = p.getBool('panorama.voz') ?? true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narrator ??= StepNarrator(context.read<ReadAloud>());
  }

  @override
  void dispose() {
    _gap?.cancel();
    _narrator?.dispose();
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- câmera

  /// [room] = fração da altura da tela que o trecho pode ocupar (na apresentação sobra espaço
  /// embaixo para o painel de texto).
  Matrix4 _matrixFor(Rect r, {double maxScale = 1.35, double? focusY, double room = 0.6}) {
    final w = _view.width, h = _view.height;
    final scale = math.min(w / (r.width + 70), h * room / (r.height + 50)).clamp(0.28, maxScale);
    final tx = w / 2 - r.center.dx * scale;
    final ty = (focusY ?? h * 0.4) - r.center.dy * scale;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _moveTo(Rect r, {bool animate = true, double maxScale = 1.35, double? focusY, double room = 0.6}) {
    final target = _matrixFor(r, maxScale: maxScale, focusY: focusY, room: room);
    if (!animate) {
      _tc.value = target;
      return;
    }
    _camera = Matrix4Tween(begin: _tc.value, end: target).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  Rect _rectOf(Iterable<String> ids) {
    final tree = _tree!;
    Rect? r;
    for (final id in ids) {
      final n = tree.byId[id];
      if (n == null) continue;
      final box = Rect.fromCenter(center: Offset(n.x, n.y), width: n.halfWidth * 2, height: n.halfHeight * 2);
      r = r == null ? box : r.expandToInclude(box);
    }
    return r ?? Rect.fromLTWH(0, 0, tree.width, tree.height);
  }

  void _showAll({bool animate = true}) {
    final tree = _tree!;
    if (_view.width >= 900) {
      _moveTo(Rect.fromLTWH(0, 0, tree.width, tree.height),
          animate: animate, maxScale: 1.1, focusY: _view.height * 0.48, room: 0.96);
    } else {
      // Tela estreita: começa no topo (Abraão a Jacó); o resto é só arrastar.
      _moveTo(_rectOf(['agar', 'sara', 'esau', 'jaco']), animate: animate, maxScale: 0.8);
    }
  }

  // ---------------------------------------------------------------- apresentação

  void _startTour() {
    setState(() {
      _step = 0;
      _playing = true;
    });
    _enterStep();
  }

  void _endTour() {
    _gap?.cancel();
    _narrator?.stop();
    setState(() {
      _step = null;
      _playing = false;
    });
    _showAll();
  }

  void _enterStep() {
    final tree = _tree!;
    final i = _step;
    if (i == null) return;
    _gap?.cancel();
    final step = tree.steps[i];
    _moveTo(_rectOf(step.nodes));
    if (!_playing) {
      _narrator?.stop();
      return;
    }
    _narrator?.start(step.text, voice: _voice, onDone: () {
      if (!mounted || !_playing || _step != i) return;
      _gap = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || !_playing || _step != i) return;
        if (i < tree.steps.length - 1) {
          setState(() => _step = i + 1);
          _enterStep();
        } else {
          setState(() => _playing = false);
        }
      });
    });
  }

  void _goStep(int i) {
    final tree = _tree!;
    if (i < 0 || i >= tree.steps.length) return;
    setState(() => _step = i);
    _enterStep();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      if (_step == _tree!.steps.length - 1) {
        _goStep(0);
      } else {
        _enterStep();
      }
    } else {
      _gap?.cancel();
      _narrator?.stop();
    }
  }

  Future<void> _toggleVoice() async {
    setState(() => _voice = !_voice);
    (await SharedPreferences.getInstance()).setBool('panorama.voz', _voice);
    if (_playing) _enterStep();
  }

  // ---------------------------------------------------------------- pessoa

  void _openNode(TreeNode n) {
    final tree = _tree!;
    final color = _nodeColor(tree, n);
    if (_playing) _togglePlay();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: color, child: Text(n.name.characters.first, style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.name, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  if (n.sub.isNotEmpty) Text(n.sub, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(n.text, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [for (final r in n.refs) RefChip(r, color: color)]),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final tree = _tree;
    final theme = Theme.of(context);
    final step = _step == null || tree == null ? null : tree.steps[_step!];
    final lit = step?.nodes.toSet();
    return Scaffold(
      appBar: AppBar(
        title: const Text('A família de Abraão'),
        actions: [
          if (tree != null && _step == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Apresentar'),
                onPressed: _startTour,
              ),
            ),
          if (tree != null)
            IconButton(tooltip: 'Ver a árvore inteira', icon: const Icon(Icons.zoom_out_map), onPressed: () => _showAll()),
        ],
      ),
      body: tree == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              _view = box.biggest;
              if (!_placed) {
                _placed = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showAll(animate: false);
                });
              }
              return Stack(children: [
                InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: SizedBox(
                    width: tree.width,
                    height: tree.height,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _TreeLines(tree, theme.colorScheme.outline, lit)),
                      ),
                      for (final n in tree.nodes)
                        Positioned(
                          left: n.x - n.halfWidth,
                          top: n.y - n.halfHeight,
                          width: n.halfWidth * 2,
                          height: n.halfHeight * 2,
                          child: _NodeChip(
                            node: n,
                            color: _nodeColor(tree, n),
                            dim: lit != null && !lit.contains(n.id),
                            glow: lit != null && lit.contains(n.id),
                            onTap: () => _openNode(n),
                          ),
                        ),
                    ]),
                  ),
                ),
                if (step == null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Text('Arraste e aproxime com os dedos. Toque num nome para ver quem foi e onde está na Bíblia.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ),
                if (step != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: _TourPanel(
                        index: _step!,
                        total: tree.steps.length,
                        text: step.text,
                        reference: step.ref,
                        playing: _playing,
                        voice: _voice,
                        onPrev: _step! > 0 ? () => _goStep(_step! - 1) : null,
                        onNext: _step! < tree.steps.length - 1 ? () => _goStep(_step! + 1) : null,
                        onPlay: _togglePlay,
                        onVoice: _toggleVoice,
                        onClose: _endTour,
                      ),
                    ),
                  ),
              ]);
            }),
    );
  }
}

class _NodeChip extends StatelessWidget {
  final TreeNode node;
  final Color color;
  final bool dim;
  final bool glow;
  final VoidCallback onTap;
  const _NodeChip({required this.node, required this.color, required this.dim, required this.glow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = node.type == 'descendente';
    final patriarch = node.type == 'patriarca';
    final child = small
        ? Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 1.4),
            ),
            child: Text(node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(patriarch ? 16 : 23),
              border: patriarch ? Border.all(color: jgGold, width: 2) : null,
              boxShadow: [
                BoxShadow(color: glow ? color.withValues(alpha: 0.75) : Colors.black26, blurRadius: glow ? 16 : 4, spreadRadius: glow ? 2 : 0),
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: patriarch ? 15 : 13,
                backgroundColor: Colors.white24,
                child: Text(node.name.characters.first,
                    style: TextStyle(color: patriarch ? jgGold : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: patriarch ? jgGold : Colors.white,
                          fontSize: patriarch ? 17 : 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: patriarch ? 'serif' : null,
                          height: 1.1)),
                  if (node.sub.isNotEmpty)
                    Text(node.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.15)),
                ]),
              ),
            ]),
          );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: dim ? 0.22 : 1,
      child: Semantics(button: true, label: node.name, child: GestureDetector(onTap: onTap, child: child)),
    );
  }
}

/// Linhas da árvore: casais lado a lado, filhos descendo do casal, descendentes numa coluna.
class _TreeLines extends CustomPainter {
  final FamilyTree tree;
  final Color color;
  final Set<String>? lit;
  _TreeLines(this.tree, this.color, this.lit);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: lit == null ? 0.8 : 0.25);
    for (final c in tree.couples) {
      final a = tree.byId[c[0]], b = tree.byId[c[1]];
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(a.x + a.halfWidth, a.y), Offset(b.x - b.halfWidth, b.y), base);
    }
    for (final e in tree.edges) {
      final to = tree.byId[e.to];
      final from = [for (final id in e.from) tree.byId[id]].whereType<TreeNode>().toList();
      if (to == null || from.isEmpty) continue;
      if (e.list > 0) {
        // Coluna de descendentes: um traço da tribo até o último nome.
        canvas.drawLine(Offset(to.x, from.first.y + from.first.halfHeight), Offset(to.x, to.y + (e.list - 1) * 36 - to.halfHeight), base);
        continue;
      }
      final start = from.length == 2
          ? Offset((from[0].x + from[1].x) / 2, from[0].y)
          : Offset(from[0].x, from[0].y + from[0].halfHeight);
      final end = Offset(to.x, to.y - to.halfHeight);
      final midY = end.dy - 24;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx, midY)
          ..lineTo(end.dx, midY)
          ..lineTo(end.dx, end.dy),
        base,
      );
    }
  }

  @override
  bool shouldRepaint(_TreeLines old) => old.color != color || old.lit != lit;
}

/// Painel da apresentação: texto do passo, referência e controles.
class _TourPanel extends StatelessWidget {
  final int index;
  final int total;
  final String text;
  final String reference;
  final bool playing;
  final bool voice;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPlay;
  final VoidCallback onVoice;
  final VoidCallback onClose;
  const _TourPanel({
    required this.index,
    required this.total,
    required this.text,
    required this.reference,
    required this.playing,
    required this.voice,
    required this.onPrev,
    required this.onNext,
    required this.onPlay,
    required this.onVoice,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xF20E1626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: jgGold.withValues(alpha: 0.6)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Passo ${index + 1} de $total',
                style: const TextStyle(color: jgGold, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: 'Sair da apresentação',
              visualDensity: VisualDensity.compact,
              color: Colors.white70,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            if (reference.isNotEmpty) RefChip(reference),
            const Spacer(),
            IconButton(
              tooltip: voice ? 'Desligar a voz' : 'Ligar a voz',
              color: voice ? Colors.white : Colors.white54,
              icon: Icon(voice ? Icons.volume_up : Icons.volume_off),
              onPressed: onVoice,
            ),
            IconButton(
              tooltip: 'Passo anterior',
              color: Colors.white,
              disabledColor: Colors.white24,
              icon: const Icon(Icons.skip_previous),
              onPressed: onPrev,
            ),
            IconButton.filled(tooltip: playing ? 'Pausar' : 'Tocar', icon: Icon(playing ? Icons.pause : Icons.play_arrow), onPressed: onPlay),
            IconButton(
              tooltip: 'Próximo passo',
              color: Colors.white,
              disabledColor: Colors.white24,
              icon: const Icon(Icons.skip_next),
              onPressed: onNext,
            ),
          ]),
        ]),
      );
}
