import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    if (bible == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Progresso de Leitura')),
          body: const Center(child: Text('Nenhuma versão instalada.')));
    }
    final total = bible.totalChapters;
    final read = app.readChapters.length;
    final pct = total == 0 ? 0.0 : read / total;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progresso de Leitura'), actions: [
        IconButton(
          tooltip: 'Recomeçar progresso',
          icon: const Icon(Icons.restart_alt),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Recomeçar progresso?'),
                content: const Text('Todos os capítulos voltarão a ficar como não lidos.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recomeçar')),
                ],
              ),
            );
            if (ok == true) app.resetProgress();
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('${(pct * 100).toStringAsFixed(1)}%', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: pct, minHeight: 10),
              const SizedBox(height: 8),
              Text('$read de $total capítulos lidos'),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4,
            children: [
              for (final b in bible.books)
                Builder(builder: (context) {
                  final n = b.chapters.length;
                  final r = List.generate(n, (i) => i + 1)
                      .where((ch) => app.readChapters.contains('${b.index}:$ch'))
                      .length;
                  return ListTile(
                    title: Text(b.name),
                    subtitle: LinearProgressIndicator(value: n == 0 ? 0 : r / n),
                    trailing: Text('$r/$n'),
                  );
                }),
            ],
          );
        }),
      ]),
    );
  }
}
