import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor Supabase do app (projeto biblia-jg).
const supabaseUrl = 'https://ayjsoixzroxkrnkpkkip.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF5anNvaXh6cm94a3Jua3Bra2lwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU0NzcyMDksImV4cCI6MjExMTA1MzIwOX0.AX_pzuq9GY2ugKBjjdwJWVcXZw3Q7DGWNpsUFlWq6f4';

/// Chave do app para a IA (o servidor guarda só o hash e limita o uso por aparelho).
const _appKey = 'jg_usBloH9hTBbeCNhpF3eVcGxF65MaM0nK';

class AiTurn {
  final bool fromUser;
  final String text;
  const AiTurn(this.fromUser, this.text);

  Map<String, String> toJson() => {'role': fromUser ? 'user' : 'model', 'text': text};
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Perfis teológicos disponíveis (o texto de cada um fica no servidor).
const aiProfiles = <String, String>{
  'assembleiano': 'Assembleiano clássico',
  'geral': 'Cristão geral',
  'batista': 'Batista',
  'reformado': 'Reformado',
  'academico': 'Acadêmico',
  'catolico': 'Católico',
};

class AiService {
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  static Future<String> profile() async =>
      (await SharedPreferences.getInstance()).getString('ai_profile') ?? 'assembleiano';

  static Future<void> setProfile(String p) async =>
      (await SharedPreferences.getInstance()).setString('ai_profile', p);

  /// Envia o pedido à IA. [task]: explain, commentary, term, devotional, story, quiz, sermon, chat.
  static Future<String> ask({
    required String task,
    required List<AiTurn> messages,
    String? reference,
    String? version,
    String? verseText,
    String? profileOverride,
  }) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$supabaseUrl/functions/v1/ai-verse'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $supabaseAnonKey',
              'apikey': supabaseAnonKey,
              'x-app-key': _appKey,
              'x-device-id': await deviceId(),
            },
            body: jsonEncode({
              'task': task,
              'profile': profileOverride ?? await profile(),
              'reference': ?reference,
              'version': ?version,
              'verseText': ?verseText,
              'messages': messages.map((m) => m.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      throw const AiException('Sem conexão com a internet. A IA precisa de internet.');
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('Resposta inválida do servidor (${res.statusCode}).');
    }
    if (res.statusCode != 200 || data['text'] == null) {
      throw AiException((data['error'] ?? 'A IA não respondeu (${res.statusCode}).').toString());
    }
    return data['text'] as String;
  }
}
