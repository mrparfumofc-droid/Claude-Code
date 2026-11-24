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
