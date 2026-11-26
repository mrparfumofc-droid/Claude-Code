import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_audio.dart';
import 'stories.dart' show StoryMedia;

/// De onde veio a voz da leitura do capítulo.
enum ReadSource {
  /// Gravação com a voz padrão do app (Algieba).
  recorded,

  /// Versão livre, mas o capítulo ainda não foi gravado: a gravação foi pedida e, por enquanto,
  /// lê a voz do aparelho.
  requested,

  /// Versão com direitos reservados (não pode ser gravada): lê a voz do aparelho.
  device,
}

/// Leitura em voz alta, versículo por versículo, avisando qual está sendo lido.
///
/// A voz do app é uma só (Algieba, gravada). A voz do aparelho só entra enquanto a gravação de um
/// texto não existe; não há mais escolha de voz.
class ReadAloud extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool speaking = false;

  /// Está tocando uma gravação (e não a voz do aparelho).
  bool recorded = false;
  SharedPreferences? _prefs;

  /// Versículo sendo lido agora (1..n), ou null.
  int? currentVerse;
  double rate = 0.5; // 0.25 (lento) .. 1.0 (rápido); 0.5 = velocidade normal
  List<(int, String)> _queue = const [];
  int _pos = 0;
  String _lang = 'pt-BR';

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  int _run = 0;

  double get _speed => (rate / 0.5).clamp(0.5, 2.0);

  Future<void> _init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    rate = _prefs!.getDouble('tts.rate') ?? rate;
    // Quem já tinha escolhido um mecanismo de fala mais natural continua com ele na voz provisória.
    final engine = _prefs!.getString('tts.engine');
    if (engine != null) {
      try {
        await _tts.setEngine(engine);
      } catch (_) {}
    }
    _tts.setCompletionHandler(_next);
    _tts.setErrorHandler((_) => stop());
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  Future<void> _applyVoice(String lang) async {
    await _tts.setLanguage(lang);
    final v = _prefs?.getString('tts.voice');
    final loc = _prefs?.getString('tts.voiceLocale');
    // A voz guardada só vale para o idioma dela (pt, en ou es).
    if (v != null && loc != null && loc.toLowerCase().startsWith(lang.substring(0, 2).toLowerCase())) {
      await _tts.setVoice({'name': v, 'locale': loc});
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(_prefs?.getDouble('tts.pitch') ?? 1.0);
  }

  /// Lê os versículos [(número, texto)] com a voz do aparelho, em [lang] (pt-BR, en-US, es-ES).
  Future<void> speak(List<(int, String)> verses, {String lang = 'pt-BR'}) async {
    await _init();
    await _stopPlayer();
    await _tts.stop();
    _queue = verses;
    _pos = 0;
    _lang = lang;
    await _applyVoice(_lang);
    recorded = false;
    speaking = true;
    _speakCurrent();
  }

  /// Lê um capítulo a partir do primeiro versículo de [verses]: com a gravação (voz Algieba)
  /// quando existe; senão pede a gravação (versões livres) e lê com a voz do aparelho.
  /// [book] é o índice do livro (0..65).
  Future<ReadSource> speakChapter({
    required String bibleId,
    required int book,
    required int chapter,
    required List<(int, String)> verses,
    String lang = 'pt-BR',
  }) async {
    await _init();
    await stop();
    final run = ++_run;
    if (verses.isEmpty) return ReadSource.device;
    if (!ChapterAudio.supports(bibleId)) {
      await speak(verses, lang: lang);
      return ReadSource.device;
    }
    ChapterRecording? rec;
    try {
      rec = await ChapterAudio.load(bibleId, book, chapter).timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (run != _run) return ReadSource.recorded; // o leitor parou enquanto carregava
    if (rec != null && rec.marks.length >= verses.last.$1 && await _playRecorded(rec, verses.first.$1, run)) {
      return ReadSource.recorded;
    }
    if (run != _run) return ReadSource.recorded;
    if (rec == null) unawaited(ChapterAudio.request(bibleId, book, chapter));
    await speak(verses, lang: lang);
    return ReadSource.requested;
  }

  Future<bool> _playRecorded(ChapterRecording rec, int fromVerse, int run) async {
    final player = AudioPlayer();
    try {
      final file = await StoryMedia.file(rec.path);
      if (run != _run) {
        await player.dispose();
        return true;
      }
      if (file != null) {
        await player.setFilePath(file.path);
      } else {
        await player.setUrl(StoryMedia.url(rec.path));
      }
      await player.setSpeed(_speed);
      final start = rec.startOf(fromVerse);
      if (start > Duration.zero) await player.seek(start);
    } catch (_) {
      await player.dispose();
      return false;
    }
    if (run != _run) {
      await player.dispose();
      return true;
    }
    _player = player;
    recorded = true;
    speaking = true;
    currentVerse = fromVerse;
    notifyListeners();
    _posSub = player.positionStream.listen((pos) {
      if (!speaking || !recorded) return;
      final v = rec.verseAt(pos);
      // Não volta para trás do versículo escolhido por causa do título falado no começo.
      if (v != currentVerse && v >= fromVerse) {
        currentVerse = v;
        notifyListeners();
      }
    });
    _stateSub = player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) stop();
    });
    unawaited(player.play());
    return true;
  }

  void _speakCurrent() {
    if (_pos >= _queue.length) {
      stop();
      return;
    }
    currentVerse = _queue[_pos].$1;
    notifyListeners();
    _tts.speak(_queue[_pos].$2);
  }

  void _next() {
    if (!speaking || recorded) return;
    _pos++;
    _speakCurrent();
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _tts.setSpeechRate(r);
    try {
      await _player?.setSpeed(_speed);
    } catch (_) {}
    await _prefs?.setDouble('tts.rate', r);
    notifyListeners();
  }

  Future<void> _stopPlayer() async {
    final p = _player;
    _player = null;
    await _posSub?.cancel();
    await _stateSub?.cancel();
    _posSub = null;
    _stateSub = null;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      await p.dispose();
    }
  }

  Future<void> stop() async {
    _run++;
    speaking = false;
    recorded = false;
    currentVerse = null;
    _queue = const [];
    notifyListeners();
    await _stopPlayer();
    await _tts.stop();
  }
}
