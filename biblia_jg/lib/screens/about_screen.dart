import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/updater.dart';
import '../state/app_state.dart';
import '../widgets/update_dialog.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bible = context.watch<AppState>().bible;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/branding/logo.png', width: 220, height: 220),
            ),
            const SizedBox(height: 16),
            Text('Bíblia · JG Company', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Produzido por Joabe Gonçalves',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: Updater().currentVersionLabel().catchError((_) => ''),
              builder: (_, snap) => Text('Versão ${snap.data ?? ''}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => checkForUpdates(context, silentIfNone: false),
              icon: const Icon(Icons.system_update),
              label: const Text('Procurar atualização'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Títulos de seção e palavras de Jesus: Berean Standard Bible (domínio público).\n'
              'Referências cruzadas e lugares bíblicos: OpenBible.info (CC-BY).\n'
              'Mapas: Sentinel-2 cloudless – s2maps.eu, EOX IT Services (Copernicus 2020).\n'
              'Fotos dos fundos: Wikimedia Commons (CC0, domínio público e CC BY).\n'
              'Hinos: Wikisource (domínio público). Dicionários: Easton, Smith, Hitchcock e Torrey (domínio público, traduzidos).\n'
              'Histórias bíblicas: texto próprio do app; ilustrações (Google Gemini) e narração (Gemini TTS) '
              'criadas com inteligência artificial, como reconstituição artística. '
              'Efeito 3D: Depth Anything V2 (Apache 2.0).\n'
              'IA: Google Gemini e Gemma.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (bible != null) ...[
              Text('Texto bíblico: ${bible.name} (${bible.abbrev})',
                  textAlign: TextAlign.center),
              if (bible.copyright.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(bible.copyright, textAlign: TextAlign.center),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}
