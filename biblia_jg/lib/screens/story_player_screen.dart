import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/stories.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../widgets/parallax_image.dart';
import '../widgets/story_map.dart';
import 'dictionary_screen.dart' show showBiblePassage;

/// História ilustrada: a ilustração se move (efeito 3D), a narração toca, o mapa acompanha
/// o lugar de cada cena e o texto aparece embaixo. Passa sozinha de cena em cena.
class BibleStoryPlayer extends StatefulWidget {
  final BibleStory story;

  /// Próxima história da lista (oferecida no fim).
  final BibleStory? next;

  /// Abre com o mapa em destaque (quando vem da tela de mapas).
  final bool startOnMap;

  /// Liga a narração e o avanço automático (desligado nos testes).
  final bool autoPlay;
  const BibleStoryPlayer({super.key, required this.story, this.next, this.startOnMap = false, this.autoPlay = true});

  @override
  State<BibleStoryPlayer> createState() => _BibleStoryPlayerState();
}

class _BibleStoryPlayerState extends State<BibleStoryPlayer> with WidgetsBindingObserver {
  final _mapKey = GlobalKey();
  final _textScroll = ScrollController();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;
  ReadAloud? _tts;
  Timer? _timer;

  int _i = 0;
  late bool _playing = widget.autoPlay;
  bool _audioOn = true;
  bool _effect3d = true;
  bool _showText = true;
  late bool _mapMain = widget.startOnMap && widget.story.hasMap;
  bool _ended = false;
  bool _loadingAudio = false;
  bool _usingTts = false;
  bool _ttsStarted = false;
  int _run = 0; // muda a cada cena/pausa: respostas atrasadas são ignoradas

  BibleStory get story => widget.story;
  StoryScene get scene => story.scenes[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().catchError((_) {});
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _audioOn = prefs.getBool('stories.audio') ?? true;
      _effect3d = prefs.getBool('stories.3d') ?? true;
    });
    _tts = context.read<ReadAloud>()..addListener(_onTts);
    _enterScene();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _run++;
    _timer?.cancel();
    _playerSub?.cancel();
    _player?.dispose();
    _tts?.removeListener(_onTts);
    if (_usingTts) _tts?.stop();
    _textScroll.dispose();
    // Volta a tela ao que o usuário escolheu nas configurações.
    WakelockPlus.toggle(enable: _keepOn).catchError((_) {});
    super.dispose();
  }

  bool _keepOn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepOn = context.read<AppState>().settings.keepScreenOn;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _setPlaying(false);
  }

  // ------------------------------------------------------------------ narração

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _playerSub = p.playerStateStream.listen((s) {
      // O player repete o estado "terminou" quando é parado ou recebe outro arquivo: só vale
      // uma vez, e só para a cena em que este áudio começou a tocar.
      if (s.processingState == ProcessingState.completed && _audioRun >= 0 && _audioRun == _run) {
        _audioRun = -1;
        _onNarrationDone(_run);
      }
    });
    return _player = p;
  }

  /// Cena (número da rodada) em que o áudio carregado começou a tocar; -1 = nenhum.
  int _audioRun = -1;

  void _onTts() {
    final tts = _tts;
    if (tts == null || !_usingTts) return;
    if (tts.speaking) {
      _ttsStarted = true;
    } else if (_ttsStarted) {
      _ttsStarted = false;
      // Se a voz do aparelho parou cedo demais (erro), espera o tempo de leitura do texto.
      final expected = _readingTime(scene.text);
      final spoken = DateTime.now().difference(_ttsSince);
      final run = _run;
      if (spoken < expected * 0.4) {
        _timer?.cancel();
        _timer = Timer(expected - spoken, () => _onNarrationDone(run));
      } else {
        _onNarrationDone(run);
      }
    }
  }

  DateTime _ttsSince = DateTime.now();

  static Duration _readingTime(String text) =>
      Duration(milliseconds: (text.split(RegExp(r'\s+')).length / 2.7 * 1000).round().clamp(7000, 70000));

  Future<void> _stopNarration() async {
    _audioRun = -1;
    _timer?.cancel();
    _timer = null;
    if (_usingTts) {
      _usingTts = false;
      _ttsStarted = false;
      await _tts?.stop();
    }
    try {
      await _player?.stop();
    } catch (_) {}
  }

  /// Entra na cena atual: adianta os arquivos da próxima e começa a narração (se tocando).
  Future<void> _enterScene() async {
    final run = ++_run;
    await _stopNarration();
    if (!mounted || run != _run) return;
    if (_loadingAudio) setState(() => _loadingAudio = false);
    if (_textScroll.hasClients) _textScroll.jumpTo(0);
    if (_i + 1 < story.scenes.length) {
      final next = story.scenes[_i + 1];
      StoryMedia.warm([StoryMedia.image(next.image), StoryMedia.depth(next.image)]);
      if (next.audio && _audioOn) unawaited(StoryMedia.file(StoryMedia.narration(story.id, _i + 1)));
    }
    if (!_playing) return;
    await _narrate(run);
  }

  Future<void> _narrate(int run) async {
    final s = scene;
    if (!_audioOn) {
      // Sem áudio: tempo de leitura do texto.
      _timer = Timer(_readingTime(s.text), () => _onNarrationDone(run));
      return;
    }
    if (s.audio) {
      setState(() => _loadingAudio = true);
      try {
        final path = StoryMedia.narration(story.id, _i);
        final file = await StoryMedia.file(path);
        if (!mounted || run != _run) return;
        if (file != null) {
          await _audio.setFilePath(file.path);
        } else {
          await _audio.setUrl(StoryMedia.url(path));
        }
        if (!mounted || run != _run) return;
        setState(() => _loadingAudio = false);
        _audioRun = run;
        unawaited(_audio.play());
        return;
      } catch (_) {
        if (!mounted || run != _run) return;
      }
      setState(() => _loadingAudio = false);
    }
    // Sem narração gravada (ou sem internet): voz do aparelho.
    final tts = _tts;
    if (tts == null) return;
    _usingTts = true;
    _ttsStarted = false;
    _ttsSince = DateTime.now();
    try {
      await tts.speak([(1, '${s.title}. ${s.text}')]);
      // Se a voz do aparelho não começar, não fica parado para sempre.
      _timer = Timer(const Duration(seconds: 6), () {
        if (run == _run && _usingTts && !_ttsStarted && !(tts.speaking)) {
          _timer = Timer(_readingTime(s.text), () => _onNarrationDone(run));
        }
      });
    } catch (_) {
      _usingTts = false;
    }
  }

  void _onNarrationDone(int run) {
    if (!mounted || run != _run || !_playing) return;
    _usingTts = false;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || run != _run || !_playing) return;
      if (_i < story.scenes.length - 1) {
        _go(_i + 1);
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _run++;
    _stopNarration();
    StoriesData.markFinished(story.id);
    setState(() {
      _playing = false;
      _ended = true;
    });
  }

  void _go(int i) {
    if (i < 0 || i >= story.scenes.length) return;
    setState(() {
      _i = i;
      _ended = false;
    });
    _enterScene();
  }

  void _setPlaying(bool v) {
    if (v == _playing) return;
    setState(() => _playing = v);
    if (!v) {
      _run++;
      _timer?.cancel();
      if (_usingTts) {
        _usingTts = false;
        _tts?.stop();
      } else {
        _player?.pause();
      }
      return;
    }
    // Retoma o áudio de onde parou; a voz do aparelho recomeça a cena.
    final p = _player;
    if (!_usingTts && _audioOn && scene.audio && p != null && p.processingState == ProcessingState.ready) {
      _audioRun = ++_run;
      unawaited(p.play());
    } else {
      _enterScene();
    }
  }

  Future<void> _toggleAudio() async {
    setState(() => _audioOn = !_audioOn);
    (await SharedPreferences.getInstance()).setBool('stories.audio', _audioOn);
    if (_playing) _enterScene();
  }

  Future<void> _toggle3d() async {
    setState(() => _effect3d = !_effect3d);
    (await SharedPreferences.getInstance()).setBool('stories.3d', _effect3d);
  }

  Future<void> _openPassage(String reference) async {
    final p = parseStoryReference(reference);
    if (p == null) return;
    _setPlaying(false);
    await showBiblePassage(context, p);
  }

  // ------------------------------------------------------------------ tela

  @override
  Widget build(BuildContext context) {
    final scenes = story.scenes;
    final s = scene;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final wide = size.width >= 720;
    final hasMap = story.hasMap;
    final insetW = wide ? 300.0 : 148.0;
    final insetH = insetW * 0.64;

    final stops = <MapStop?>[
      for (final c in scenes)
        c.point == null ? null : MapStop(c.place, c.point!, c.zoom, c.title, c.reference),
    ];

    Widget map({required bool main}) => StoryMapView(
          key: _mapKey,
          stops: stops,
          index: _i,
          color: story.color,
          route: story.route,
          labels: main,
          interactive: main,
          zoomOut: main ? 0 : 1.6,
          onTapStop: main ? _go : null,
          onReference: _openPassage,
        );

    // Cena ainda sem ilustração: mostra o mapa (se tiver lugar) ou um quadro com o título.
    final autoMap = !s.hasImage && s.point != null;
    final mapMain = _mapMain || autoMap;
    final stage = AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      child: s.hasImage
          ? ParallaxImage(
              key: ValueKey('${s.image}-$_effect3d'),
              imageKey: s.image,
              depthEffect: _effect3d,
              tint: story.color,
            )
          : _TitleStage(key: ValueKey('titulo-$_i'), story: story, scene: s),
    );

    final panel = _showText || mapMain
        ? _TextPanel(
            story: story,
            scene: s,
            index: _i,
            playing: _playing,
            loading: _loadingAudio,
            audioOn: _audioOn,
            compact: mapMain,
            scroll: _textScroll,
            maxTextHeight: size.height * (wide ? 0.26 : 0.24),
            onPrev: _i > 0 ? () => _go(_i - 1) : null,
            onNext: _i < scenes.length - 1 ? () => _go(_i + 1) : _finish,
            onPlay: () => _setPlaying(!_playing),
            onAudio: _toggleAudio,
            onReference: () => _openPassage(s.reference),
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: mapMain
              ? map(main: true)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showText = !_showText),
                  child: stage,
                ),
        ),
        // Escurece embaixo e em cima para o texto ficar legível sobre a ilustração.
        if (!mapMain)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                    stops: [0, 0.18, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
        // Barra de cima: voltar, título, progresso por cena e opções.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, pad.top + 6, 8, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                for (var k = 0; k < scenes.length; k++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _go(k),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          decoration: BoxDecoration(
                            color: k <= _i ? story.color : Colors.white30,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(story.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  icon: const CircleAvatar(
                      radius: 18, backgroundColor: mapCardBg, child: Icon(Icons.tune, color: Colors.white, size: 20)),
                  onSelected: (v) {
                    if (v == '3d') _toggle3d();
                    if (v == 'texto') setState(() => _showText = !_showText);
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(value: '3d', checked: _effect3d, child: const Text('Efeito 3D na ilustração')),
                    CheckedPopupMenuItem(value: 'texto', checked: _showText, child: const Text('Texto na tela')),
                  ],
                ),
              ]),
            ]),
          ),
        ),
        // Janela pequena: o mapa (ou a cena, quando o mapa está em destaque). Toque para trocar.
        if (hasMap && !autoMap)
          Positioned(
            top: pad.top + 76,
            right: 12,
            width: insetW,
            height: insetH,
            child: _Inset(
              color: story.color,
              label: _mapMain ? 'Ver a cena' : 'Ver no mapa',
              icon: _mapMain ? Icons.image : Icons.public,
              onTap: () => setState(() => _mapMain = !_mapMain),
              child: _mapMain ? StoryThumb(imageKey: s.hasImage ? s.image : null, tint: story.color) : map(main: false),
            ),
          ),
        if (panel != null && !_ended)
          Align(
            alignment: wide ? Alignment.bottomLeft : Alignment.bottomCenter,
            child: SafeArea(child: panel),
          ),
        if (_ended)
          Positioned.fill(
            child: _EndCard(
              story: story,
              next: widget.next,
              onReplay: () {
                setState(() => _playing = widget.autoPlay);
                _go(0);
              },
              onRead: () => _openPassage(story.scenes.first.reference),
              onNext: widget.next == null
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => BibleStoryPlayer(story: widget.next!)),
                      ),
            ),
          ),
      ]),
    );
  }
}

/// Quadro mostrado enquanto a ilustração da cena não chega: cor da história e o título.
class _TitleStage extends StatelessWidget {
  final BibleStory story;
  final StoryScene scene;
  const _TitleStage({super.key, required this.story, required this.scene});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color.lerp(const Color(0xFF0B1220), story.color, 0.4)!, const Color(0xFF0B1220)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 160),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_stories, color: story.color.withValues(alpha: 0.8), size: 54),
              const SizedBox(height: 14),
              Text(scene.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.15)),
              const SizedBox(height: 8),
              Text('${scene.reference} · ilustração a caminho',
                  textAlign: TextAlign.center, style: TextStyle(color: story.color, fontSize: 14)),
            ]),
          ),
        ),
      );
}

/// Janela pequena no canto (mapa ou cena), com borda e legenda.
class _Inset extends StatelessWidget {
  final Widget child;
  final Color color;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Inset({required this.child, required this.color, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.9), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 16)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              AbsorbPointer(child: child),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Painel de baixo: cena, título, texto narrado e controles.
class _TextPanel extends StatelessWidget {
  final BibleStory story;
  final StoryScene scene;
  final int index;
  final bool playing;
  final bool loading;
  final bool audioOn;
  final bool compact;
  final ScrollController scroll;
  final double maxTextHeight;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPlay;
  final VoidCallback onAudio;
  final VoidCallback onReference;
  const _TextPanel({
    required this.story,
    required this.scene,
    required this.index,
    required this.playing,
    required this.loading,
    required this.audioOn,
    required this.compact,
    required this.scroll,
    required this.maxTextHeight,
    required this.onPrev,
    required this.onNext,
    required this.onPlay,
    required this.onAudio,
    required this.onReference,
  });

  @override
  Widget build(BuildContext context) {
    final place = scene.place.isEmpty ? '' : ' · ${scene.place}';
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
      decoration: BoxDecoration(
        color: mapCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: story.color.withValues(alpha: 0.55)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cena ${index + 1} de ${story.scenes.length}$place',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: story.color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(scene.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.15)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: compact ? maxTextHeight * 0.7 : maxTextHeight),
          child: Scrollbar(
            controller: scroll,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.only(right: 8),
              child: Text(scene.text, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 16.5, height: 1.45)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.menu_book, size: 16),
                label: Text(scene.reference, overflow: TextOverflow.ellipsis),
                tooltip: 'Ler na Bíblia',
                onPressed: onReference,
              ),
            ),
          ),
          IconButton(
            tooltip: audioOn ? 'Desligar a narração' : 'Ligar a narração',
            color: audioOn ? Colors.white : Colors.white54,
            icon: Icon(audioOn ? Icons.volume_up : Icons.volume_off),
            onPressed: onAudio,
          ),
          IconButton(
            tooltip: 'Cena anterior',
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.skip_previous),
            onPressed: onPrev,
          ),
          IconButton.filled(
            tooltip: playing ? 'Pausar' : 'Tocar',
            iconSize: 28,
            icon: loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: onPlay,
          ),
          IconButton(
            tooltip: 'Próxima cena',
            color: Colors.white,
            icon: const Icon(Icons.skip_next),
            onPressed: onNext,
          ),
        ]),
      ]),
    );
  }
}

/// Fim da história: reflexão e o que fazer depois.
class _EndCard extends StatelessWidget {
  final BibleStory story;
  final BibleStory? next;
  final VoidCallback onReplay;
  final VoidCallback onRead;
  final VoidCallback? onNext;
  const _EndCard({required this.story, required this.next, required this.onReplay, required this.onRead, required this.onNext});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xB3000000),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xF20E1626),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: story.color.withValues(alpha: 0.7)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_stories, color: story.color, size: 36),
                const SizedBox(height: 10),
                Text(story.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                const SizedBox(height: 4),
                Text(story.reference, textAlign: TextAlign.center, style: TextStyle(color: story.color, fontSize: 13)),
                if (story.application.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Para pensar', style: TextStyle(color: story.color, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(story.application,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 20),
                if (onNext != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Próxima: ${next!.title}', overflow: TextOverflow.ellipsis),
                      onPressed: onNext,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
                  TextButton.icon(icon: const Icon(Icons.replay), label: const Text('Ouvir de novo'), onPressed: onReplay),
                  TextButton.icon(icon: const Icon(Icons.menu_book), label: const Text('Ler na Bíblia'), onPressed: onRead),
                  TextButton.icon(
                      icon: const Icon(Icons.close), label: const Text('Fechar'), onPressed: () => Navigator.pop(context)),
                ]),
              ]),
            ),
          ),
        ),
      );
}
