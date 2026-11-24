import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible.dart';
import '../state/app_state.dart';

/// Leitura de um dia: capítulos (livro 0..65, capítulo).
typedef DayReading = List<(int, int)>;

class ReadingPlan {
  final String id;
  final String name;
  final String description;
  final int days;
  final List<int> books; // índices dos livros, na ordem
  const ReadingPlan(this.id, this.name, this.description, this.days, this.books);

  /// Distribui os capítulos dos [books] em [days] dias de forma equilibrada.
  List<DayReading> schedule(Bible bible) {
    final chapters = <(int, int)>[
      for (final b in books)
        if (b < bible.books.length)
          for (var c = 1; c <= bible.books[b].chapters.length; c++) (b, c),
    ];
    final out = <DayReading>[];
    for (var d = 0; d < days; d++) {
      final start = (chapters.length * d / days).round();
      final end = (chapters.length * (d + 1) / days).round();
      out.add(chapters.sublist(start, end));
    }
    return out;
  }
}

List<int> _range(int a, int b) => [for (var i = a; i <= b; i++) i];

final readingPlans = <ReadingPlan>[
  ReadingPlan('marcos16', 'Comece por Marcos', 'Para quem está começando: o Evangelho mais curto, 1 capítulo por dia (16 dias).', 16, [40]),
  ReadingPlan('joao21', 'Evangelho de João em 21 dias', 'Conheça Jesus de perto: 1 capítulo por dia.', 21, [42]),
  ReadingPlan('proverbios31', 'Provérbios em 31 dias', 'Um capítulo de sabedoria por dia.', 31, [19]),
  ReadingPlan('atos28', 'Atos em 28 dias', 'O começo da igreja: 1 capítulo por dia.', 28, [43]),
  ReadingPlan('biblia365', 'Bíblia em 1 ano', 'Toda a Bíblia, de Gênesis a Apocalipse, em 365 dias.', 365, _range(0, 65)),
  ReadingPlan('biblia180', 'Bíblia em 6 meses', 'Toda a Bíblia em 180 dias (cerca de 7 capítulos por dia).', 180, _range(0, 65)),
  ReadingPlan('nt90', 'Novo Testamento em 90 dias', 'De Mateus a Apocalipse em 3 meses.', 90, _range(39, 65)),
  ReadingPlan('at270', 'Antigo Testamento em 9 meses', 'De Gênesis a Malaquias em 270 dias.', 270, _range(0, 38)),
  ReadingPlan('evangelhos30', 'Os 4 Evangelhos em 30 dias', 'Mateus, Marcos, Lucas e João.', 30, [39, 40, 41, 42]),
  ReadingPlan('salmos-proverbios60', 'Salmos e Provérbios em 60 dias', 'Oração e sabedoria para o dia a dia.', 60, [18, 19]),
  ReadingPlan('paulo60', 'Cartas de Paulo em 60 dias', 'De Romanos a Filemom.', 60, _range(44, 56)),
  ReadingPlan('pentateuco60', 'Pentateuco em 60 dias', 'Os cinco livros de Moisés.', 60, _range(0, 4)),
  ReadingPlan('profetas90', 'Profetas em 90 dias', 'De Isaías a Malaquias.', 90, _range(22, 38)),
];

/// Progresso do plano guardado no aparelho.
class PlanProgress {
  final String planId;
  final DateTime start;
  final Set<int> done; // dias concluídos (0..)
  PlanProgress(this.planId, this.start, this.done);

  int get todayIndex => DateTime.now().difference(DateTime(start.year, start.month, start.day)).inDays;

  /// Próximo dia ainda não lido (plano flexível: sem atraso, continua de onde parou).
  int nextDay(int days) {
    for (var d = 0; d < days; d++) {
      if (!done.contains(d)) return d;
    }
    return days - 1;
  }

  bool finished(int days) => done.length >= days;

  int get streak {
    var s = 0;
    for (var d = todayIndex; d >= 0; d--) {
      if (done.contains(d)) {
        s++;
      } else if (d != todayIndex) {
        break;
      }
    }
    return s;
  }

  static Future<PlanProgress?> load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('plan_id');
    final start = p.getString('plan_start');
    if (id == null || start == null) return null;
    return PlanProgress(id, DateTime.parse(start),
        (p.getStringList('plan_done') ?? const []).map(int.parse).toSet());
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('plan_id', planId);
    await p.setString('plan_start', start.toIso8601String());
    await p.setStringList('plan_done', done.map((e) => '$e').toList());
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('plan_id');
    await p.remove('plan_start');
    await p.remove('plan_done');
  }
}

class ReadingPlansScreen extends StatefulWidget {
  const ReadingPlansScreen({super.key});

  @override
  State<ReadingPlansScreen> createState() => _ReadingPlansScreenState();
}

class _ReadingPlansScreenState extends State<ReadingPlansScreen> {
  PlanProgress? _progress;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    PlanProgress.load().then((p) => setState(() {
          _progress = p;
          _loaded = true;
        }));
  }

  Future<void> _startPlan(ReadingPlan plan) async {
    final p = PlanProgress(plan.id, DateTime.now(), {});
    await p.save();
    setState(() => _progress = p);
  }

  Future<void> _toggleDay(int day) async {
    final p = _progress!;
    if (!p.done.remove(day)) p.done.add(day);
    await p.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bible = app.bible;
    if (!_loaded || bible == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Planos de leitura')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final progress = _progress;
    final plan = progress == null ? null : readingPlans.where((p) => p.id == progress.planId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Planos de leitura'), actions: [
        if (plan != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).appBarTheme.foregroundColor),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Trocar de plano?'),
                  content: const Text('O progresso do plano atual será apagado.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trocar')),
                  ],
                ),
              );
              if (ok != true) return;
              await PlanProgress.clear();
              if (mounted) setState(() => _progress = null);
            },
            child: const Text('Trocar plano'),
          ),
      ]),
      body: plan == null || progress == null ? _choose() : _active(app, bible, plan, progress),
    );
  }

  Widget _choose() => ListView(padding: const EdgeInsets.all(12), children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Escolha um plano. Não tem data marcada: você lê no seu ritmo e continua de onde parou, sem atraso.'),
        ),
        for (final p in readingPlans)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${p.days}')),
              title: Text(p.name),
              subtitle: Text(p.description),
              trailing: FilledButton(onPressed: () => _startPlan(p), child: const Text('Começar')),
            ),
          ),
      ]);

  Widget _active(AppState app, Bible bible, ReadingPlan plan, PlanProgress progress) {
    final schedule = plan.schedule(bible);
    final today = progress.nextDay(plan.days);
    final pct = progress.done.length / plan.days;
    String label(DayReading r) {
      if (r.isEmpty) return '—';
      final parts = <String>[];
      var i = 0;
      while (i < r.length) {
        var j = i;
        while (j + 1 < r.length && r[j + 1].$1 == r[i].$1 && r[j + 1].$2 == r[j].$2 + 1) {
          j++;
        }
        final name = bible.books[r[i].$1].name;
        parts.add(i == j ? '$name ${r[i].$2}' : '$name ${r[i].$2}–${r[j].$2}');
        i = j + 1;
      }
      return parts.join('; ');
    }

    return ListView.builder(
      itemCount: plan.days + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: pct, minHeight: 8),
                const SizedBox(height: 8),
                Text('${progress.done.length} de ${plan.days} dias · ${(pct * 100).toStringAsFixed(0)}%'),
                Text(progress.finished(plan.days)
                    ? 'Plano concluído. Glória a Deus!'
                    : 'No seu ritmo: sem atraso, continue de onde parou.'),
                const SizedBox(height: 12),
                Text('Próxima leitura (dia ${today + 1}): ${label(schedule[today])}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (b, c) in schedule[today])
                    ActionChip(
                      avatar: Icon(
                          app.readChapters.contains('$b:$c') ? Icons.check_circle : Icons.menu_book,
                          size: 18),
                      label: Text('${bible.books[b].name} $c'),
                      onPressed: () {
                        app.openAt(b, c);
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _toggleDay(today),
                  icon: Icon(progress.done.contains(today) ? Icons.undo : Icons.check),
                  label: Text(progress.done.contains(today) ? 'Desmarcar' : 'Concluir esta leitura'),
                ),
              ]),
            ),
          );
        }
        final d = i - 1;
        return CheckboxListTile(
          value: progress.done.contains(d),
          onChanged: (_) => _toggleDay(d),
          title: Text('Dia ${d + 1}${d == today && !progress.done.contains(d) ? ' · próxima' : ''}'),
          subtitle: Text(label(schedule[d])),
          selected: d == today,
        );
      },
    );
  }
}
