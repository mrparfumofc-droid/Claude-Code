import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma voz do mecanismo de fala do aparelho.
class TtsVoice {
  final String name;
  final String locale;
  final bool online;
  final int quality;
  const TtsVoice(this.name, this.locale, {this.online = false, this.quality = 0});

  /// Nome amigável: "Voz 3 · online · alta qualidade".
  String label(int index) => [
        'Voz ${index + 1}',
        online ? 'online (mais natural)' : 'offline',
        if (quality >= 400) 'alta qualidade',
      ].join(' · ');
}

/// Leitura em voz alta, versículo por versículo, avisando qual está sendo lido.
class ReadAloud extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool speaking = false;
  SharedPreferences? _prefs;

  /// Versículo sendo lido agora (1..n), ou null.
  int? currentVerse;
  double rate = 0.5; // 0.25 (lento) .. 1.0 (rápido) no Android
  double pitch = 1.0; // 0.5 (grave) .. 2.0 (agudo)
  String? engine; // null = padrão do aparelho
  String? voiceName;
  String? voiceLocale;
  List<(int, String)> _queue = const [];
  int _pos = 0;
  String _lang = 'pt-BR';

  Future<void> _init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    rate = _prefs!.getDouble('tts.rate') ?? rate;
    pitch = _prefs!.getDouble('tts.pitch') ?? pitch;
    engine = _prefs!.getString('tts.engine');
    voiceName = _prefs!.getString('tts.voice');
    voiceLocale = _prefs!.getString('tts.voiceLocale');
    if (engine != null) {
      try {
        await _tts.setEngine(engine!);
      } catch (_) {
        engine = null;
      }
    }
    _tts.setCompletionHandler(_next);
    _tts.setErrorHandler((_) => stop());
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  Future<void> _applyVoice(String lang) async {
    await _tts.setLanguage(lang);
    final v = voiceName;
    final loc = voiceLocale;
    // A voz escolhida só vale para o idioma dela (pt, en ou es).
    if (v != null && loc != null && loc.toLowerCase().startsWith(lang.substring(0, 2).toLowerCase())) {
      await _tts.setVoice({'name': v, 'locale': loc});
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
  }

  /// Lê os versículos [(número, texto)] em [lang] (pt-BR, en-US, es-ES).
  Future<void> speak(List<(int, String)> verses, {String lang = 'pt-BR'}) async {
    await _init();
    await _tts.stop();
    _queue = verses;
    _pos = 0;
    _lang = lang;
    await _applyVoice(_lang);
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
    await _prefs?.setDouble('tts.rate', r);
    notifyListeners();
  }

  Future<void> setPitch(double p) async {
    await _init();
    pitch = p;
    await _tts.setPitch(p);
    await _prefs?.setDouble('tts.pitch', p);
    notifyListeners();
  }

  /// Mecanismos de fala instalados (ex.: com.google.android.tts, com.samsung.SMT).
  Future<List<String>> engines() async {
    await _init();
    try {
      final list = await _tts.getEngines;
      return [for (final e in (list as List? ?? const [])) e.toString()];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setEngine(String? e) async {
    await _init();
    await stop();
    engine = e;
    voiceName = null;
    voiceLocale = null;
    if (e != null) {
      await _tts.setEngine(e);
      await _prefs?.setString('tts.engine', e);
    } else {
      await _prefs?.remove('tts.engine');
    }
    await _prefs?.remove('tts.voice');
    await _prefs?.remove('tts.voiceLocale');
    notifyListeners();
  }

  /// Vozes do mecanismo atual para o idioma (prefixo "pt", "en" ou "es").
  Future<List<TtsVoice>> voices(String langPrefix) async {
    await _init();
    try {
      final list = await _tts.getVoices as List? ?? const [];
      final out = <TtsVoice>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString() ?? '';
        final locale = raw['locale']?.toString() ?? '';
        if (name.isEmpty || !locale.toLowerCase().startsWith(langPrefix)) continue;
        final net = raw['network_required']?.toString();
        out.add(TtsVoice(
          name,
          locale,
          online: net == '1' || net == 'true' || name.contains('network'),
          quality: int.tryParse(raw['quality']?.toString() ?? '') ?? 0,
        ));
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> setVoice(TtsVoice? v) async {
    await _init();
    voiceName = v?.name;
    voiceLocale = v?.locale;
    if (v == null) {
      await _prefs?.remove('tts.voice');
      await _prefs?.remove('tts.voiceLocale');
    } else {
      await _prefs?.setString('tts.voice', v.name);
      await _prefs?.setString('tts.voiceLocale', v.locale);
    }
    notifyListeners();
  }

  /// Toca uma amostra com a voz [v] (ou a escolhida).
  Future<void> preview(String text, {TtsVoice? v, String lang = 'pt-BR'}) async {
    await _init();
    await stop();
    await _tts.setLanguage(lang);
    if (v != null) {
      await _tts.setVoice({'name': v.name, 'locale': v.locale});
    } else {
      await _applyVoice(lang);
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    speaking = false;
    currentVerse = null;
    _queue = const [];
    notifyListeners();
    await _tts.stop();
  }
}
