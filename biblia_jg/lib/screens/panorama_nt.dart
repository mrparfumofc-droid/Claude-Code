import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible.dart';
import '../services/nt_guide.dart';
import '../services/stories.dart' show StoriesData, parseStoryReference;
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/study_art.dart';
import 'panorama_presenter.dart';
import 'panorama_screen.dart' show BookSheetScreen;
import 'panorama_tree.dart' show RefChip;

String _bookName(BuildContext context, int n) {
  final bible = context.read<AppState>().bible;
  return bible != null && n - 1 < bible.books.length ? bible.books[n - 1].name : canonicalBooks[n - 1].name;
}

/// Quadro com a ilustração ao fundo, coberta por um véu da cor do grupo para o texto branco continuar legível.
class _Backdrop extends StatelessWidget {
  final String art;
  final Color color;
  final bool large;
  final Widget child;
  const _Backdrop({required this.art, required this.color, required this.child, this.large = false});

  @override
  Widget build(BuildContext context) {
    const night = Color(0xFF0E1626);
    final deep = Color.lerp(color, night, 0.5)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(fit: StackFit.passthrough, children: [
        Positioned.fill(child: StudyArt(art: art, color: color, icon: Icons.menu_book, large: large, cacheWidth: large ? 1400 : 700)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0, 0.5, 1],
                colors: [color.withValues(alpha: 0.96), deep.withValues(alpha: 0.72), night.withValues(alpha: 0.28)],
              ),
            ),
          ),
        ),
        child,
      ]),
    );
  }
}

// ======================================================================
// Índice dos 27 livros
// ======================================================================

/// "Novo Testamento, livro por livro": o índice, por grupo ou na ordem em que os livros foram escritos.
class NtGuideScreen extends StatefulWidget {
  const NtGuideScreen({super.key});

  @override
  State<NtGuideScreen> createState() => _NtGuideScreenState();
}

class _NtGuideScreenState extends State<NtGuideScreen> {
  static const _orderKey = 'nt.ordem_escrita';
  NtGuide? _guide;
  Set<int> _done = const {};
  bool _chrono = false;

  @override
  void initState() {
    super.initState();
    NtGuide.load().then((g) {
      if (mounted) setState(() => _guide = g);
    });
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _chrono = p.getBool(_orderKey) ?? false);
    }).catchError((_) {});
    NtProgress.revision.addListener(_loadDone);
    _loadDone();
  }

  @override
  void dispose() {
    NtProgress.revision.removeListener(_loadDone);
    super.dispose();
  }

  void _loadDone() {
    NtProgress.load().then((s) {
      if (mounted) setState(() => _done = s);
    }).catchError((_) {});
  }

  void _setOrder(bool chrono) {
    setState(() => _chrono = chrono);
    SharedPreferences.getInstance().then((p) => p.setBool(_orderKey, chrono)).catchError((_) => false);
  }

  Widget _grid(NtGuide g, List<NtBook> books) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380, mainAxisExtent: 156, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: books.length,
        itemBuilder: (context, i) {
          final b = books[i];
          final color = g.groupOf(b).color;
          return _Backdrop(
            art: b.cover,
            color: color,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NtBookScreen(number: b.n))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        child: Text(_chrono ? '${b.order}º · ${b.date}' : b.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      if (_done.contains(b.n))
                        const Tooltip(message: 'Estudado', child: Icon(Icons.check_circle, color: Colors.white, size: 22)),
                    ]),
                    const Spacer(),
                    Text(_bookName(context, b.n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
                    const SizedBox(height: 3),
                    Text(b.theme,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.25)),
                    const SizedBox(height: 4),
                    Text('${b.parts.length} partes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    final theme = Theme.of(context);
    context.watch<AppState>(); // os nomes dos livros acompanham a versão aberta
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Testamento, livro por livro')),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
                  Text(
                    'Cada livro contado em partes, seguindo os capítulos: quem escreveu, para quem e por quê, o que acontece ou o que o autor ensina, '
                    'os versículos-chave e as lições para hoje. Abra um livro para ler ou toque em Apresentar para ouvir com as ilustrações.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.view_module_outlined), label: Text('Por grupo')),
                        ButtonSegment(value: true, icon: Icon(Icons.schedule), label: Text('Ordem em que foram escritos')),
                      ],
                      selected: {_chrono},
                      onSelectionChanged: (s) => _setOrder(s.first),
                    ),
                    SizedBox(
                      width: 240,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${_done.length} de ${g.books.length} livros estudados', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: _done.length / g.books.length, minHeight: 6, color: jgGold),
                        ),
                      ]),
                    ),
                  ]),
                  if (_chrono) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ordem aproximada, pela posição tradicional. Várias datas são discutidas pelos estudiosos; o que não muda é a sequência geral: '
                      'primeiro as cartas das viagens de Paulo, depois os Evangelhos e as cartas da prisão, por fim os escritos de João.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _grid(g, g.chronological),
                  ] else
                    for (final group in g.groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
                        child: Row(children: [
                          Container(width: 5, height: 34, decoration: BoxDecoration(color: group.color, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(group.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                              if (group.sub.isNotEmpty)
                                Text(group.sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ]),
                          ),
                        ]),
                      ),
                      _grid(g, [for (final b in g.books) if (b.group == group.id) b]),
                    ],
                ]),
              ),
            ),
    );
  }
}

// ======================================================================
// Guia de um livro
// ======================================================================

/// O guia de um livro do Novo Testamento (número 40..66): contexto, partes, versículos-chave,
/// lições e ligações, com apresentação narrada parte por parte.
class NtBookScreen extends StatefulWidget {
  final int number;
  const NtBookScreen({super.key, required this.number});

  @override
  State<NtBookScreen> createState() => _NtBookScreenState();
}

class _NtBookScreenState extends State<NtBookScreen> {
  NtGuide? _guide;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    NtGuide.load().then((g) {
      if (mounted) setState(() => _guide = g);
    });
    NtProgress.revision.addListener(_loadDone);
    _loadDone();
  }

  @override
  void dispose() {
    NtProgress.revision.removeListener(_loadDone);
    super.dispose();
  }

  void _loadDone() {
    NtProgress.load().then((s) {
      if (mounted) setState(() => _done = s.contains(widget.number));
    }).catchError((_) {});
  }

  /// Texto do versículo-chave na versão aberta.
  String? _verseText(Bible? bible, String ref) {
    final p = parseStoryReference(ref);
    if (bible == null || p == null || p.book >= bible.books.length) return null;
    final chapters = bible.books[p.book].chapters;
    if (p.chapter < 1 || p.chapter > chapters.length || p.verse == null) return null;
    final verses = chapters[p.chapter - 1];
    final out = <String>[];
    for (var v = p.verse!; v <= (p.endVerse ?? p.verse!) && v <= verses.length; v++) {
      out.add(plainVerse(verses[v - 1]).trim());
    }
    return out.isEmpty ? null : out.join(' ');
  }

  void _present(NtBook b, NtGroup group, String name, {int at = 0, bool play = true}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyPresenter(
        title: name,
        color: group.color,
        icon: Icons.menu_book,
        initialStep: at,
        autoPlay: play,
        onCompleted: () => NtProgress.set(b.n, true),
        steps: [
          PresenterStep(kicker: '${group.name} · ${b.date}', title: name, text: '${b.theme}. ${b.why}', art: b.cover),
          for (final p in b.parts) PresenterStep(kicker: p.label, title: p.title, text: p.text, refs: p.refs, art: p.art),
          PresenterStep(kicker: 'Lições para hoje', title: 'O que $name nos ensina', text: b.lessons.join(' '), refs: b.keys, art: b.cover),
        ],
      ),
    ));
  }

  Future<void> _stories(NtBook b) async {
    final data = await StoriesData.load();
    if (!mounted) return;
    final list = [for (final id in b.stories) data.byId(id)].nonNulls.toList();
    if (list.isEmpty) return;
    if (list.length == 1) {
      openIllustratedStory(context, list.first.id);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
            const ListTile(title: Text('Histórias ilustradas deste livro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            for (final s in list)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(s.title),
                subtitle: Text('${s.reference} · ${s.scenes.length} cenas'),
                onTap: () {
                  Navigator.pop(ctx);
                  openIllustratedStory(context, s.id);
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _guide;
    final n = widget.number;
    final app = context.watch<AppState>();
    final bible = app.bible;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _bookName(context, n);
    final b = g?.byNumber[n];
    if (g == null || b == null) {
      return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: g == null ? const CircularProgressIndicator() : const Text('Este livro não tem guia.')),
      );
    }
    final group = g.groupOf(b);
    final color = group.color;
    final chapters = bible != null && n - 1 < bible.books.length ? bible.books[n - 1].chapters.length : null;

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 5, height: 22, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif'))),
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        );

    Widget badge(String label, String value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
          ]),
        );

    Widget fact(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            SizedBox(width: 92, child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 15.5, height: 1.35))),
          ]),
        );

    Widget part(int i) {
      final p = b.parts[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _present(b, group, name, at: i + 1, play: false),
            child: LayoutBuilder(builder: (context, box) {
              final side = box.maxWidth >= 520;
              final art = StudyArt(art: p.art, color: color, icon: Icons.menu_book, cacheWidth: 560);
              final body = Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(p.label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ]),
                  const SizedBox(height: 8),
                  Text(p.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(p.text, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 2, children: [for (final r in p.refs) RefChip(r, color: color)]),
                ]),
              );
              return side
                  ? Stack(children: [
                      Positioned(left: 0, top: 0, bottom: 0, width: 168, child: art),
                      Padding(padding: const EdgeInsets.only(left: 168), child: body),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(height: 150, child: art), body]);
            }),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Apresentar'),
              onPressed: () => _present(b, group, name),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            _Backdrop(
              art: b.cover,
              color: color,
              large: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${group.name} · ${n - 39}º livro do Novo Testamento',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
                  const SizedBox(height: 6),
                  Text(b.theme, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    badge('Data', b.date),
                    if (chapters != null) badge('Capítulos', '$chapters'),
                    badge('Partes do guia', '${b.parts.length}'),
                    if (_done) badge('Situação', 'Estudado ✓'),
                  ]),
                ]),
              ),
            ),
            section(
              'Contexto',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                fact(Icons.edit_outlined, 'Autor', b.author),
                fact(Icons.event_outlined, 'Data', b.date),
                fact(Icons.place_outlined, 'De onde', b.from),
                fact(Icons.groups_outlined, 'Para quem', b.to),
                const SizedBox(height: 8),
                Text('Por que foi escrito', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(b.why, style: const TextStyle(fontSize: 16, height: 1.5)),
              ]),
            ),
            section(
              '$name em ${b.parts.length} partes',
              Column(children: [for (var i = 0; i < b.parts.length; i++) part(i)]),
            ),
            section(
              'Versículos-chave',
              Column(children: [
                for (final r in b.keys)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    decoration: BoxDecoration(
                      color: jgGold.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: jgGold.withValues(alpha: 0.55)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (_verseText(bible, r) case final t?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('“$t”', style: const TextStyle(fontSize: 17, height: 1.45, fontFamily: 'serif')),
                        ),
                      RefChip(r, color: color),
                    ]),
                  ),
              ]),
            ),
            section(
              'Lições para hoje',
              Column(children: [
                for (final l in b.lessons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_outline, size: 20, color: color)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l, style: const TextStyle(fontSize: 16, height: 1.45))),
                    ]),
                  ),
              ]),
            ),
            if (b.links.isNotEmpty)
              section(
                'Como $name se liga ao restante da Bíblia',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final l in b.links)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.text, style: const TextStyle(fontSize: 15.5, height: 1.4)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 8, runSpacing: 2, children: [
                          for (final r in l.refs) RefChip(r, color: color),
                          if (l.book != null && g.byNumber.containsKey(l.book))
                            ActionChip(
                              avatar: Icon(Icons.school_outlined, size: 16, color: color),
                              label: Text('Guia de ${_bookName(context, l.book!)}', style: const TextStyle(fontSize: 12.5)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => NtBookScreen(number: l.book!))),
                            ),
                        ]),
                      ]),
                    ),
                ]),
              ),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.tonalIcon(
                icon: Icon(_done ? Icons.check_circle : Icons.radio_button_unchecked),
                label: Text(_done ? 'Estudado (toque para desmarcar)' : 'Marcar como estudado'),
                onPressed: () => NtProgress.set(n, !_done),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Ficha do livro: personagens e acontecimentos'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookSheetScreen(number: n))),
              ),
              if (b.stories.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Histórias ilustradas'),
                  onPressed: () => _stories(b),
                ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              if (n > 40)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: Text(_bookName(context, n - 1), overflow: TextOverflow.ellipsis),
                      onPressed: () => Navigator.of(context)
                          .pushReplacement(MaterialPageRoute(builder: (_) => NtBookScreen(number: n - 1))),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (n < 66)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_bookName(context, n + 1), overflow: TextOverflow.ellipsis),
                      onPressed: () => Navigator.of(context)
                          .pushReplacement(MaterialPageRoute(builder: (_) => NtBookScreen(number: n + 1))),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            Text('Autoria e datas pela posição tradicional, aproximadas. O texto é um guia de estudo: confira tudo na própria Bíblia.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
