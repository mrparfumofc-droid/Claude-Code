import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bible.dart';
import '../state/app_state.dart';

enum SearchScope { all, oldTestament, newTestament, currentBook }

class SearchHit {
  final VerseRef ref;
  final String text;
  const SearchHit(this.ref, this.text);
}

const maxSearchHits = 1000;

/// Busca todas as palavras (sem acento, sem diferenciar maiúsculas),
/// ou a frase exata se vier entre aspas.
List<SearchHit> searchBible(Bible bible, String query, SearchScope scope, int currentBook) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final exact = q.length > 2 && q.startsWith('"') && q.endsWith('"');
  final terms = exact
      ? [normalizeForSearch(q.substring(1, q.length - 1))]
      : normalizeForSearch(q).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final hits = <SearchHit>[];
  for (final b in bible.books) {
    final inScope = switch (scope) {
      SearchScope.all => true,
      SearchScope.oldTestament => !b.newTestament,
      SearchScope.newTestament => b.newTestament,
      SearchScope.currentBook => b.index == currentBook,
    };
    if (!inScope) continue;
    for (var c = 0; c < b.chapters.length; c++) {
      final verses = b.chapters[c];
      for (var v = 0; v < verses.length; v++) {
        final norm = normalizeForSearch(verses[v]);
        if (terms.every(norm.contains)) {
          hits.add(SearchHit(VerseRef(b.index, c + 1, v + 1), plainVerse(verses[v]).trim()));
          if (hits.length >= maxSearchHits) return hits;
        }
      }
    }
  }
  return hits;
}

List<SearchHit> _searchIsolate((Bible, String, SearchScope, int) a) =>
    searchBible(a.$1, a.$2, a.$3, a.$4);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  SearchScope _scope = SearchScope.all;
  List<SearchHit>? _hits;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final app = context.read<AppState>();
    final bible = app.bible;
    if (bible == null || _controller.text.trim().length < 2) return;
    setState(() => _busy = true);
    final hits = await compute(_searchIsolate, (bible, _controller.text, _scope, app.book));
    if (mounted) {
      setState(() {
        _hits = hits;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hits = _hits;
    return Scaffold(
      appBar: AppBar(title: const Text('Pesquisa')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  hintText: 'Palavras ou "frase exata"',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _run),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final (s, label) in [
                  (SearchScope.all, 'Bíblia toda'),
                  (SearchScope.oldTestament, 'Antigo Testamento'),
                  (SearchScope.newTestament, 'Novo Testamento'),
                  (SearchScope.currentBook, app.currentBook?.name ?? 'Livro atual'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _scope == s,
                      onSelected: (_) {
                        setState(() => _scope = s);
                        _run();
                      },
                    ),
                  ),
              ]),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (hits != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(hits.length >= maxSearchHits
                    ? 'Mais de $maxSearchHits resultados — refine a busca'
                    : '${hits.length} resultado(s)'),
              ),
            Expanded(
              child: hits == null
                  ? const SizedBox()
                  : ListView.separated(
                      itemCount: hits.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final h = hits[i];
                        return ListTile(
                          title: Text(h.ref.label(app.bible),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(h.text),
                          onTap: () {
                            app.goTo(h.ref.book, h.ref.chapter, verse: h.ref.verse);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
