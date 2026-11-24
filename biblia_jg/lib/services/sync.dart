import 'dart:convert';

import '../models/reader_settings.dart';
import '../state/app_state.dart';
import 'account_service.dart';
import 'dictionary_service.dart';

/// Preferências que também vão na cópia (plano de leitura, favoritos do hinário, meta).
const _stringKeys = ['plan_id', 'plan_start'];
const _listKeys = ['plan_done', 'hymn.favorites'];
const _intKeys = ['goal_minutes'];

/// Monta a cópia completa deste aparelho (dados, ajustes de leitura, plano,
/// e marcações do dicionário).
Future<Map<String, dynamic>> localSnapshot(AppState app, [DictionaryService? dict]) async {
  final p = app.prefs;
  final marks = dict == null ? null : await dict.loadedMarks();
  return {
    ...await app.db.exportAll(),
    'settings': app.settings.toJson(),
    'prefs': {
      for (final k in _stringKeys)
        if (p.getString(k) != null) k: p.getString(k),
      for (final k in _listKeys)
        if (p.getStringList(k) != null) k: p.getStringList(k),
      for (final k in _intKeys)
        if (p.getInt(k) != null) k: p.getInt(k),
    },
    // Só envia as marcações do dicionário se a leitura do arquivo deu certo.
    'dict_marks': ?marks,
  };
}

/// Aplica uma cópia vinda da nuvem. Com [merge], junta com o que já existe aqui.
Future<void> applySnapshot(AppState app, Map<String, dynamic> data,
    [DictionaryService? dict, bool merge = false]) async {
  await app.restoreBackup(data, merge: merge);
  final s = data['settings'];
  if (s is Map) {
    try {
      await app.updateSettings(ReaderSettings.fromJson(jsonDecode(jsonEncode(s))));
    } catch (_) {}
  }
  final prefs = data['prefs'];
  if (prefs is Map) {
    final p = app.prefs;
    final hasPlan = p.getString('plan_id') != null;
    for (final k in _stringKeys) {
      final v = prefs[k];
      if (v is String && (!merge || !hasPlan)) await p.setString(k, v);
    }
    for (final k in _listKeys) {
      final v = prefs[k];
      if (v is! List) continue;
      final list = [for (final e in v) '$e'];
      if (k == 'plan_done') {
        if (!merge || !hasPlan) await p.setStringList(k, list);
      } else {
        await p.setStringList(k, merge ? {...?p.getStringList(k), ...list}.toList() : list);
      }
    }
    for (final k in _intKeys) {
      final v = prefs[k];
      if (v is int && (!merge || p.getInt(k) == null)) await p.setInt(k, v);
    }
  }
  final marks = data['dict_marks'];
  if (dict != null && marks is Map) dict.importMarks(marks.cast<String, dynamic>(), merge: merge);
}

/// Impressão digital da cópia (para saber se algo mudou aqui desde a última sincronização).
int snapshotHash(Map<String, dynamic> snap) {
  final s = jsonEncode({...snap}..remove('exportedAt'));
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

bool _running = false;

/// Sincronização (ao abrir, ao voltar e ao sair do app). Nunca perde dados:
/// - nuvem mais nova e nada mudou aqui: a nuvem vale (inclusive o que foi apagado lá);
/// - nuvem mais nova e também mudou aqui: junta os dois e envia o resultado;
/// - só mudou aqui: envia.
/// Retorna false se não conseguiu (sem internet, sessão vencida).
Future<bool> autoSync(AppState app, AccountService account, [DictionaryService? dict]) async {
  if (!account.signedIn) return false;
  if (_running) return true;
  _running = true;
  try {
    final cloud = await account.pull();
    final last = account.lastSync;
    var local = await localSnapshot(app, dict);
    final dirty = last == null || snapshotHash(local) != account.lastHash;
    final cloudNewer =
        cloud != null && (last == null || cloud.updatedAt.isAfter(last.add(const Duration(seconds: 5))));
    if (cloudNewer) {
      await applySnapshot(app, cloud.data, dict, dirty);
      local = await localSnapshot(app, dict);
      if (!dirty) {
        await account.markSynced(cloud.updatedAt, hash: snapshotHash(local));
        return true;
      }
    } else if (!dirty && cloud != null) {
      return true; // nada mudou
    }
    await account.push(local, hash: snapshotHash(local));
    return true;
  } catch (_) {
    return false; // sem internet ou sessão expirada: tenta de novo na próxima vez
  } finally {
    _running = false;
  }
}
