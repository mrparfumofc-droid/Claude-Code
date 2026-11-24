import 'package:flutter/material.dart';

import '../models/bible.dart';
import '../models/reference_parser.dart';
import '../services/xrefs.dart';
import '../state/app_state.dart';

String passageText(Bible bible, Passage p) {
  if (p.book >= bible.books.length) return '';
  final b = bible.books[p.book];
  if (p.chapter < 1 || p.chapter > b.chapters.length) return '';
  final verses = b.chapters[p.chapter - 1];
  final start = (p.verse ?? 1).clamp(1, verses.length);
  final end = (p.endVerse ?? p.verse ?? verses.length).clamp(start, verses.length);
  return [for (var v = start; v <= end; v++) plainVerse(verses[v - 1]).trim()].join(' ');
}

Future<void> showCrossReferences(BuildContext context, AppState app, VerseRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => FutureBuilder<List<Passage>>(
        future: CrossReferences.forVerse(ref.book, ref.chapter, ref.verse),
        builder: (ctx, snap) {
          final list = snap.data;
          final bible = app.bible!;
          return ListView(controller: scroll, children: [
            ListTile(
              title: Text('Referências cruzadas · ${ref.label(bible)}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: const Text(CrossReferences.attribution),
            ),
            if (list == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhuma referência cruzada para este versículo.'))
            else
              for (final p in list)
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(p.label(bible), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(passageText(bible, p), maxLines: 3, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    app.goTo(p.book, p.chapter, verse: p.verse);
                  },
                ),
          ]);
        },
      ),
    ),
  );
}
