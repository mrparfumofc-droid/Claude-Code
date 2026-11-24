import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart' show supabaseAnonKey, supabaseUrl;

/// ID (público) do cliente OAuth "Aplicativo da Web" no Google Cloud. O token do
/// Google é emitido para ele e o Supabase confere esse mesmo ID.
const googleWebClientId =
    '703427545959-3dmuhhtgimtmvtrj6so62t1r9ucehhg1.apps.googleusercontent.com';

class AccountException implements Exception {
  final String message;
  const AccountException(this.message);
  @override
  String toString() => message;
}

/// Cópia guardada na nuvem.
class CloudCopy {
  final Map<String, dynamic> data;
  final String? device;
  final DateTime updatedAt;
  const CloudCopy(this.data, this.device, this.updatedAt);
}

/// Login com a conta Google (via Supabase Auth) e sincronização dos dados do
/// usuário (marcações, favoritos, anotações, histórico, progresso e ajustes).
class AccountService extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _googleReady = false;
  bool busy = false;

  String? email;
  String? name;
  String? photoUrl;
  String? _userId;
  String? _access;
  String? _refresh;
  DateTime? _expiresAt;
  DateTime? lastSync;

  bool get signedIn => _userId != null && _refresh != null;

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  /// Carrega a sessão salva (sem abrir nada do Google).
  Future<void> load() async {
    final p = await _p;
    final raw = p.getString('account.session');
    if (raw != null) {
      try {
        _apply(jsonDecode(raw) as Map<String, dynamic>, save: false);
      } catch (_) {}
    }
    final ls = p.getString('account.lastSync');
    lastSync = ls == null ? null : DateTime.tryParse(ls);
    notifyListeners();
  }

  void _apply(Map<String, dynamic> s, {bool save = true}) {
    final user = s['user'] as Map<String, dynamic>?;
    final meta = (user?['user_metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    _userId = user?['id'] as String? ?? _userId;
    email = user?['email'] as String? ?? email;
    name = (meta['full_name'] ?? meta['name']) as String? ?? name;
    photoUrl = (meta['avatar_url'] ?? meta['picture']) as String? ?? photoUrl;
    _access = s['access_token'] as String?;
    _refresh = s['refresh_token'] as String? ?? _refresh;
    final exp = s['expires_at'];
    _expiresAt = exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
        : DateTime.now().add(Duration(seconds: (s['expires_in'] as num?)?.toInt() ?? 3600));
    if (save) {
      _prefs?.setString(
          'account.session',
          jsonEncode({
            'user': {
              'id': _userId,
              'email': email,
              'user_metadata': {'full_name': name, 'avatar_url': photoUrl},
            },
            'access_token': _access,
            'refresh_token': _refresh,
            'expires_at': _expiresAt!.millisecondsSinceEpoch ~/ 1000,
          }));
    }
  }

  Map<String, String> get _base => {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _auth(String grant, Map<String, String> body) async {
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse('$supabaseUrl/auth/v1/token?grant_type=$grant'),
              headers: _base, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const AccountException('Sem conexão com a internet.');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final msg = (data['msg'] ?? data['error_description'] ?? data['error'] ?? res.statusCode).toString();
      throw AccountException('O servidor recusou o login ($msg).');
    }
    return data;
  }

  /// Abre a escolha de conta Google e entra no app.
  Future<void> signIn() async {
    busy = true;
    notifyListeners();
    try {
      final g = GoogleSignIn.instance;
      if (!_googleReady) {
        await g.initialize(serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final GoogleSignInAccount account;
      try {
        account = await g.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw const AccountException('Login cancelado.');
        }
        throw AccountException('O Google não concluiu o login (${e.code.name}).');
      }
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AccountException('O Google não enviou o token de login.');
      final s = await _auth('id_token', {'provider': 'google', 'id_token': idToken});
      await _p;
      _apply(s);
      name ??= account.displayName;
      photoUrl ??= account.photoUrl;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    final p = await _p;
    await p.remove('account.session');
    await p.remove('account.lastSync');
    _userId = _access = _refresh = email = name = photoUrl = null;
    _expiresAt = null;
    lastSync = null;
    notifyListeners();
  }

  String? get userId => _userId;

  /// Token de acesso válido (renova sozinho quando está para vencer).
  Future<String> accessToken() => _token();

  Future<String> _token() async {
    if (!signedIn) throw const AccountException('Entre com a conta Google primeiro.');
    if (_access == null || _expiresAt == null ||
        DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 1)))) {
      final s = await _auth('refresh_token', {'refresh_token': _refresh!});
      await _p;
      _apply(s);
    }
    return _access!;
  }

  /// Lê a cópia da nuvem (ou null se ainda não existe).
  Future<CloudCopy?> pull() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/user_sync?select=data,device,updated_at&user_id=eq.$_userId'),
      headers: {..._base, 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw AccountException('Erro ao ler a nuvem (${res.statusCode}).');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    return CloudCopy(
      (row['data'] as Map).cast<String, dynamic>(),
      row['device'] as String?,
      DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Envia a cópia deste aparelho para a nuvem (substitui a anterior).
  Future<void> push(Map<String, dynamic> data, {String device = 'Tablet'}) async {
    final token = await _token();
    final now = DateTime.now().toUtc();
    final res = await http
        .post(
          Uri.parse('$supabaseUrl/rest/v1/user_sync?on_conflict=user_id'),
          headers: {
            ..._base,
            'Authorization': 'Bearer $token',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode({
            'user_id': _userId,
            'data': data,
            'device': device,
            'updated_at': now.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode >= 300) throw AccountException('Erro ao salvar na nuvem (${res.statusCode}).');
    await markSynced(now);
  }

  Future<void> markSynced(DateTime when) async {
    lastSync = when;
    await (await _p).setString('account.lastSync', when.toIso8601String());
    notifyListeners();
  }
}
