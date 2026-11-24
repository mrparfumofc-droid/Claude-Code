import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../models/bible.dart';
import '../models/daily.dart';
import '../state/app_state.dart';

/// Favoritos e marcações coloridas.
class MarksScreen extends StatelessWidget {
  const MarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos & Marcações'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'Favoritos'), Tab(text: 'Marcações')],
          ),
        ),
        body: const TabBarView(children: [_FavoritesTab(), _HighlightsTab()]),
      ),
    );
  }
}

void _open(BuildContext context, AppState app, VerseRef r) {
  app.openAt(r.book, r.chapter, verse: r.verse);
  Navigator.popUntil(context, (route) => route.isFirst);
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return FutureBuilder<List<VerseRef>>(
      key: ValueKey(app.userDataRevision),
      future: app.db.allFavorites(),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) return const Center(child: CircularProgressIndicator());
        if (list.isEmpty) {
          return const _Empty('Nenhum favorito ainda.\nToque num versículo e use o marcador.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = list[i];
            return ListTile(
              leading: const Icon(Icons.bookmark, color: Color(0xFFC9A227)),
              title: Text(r.label(app.bible)),
              subtitle: Text(app.bible == null ? '' : verseText(app.bible!, r) ?? ''),
              onTap: () => _open(context, app, r),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => app.removeFavoriteAt(r),
              ),
            );
          },
        );
      },
    );
  }
}

class _HighlightsTab extends StatelessWidget {
  const _HighlightsTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return FutureBuilder<List<Highlight>>(
      key: ValueKey(app.userDataRevision),
      future: app.db.allHighlights(),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) return const Center(child: CircularProgressIndicator());
        if (list.isEmpty) {
          return const _Empty('Nenhuma marcação ainda.\nToque num versículo e escolha uma cor.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final h = list[i];
            return ListTile(
              leading: CircleAvatar(radius: 12, backgroundColor: Color(h.color)),
              title: Text(h.ref.label(app.bible)),
              subtitle: Text(app.bible == null ? '' : verseText(app.bible!, h.ref) ?? ''),
              onTap: () => _open(context, app, h.ref),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => app.removeHighlightAt(h.ref),
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, textAlign: TextAlign.center));
}
