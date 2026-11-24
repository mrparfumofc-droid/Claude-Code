import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Atualização disponível na página de Releases do GitHub.
class UpdateInfo {
  final int build;
  final String apkUrl;
  final String? sha256;
  final int sizeBytes;
  const UpdateInfo({
    required this.build,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
  });

  String get sizeLabel => '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

final _buildTag = RegExp(r'^biblia-build-(\d+)$');

/// Lê a resposta de `releases/latest` e devolve a atualização,
/// ou null se não houver versão mais nova que [currentBuild].
UpdateInfo? parseLatestRelease(Map<String, dynamic> json, int currentBuild) {
  final m = _buildTag.firstMatch((json['tag_name'] ?? '').toString());
  if (m == null) return null;
  final build = int.parse(m.group(1)!);
  if (build <= currentBuild) return null;
  final assets = (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final apk = assets.where((a) => (a['name'] ?? '').toString().endsWith('.apk')).firstOrNull;
  if (apk == null) return null;
  final digest = apk['digest']?.toString();
  return UpdateInfo(
    build: build,
    apkUrl: apk['browser_download_url'].toString(),
    sha256: digest != null && digest.startsWith('sha256:') ? digest.substring(7) : null,
    sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
  );
}

class Updater {
  static const latestReleaseUrl =
      'https://api.github.com/repos/mrparfumofc-droid/Claude-Code/releases/latest';

  Future<int> currentBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  Future<String> currentVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (build ${info.buildNumber})';
  }

  /// Procura atualização. Retorna null se não houver ou se der erro de rede.
  Future<UpdateInfo?> check() async {
    final res = await http.get(Uri.parse(latestReleaseUrl), headers: const {
      'Accept': 'application/vnd.github+json',
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return parseLatestRelease(
        jsonDecode(res.body) as Map<String, dynamic>, await currentBuild());
  }
}
