import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily.dart';
import '../services/account_service.dart';
import '../services/ai_service.dart' show supabaseUrl;
import '../state/app_state.dart';
import '../theme.dart';
import 'content_screens.dart';
import 'memorize_screen.dart';
import 'needs_screen.dart';
import 'prayer_screen.dart';
import 'reading_plans_screen.dart';
import 'verse_image_screen.dart';

const _weekdays = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
const _months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
const _heroPhotos = ['campos-03.jpg', 'montanhas-02.jpg', 'agua-04.jpg', 'por-do-sol-01.jpg', 'campos-09.jpg', 'agua-07.jpg', 'montanhas-09.jpg'];

/// Tela inicial: o que fazer hoje (continuar a leitura, meta, plano, versículo, oração).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  /// Desligado nos testes de tela (o banco de dados real não roda no relógio falso).
  static bool loadData = true;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  PlanProgress? _plan;
  int _prayers = 0;
  int _memoryDue = 0;
  int _revision = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!TodayScreen.loadData) return;
    final app = context.read<AppState>();
    try {
      final plan = await PlanProgress.load();
      final prayers = (await app.db.prayers()).where((p) => p.answered == null).length;
      final now = DateTime.now();
      final due = (await app.db.memoryVerses()).where((m) => !m.due.isAfter(now)).length;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _prayers = prayers;
        _memoryDue = due;
      });
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _startPlan(String id) async {
    await PlanProgress(id, DateTime.now(), {}).save();
    await _load();
  }

  Future<void> _pickGoal(AppState app) async {
    final m = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Meta de leitura por dia'),
        children: [
          for (final v in const [5, 10, 15, 20, 30, 45, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, v),
              child: Text('$v minutos${v == app.goalMinutes ? '  ✓' : ''}'),
            ),
        ],
      ),
    );
    if (m != null) await app.setGoalMinutes(m);
  }

  Widget _card({required Widget child, Color? color, EdgeInsets padding = const EdgeInsets.all(18), VoidCallback? onTap}) => Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );

  Widget _title(IconData icon, String text, {Color? color}) => Row(children: [
        Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final account = context.watch<AccountService>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (_revision != app.userDataRevision) {
      _revision = app.userDataRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final bible = app.bible;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Bom dia' : (now.hour < 18 ? 'Boa tarde' : 'Boa noite');
    final first = (account.name ?? '').trim().split(' ').first;
    final date = '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}';

    final (chaptersToday, secondsToday) = app.todayActivity;
    final minutes = secondsToday ~/ 60;
    final goal = app.goalMinutes;
    final streak = app.streak;
    final totalRead = app.readChapters.length;

    final vod = verseOfDay(now);
    final vodText = bible == null ? null : verseText(bible, vod);
    final book = app.currentBook;

    final plan = _plan == null ? null : readingPlans.where((p) => p.id == _plan!.planId).firstOrNull;
    final isNew = totalRead == 0 && plan == null;

    // ---------- Cartões ----------
    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 250,
        child: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF14233F), Color(0xFF3A2A12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          Image.network(
            '$supabaseUrl/storage/v1/object/public/fundos/${_heroPhotos[now.weekday - 1]}',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0x99000000), Color(0x33000000), Color(0xD9000000)],
                  stops: [0, 0.35, 1],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VERSÍCULO DO DIA',
                  style: TextStyle(color: jgGold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
              const Spacer(),
              Text(
                vodText == null ? 'Instale uma versão da Bíblia para começar.' : '“$vodText”',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.35, fontFamily: 'serif', shadows: [Shadow(blurRadius: 8)]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(bible == null ? '' : '${vod.label(bible)} · ${bible.abbrev}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                if (vodText != null) ...[
                  IconButton(
                    tooltip: 'Ler no contexto',
                    color: Colors.white,
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => app.openAt(vod.book, vod.chapter, verse: vod.verse),
                  ),
                  IconButton(
                    tooltip: 'Criar imagem para compartilhar',
                    color: Colors.white,
                    icon: const Icon(Icons.ios_share),
                    onPressed: () =>
                        _open(VerseImageScreen(text: vodText, reference: '${vod.label(bible)} (${bible!.abbrev})')),
                  ),
                  IconButton(
                    tooltip: 'Memorizar',
                    color: Colors.white,
                    icon: const Icon(Icons.psychology_alt_outlined),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await app.db.addMemory(vod);
                      messenger.showSnackBar(const SnackBar(content: Text('Adicionado à memorização')));
                      _load();
                    },
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );

    final continueCard = _card(
      color: cs.primaryContainer,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.auto_stories, isNew ? 'Comece a ler' : 'Continuar leitura'),
        const SizedBox(height: 10),
        Text(book == null ? '—' : '${book.name} ${app.chapter}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(app.chapterRead ? 'Capítulo já lido: siga para o próximo' : 'Você parou aqui',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: bible == null
                ? null
                : () async {
                    if (app.chapterRead) await app.nextChapter();
                    app.requestTab(1);
                  },
            icon: const Icon(Icons.play_arrow),
            label: Text(app.chapterRead ? 'Ler o próximo' : 'Ler agora'),
          ),
          OutlinedButton.icon(
            onPressed: bible == null
                ? null
                : () async {
                    if (app.chapterRead) await app.nextChapter();
                    app.requestTab(1, focus: true);
                  },
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Sessão de 5 minutos'),
          ),
        ]),
      ]),
    );

    final goalCard = _card(
      onTap: () => _pickGoal(app),
      child: Row(children: [
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                value: (minutes / goal).clamp(0.0, 1.0),
                strokeWidth: 8,
                backgroundColor: cs.surfaceContainerHighest,
                color: minutes >= goal ? Colors.green : jgGold,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$minutes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('de $goal min', style: theme.textTheme.labelSmall),
            ]),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title(Icons.local_fire_department, streak == 0 ? 'Comece sua sequência hoje' : '$streak dia${streak == 1 ? '' : 's'} seguido${streak == 1 ? '' : 's'}',
                color: Colors.deepOrange),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 6; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: app.activeOn(now.subtract(Duration(days: i))) ? jgGold : cs.surfaceContainerHighest,
                      ),
                      child: app.activeOn(now.subtract(Duration(days: i)))
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    Text(_weekdays[now.subtract(Duration(days: i)).weekday - 1].substring(0, 1).toUpperCase(),
                        style: theme.textTheme.labelSmall),
                  ]),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              '$chaptersToday capítulo${chaptersToday == 1 ? '' : 's'} hoje · $totalRead de 1.189 lidos · toque para mudar a meta',
              style: theme.textTheme.bodySmall,
            ),
          ]),
        ),
      ]),
    );

    Widget planCard;
    if (plan != null && bible != null) {
      final progress = _plan!;
      final day = progress.nextDay(plan.days);
      final reading = plan.schedule(bible)[day];
      final done = progress.finished(plan.days);
      planCard = _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(Icons.event_note, plan.name),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.done.length / plan.days, minHeight: 6, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          Text(done
              ? 'Plano concluído. Glória a Deus!'
              : 'Dia ${day + 1} de ${plan.days} · no seu ritmo, sem atraso'),
          const SizedBox(height: 8),
          if (!done)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (b, c) in reading.take(8))
                ActionChip(
                  avatar: Icon(app.readChapters.contains('$b:$c') ? Icons.check_circle : Icons.menu_book, size: 18),
                  label: Text('${bible.books[b].name} $c'),
                  onPressed: () => app.openAt(b, c),
                ),
              FilledButton.tonal(
                onPressed: () async {
                  progress.done.add(day);
                  await progress.save();
                  _load();
                },
                child: const Text('Concluir'),
              ),
            ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _open(const ReadingPlansScreen()), child: const Text('Ver plano')),
          ),
        ]),
      );
    } else {
      planCard = _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(Icons.explore_outlined, 'Por onde começar?'),
          const SizedBox(height: 6),
          const Text('Escolha um caminho. Não tem data marcada: você lê no seu ritmo.'),
          const SizedBox(height: 10),
          for (final (id, label, sub) in const [
            ('marcos16', 'Sou novo na Bíblia', 'Evangelho de Marcos · 16 dias'),
            ('proverbios31', 'Quero constância', 'Provérbios · 1 capítulo por dia'),
            ('joao21', 'Quero conhecer Jesus', 'Evangelho de João · 21 dias'),
          ])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(sub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _startPlan(id),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _open(const ReadingPlansScreen()), child: const Text('Todos os planos')),
          ),
        ]),
      );
    }

    final needsCard = _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.volunteer_activism_outlined, 'Preciso de uma palavra para…'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var k = 0; k < needs.length; k++)
            ActionChip(
              avatar: Icon(needs[k].icon, size: 18, color: needs[k].color),
              label: Text(needs[k].name),
              onPressed: () => _open(NeedsScreen(initial: k)),
            ),
        ]),
      ]),
    );

    Widget small(IconData icon, String title, String sub, VoidCallback onTap, {Color? color}) => _card(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: (color ?? cs.primary).withValues(alpha: 0.14),
                child: Icon(icon, color: color ?? cs.primary)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        );

    final prayerCard = small(Icons.self_improvement, 'Diário de oração',
        _prayers == 0 ? 'Anote seus pedidos e guarde as respostas' : '$_prayers pedido${_prayers == 1 ? '' : 's'} em oração',
        () => _open(const PrayerScreen()), color: const Color(0xFF6A1B9A));
    final memoryCard = small(Icons.psychology_alt_outlined, 'Memorização',
        _memoryDue == 0 ? 'Guarde a Palavra no coração' : '$_memoryDue versículo${_memoryDue == 1 ? '' : 's'} para revisar hoje',
        () => _open(const MemorizeScreen()), color: const Color(0xFF00897B));
    final devotionalCard = small(Icons.wb_sunny_outlined, 'Devocional de hoje', 'Uma reflexão curta para o seu dia',
        () => openDevotional(context, app), color: const Color(0xFFEF6C00));

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 860;
          Widget pair(Widget a, Widget b) => two
              ? IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: a),
                    const SizedBox(width: 14),
                    Expanded(child: b),
                  ]),
                )
              : Column(children: [a, const SizedBox(height: 14), b]);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
                Text('$greeting${first.isEmpty ? '' : ', $first'}!',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(date, style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 14),
                hero,
                const SizedBox(height: 14),
                pair(continueCard, goalCard),
                const SizedBox(height: 14),
                pair(planCard, needsCard),
                const SizedBox(height: 14),
                if (two)
                  Row(children: [
                    Expanded(child: prayerCard),
                    const SizedBox(width: 14),
                    Expanded(child: memoryCard),
                    const SizedBox(width: 14),
                    Expanded(child: devotionalCard),
                  ])
                else ...[
                  prayerCard,
                  const SizedBox(height: 14),
                  memoryCard,
                  const SizedBox(height: 14),
                  devotionalCard,
                ],
                const SizedBox(height: 24),
                Center(
                  child: Text('Bíblia JG · Produzido por Joabe Gonçalves',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
