import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lineages.dart';
import '../services/step_narrator.dart';
import '../services/stories.dart' show StoryMedia;
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/portrait.dart';
import 'maps_screen.dart';
import 'panorama_kings.dart';
import 'panorama_tree.dart';
import 'stories_screen.dart';

const _night = Color(0xFF0E1626);

/// Cartões dos quadros de linhagens para a entrada do Panorama:
/// (id do quadro, ícone, cor, título, subtítulo, chave da ilustração de capa).
const lineageCards = <(String, IconData, Color, String, String, String)>[
  ('jesus', Icons.auto_awesome, Color(0xFF8E24AA), 'A genealogia de Jesus',
      'De Abraão a Cristo em três grupos de catorze, e a linha de Lucas até Adão', 'natal-manjedoura'),
  ('adao', Icons.park, Color(0xFF2E7D32), 'De Adão a Abraão',
      'As primeiras gerações, o dilúvio, os povos e a linha de Sem', 'noe-arcoiris'),
  ('linhas', Icons.workspace_premium, Color(0xFFB8860B), 'O rei e o sacerdote',
      'A linha real de Judá e a linha sacerdotal de Levi, até se encontrarem em Cristo', 'davi-uncao'),
  ('apostolos', Icons.groups, Color(0xFF1565C0), 'Os doze apóstolos',
      'Quem é quem, de onde vieram, o que fizeram e o que escreveram', 'pescadores-chamado'),
  ('paulo', Icons.sailing, Color(0xFF00838F), 'Paulo, o apóstolo dos gentios',
      'Origem, conversão, viagens, companheiros, igrejas e as treze cartas', 'damasco-luz'),
  ('povos', Icons.call_split, Color(0xFF6A1B9A), 'Israel e Judá: os dois povos',
      'Do mesmo tronco aos dois reinos, o exílio, a dispersão e os dias de hoje', 'josue-alianca'),
];

IconData _iconOf(String chartId) {
  for (final c in lineageCards) {
    if (c.$1 == chartId) return c.$2;
  }
  return Icons.account_tree;
}

/// Ilustração de uma parte do quadro. Enquanto a imagem não existe na nuvem, mostra um quadro
/// colorido com o símbolo do assunto (nunca um buraco nem um erro).
class _LinArt extends StatefulWidget {
  final String? imageKey;
  final Color color;
  final IconData icon;
  final bool large;
  final int? cacheWidth;
  const _LinArt({required this.imageKey, required this.color, required this.icon, this.large = false, this.cacheWidth});

  @override
  State<_LinArt> createState() => _LinArtState();
}

class _LinArtState extends State<_LinArt> {
  /// Chaves que não estão na nuvem nesta sessão (para não pedir de novo a cada redesenho).
  static final _missing = <String>{};
  Uint8List? _bytes;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_LinArt old) {
    super.didUpdateWidget(old);
    if (old.imageKey != widget.imageKey || old.large != widget.large) {
      _bytes = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final run = ++_run;
    final key = widget.imageKey;
    if (key == null || _missing.contains(key)) return;
    var b = await StoryMedia.bytes(widget.large ? StoryMedia.image(key) : StoryMedia.thumb(key));
    if (b == null && widget.large) b = await StoryMedia.bytes(StoryMedia.thumb(key));
    if (b == null) {
      _missing.add(key);
      return;
    }
    if (mounted && run == _run) setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: b == null
          ? DecoratedBox(
              key: const ValueKey('vazio'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(widget.color, Colors.white, 0.08)!, Color.lerp(widget.color, _night, 0.72)!],
                ),
              ),
              child: SizedBox.expand(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 0.5,
                  child: FittedBox(child: Icon(widget.icon, color: Colors.white.withValues(alpha: 0.28))),
                ),
              ),
            )
          : Image.memory(b,
              key: ValueKey(widget.imageKey),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: widget.cacheWidth,
              gaplessPlayback: true),
    );
  }
}

/// Um quadro de linhagem: árvore ou linha de marcos, com cada parte ilustrada e explicada.
/// Dá para explorar (arrastar, aproximar, tocar) ou assistir à apresentação passo a passo.
class LineageChartScreen extends StatefulWidget {
  /// jesus, adao, linhas, apostolos, paulo ou povos.
  final String id;
  const LineageChartScreen({super.key, required this.id});

  @override
  State<LineageChartScreen> createState() => _LineageChartScreenState();
}

class _LineageChartScreenState extends State<LineageChartScreen> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Animation<Matrix4>? _camera;
  LineageChart? _chart;
  bool _failed = false;
  StepNarrator? _narrator;
  Size _view = Size.zero;
  bool _placed = false;
  int? _step; // null = explorando livremente
  Set<String>? _lit;
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
    LineagesData.load().then((d) {
      if (!mounted) return;
      setState(() {
        _chart = d.byId(widget.id);
        _failed = _chart == null;
      });
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
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

  void _setCamera(Matrix4 target, bool animate) {
    if (!animate) {
      _anim.stop();
      _tc.value = target;
      return;
    }
    _camera = Matrix4Tween(begin: _tc.value, end: target).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  /// [room] = fração da altura da tela que o trecho pode ocupar (na apresentação sobra espaço
  /// embaixo para o painel de texto).
  void _moveTo(Rect r, {bool animate = true, double maxScale = 1.25, double? focusY, double room = 0.6}) {
    final w = _view.width, h = _view.height;
    final scale = math.min(w / (r.width + 70), h * room / (r.height + 50)).clamp(0.22, maxScale);
    final tx = w / 2 - r.center.dx * scale;
    final ty = (focusY ?? h * 0.4) - r.center.dy * scale;
    _setCamera(
        Matrix4.identity()
          ..translateByDouble(tx, ty, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1),
        animate);
  }

  Rect _rectOf(Iterable<String> ids) {
    final chart = _chart!;
    Rect? r;
    for (final id in ids) {
      final n = chart.byId[id];
      if (n == null) continue;
      r = r == null ? n.rect : r.expandToInclude(n.rect);
    }
    return r ?? Rect.fromLTWH(0, 0, chart.width, chart.height);
  }

  /// Posição inicial: o quadro na largura da tela, legível, a partir do topo.
  void _home({bool animate = true}) {
    final c = _chart!;
    final fit = _view.width / (c.width + 24);
    if (fit < 0.6) {
      // Tela estreita: começa pela primeira parte; o resto é só arrastar.
      _moveTo(_rectOf(c.steps.isEmpty ? [c.nodes.first.id] : c.steps.first.nodes), animate: animate, maxScale: 1);
      return;
    }
    final scale = math.min(fit, 1.15);
    final ty = math.max(8.0, (_view.height - c.height * scale) / 2);
    _setCamera(
        Matrix4.identity()
          ..translateByDouble((_view.width - c.width * scale) / 2, ty, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1),
        animate);
  }

  void _showAll() {
    final c = _chart!;
    _moveTo(Rect.fromLTWH(0, 0, c.width, c.height), maxScale: 1.1, focusY: _view.height * 0.5, room: 0.97);
  }

  // ---------------------------------------------------------------- apresentação

  void _startTour() {
    final chart = _chart!;
    if (chart.steps.isEmpty) return;
    setState(() {
      _step = 0;
      _lit = chart.steps.first.nodes.toSet();
      _playing = true;
    });
    _enterStep();
  }

  void _endTour() {
    _gap?.cancel();
    _narrator?.stop();
    setState(() {
      _step = null;
      _lit = null;
      _playing = false;
    });
    _home();
  }

  void _enterStep() {
    final chart = _chart!;
    final i = _step;
    if (i == null) return;
    _gap?.cancel();
    final step = chart.steps[i];
    _moveTo(_rectOf(step.nodes), focusY: _view.height * 0.3, room: 0.46);
    if (!_playing) {
      _narrator?.stop();
      return;
    }
    _narrator?.start(step.text, voice: _voice, onDone: () {
      if (!mounted || !_playing || _step != i) return;
      _gap = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || !_playing || _step != i) return;
        if (i < chart.steps.length - 1) {
          _goStep(i + 1);
        } else {
          setState(() => _playing = false);
        }
      });
    });
  }

  void _goStep(int i) {
    final chart = _chart!;
    if (i < 0 || i >= chart.steps.length) return;
    setState(() {
      _step = i;
      _lit = chart.steps[i].nodes.toSet();
    });
    _enterStep();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      if (_step == _chart!.steps.length - 1) {
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

  // ---------------------------------------------------------------- fichas

  (String, Widget)? _linkTarget(String link) {
    switch (link) {
      case 'abraao':
        return ('Ver a família de Abraão', const FamilyTreeScreen());
      case 'reis':
        return ('Ver os reis de Israel e Judá', const KingsScreen());
      case 'historias':
        return ('Ver as histórias ilustradas', const StoriesScreen());
      case 'mapas':
        return ('Ver os mapas e as viagens', const MapsScreen());
    }
    if (link.startsWith('quadro:')) {
      final id = link.substring(7);
      for (final c in lineageCards) {
        if (c.$1 == id) return ('Abrir: ${c.$4}', LineageChartScreen(id: id));
      }
    }
    return null;
  }

  void _pauseTour() {
    if (_playing) _togglePlay();
  }

  void _openNode(LinNode n) {
    final chart = _chart!;
    final color = n.color ?? chart.color;
    final link = _linkTarget(n.link);
    if (n.text.isEmpty && n.refs.isEmpty && link == null) return;
    _pauseTour();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final accent = theme.brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.45)! : color;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (n.art != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: _LinArt(imageKey: n.art, color: color, icon: _iconOf(chart.id), large: true, cacheWidth: 1200),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(children: [
                  _avatar(n, color, big: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                      if (n.sub.isNotEmpty) Text(n.sub, style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                if (n.facts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final (k, v) in n.facts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '$k: ', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                          TextSpan(text: v),
                        ]),
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                ],
                if (n.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(n.text, style: const TextStyle(fontSize: 16, height: 1.45)),
                ],
                if (n.refs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 4, children: [for (final r in n.refs) RefChip(r, color: accent)]),
                ],
                if (link != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(link.$1),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => link.$2));
                    },
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  void _openIntro() {
    final chart = _chart!;
    _pauseTour();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: _LinArt(imageKey: chart.cover, color: chart.color, icon: _iconOf(chart.id), large: true, cacheWidth: 1200),
              ),
            ),
            const SizedBox(height: 14),
            Text(chart.title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
            const SizedBox(height: 8),
            Text(chart.intro, style: const TextStyle(fontSize: 16, height: 1.45)),
            const SizedBox(height: 14),
            if (chart.steps.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
                icon: const Icon(Icons.play_arrow),
                label: Text('Apresentar em ${chart.steps.length} passos'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _startTour();
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _avatar(LinNode n, Color color, {bool big = false}) {
    final initial = Text(n.name.characters.first,
        style: TextStyle(color: Colors.white, fontSize: big ? 20 : 13, fontWeight: FontWeight.bold));
    final p = n.portrait;
    if (p == null) return CircleAvatar(radius: big ? 20 : 13, backgroundColor: big ? color : Colors.white24, child: initial);
    return PortraitAvatar(
      name: p,
      radius: big ? 38 : 18,
      fallbackRadius: big ? 20 : 13,
      color: big ? color : Colors.white24,
      ring: big ? color : null,
      zoomable: big,
      child: initial,
    );
  }

  // ---------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final theme = Theme.of(context);
    final step = _step == null || chart == null ? null : chart.steps[_step!];
    final lit = _lit;
    String title = 'Panorama bíblico';
    for (final c in lineageCards) {
      if (c.$1 == widget.id) title = c.$4;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(chart?.title ?? title),
        actions: [
          if (chart != null && _step == null && chart.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Apresentar'),
                onPressed: _startTour,
              ),
            ),
          if (chart != null) IconButton(tooltip: 'Sobre este quadro', icon: const Icon(Icons.info_outline), onPressed: _openIntro),
          if (chart != null) IconButton(tooltip: 'Ver o quadro inteiro', icon: const Icon(Icons.zoom_out_map), onPressed: _showAll),
        ],
      ),
      body: chart == null
          ? Center(
              child: _failed
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Não foi possível abrir este quadro.', textAlign: TextAlign.center),
                    )
                  : const CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              _view = box.biggest;
              if (!_placed) {
                _placed = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _home(animate: false);
                });
              }
              final dark = theme.brightness == Brightness.dark;
              return Stack(children: [
                InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.15,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(700),
                  onInteractionStart: (_) => _anim.stop(),
                  child: SizedBox(
                    width: chart.width,
                    height: chart.height,
                    child: Stack(clipBehavior: Clip.none, children: [
                      for (final b in chart.bands)
                        Positioned.fromRect(
                          rect: b.rect,
                          child: IgnorePointer(child: _BandBox(band: b, dark: dark, dim: lit != null)),
                        ),
                      Positioned.fill(
                        child: CustomPaint(painter: _LinLines(chart, theme.colorScheme.outline, lit)),
                      ),
                      for (final n in chart.nodes)
                        Positioned.fromRect(
                          rect: n.rect,
                          child: _LinNodeChip(
                            node: n,
                            color: n.color ?? chart.color,
                            icon: _iconOf(chart.id),
                            avatar: _avatar(n, n.color ?? chart.color),
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
                      child: Text(
                          'Arraste e aproxime com os dedos. Toque em cada parte para ver a explicação, a ilustração e onde está na Bíblia.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ),
                if (step != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: _LinTourPanel(
                        index: _step!,
                        total: chart.steps.length,
                        step: step,
                        color: chart.color,
                        icon: _iconOf(chart.id),
                        maxTextHeight: math.max(90, box.maxHeight * 0.3),
                        playing: _playing,
                        voice: _voice,
                        onPrev: _step! > 0 ? () => _goStep(_step! - 1) : null,
                        onNext: _step! < chart.steps.length - 1 ? () => _goStep(_step! + 1) : null,
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

/// Faixa de fundo com o título de uma parte do quadro.
class _BandBox extends StatelessWidget {
  final LinBand band;
  final bool dark;
  final bool dim;
  const _BandBox({required this.band, required this.dark, required this.dim});

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Color.lerp(band.color, Colors.white, 0.5)! : band.color;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: dim ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: band.color.withValues(alpha: dark ? 0.16 : 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: band.color.withValues(alpha: 0.38), width: 1.4),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        alignment: band.titleAtBottom ? Alignment.bottomLeft : Alignment.topLeft,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(band.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
          if (band.sub.isNotEmpty)
            Text(band.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ink.withValues(alpha: 0.85), fontSize: 11.5, height: 1.25)),
        ]),
      ),
    );
  }
}

class _LinNodeChip extends StatelessWidget {
  final LinNode node;
  final Color color;
  final IconData icon;
  final Widget avatar;
  final bool dim;
  final bool glow;
  final VoidCallback onTap;
  const _LinNodeChip({
    required this.node,
    required this.color,
    required this.icon,
    required this.avatar,
    required this.dim,
    required this.glow,
    required this.onTap,
  });

  List<BoxShadow> get _shadow =>
      [BoxShadow(color: glow ? color.withValues(alpha: 0.8) : Colors.black26, blurRadius: glow ? 16 : 4, spreadRadius: glow ? 2 : 0)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? Color.lerp(color, Colors.white, 0.5)! : color;
    Widget child;
    switch (node.type) {
      case 'elo':
        child = Center(
          child: Text(node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic)),
        );
      case 'mini':
        child = Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink, width: glow ? 2.2 : 1.4),
            boxShadow: glow ? _shadow : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (node.portrait != null)
              PortraitAvatar(
                  name: node.portrait!, radius: 11, hideWhenMissing: true, margin: const EdgeInsets.only(right: 4)),
            Flexible(
              child: Text(node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      case 'grupo':
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink, width: glow ? 2.4 : 1.6),
            boxShadow: glow ? _shadow : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(node.name,
                maxLines: node.sub.isEmpty ? 2 : 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.15)),
            if (node.sub.isNotEmpty)
              Text(node.sub,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.2)),
          ]),
        );
      case 'marco':
        child = Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), boxShadow: _shadow),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(aspectRatio: 1, child: _LinArt(imageKey: node.art, color: color, icon: icon)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (node.sub.isNotEmpty)
                  Text(node.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: jgGold, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.15)),
                Text(node.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.12)),
              ]),
            ),
          ]),
        );
      default:
        final big = node.type == 'destaque';
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(big ? 16 : 23),
            border: big ? Border.all(color: jgGold, width: 2) : null,
            boxShadow: _shadow,
          ),
          child: Row(children: [
            avatar,
            const SizedBox(width: 5),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: big ? jgGold : Colors.white,
                        fontSize: big ? 16.5 : 13.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: big ? 'serif' : null,
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
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: dim ? 0.2 : 1,
      child: Semantics(
        button: true,
        label: node.sub.isEmpty ? node.name : '${node.name}, ${node.sub}',
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      ),
    );
  }
}

/// Linhas do quadro: casais lado a lado, filhos descendo, marcos em sequência; tracejado para
/// ligações que pulam gerações ou não são de sangue.
class _LinLines extends CustomPainter {
  final LineageChart chart;
  final Color color;
  final Set<String>? lit;
  _LinLines(this.chart, this.color, this.lit);

  static Path _dash(Path source) {
    final out = Path();
    for (final m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + 7, m.length)), Offset.zero);
        d += 13;
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: lit == null ? 0.8 : 0.22);
    final strong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = jgGold;
    bool on(Iterable<String> ids) => lit != null && ids.every(lit!.contains);

    for (final c in chart.couples) {
      if (c.length < 2) continue;
      final a = chart.byId[c[0]], b = chart.byId[c[1]];
      if (a == null || b == null) continue;
      final left = a.x <= b.x ? a : b, right = a.x <= b.x ? b : a;
      canvas.drawLine(Offset(left.x + left.w / 2, left.y), Offset(right.x - right.w / 2, right.y), on(c) ? strong : base);
    }
    for (final e in chart.edges) {
      final to = chart.byId[e.to];
      final from = [for (final id in e.from) chart.byId[id]].whereType<LinNode>().toList();
      if (to == null || from.isEmpty) continue;
      final path = Path();
      if (e.horizontal) {
        final f = from.first;
        final ltr = to.x >= f.x;
        final start = Offset(f.x + (ltr ? f.w / 2 : -f.w / 2), f.y);
        final end = Offset(to.x + (ltr ? -to.w / 2 : to.w / 2), to.y);
        path.moveTo(start.dx, start.dy);
        if ((start.dy - end.dy).abs() > 0.5) {
          final midX = e.mid ?? (start.dx + end.dx) / 2;
          path
            ..lineTo(midX, start.dy)
            ..lineTo(midX, end.dy);
        }
        path.lineTo(end.dx, end.dy);
      } else {
        final start = from.length == 2
            ? Offset((from[0].x + from[1].x) / 2, from[0].y)
            : Offset(from[0].x, from[0].y + from[0].h / 2);
        final end = Offset(to.x, to.y - to.h / 2);
        path.moveTo(start.dx, start.dy);
        if ((start.dx - end.dx).abs() > 0.5 || e.mid != null) {
          final midY = e.mid ?? end.dy - math.min(24.0, math.max(6.0, (end.dy - start.dy) / 2));
          path
            ..lineTo(start.dx, midY)
            ..lineTo(end.dx, midY);
        }
        path.lineTo(end.dx, end.dy);
      }
      canvas.drawPath(e.dashed ? _dash(path) : path, on([...e.from, e.to]) ? strong : base);
    }
  }

  @override
  bool shouldRepaint(_LinLines old) => old.chart != chart || old.color != color || old.lit != lit;
}

/// Painel da apresentação: ilustração da parte, texto, referência e controles.
class _LinTourPanel extends StatelessWidget {
  final int index;
  final int total;
  final LinStep step;
  final Color color;
  final IconData icon;
  final double maxTextHeight;
  final bool playing;
  final bool voice;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPlay;
  final VoidCallback onVoice;
  final VoidCallback onClose;
  const _LinTourPanel({
    required this.index,
    required this.total,
    required this.step,
    required this.color,
    required this.icon,
    required this.maxTextHeight,
    required this.playing,
    required this.voice,
    required this.onPrev,
    required this.onNext,
    required this.onPlay,
    required this.onVoice,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Widget picture(double width, double height) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: width,
            height: height,
            child: _LinArt(imageKey: step.art, color: color, icon: icon, large: true, cacheWidth: 800),
          ),
        );
    final header = Row(children: [
      Text('Passo ${index + 1} de $total', style: const TextStyle(color: jgGold, fontSize: 12, fontWeight: FontWeight.w700)),
      const Spacer(),
      IconButton(
        tooltip: 'Sair da apresentação',
        visualDensity: VisualDensity.compact,
        color: Colors.white70,
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
    ]);
    final text = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxTextHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (step.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(step.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.15)),
            ),
          Text(step.text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
        ]),
      ),
    );
    final controls = Row(children: [
      if (step.ref.isNotEmpty) Flexible(child: RefChip(step.ref)),
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
    ]);
    return Container(
      constraints: const BoxConstraints(maxWidth: 860),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xF20E1626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jgGold.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
      ),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= 620) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            picture(250, 166),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                header,
                text,
                const SizedBox(height: 4),
                controls,
              ]),
            ),
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          picture(double.infinity, 104),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 6), child: text),
          const SizedBox(height: 4),
          controls,
        ]);
      }),
    );
  }
}
