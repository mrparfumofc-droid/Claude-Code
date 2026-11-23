import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../state/app_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _rev = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico'), actions: [
        IconButton(
          tooltip: 'Limpar histórico',
          icon: const Icon(Icons.delete_sweep),
          onPressed: () async {
            await app.db.clearHistory();
            setState(() => _rev++);
          },
        ),
      ]),
      body: FutureBuilder<List<HistoryEntry>>(
        key: ValueKey(_rev),
        future: app.db.history(),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) return const Center(child: Text('Nenhum capítulo lido ainda.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final h = list[i];
              final name = bible != null && h.book < bible.books.length
                  ? bible.books[h.book].name
                  : 'Livro ${h.book + 1}';
              final d = h.at;
              final when =
                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text('$name ${h.chapter}'),
                trailing: Text(when),
                onTap: () {
                  app.goTo(h.book, h.chapter);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }
}
