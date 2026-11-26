import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/step_narrator.dart';
import '../services/stories.dart' show StoriesData;
import '../state/app_state.dart';
import '../services/tts.dart';
import '../theme.dart';
import '../widgets/portrait.dart';
import '../widgets/study_art.dart';
import 'panorama_tree.dart' show openPanoramaRef;
import 'story_player_screen.dart';

/// Abre a história ilustrada [id] (as das Histórias bíblicas), se ela existir.
Future<void> openIllustratedStory(BuildContext context, String id) async {
  final data = await StoriesData.load();
  final story = data.byId(id);
  if (story == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BibleStoryPlayer(story: story)));
}

/// Um passo de uma apresentação de estudo: ilustração, título, texto e referências.
class PresenterStep {
  /// Linha pequena acima do título ("c. 2091 a.C.", "caps. 5–7").
  final String kicker;
  final String title;
  final String text;
  final List<String> refs;
  final List<String> people;
  final String? art;
  const PresenterStep({required this.kicker, required this.title, required this.text, this.refs = const [], this.people = const [], this.art});

  /// O que o narrador lê.
  String get speech => '$title. $text';
}

/// Apresentação passo a passo, em tela cheia: a ilustração de cada parte ao fundo e, embaixo,
/// o texto narrado, as referências e os controles. Avança sozinha enquanto estiver tocando.
class StudyPresenter extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<PresenterStep> steps;
  final int initialStep;

  /// Começa narrando (false = abre parado no passo escolhido).
  final bool autoPlay;

  /// Chamado quando a narração do último passo termina.
  final VoidCallback? onCompleted;
  const StudyPresenter({
    super.key,
    required this.title,
    required this.color,
    required this.steps,
    this.icon = Icons.auto_stories,
    this.initialStep = 0,
    this.autoPlay = true,
    this.onCompleted,
  });

  @override
  State<StudyPresenter> createState() => _StudyPresenterState();
}

class _StudyPresenterState extends State<StudyPresenter> with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 16));
  StepNarrator? _narrator;
  late int _step = widget.initialStep.clamp(0, widget.steps.length - 1);
  bool _playing = false;
  bool _voice = true;
  bool _started = false;
  bool _ended = false; // a narração chegou ao fim do último passo
  bool _keepOn = false; // ajuste do leitor para a tela (devolvido ao sair)
  Timer? _gap;

  @override
  void initState() {
    super.initState();
    _zoom.repeat(reverse: true);
    WakelockPlus.enable().catchError((_) {});
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _voice = p.getBool('panorama.voz') ?? true);
      if (widget.autoPlay && !_started) _play();
    }).catchError((_) {
      if (mounted && widget.autoPlay && !_started) _play();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narrator ??= StepNarrator(context.read<ReadAloud>());
    _keepOn = context.read<AppState>().settings.keepScreenOn;
  }

  @override
  void dispose() {
    _gap?.cancel();
    _narrator?.dispose();
    _zoom.dispose();
    WakelockPlus.toggle(enable: _keepOn).catchError((_) {});
    super.dispose();
  }

  void _play() {
    _started = true;
    setState(() {
      _playing = true;
      _ended = false;
    });
    _enterStep();
  }

  void _pause() {
    _gap?.cancel();
    _narrator?.stop();
    if (_playing) setState(() => _playing = false);
  }

  void _enterStep() {
    _gap?.cancel();
    final i = _step;
    if (i + 1 < widget.steps.length) StudyArt.warm(widget.steps[i + 1].art, large: true);
    if (!_playing) {
      _narrator?.stop();
      return;
    }
    _narrator?.start(widget.steps[i].speech, voice: _voice, onDone: () {
      if (!mounted || !_playing || _step != i) return;
      _gap = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || !_playing || _step != i) return;
        if (i < widget.steps.length - 1) {
          setState(() => _step = i + 1);
          _enterStep();
        } else {
          setState(() {
            _playing = false;
            _ended = true;
          });
          widget.onCompleted?.call();
        }
      });
    });
  }

  void _go(int i) {
    if (i < 0 || i >= widget.steps.length) return;
    setState(() {
      _step = i;
      _ended = false;
    });
    _enterStep();
  }

  void _togglePlay() {
    if (_playing) {
      _pause();
    } else if (_ended) {
      // Terminou: tocar de novo recomeça do primeiro passo.
      setState(() => _step = 0);
      _play();
    } else {
      _play();
    }
  }

  Future<void> _toggleVoice() async {
    setState(() => _voice = !_voice);
    (await SharedPreferences.getInstance()).setBool('panorama.voz', _voice);
    if (_playing) _enterStep();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final total = widget.steps.length;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 560;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      body: Stack(fit: StackFit.expand, children: [
        // Ilustração do passo, com um leve movimento.
        // Um só quadro: a ilustração anterior fica até a nova carregar e então se dissolve nela.
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.07).animate(CurvedAnimation(parent: _zoom, curve: Curves.easeInOut)),
          child: StudyArt(
            art: step.art,
            color: widget.color,
            icon: widget.icon,
            large: true,
            cacheWidth: 1600,
            fade: const Duration(milliseconds: 700),
          ),
        ),
        // Escurece embaixo (texto) e um pouco em cima (título).
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.22, 0.5, 1],
                colors: [Color(0xB30E1626), Color(0x000E1626), Color(0x330E1626), Color(0xE60E1626)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // Barra de cima: fechar, título e o andamento.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 14, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Sair da apresentação',
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)])),
                ),
                Text('${_step + 1} de $total',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_step + 1) / total,
                  minHeight: 3,
                  color: jgGold,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const Spacer(),
            // Painel do texto.
            Container(
              constraints: BoxConstraints(maxWidth: 780, maxHeight: size.height * (compact ? 0.78 : 0.62)),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xF20E1626),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: jgGold.withValues(alpha: 0.55)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (step.kicker.isNotEmpty)
                        Text(step.kicker.toUpperCase(),
                            style: const TextStyle(color: jgGold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                      Text(step.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.2)),
                      const SizedBox(height: 8),
                      Text(step.text, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.45)),
                      if (step.people.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final p in step.people) PersonChip(p, radius: 13)]),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final r in step.refs)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.menu_book, size: 15),
                              label: Text(r, style: const TextStyle(fontSize: 12.5)),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Ler na Bíblia',
                              onPressed: () {
                                _pause();
                                openPanoramaRef(context, r);
                              },
                            ),
                          ),
                      ]),
                    ),
                  ),
                  IconButton(
                    tooltip: _voice ? 'Desligar a voz' : 'Ligar a voz',
                    color: _voice ? Colors.white : Colors.white54,
                    icon: Icon(_voice ? Icons.volume_up : Icons.volume_off),
                    onPressed: _toggleVoice,
                  ),
                  IconButton(
                    tooltip: 'Passo anterior',
                    color: Colors.white,
                    disabledColor: Colors.white24,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _step > 0 ? () => _go(_step - 1) : null,
                  ),
                  IconButton.filled(
                    tooltip: _playing ? 'Pausar' : 'Tocar',
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlay,
                  ),
                  IconButton(
                    tooltip: 'Próximo passo',
                    color: Colors.white,
                    disabledColor: Colors.white24,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _step < total - 1 ? () => _go(_step + 1) : null,
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
