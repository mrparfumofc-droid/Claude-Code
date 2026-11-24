import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Leitura em voz alta, versículo por versículo, avisando qual está sendo lido.
class ReadAloud extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool speaking = false;

  /// Versículo sendo lido agora (1..n), ou null.
  int? currentVerse;
  double rate = 0.5; // 0.25 (lento) .. 1.0 (rápido) no Android
  List<(int, String)> _queue = const [];
  int _pos = 0;
  String _lang = 'pt-BR';

  Future<void> _init() async {
    if (_ready) return;
    _tts.setCompletionHandler(_next);
    _tts.setErrorHandler((_) => stop());
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  /// Lê os versículos [(número, texto)] em [lang] (pt-BR, en-US, es-ES).
  Future<void> speak(List<(int, String)> verses, {String lang = 'pt-BR'}) async {
    await _init();
    await _tts.stop();
    _queue = verses;
    _pos = 0;
    _lang = lang;
    await _tts.setLanguage(_lang);
    await _tts.setSpeechRate(rate);
    speaking = true;
    _speakCurrent();
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
    if (!speaking) return;
    _pos++;
    _speakCurrent();
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _tts.setSpeechRate(r);
    notifyListeners();
  }

  Future<void> stop() async {
    speaking = false;
    currentVerse = null;
    _queue = const [];
    notifyListeners();
    await _tts.stop();
  }
}
