import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';

/// Abre o Spotify ou o YouTube do próprio usuário (com a conta dele) para tocar enquanto lê.
/// O app não toca essas músicas por dentro: os dois serviços só liberam isso em apps deles ou com
/// contrato próprio. A música toca no app do serviço e continua ao voltar para a Bíblia.
Future<void> showExternalMusic(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ExternalMusicSheet(),
    );

class _ExternalMusicSheet extends StatefulWidget {
  const _ExternalMusicSheet();

  @override
  State<_ExternalMusicSheet> createState() => _ExternalMusicSheetState();
}

class _ExternalMusicSheetState extends State<_ExternalMusicSheet> {
  late final _prefs = context.read<AppState>().prefs;
  late final _spotify = TextEditingController(text: _prefs.getString('music.spotify') ?? '');
  late final _youtube = TextEditingController(text: _prefs.getString('music.youtube') ?? '');

  @override
  void dispose() {
    _spotify.dispose();
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _open(String typed, String fallback, String key, String host) async {
    final messenger = ScaffoldMessenger.of(context);
    var url = typed.trim();
    await _prefs.setString(key, url);
    if (url.isEmpty) url = fallback;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains(host)) {
      messenger.showSnackBar(SnackBar(content: Text('Esse endereço não parece ser do $host.')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Não consegui abrir. O aplicativo está instalado?')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget service(String name, IconData icon, Color color, TextEditingController c, String hint, VoidCallback onOpen) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Abrir'), onPressed: onOpen),
            ]),
          ]),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ouvir pelo meu Spotify ou YouTube', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Cole o link da sua playlist (opcional) e toque em Abrir. A música toca no aplicativo do serviço, com a sua conta; '
              'volte para a Bíblia e ela continua tocando.'),
          service('Spotify', Icons.graphic_eq, const Color(0xFF1DB954), _spotify, 'Link da playlist (ou deixe vazio)',
              () => _open(_spotify.text, 'https://open.spotify.com/', 'music.spotify', 'spotify.com')),
          service('YouTube', Icons.smart_display, const Color(0xFFFF0000), _youtube, 'Link da playlist ou do vídeo (ou deixe vazio)',
              () => _open(_youtube.text, 'https://music.youtube.com/', 'music.youtube', 'youtube.com')),
          const SizedBox(height: 14),
          Text(
            'No YouTube, a música só continua com a tela em outro app para quem tem YouTube Premium. '
            'Tocar Spotify ou YouTube por dentro deste app não é permitido pelos serviços, por isso abrimos o aplicativo deles.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}
