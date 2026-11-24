import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../state/app_state.dart';
import '../widgets/note_editor.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Anotações')),
      body: FutureBuilder<List<Note>>(
        key: ValueKey(app.userDataRevision),
        future: app.db.allNotes(),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return const Center(
              child: Text('Nenhuma anotação ainda.\nToque num versículo e escolha "Anotação".',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = list[i];
              final d = n.updated;
              return Card(
                child: ListTile(
                  title: Text(n.ref.label(app.bible),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text(n.text),
                    const SizedBox(height: 4),
                    Text('${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  onTap: () => showNoteEditor(context, app, n.ref, existing: n),
                  trailing: IconButton(
                    tooltip: 'Ir para o versículo',
                    icon: const Icon(Icons.menu_book),
                    onPressed: () {
                      app.openAt(n.ref.book, n.ref.chapter, verse: n.ref.verse);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
