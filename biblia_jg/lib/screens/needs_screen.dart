import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bible.dart';
import '../state/app_state.dart';
import 'verse_image_screen.dart';

/// Um tema de "Palavra para o momento": versículos escolhidos para uma necessidade.
class Need {
  final String name;
  final IconData icon;
  final Color color;

  /// Trechos: [livro 0..65, capítulo, versículo inicial, versículo final].
  final List<List<int>> refs;
  const Need(this.name, this.icon, this.color, this.refs);
}

const needs = <Need>[
  Need('Ansiedade', Icons.air, Color(0xFF5C6BC0), [[49, 4, 6, 7], [59, 5, 7, 7], [39, 6, 33, 34], [18, 94, 19, 19], [22, 26, 3, 3], [42, 14, 27, 27]]),
  Need('Medo', Icons.shield_outlined, Color(0xFF455A64), [[22, 41, 10, 10], [18, 27, 1, 1], [54, 1, 7, 7], [5, 1, 9, 9], [18, 56, 3, 4], [18, 23, 4, 4]]),
  Need('Tristeza e luto', Icons.water_drop_outlined, Color(0xFF1976D2), [[18, 34, 18, 18], [39, 5, 4, 4], [65, 21, 4, 4], [18, 30, 5, 5], [46, 1, 3, 4], [42, 11, 25, 26]]),
  Need('Cansaço', Icons.battery_2_bar, Color(0xFF00897B), [[39, 11, 28, 30], [22, 40, 29, 31], [18, 23, 1, 3], [47, 6, 9, 9], [46, 12, 9, 9]]),
  Need('Solidão', Icons.person_outline, Color(0xFF6D4C41), [[4, 31, 8, 8], [57, 13, 5, 5], [18, 139, 7, 10], [39, 28, 20, 20], [22, 49, 15, 16]]),
  Need('Culpa e perdão', Icons.healing, Color(0xFF8E24AA), [[61, 1, 9, 9], [44, 8, 1, 1], [18, 103, 10, 12], [22, 1, 18, 18], [32, 7, 18, 19], [18, 51, 10, 10]]),
  Need('Decisões', Icons.alt_route, Color(0xFFEF6C00), [[19, 3, 5, 6], [58, 1, 5, 5], [18, 32, 8, 8], [22, 30, 21, 21], [18, 119, 105, 105], [23, 29, 11, 11]]),
  Need('Finanças', Icons.savings_outlined, Color(0xFF2E7D32), [[49, 4, 19, 19], [39, 6, 31, 33], [18, 37, 25, 25], [57, 13, 5, 6], [19, 3, 9, 10]]),
  Need('Doença', Icons.local_hospital_outlined, Color(0xFFC62828), [[22, 53, 4, 5], [18, 103, 2, 3], [58, 5, 14, 15], [23, 17, 14, 14], [18, 41, 3, 3], [1, 15, 26, 26]]),
  Need('Tentação', Icons.gpp_maybe_outlined, Color(0xFF37474F), [[45, 10, 13, 13], [58, 4, 7, 7], [57, 4, 15, 16], [18, 119, 11, 11], [39, 26, 41, 41], [47, 5, 16, 16]]),
  Need('Gratidão', Icons.celebration_outlined, Color(0xFFF9A825), [[18, 100, 4, 5], [51, 5, 16, 18], [18, 118, 24, 24], [15, 8, 10, 10], [49, 4, 4, 4], [18, 103, 1, 2]]),
  Need('Fé e esperança', Icons.wb_twilight, Color(0xFFD81B60), [[57, 11, 1, 1], [44, 8, 28, 28], [24, 3, 22, 23], [44, 15, 13, 13], [18, 46, 1, 1], [40, 9, 23, 23]]),
  Need('Família', Icons.family_restroom, Color(0xFF00838F), [[5, 24, 15, 15], [48, 5, 25, 25], [19, 22, 6, 6], [18, 127, 1, 1], [50, 3, 13, 14], [45, 13, 4, 7]]),
  Need('Raiva e conflito', Icons.local_fire_department_outlined, Color(0xFFBF360C), [[48, 4, 26, 27], [19, 15, 1, 1], [58, 1, 19, 20], [44, 12, 18, 19], [39, 5, 9, 9]]),
  Need('Salvação', Icons.favorite_border, Color(0xFFAD1457), [[42, 3, 16, 16], [44, 10, 9, 10], [48, 2, 8, 9], [43, 4, 12, 12], [42, 14, 6, 6], [44, 6, 23, 23]]),
];

/// Texto de um trecho [livro, cap, v1, v2] na versão aberta (sem marcações).
String? passageText(Bible bible, List<int> r) {
  if (r[0] >= bible.books.length) return null;
  final book = bible.books[r[0]];
  if (r[1] < 1 || r[1] > book.chapters.length) return null;
  final verses = book.chapters[r[1] - 1];
  final out = <String>[];
  for (var v = r[2]; v <= r[3] && v <= verses.length; v++) {
    out.add(plainVerse(verses[v - 1]).trim());
  }
  return out.isEmpty ? null : out.join(' ');
}

String passageLabel(Bible bible, List<int> r) {
  final name = r[0] < bible.books.length ? bible.books[r[0]].name : canonicalBooks[r[0]].name;
  return r[2] == r[3] ? '$name ${r[1]}:${r[2]}' : '$name ${r[1]}:${r[2]}-${r[3]}';
}

/// "Palavra para o momento": versículos por necessidade (ansiedade, medo, luto…).
class NeedsScreen extends StatefulWidget {
  final int initial;
  const NeedsScreen({super.key, this.initial = 0});

  @override
  State<NeedsScreen> createState() => _NeedsScreenState();
}

class _NeedsScreenState extends State<NeedsScreen> {
  late int _i = widget.initial.clamp(0, needs.length - 1);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    final need = needs[_i];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Palavra para o momento')),
      body: bible == null
          ? const Center(child: Text('Instale uma versão da Bíblia primeiro.'))
          : Column(children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (var k = 0; k < needs.length; k++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(needs[k].icon, size: 18, color: _i == k ? null : needs[k].color),
                          label: Text(needs[k].name),
                          selected: _i == k,
                          onSelected: (_) => setState(() => _i = k),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                      for (final r in need.refs)
                        if (passageText(bible, r) case final text?)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            child: Container(
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: need.color, width: 5))),
                              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('“$text”',
                                    style: TextStyle(
                                        fontSize: 19, height: 1.45, fontFamily: app.settings.fontFamily)),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                    child: Text('${passageLabel(bible, r)} · ${bible.abbrev}',
                                        style: theme.textTheme.labelLarge?.copyWith(color: need.color)),
                                  ),
                                  IconButton(
                                    tooltip: 'Ler no contexto',
                                    icon: const Icon(Icons.menu_book_outlined),
                                    onPressed: () {
                                      app.openAt(r[0], r[1], verse: r[2]);
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Memorizar',
                                    icon: const Icon(Icons.psychology_alt_outlined),
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      await app.db.addMemory(VerseRef(r[0], r[1], r[2]));
                                      messenger.showSnackBar(
                                          const SnackBar(content: Text('Adicionado à memorização')));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Criar imagem',
                                    icon: const Icon(Icons.image_outlined),
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => VerseImageScreen(
                                            text: text, reference: '${passageLabel(bible, r)} (${bible.abbrev})'))),
                                  ),
                                  IconButton(
                                    tooltip: 'Copiar',
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: '“$text” — ${passageLabel(bible, r)} (${bible.abbrev})'));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(content: Text('Copiado')));
                                    },
                                  ),
                                ]),
                              ]),
                            ),
                          ),
                    ]),
                  ),
                ),
              ),
            ]),
    );
  }
}
