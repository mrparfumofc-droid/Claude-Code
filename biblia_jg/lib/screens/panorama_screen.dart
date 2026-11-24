import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bible.dart';
import '../services/panorama.dart';
import '../services/stories.dart' show parseStoryReference;
import '../state/app_state.dart';
import '../theme.dart';
import 'ai_chat_screen.dart';
import 'panorama_diagrams.dart';
import 'panorama_kings.dart';
import 'panorama_tree.dart';

/// Panorama bíblico: quadros visuais de estudo (árvore, reis, profetas e a ficha de cada livro).
class PanoramaScreen extends StatelessWidget {
  const PanoramaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, Color, String, String, Widget)>[
      (Icons.route, const Color(0xFFEF6C00), 'Linha do tempo da Bíblia',
          'Da criação à igreja primitiva em onze épocas', const BibleTimelineScreen()),
      (Icons.account_tree, const Color(0xFF1B2A4A), 'A família de Abraão',
          'De Abraão às doze tribos, com apresentação passo a passo', const FamilyTreeScreen()),
      (Icons.timeline, const Color(0xFF2E7D32), 'Reis de Israel e Judá',
          'Linha do tempo dos dois reinos, do rei Saul ao exílio', const KingsScreen()),
      (Icons.campaign, const Color(0xFFC0392B), 'Os profetas e suas missões',
          'Quando falaram, para quem e qual foi a mensagem', const ProphetsScreen()),
      (Icons.holiday_village, const Color(0xFF8D6E63), 'O tabernáculo',
          'A tenda de Deus vista de cima: cada peça e o que ela anuncia', const TabernacleScreen()),
      (Icons.grid_view_rounded, const Color(0xFF1E88E5), 'Os 66 livros',
          'A ficha de cada livro: autor, data, personagens e acontecimentos', const BooksPanoramaScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Panorama bíblico')),
      body: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 720 ? 2 : 1;
        return GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: cols == 2 ? 2.9 : 2.6,
          children: [
            for (final (icon, color, title, subtitle, page) in items)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: color,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
                    child: Stack(children: [
                      Positioned(right: -18, bottom: -22, child: Icon(icon, size: 150, color: Colors.white.withValues(alpha: 0.10))),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          CircleAvatar(backgroundColor: Colors.white24, child: Icon(icon, color: Colors.white)),
                          const Spacer(),
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
                          const SizedBox(height: 4),
                          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// ======================================================================
// Profetas
// ======================================================================

const _periods = <(String, String, String, Color)>[
  ('pre', 'Antes do exílio', 'Avisos a Israel, a Judá e às nações', Color(0xFFC0392B)),
  ('exilio', 'No exílio', 'Entre os cativos na Babilônia', Color(0xFF6A1B9A)),
  ('pos', 'Depois do exílio', 'Aos que voltaram para Jerusalém', Color(0xFF00897B)),
];

class ProphetsScreen extends StatefulWidget {
  const ProphetsScreen({super.key});

  @override
  State<ProphetsScreen> createState() => _ProphetsScreenState();
}

class _ProphetsScreenState extends State<ProphetsScreen> {
  List<Prophet>? _all;
  String _filter = 'Todos';

  @override
  void initState() {
    super.initState();
    PanoramaData.load().then((d) {
      if (mounted) setState(() => _all = d.prophets);
    });
  }

  bool _matches(Prophet p) => switch (_filter) {
        'Todos' => true,
        'Nações' => p.audience.any((a) => a != 'Israel' && a != 'Judá' && a != 'Exilados'),
        _ => p.audience.contains(_filter),
      };

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final theme = Theme.of(context);
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Os profetas e suas missões')),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final cardW = box.maxWidth >= 1000
                  ? (box.maxWidth - 32 - 24) / 3
                  : (box.maxWidth >= 640 ? (box.maxWidth - 32 - 12) / 2 : box.maxWidth - 32);
              return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Text('Os dezesseis profetas que deixaram livros, em ordem de tempo. As datas são aproximadas.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final f in const ['Todos', 'Israel', 'Judá', 'Nações', 'Exilados'])
                    ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
                ]),
                for (final (id, title, subtitle, color) in _periods)
                  if (all.any((p) => p.period == id && _matches(p))) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(width: 6, height: 38, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final p in all.where((p) => p.period == id && _matches(p)))
                        SizedBox(
                          width: cardW,
                          child: Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: double.infinity,
                                color: color,
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(p.name,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                                  ),
                                  Text(p.date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Wrap(spacing: 6, runSpacing: 4, children: [
                                    for (final a in p.audience)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                                        child: Text('Para $a', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text(p.message, style: const TextStyle(fontSize: 15, height: 1.4)),
                                  const SizedBox(height: 6),
                                  Text('Reis da época: ${p.kings}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  Row(children: [
                                    RefChip(p.ref, color: color),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => BookSheetScreen(number: p.book + 1))),
                                      child: Text('Ficha de ${app.bible?.books[p.book].name ?? canonicalBooks[p.book].name}'),
                                    ),
                                  ]),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                    ]),
                  ],
              ]);
            }),
    );
  }
}

// ======================================================================
// Os 66 livros
// ======================================================================

class BooksPanoramaScreen extends StatefulWidget {
  const BooksPanoramaScreen({super.key});

  @override
  State<BooksPanoramaScreen> createState() => _BooksPanoramaScreenState();
}

class _BooksPanoramaScreenState extends State<BooksPanoramaScreen> {
  PanoramaData? _data;

  @override
  void initState() {
    super.initState();
    PanoramaData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final theme = Theme.of(context);
    final bible = context.watch<AppState>().bible;
    return Scaffold(
      appBar: AppBar(title: const Text('Os 66 livros')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              Text('Toque num livro para ver a ficha: quem escreveu, quando, o tema, os personagens e os acontecimentos.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              for (final g in d.groups) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 8),
                  Text(g.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('${g.to - g.from + 1} ${g.to == g.from ? 'livro' : 'livros'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var n = g.from; n <= g.to; n++)
                    SizedBox(
                      width: 104,
                      height: 78,
                      child: Material(
                        color: g.color,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookSheetScreen(number: n))),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$nº', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(_abbrev(n),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.05)),
                              Text(bible != null && n - 1 < bible.books.length ? bible.books[n - 1].name : canonicalBooks[n - 1].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
              ],
            ]),
    );
  }
}

String _abbrev(int n) {
  final a = canonicalBooks[n - 1].abbrev;
  // "1sm" -> "1Sm", "gn" -> "Gn".
  final i = a.indexOf(RegExp(r'[^0-9]'));
  return i < 0 ? a : a.substring(0, i) + a[i].toUpperCase() + a.substring(i + 1);
}

/// Ficha de um livro (número 1..66).
class BookSheetScreen extends StatefulWidget {
  final int number;
  const BookSheetScreen({super.key, required this.number});

  @override
  State<BookSheetScreen> createState() => _BookSheetScreenState();
}

class _BookSheetScreenState extends State<BookSheetScreen> {
  PanoramaData? _data;

  @override
  void initState() {
    super.initState();
    PanoramaData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  String? _keyText(Bible? bible, String ref) {
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

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final n = widget.number;
    final app = context.watch<AppState>();
    final bible = app.bible;
    final theme = Theme.of(context);
    final name = bible != null && n - 1 < bible.books.length ? bible.books[n - 1].name : canonicalBooks[n - 1].name;
    if (d == null) {
      return Scaffold(appBar: AppBar(title: Text(name)), body: const Center(child: CircularProgressIndicator()));
    }
    final sheet = d.books[n];
    final group = d.groupOf(n);
    final chapters = bible != null && n - 1 < bible.books.length ? bible.books[n - 1].chapters : null;
    final verses = chapters?.fold<int>(0, (s, c) => s + c.length);

    Widget badge(String label, String value) => Container(
          constraints: const BoxConstraints(minWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        );

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 5, height: 20, decoration: BoxDecoration(color: group.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        );

    final keyText = sheet == null ? null : _keyText(bible, sheet.key);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
            // Cabeçalho colorido com os números do livro.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [group.color, Color.lerp(group.color, const Color(0xFF0E1626), 0.45)!],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$nº livro · ${group.name} · ${n <= 39 ? 'Antigo' : 'Novo'} Testamento',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
                if (sheet != null) ...[
                  const SizedBox(height: 4),
                  Text(sheet.theme, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3)),
                ],
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (chapters != null) badge('Capítulos', '${chapters.length}'),
                  if (verses != null) badge('Versículos', '$verses'),
                  if (sheet != null) badge('Autor', sheet.author),
                  if (sheet != null) badge('Data', sheet.date),
                ]),
                if (sheet != null && sheet.authorNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Autoria: ${sheet.authorNote}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ]),
            ),
            if (sheet == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('A ficha deste livro ainda está sendo preparada.', textAlign: TextAlign.center),
              )
            else ...[
              section('Resumo', Text(sheet.summary, style: const TextStyle(fontSize: 16, height: 1.45))),
              section(
                'Versículo-chave',
                Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openPanoramaRef(context, sheet.key),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (keyText != null)
                          Text('“$keyText”',
                              style: const TextStyle(fontSize: 17, height: 1.4, fontStyle: FontStyle.italic, fontFamily: 'serif')),
                        const SizedBox(height: 6),
                        Text('${sheet.key}${bible == null ? '' : ' · ${bible.abbrev}'}',
                            style: TextStyle(color: group.color, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
              section(
                'Principais personagens',
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final (who, note) in sheet.people)
                    Container(
                      width: 270,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: group.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: group.color.withValues(alpha: 0.35)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: group.color,
                          child: Text(who.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(who, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(note, style: theme.textTheme.bodySmall?.copyWith(height: 1.3)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),
              section(
                sheet.narrative ? 'Principais acontecimentos' : 'Principais assuntos',
                Column(children: [
                  for (var i = 0; i < sheet.events.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => openPanoramaRef(context, sheet.events[i].$2),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: group.color,
                                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(sheet.events[i].$1, style: const TextStyle(fontSize: 15.5))),
                              const SizedBox(width: 8),
                              Text(sheet.events[i].$2, style: TextStyle(color: group.color, fontWeight: FontWeight.w700, fontSize: 13)),
                              Icon(Icons.chevron_right, color: group.color, size: 20),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              section(
                'Cristo neste livro',
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: jgGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: jgGold.withValues(alpha: 0.6)),
                  ),
                  child: Text(sheet.christ, style: const TextStyle(fontSize: 16, height: 1.4)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.menu_book),
                label: Text('Ler $name'),
                onPressed: () {
                  context.read<AppState>().openAt(n - 1, 1);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Perguntar à IA sobre este livro'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AiChatScreen(
                    title: 'Sobre $name',
                    task: 'chat',
                    reference: 'Livro de $name',
                    version: bible?.abbrev,
                    cacheKey: 'intro_${n - 1}',
                    initialPrompt:
                        'Faça uma introdução simples ao livro de $name, em linguagem fácil: quem escreveu, quando e para quem; '
                        'o tema central; os assuntos principais em tópicos; onde ele se encaixa na história da Bíblia; '
                        'e uma dica de como ler. No máximo 250 palavras.',
                  ),
                )),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Autor e data seguem a visão tradicional e são aproximados. Capítulos e versículos são contados na versão aberta.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
