import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_service.dart' show appKey, supabaseAnonKey, supabaseUrl;
import 'stories.dart' show StoryMedia;

/// Narrações gravadas com a voz padrão do app (Algieba) para os textos explicativos (Panorama,
/// árvores, guia do Novo Testamento). A gravação é achada pelo próprio texto: o PC do dono grava
/// `narr/<chave>.mp3` e publica a lista em `narr/index.json`, então gravação nova chega sem novo APK.
class NarrationCloud {
  /// Nome da voz padrão do app.
  static const voice = 'Algieba';

  static Set<String>? _keys;
  static DateTime? _checked;
  static Future<void>? _loading;

  /// Chave estável do texto (igual à de tool/historias/narr.py): dois FNV-1a de 32 bits sobre o
  /// UTF-8 do texto com os espaços normalizados, em 16 dígitos hexadecimais.
  static String keyFor(String text) {
    final bytes = utf8.encode(text.trim().split(RegExp(r'\s+')).join(' '));
    return _hex(_fnv(bytes)) + _hex(_fnv(bytes.reversed));
  }

  static int _fnv(Iterable<int> bytes) {
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = _mul((h ^ b) & 0xFFFFFFFF);
    }
    return h;
  }

  /// (a * 16777619) mod 2^32, em partes de 16 bits para dar o mesmo resultado também na web.
  static int _mul(int a) {
    const p = 0x01000193;
    final lo = a & 0xFFFF, hi = (a >> 16) & 0xFFFF;
    return ((lo * p) + (((hi * p) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(8, '0');

  static Set<String> parseIndex(String raw) {
    final j = jsonDecode(raw);
    final list = j is Map ? j['h'] : null;
    return {for (final k in (list as List? ?? const [])) '$k'};
  }

  /// Caminho da gravação deste texto no bucket, ou null se ainda não foi gravado.
  static Future<String?> pathFor(String text) async {
    await _ensure();
    final k = keyFor(text);
    return (_keys?.contains(k) ?? false) ? 'narr/$k.mp3' : null;
  }

  static final _asked = <String>{};

  /// Pede a gravação de um texto que o app teve de narrar com a voz do aparelho (uma vez por sessão).
  static Future<void> request(String text) async {
    final k = keyFor(text);
    if (!_asked.add(k)) return;
    try {
      await http
          .post(Uri.parse('$supabaseUrl/functions/v1/historias-admin'),
              headers: {
                'Authorization': 'Bearer $supabaseAnonKey',
                'apikey': supabaseAnonKey,
                'x-app-key': appKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'narrar': text}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      _asked.remove(k);
    }
  }

  static Future<void> _ensure() {
    final last = _checked;
    if (_keys != null && last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) {
      return Future.value();
    }
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    _checked = DateTime.now();
    File? local;
    if (!kIsWeb) {
      try {
        local = File('${(await StoryMedia.dir()).path}/narr_index.json');
        if (_keys == null && await local.exists()) _keys = parseIndex(await local.readAsString());
      } catch (_) {}
    }
    try {
      // Sem internet não segura a apresentação: espera pouco e segue com o que já tem.
      final res = await http
          .get(Uri.parse('${StoryMedia.url('narr/index.json')}?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(Duration(seconds: _keys == null ? 6 : 3));
      if (res.statusCode == 200) {
        final raw = utf8.decode(res.bodyBytes);
        _keys = parseIndex(raw);
        if (local != null) await local.writeAsString(raw);
      }
    } catch (_) {}
    _keys ??= {};
  }
}
