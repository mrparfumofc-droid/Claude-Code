import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../models/bible.dart';
import '../models/daily.dart';
import '../models/reference_parser.dart';
import '../state/app_state.dart';

/// Intervalo até a próxima revisão, por nível (repetição espaçada).
const memoryIntervals = [0, 1, 3, 7, 14, 30];

DateTime nextReview(int level) =>
    DateTime.now().add(Duration(days: memoryIntervals[level.clamp(0, memoryIntervals.length - 1)]));

/// Esconde parte das palavras conforme o nível: quanto maior, mais palavras somem.
/// Retorna (palavra, escondida).
List<(String, bool)> maskWords(String text, int level) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // nível 0: 1 em cada 4; 1: 1 em cada 3; 2: metade; 3: 2 em cada 3; 4+: tudo.
  bool hide(int i) => switch (level) {
        <= 0 => i % 4 == 3,
        1 => i % 3 == 2,
        2 => i.isOdd,
        3 => i % 3 != 0,
        _ => true,
      };
  return [for (var i = 0; i < words.length; i++) (words[i], hide(i) && words[i].length > 2)];
}

/// Memorização de versículos com repetição espaçada.
class MemorizeScreen extends StatefulWidget {
  const MemorizeScreen({super.key});

  @override
  State<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
  List<MemoryVerse>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await context.read<AppState>().db.memoryVerses();
    if (mounted) setState(() => _list = l);
  }

  Future<void> _addByReference() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar versículo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: João 3:16', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Adicionar')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.trim().isEmpty) return;
    final p = parseReference(text);
    if (p == null || p.verse == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Não entendi. Escreva como: João 3:16')));
      return;
    }
    await app.db.addMemory(VerseRef(p.book, p.chapter, p.verse!));
    await _load();
  }

  Future<void> _addFavorites() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final favs = await app.db.allFavorites();
    final have = {for (final m in _list ?? const <MemoryVerse>[]) m.ref.key};
    var n = 0;
    for (final f in favs) {
      if (have.add(f.key)) {
        await app.db.addMemory(f);
        n++;
      }
    }
    messenger.showSnackBar(SnackBar(
        content: Text(n == 0 ? 'Seus favoritos já estão aqui (ou você ainda não tem favoritos).' : '$n versículo(s) adicionados')));
    await _load();
  }

  Future<void> _practice(List<MemoryVerse> queue) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PracticeScreen(queue: queue)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    final list = _list;
    final now = DateTime.now();
    final due = list?.where((m) => !m.due.isAfter(now)).toList() ?? const <MemoryVerse>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorização'),
        actions: [
          IconButton(tooltip: 'Adicionar meus favoritos', icon: const Icon(Icons.bookmark_add_outlined), onPressed: _addFavorites),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addByReference,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar versículo'),
      ),
      body: list == null || bible == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const Icon(Icons.psychology_alt_outlined, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            list.isEmpty
                                ? 'Guarde a Palavra no coração. Adicione um versículo e pratique um pouco por dia: o app vai escondendo as palavras aos poucos.'
                                : due.isEmpty
                                    ? 'Tudo em dia! Nenhum versículo para revisar agora.'
                                    : '${due.length} versículo(s) para revisar hoje.',
                          ),
                        ),
                        if (due.isNotEmpty) FilledButton(onPressed: () => _practice(due), child: const Text('Praticar')),
                      ]),
                    ),
                  ),
                  for (final m in list)
                    Card(
                      child: ListTile(
                        title: Text(m.ref.label(bible), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${verseText(bible, m.ref) ?? ''}\n'
                          '${m.due.isAfter(now) ? 'Próxima revisão em ${m.due.difference(now).inDays + 1} dia(s)' : 'Revisar hoje'} · nível ${m.level + 1} de ${memoryIntervals.length}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Remover',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await app.db.removeMemory(m.ref);
                            await _load();
                          },
                        ),
                        onTap: () => _practice([m]),
                      ),
                    ),
                ]),
              ),
            ),
    );
  }
}

class _PracticeScreen extends StatefulWidget {
  final List<MemoryVerse> queue;
  const _PracticeScreen({required this.queue});

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen> {
  int _i = 0;
  final Set<int> _revealed = {};
  bool _showAll = false;

  bool _rating = false;

  Future<void> _rate(bool remembered) async {
    if (_rating) return; // evita toque duplo pular um versículo
    _rating = true;
    try {
      await _rateNow(remembered);
    } finally {
      _rating = false;
    }
  }

  Future<void> _rateNow(bool remembered) async {
    final app = context.read<AppState>();
    final m = widget.queue[_i];
    final level = remembered ? (m.level + 1).clamp(0, memoryIntervals.length - 1) : (m.level - 1).clamp(0, 5);
    await app.db.setMemory(m.ref, level, remembered ? nextReview(level) : DateTime.now());
    if (!mounted) return;
    if (_i < widget.queue.length - 1) {
      setState(() {
        _i++;
        _revealed.clear();
        _showAll = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible!;
    final m = widget.queue[_i];
    final text = verseText(bible, m.ref) ?? '';
    final words = maskWords(text, m.level);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${m.ref.label(bible)} · ${_i + 1}/${widget.queue.length}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text('Tente dizer o versículo em voz alta. Toque nas lacunas para conferir.',
                  style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(spacing: 8, runSpacing: 12, alignment: WrapAlignment.center, children: [
                    for (var k = 0; k < words.length; k++)
                      if (!words[k].$2 || _showAll || _revealed.contains(k))
                        Text(words[k].$1,
                            style: TextStyle(
                                fontSize: 26,
                                fontFamily: app.settings.fontFamily,
                                color: words[k].$2 ? theme.colorScheme.primary : null))
                      else
                        GestureDetector(
                          onTap: () => setState(() => _revealed.add(k)),
                          child: Container(
                            width: 14.0 * words[k].$1.length.clamp(3, 12),
                            height: 34,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 2)),
                            ),
                          ),
                        ),
                  ]),
                ),
              ),
              if (!_showAll)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Mostrar o versículo inteiro'),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rate(false),
                    icon: const Icon(Icons.replay),
                    label: const Text('Ainda não'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _rate(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Lembrei'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
