import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'narration_cloud.dart';
import 'stories.dart' show StoryMedia;
import 'tts.dart';

/// Conduz uma apresentação passo a passo: toca a gravação do texto com a voz padrão do app
/// (Algieba) quando ela já existe; senão fala com a voz do aparelho; e avisa quando terminou.
/// Sem voz, espera o tempo de leitura. Se a voz falhar, também espera o tempo.
class StepNarrator {
  final ReadAloud tts;
  StepNarrator(this.tts);

  Timer? _timer;
  int _run = 0;
  bool _listening = false;
  bool _started = false;
  DateTime _since = DateTime.now();
  String _text = '';
  VoidCallback? _finish;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;

  static Duration readingTime(String text) =>
      Duration(milliseconds: (text.split(RegExp(r'\s+')).length / 2.6 * 1000).round().clamp(5000, 60000));

  void start(String text, {required bool voice, required VoidCallback onDone}) {
    stop();
    final run = ++_run;
    void finish() {
      if (run != _run) return;
      _run++;
      _detach();
      onDone();
    }

    if (!voice) {
      _timer = Timer(readingTime(text), finish);
      return;
    }
    NarrationCloud.pathFor(text).then((path) async {
      if (run != _run) return;
      if (path != null && await _playRecorded(path, run, finish)) return;
      if (path == null) unawaited(NarrationCloud.request(text));
      if (run == _run) _speakWithDevice(text, run, finish);
    }).catchError((_) {
      if (run == _run) _speakWithDevice(text, run, finish);
    });
  }

  /// Toca a gravação. Devolve false se não deu (aí entra a voz do aparelho).
  Future<bool> _playRecorded(String path, int run, VoidCallback finish) async {
    try {
      final player = _player ??= AudioPlayer();
      final file = await StoryMedia.file(path);
      if (run != _run) return true;
      if (file != null) {
        await player.setFilePath(file.path);
      } else {
        await player.setUrl(StoryMedia.url(path));
      }
      if (run != _run) return true;
      await _playerSub?.cancel();
      _playerSub = player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) finish();
      });
      unawaited(player.play());
      return true;
    } catch (_) {
      return false;
    }
  }

  void _speakWithDevice(String text, int run, VoidCallback finish) {
    _text = text;
    _finish = finish;
    _started = false;
    _since = DateTime.now();
    _listening = true;
    tts.addListener(_onTts);
    tts.speak([(1, text)]).then((_) {
      if (run != _run) return;
      // Se a voz não começar, segue pelo tempo de leitura.
      _timer = Timer(const Duration(seconds: 6), () {
        if (run == _run && !_started && !tts.speaking) _timer = Timer(readingTime(text), finish);
      });
    }).catchError((_) {
      if (run == _run) _timer = Timer(readingTime(text), finish);
    });
  }

  void _onTts() {
    if (!_listening) return;
    if (tts.speaking) {
      _started = true;
      return;
    }
    if (!_started) return;
    _started = false;
    final finish = _finish;
    final spoken = DateTime.now().difference(_since);
    final expected = readingTime(_text);
    _timer?.cancel();
    if (spoken < expected * 0.4) {
      // Parou cedo demais (erro da voz): completa o tempo de leitura.
      _timer = Timer(expected - spoken, () => finish?.call());
    } else {
      finish?.call();
    }
  }

  void _detach() {
    if (_listening) {
      _listening = false;
      tts.removeListener(_onTts);
    }
    _finish = null;
  }

  void stop() {
    _run++;
    _timer?.cancel();
    _timer = null;
    _playerSub?.cancel();
    _playerSub = null;
    final p = _player;
    if (p != null && p.playing) unawaited(p.stop().catchError((_) {}));
    if (_listening) {
      _detach();
      tts.stop();
    }
  }

  void dispose() {
    stop();
    final p = _player;
    _player = null;
    if (p != null) unawaited(p.dispose().catchError((_) {}));
  }
}
