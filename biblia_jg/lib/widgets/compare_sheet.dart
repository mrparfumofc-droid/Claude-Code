import 'package:flutter/material.dart';

import '../models/bible.dart';
import '../state/app_state.dart';

/// Versões mostradas na comparação, da linguagem mais simples à mais tradicional.
const _preferred = ['ntlh', 'nvt', 'nvi', 'naa', 'ara', 'arc', 'acf', 'kja'];

/// Mostra o mesmo trecho em outras versões (ajuda a entender texto difícil).
Future<void> showCompareVersions(BuildContext context, AppState app, int book, int chapter, List<int> verses) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CompareSheet(app: app, book: book, chapter: chapter, verses: verses),
  );
}

class _CompareSheet extends StatefulWidget {
  final AppState app;
  final int book;
  final int chapter;
  final List<int> verses;
  const _CompareSheet({required this.app, required this.book, required this.chapter, required this.verses});

  @override
  State<_CompareSheet> createState() => _CompareSheetState();
}

class _CompareSheetState extends State<_CompareSheet> {
  final _results = <(String, String, String)>[]; // (sigla, nome, texto)
  bool _loading = true;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  String? _text(Bible b) {
    if (widget.book >= b.books.length) return null;
    final chapters = b.books[widget.book].chapters;
    if (widget.chapter > chapters.length) return null;
    final vs = chapters[widget.chapter - 1];
    final out = [
      for (final v in widget.verses)
        if (v >= 1 && v <= vs.length) plainVerse(vs[v - 1]).trim()
    ];
    return out.isEmpty ? null : out.join(' ');
  }

  Future<void> _load() async {
    final app = widget.app;
    final current = app.bible;
    if (current != null) {
      final t = _text(current);
      if (t != null) _results.add((current.abbrev, '${current.name} (aberta)', t));
    }
    final ids = {for (final v in app.versions) v.id};
    final wanted = _preferred.where((id) => ids.contains(id) && id != current?.id).take(5);
    for (final id in wanted) {
      if (!_alive) return;
      try {
        final b = await app.repo.load(id);
        final t = b == null ? null : _text(b);
        if (b != null && t != null && _alive) setState(() => _results.add((b.abbrev, b.name, t)));
      } catch (_) {}
    }
    if (_alive) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.app.currentBook?.name ?? '';
    final ref = widget.verses.length == 1
        ? '$name ${widget.chapter}:${widget.verses.first}'
        : '$name ${widget.chapter}:${widget.verses.first}-${widget.verses.last}';
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            Expanded(child: Text('Comparar versões · $ref', style: theme.textTheme.titleMedium)),
            if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 28),
            itemBuilder: (context, i) {
              final (abbrev, full, text) = _results[i];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$abbrev · $full', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 6),
                SelectableText(text, style: TextStyle(fontSize: 18, height: 1.45, fontFamily: widget.app.settings.fontFamily)),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
