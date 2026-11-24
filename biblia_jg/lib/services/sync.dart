import 'dart:convert';

import '../models/reader_settings.dart';
import '../state/app_state.dart';
import 'account_service.dart';

/// Monta a cópia completa deste aparelho (dados + ajustes de leitura).
Future<Map<String, dynamic>> localSnapshot(AppState app) async => {
      ...await app.db.exportAll(),
      'settings': app.settings.toJson(),
    };

/// Aplica uma cópia vinda da nuvem neste aparelho.
Future<void> applySnapshot(AppState app, Map<String, dynamic> data) async {
  await app.restoreBackup(data);
  final s = data['settings'];
  if (s is Map) {
    try {
      await app.updateSettings(ReaderSettings.fromJson(jsonDecode(jsonEncode(s))));
    } catch (_) {}
  }
}

/// Sincronização automática (ao abrir e ao sair do app):
/// se a nuvem tem uma cópia mais nova que a última sincronização daqui
/// (feita em outro aparelho), traz para cá; senão, envia a daqui.
Future<void> autoSync(AppState app, AccountService account) async {
  if (!account.signedIn) return;
  try {
    final cloud = await account.pull();
    final last = account.lastSync;
    if (cloud != null && (last == null || cloud.updatedAt.isAfter(last.add(const Duration(seconds: 5))))) {
      await applySnapshot(app, cloud.data);
      await account.markSynced(cloud.updatedAt);
    } else {
      await account.push(await localSnapshot(app));
    }
  } catch (_) {
    // Sem internet ou sessão expirada: tenta de novo na próxima vez.
  }
}

/// Só envia (ao sair do app).
Future<void> pushOnly(AppState app, AccountService account) async {
  if (!account.signedIn) return;
  try {
    await account.push(await localSnapshot(app));
  } catch (_) {}
}
