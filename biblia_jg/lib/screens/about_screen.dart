import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

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
            const CircleAvatar(
              radius: 48,
              backgroundColor: jgNavy,
              child: Text('JG',
                  style: TextStyle(color: jgGold, fontSize: 36, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text('Bíblia · JG Company', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Versão 1.0.0'),
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
