import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Lista de livros (AT / NT) com a grade de capítulos do livro aberto.
/// No tablet fica fixa à esquerda; no celular abre como página.
class BookChapterPanel extends StatefulWidget {
  final VoidCallback? onSelected;
  const BookChapterPanel({super.key, this.onSelected});

  @override
  State<BookChapterPanel> createState() => _BookChapterPanelState();
}

class _BookChapterPanelState extends State<BookChapterPanel> {
  int? _expanded;
  bool _newTestament = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    if (bible == null) return const SizedBox();
    if (!_initialized) {
      _initialized = true;
      _expanded = app.book;
      _newTestament = bible.books[app.book].newTestament;
    }
    final scheme = Theme.of(context).colorScheme;
    final books = bible.books.where((b) => b.newTestament == _newTestament).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Antigo Testamento')),
            ButtonSegment(value: true, label: Text('Novo Testamento')),
          ],
          selected: {_newTestament},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _newTestament = s.first),
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, i) {
            final b = books[i];
            final open = _expanded == b.index;
            final current = app.book == b.index;
            final readCount = List.generate(b.chapters.length, (c) => c + 1)
                .where((c) => app.readChapters.contains('${b.index}:$c'))
                .length;
            return Column(children: [
              ListTile(
                dense: true,
                selected: current,
                title: Text(b.name,
                    style: TextStyle(fontWeight: current ? FontWeight.bold : null)),
                subtitle: readCount > 0
                    ? LinearProgressIndicator(value: readCount / b.chapters.length)
                    : null,
                trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
                onTap: () => setState(() => _expanded = open ? null : b.index),
              ),
              if (open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var c = 1; c <= b.chapters.length; c++)
                        _ChapterChip(
                          number: c,
                          selected: current && app.chapter == c,
                          read: app.readChapters.contains('${b.index}:$c'),
                          scheme: scheme,
                          onTap: () {
                            app.goTo(b.index, c);
                            widget.onSelected?.call();
                          },
                        ),
                    ],
                  ),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _ChapterChip extends StatelessWidget {
  final int number;
  final bool selected;
  final bool read;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _ChapterChip(
      {required this.number,
      required this.selected,
      required this.read,
      required this.scheme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? scheme.primary
        : read
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 40,
          child: Center(child: Text('$number', style: TextStyle(color: fg))),
        ),
      ),
    );
  }
}

class BookChapterPage extends StatelessWidget {
  const BookChapterPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Livros e capítulos')),
        body: BookChapterPanel(onSelected: () => Navigator.pop(context)),
      );
}
