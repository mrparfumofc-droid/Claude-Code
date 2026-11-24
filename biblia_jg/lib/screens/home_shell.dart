import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../models/bible.dart';
import '../models/reference_parser.dart';
import '../services/account_service.dart';
import '../services/dictionary_service.dart';
import '../services/sync.dart';
import '../state/app_state.dart';
import '../widgets/book_chapter_panel.dart';
import '../widgets/quick_settings_sheet.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'ai_chat_screen.dart';
import 'backup_screen.dart';
import 'content_screens.dart';
import 'devotional_screen.dart';
import 'dictionary_screen.dart';
import 'history_screen.dart';
import 'hymnal_screen.dart';
import 'library_screen.dart';
import 'maps_screen.dart';
import 'marks_screen.dart';
import 'memorize_screen.dart';
import 'music_screen.dart';
import 'needs_screen.dart';
import 'notes_screen.dart';
import 'panorama_screen.dart';
import 'prayer_screen.dart';
import 'progress_screen.dart';
import 'quiz_screen.dart';
import 'reader_view.dart';
import 'reading_plans_screen.dart';
import 'search_screen.dart';
import 'sermons_screen.dart';
import 'settings_screen.dart';
import 'stories_screen.dart';
import 'today_screen.dart';
import 'versions_screen.dart';
import 'voice_screen.dart';

/// Largura a partir da qual usamos o layout de tablet (duas colunas).
const tabletBreakpoint = 720.0;

/// Casca do app: abas Hoje, Bíblia, Estudo, Biblioteca e Mais.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Desligado nos testes (evita acesso à rede e relógios).
  static bool autoCheckUpdates = true;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  final _built = <int>{0};
  bool _chrome = true; // barra de abas visível (a leitura esconde no modo foco)
  bool? _railHidden; // barra lateral recolhida pelo usuário (tablet)
  bool? _lastFullScreen;
  bool _resumed = true;
  Timer? _clock;

  static const _destinations = <(IconData, IconData, String)>[
    (Icons.today_outlined, Icons.today, 'Hoje'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Bíblia'),
    (Icons.school_outlined, Icons.school, 'Estudo'),
    (Icons.local_library_outlined, Icons.local_library, 'Biblioteca'),
    (Icons.more_horiz, Icons.more_horiz, 'Mais'),
  ];

  @override
  void initState() {
    super.initState();
    if (!HomeShell.autoCheckUpdates) return;
    WidgetsBinding.instance.addObserver(this);
    // Procura atualização e sincroniza a conta alguns segundos depois de abrir o app.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkForUpdates(context);
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        autoSync(context.read<AppState>(), context.read<AccountService>(), context.read<DictionaryService>());
      }
    });
    // Conta o tempo de leitura (para a meta diária) enquanto a aba Bíblia está na tela.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || !_resumed || _tab != 1) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      context.read<AppState>().logReading(seconds: 20);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!mounted) return;
    final app = context.read<AppState>();
    // Ao sair e ao voltar: sincroniza (junta com a nuvem se outro aparelho mudou algo).
    if (state == AppLifecycleState.paused) {
      autoSync(app, context.read<AccountService>(), context.read<DictionaryService>());
    } else if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastResumeSync) > const Duration(seconds: 45)) {
        _lastResumeSync = DateTime.now();
        autoSync(app, context.read<AccountService>(), context.read<DictionaryService>());
      }
      app.rescheduleNotifications(); // mantém os lembretes dos próximos dias agendados
    }
  }

  DateTime _lastResumeSync = DateTime(2000);

  void _applyFullScreen(bool full) {
    if (_lastFullScreen == full) return;
    _lastFullScreen = full;
    SystemChrome.setEnabledSystemUIMode(full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _setRailHidden(bool hidden) {
    setState(() => _railHidden = hidden);
    context.read<AppState>().prefs.setBool('ui.rail_hidden', hidden);
  }

  void _select(int i) => setState(() {
        _tab = i;
        _built.add(i);
        if (i != 1) _chrome = true;
      });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _applyFullScreen(app.settings.fullScreen);
    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Outra tela pediu para abrir uma aba (ex.: tocar numa referência abre a Bíblia).
    if (app.tabRequest >= 0) {
      final t = app.tabRequest;
      app.tabRequest = -1;
      if (t != _tab) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _select(t);
        });
      }
    }
    final wide = MediaQuery.sizeOf(context).width >= tabletBreakpoint;
    final railHidden = _railHidden ??= app.prefs.getBool('ui.rail_hidden') ?? false;
    Widget page(int i) => switch (i) {
          0 => const TodayScreen(),
          1 => ReaderPage(onChrome: (v) {
              if (_chrome != v) setState(() => _chrome = v);
            }),
          2 => const StudyHub(),
          3 => const LibraryHub(),
          _ => const MoreScreen(),
        };
    final stack = IndexedStack(
      index: _tab,
      children: [for (var i = 0; i < 5; i++) _built.contains(i) ? page(i) : const SizedBox.shrink()],
    );

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: wide
          ? Scaffold(
              body: Stack(children: [
               Row(children: [
                if (_chrome && !railHidden)
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/branding/logo.png', width: 44, height: 44,
                            errorBuilder: (_, _, _) => const Icon(Icons.menu_book, size: 36)),
                      ),
                    ),
                    destinations: [
                      for (final (icon, selected, label) in _destinations)
                        NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                    ],
                    // Embaixo: a música e o botão de recolher a barra.
                    trailingAtBottom: true,
                    scrollable: true,
                    trailing: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const RailMusic(),
                        IconButton(
                          tooltip: 'Ocultar a barra lateral',
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                          onPressed: () => _setRailHidden(true),
                        ),
                      ]),
                    ),
                  ),
                if (_chrome && !railHidden) const VerticalDivider(width: 1),
                Expanded(child: stack),
               ]),
               // Barra recolhida: uma alça discreta na borda traz de volta.
               if (_chrome && railHidden)
                 Positioned(
                   left: 0,
                   bottom: 72,
                   child: Material(
                     elevation: 3,
                     color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
                     borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                     child: InkWell(
                       borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                       onTap: () => _setRailHidden(false),
                       child: const Tooltip(
                         message: 'Mostrar a barra lateral',
                         child: SizedBox(width: 26, height: 60, child: Icon(Icons.keyboard_double_arrow_right, size: 20)),
                       ),
                     ),
                   ),
                 ),
              ]),
            )
          : Scaffold(
              body: stack,
              bottomNavigationBar: _chrome
                  ? NavigationBar(
                      selectedIndex: _tab,
                      onDestinationSelected: _select,
                      destinations: [
                        for (final (icon, selected, label) in _destinations)
                          NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
                      ],
                    )
                  : null,
            ),
    );
  }
}

// ======================================================================
// Aba Bíblia
// ======================================================================

class ReaderPage extends StatefulWidget {
  /// Avisa a casca para mostrar/esconder a barra de abas.
  final ValueChanged<bool> onChrome;
  const ReaderPage({super.key, required this.onChrome});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  bool _barsVisible = true;
  bool? _panelChoice; // null = automático (aberto só em telas largas)
  bool _focus = false;
  int _focusSeconds = 0;
  Timer? _focusTimer;
  int? _focusGoal; // minutos escolhidos para a sessão (0 = sem limite)
  bool _alarmed = false;
  Offset? _pill; // onde o relógio do modo foco fica (o leitor arrasta)

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _setBars(bool visible) {
    if (_barsVisible == visible) return;
    setState(() => _barsVisible = visible);
    widget.onChrome(visible && !_focus);
  }

  void _startFocus() {
    _focusTimer?.cancel();
    setState(() {
      _focus = true;
      _focusSeconds = 0;
      _alarmed = false;
      _focusGoal = null; // volta ao tempo guardado
    });
    widget.onChrome(false);
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  int _goal(AppState app) => _focusGoal ??= app.prefs.getInt('focus.goal') ?? 10;

  void _tick() {
    if (!mounted) return;
    setState(() => _focusSeconds++);
    final app = context.read<AppState>();
    final goal = _goal(app);
    if (goal > 0 && !_alarmed && _focusSeconds >= goal * 60) {
      _alarmed = true;
      _ringAlarm(app, goal);
    }
  }

  /// O tempo escolhido acabou: toca o alarme e pergunta o que fazer.
  Future<void> _ringAlarm(AppState app, int goal) async {
    final name = '${app.currentBook?.name ?? ''} ${app.chapter}'.trim();
    app.notifications.alarm('Tempo de leitura concluído', '$goal minutos · $name');
    SystemSound.play(SystemSoundType.alert);
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted || !_focus) return;
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.alarm_on, size: 40),
        title: const Text('Tempo concluído'),
        content: Text('Você leu por $goal minutos. Quer continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 5), child: const Text('Mais 5 minutos')),
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Continuar sem alarme')),
          FilledButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Concluir leitura')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 5) {
      setState(() {
        _focusGoal = _focusSeconds ~/ 60 + 5;
        _alarmed = false;
      });
    } else if (choice == -1) {
      _finishFocus(app);
    }
  }

  /// Escolhe por quanto tempo ler (o alarme toca no fim).
  Future<void> _chooseGoal(AppState app) async {
    final current = _goal(app);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Por quanto tempo quer ler?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Quando o tempo acabar, o aparelho toca um alarme. Dá para arrastar o relógio para onde quiser.'),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const [0, 5, 10, 15, 20, 30, 45, 60, 90])
                ChoiceChip(
                  label: Text(m == 0 ? 'Sem limite' : '$m min'),
                  selected: m == current,
                  onSelected: (_) => Navigator.pop(ctx, m),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    app.prefs.setInt('focus.goal', picked);
    setState(() {
      _focusGoal = picked;
      _alarmed = picked > 0 && _focusSeconds >= picked * 60;
    });
  }

  /// Faixa de cima do modo foco: a hora à esquerda e o livro com o capítulo no centro.
  Widget _focusStrip(String title) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 40,
        child: Stack(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(clock,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _push(const BookChapterPage()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(title,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Relógio do modo foco: mostra o tempo, abre a escolha da duração e pode ser arrastado.
  Widget _focusPill(AppState app, BoxConstraints box) {
    final scheme = Theme.of(context).colorScheme;
    final goal = _goal(app);
    final total = goal * 60;
    final remaining = goal > 0 ? total - _focusSeconds : _focusSeconds;
    final shown = remaining.abs();
    final label =
        '${goal > 0 && remaining < 0 ? '+' : ''}${(shown ~/ 60).toString().padLeft(2, '0')}:${(shown % 60).toString().padLeft(2, '0')}';
    final done = goal > 0 ? _focusSeconds >= total : _focusSeconds >= 300;
    _pill ??= app.prefs.containsKey('focus.px')
        ? Offset(app.prefs.getDouble('focus.px') ?? 0, app.prefs.getDouble('focus.py') ?? 0)
        : Offset(box.maxWidth - 372, box.maxHeight - 76);
    final top = MediaQuery.paddingOf(context).top + 44;
    final pos = Offset(
      _pill!.dx.clamp(4.0, (box.maxWidth - 160).clamp(4.0, double.infinity)),
      _pill!.dy.clamp(top, (box.maxHeight - 60).clamp(top, double.infinity)),
    );
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _pill = pos + d.delta),
        onPanEnd: (_) {
          app.prefs.setDouble('focus.px', pos.dx);
          app.prefs.setDouble('focus.py', pos.dy);
        },
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(28),
          color: scheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Tooltip(
                message: 'Arraste para mudar de lugar',
                child: Icon(Icons.drag_indicator, size: 20, color: scheme.onInverseSurface.withValues(alpha: 0.6)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _chooseGoal(app),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (done)
                      const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent)
                    else if (goal > 0)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: (_focusSeconds / total).clamp(0.0, 1.0),
                          strokeWidth: 2.5,
                          color: Colors.greenAccent,
                          backgroundColor: scheme.onInverseSurface.withValues(alpha: 0.25),
                        ),
                      )
                    else
                      Icon(Icons.timer_outlined, size: 18, color: scheme.onInverseSurface),
                    const SizedBox(width: 8),
                    Text(label,
                        style: TextStyle(
                            color: scheme.onInverseSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                    Icon(Icons.arrow_drop_down, size: 18, color: scheme.onInverseSurface),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(onPressed: () => _finishFocus(app), child: const Text('Concluir leitura')),
              IconButton(
                tooltip: 'Sair do modo foco',
                color: scheme.onInverseSurface,
                icon: const Icon(Icons.close),
                onPressed: _stopFocus,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _stopFocus() {
    _focusTimer?.cancel();
    setState(() {
      _focus = false;
      _barsVisible = true;
    });
    widget.onChrome(true);
  }

  /// Fim da leitura em modo foco: marca como lido e convida a anotar o que ficou.
  Future<void> _finishFocus(AppState app) async {
    final book = app.book, chapter = app.chapter, name = app.currentBook?.name ?? '';
    await app.markChapterRead();
    if (!mounted) return;
    final ctrl = TextEditingController();
    final next = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name $chapter lido 🎉'),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('O que ficou desta leitura? Escrever em uma frase ajuda a guardar.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Opcional', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Encerrar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Próximo capítulo')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (text.isNotEmpty) {
      final now = DateTime.now();
      await app.saveNote(Note(ref: VerseRef(book, chapter, 1), text: text, created: now, updated: now));
    }
    if (!mounted) return;
    if (next == true) {
      await app.nextChapter();
      if (mounted) {
        setState(() {
          _focusSeconds = 0;
          _alarmed = false;
        });
      }
    } else {
      _stopFocus();
    }
  }

  /// Resumo simples do capítulo ou introdução do livro (IA, guardado no aparelho).
  void _understand(AppState app, {required bool intro}) {
    final b = app.currentBook;
    final bible = app.bible;
    if (b == null || bible == null) return;
    _push(AiChatScreen(
      title: intro ? 'Introdução a ${b.name}' : 'Entenda ${b.name} ${app.chapter}',
      task: 'chat',
      reference: intro ? 'Livro de ${b.name}' : '${b.name} ${app.chapter}',
      version: bible.abbrev,
      verseText: intro ? null : app.currentVerses.map(plainVerse).join(' '),
      initialPrompt: intro
          ? 'Faça uma introdução simples ao livro de ${b.name}, em linguagem fácil: quem escreveu, quando e para quem; '
              'o tema central; os assuntos principais em tópicos; onde ele se encaixa na história da Bíblia; '
              'e uma dica de como ler. No máximo 250 palavras.'
          : 'Resuma este capítulo em linguagem simples, para quem está começando: 1) o que acontece, em até 5 linhas; '
              '2) palavras ou costumes difíceis explicados; 3) a ideia principal em 1 frase; '
              '4) uma aplicação prática para hoje. No máximo 220 palavras.',
      cacheKey: intro ? 'intro_${app.book}' : 'chap_${bible.id}_${app.book}_${app.chapter}',
    ));
  }

  /// Caixa "Ir para": aceita "Jo 3:16", "Salmos 23", "1 Co 13.4".
  Future<void> _goToReference(AppState app) async {
    final controller = TextEditingController();
    String? error;
    final passage = await showDialog<Passage>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void submit() {
            final p = parseReference(controller.text);
            if (p == null) {
              setLocal(() => error = 'Não entendi. Exemplos: Jo 3:16, Salmos 23, 1 Co 13.4');
            } else {
              Navigator.pop(ctx, p);
            }
          }

          return AlertDialog(
            title: const Text('Ir para'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(hintText: 'Ex.: Jo 3:16', errorText: error, border: const OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: submit, child: const Text('Ir')),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (passage != null) await app.goTo(passage.book, passage.chapter, verse: passage.verse);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.focusRequest) {
      app.focusRequest = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus) _startFocus();
      });
    }
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= tabletBreakpoint;
    // Em tablet em pé (estreito) o painel de livros começa fechado para sobrar texto.
    final panelOpen = _panelChoice ?? width >= 1000;
    final book = app.currentBook;
    final title = book == null ? 'Bíblia JG' : '${book.name} ${app.chapter}';
    final fg = Theme.of(context).appBarTheme.foregroundColor;

    final topBar = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: _barsVisible && !_focus
          ? AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: InkWell(
                onTap: book == null
                    ? null
                    : () => wide ? setState(() => _panelChoice = !panelOpen) : _push(const BookChapterPage()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ),
              ),
              actions: [
                if (app.bible != null)
                  TextButton(
                    onPressed: () => _push(const VersionsScreen()),
                    style: TextButton.styleFrom(foregroundColor: fg),
                    child: Text(app.bible!.abbrev, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                if (book != null)
                  PopupMenuButton<int>(
                    tooltip: 'Entender o que estou lendo',
                    icon: const Icon(Icons.lightbulb_outline),
                    onSelected: (v) => v == 2 ? _push(BookSheetScreen(number: app.book + 1)) : _understand(app, intro: v == 1),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 0, child: Text('Resumo simples de ${book.name} ${app.chapter}')),
                      PopupMenuItem(value: 1, child: Text('Introdução ao livro de ${book.name}')),
                      PopupMenuItem(value: 2, child: Text('Ficha de ${book.name}: autor, personagens, acontecimentos')),
                    ],
                  ),
                if (book != null)
                  IconButton(
                    tooltip: 'Modo foco (ler sem distrações)',
                    icon: const Icon(Icons.center_focus_strong_outlined),
                    onPressed: _startFocus,
                  ),
                IconButton(
                  tooltip: 'Ir para referência',
                  icon: const Icon(Icons.near_me_outlined),
                  onPressed: () => _goToReference(app),
                ),
                IconButton(
                  tooltip: 'Ajustes de leitura',
                  icon: const Icon(Icons.text_fields),
                  onPressed: () => showQuickSettings(context),
                ),
                if (wide)
                  IconButton(
                    tooltip: 'Pesquisar',
                    icon: const Icon(Icons.search),
                    onPressed: () => _push(const SearchScreen()),
                  ),
              ],
            )
          : (_focus ? _focusStrip(title) : SizedBox(height: MediaQuery.paddingOf(context).top)),
    );

    Widget body;
    if (app.bible == null) {
      body = _NoBible(error: app.loadError, onImport: () => _push(const VersionsScreen()));
    } else {
      final reader = ReaderView(
        onScrollDirection: (down) {
          if (_focus || !app.settings.hideMenusOnScroll) return;
          _setBars(!down);
        },
      );
      final showPanel = wide && panelOpen && !_focus;
      body = wide
          ? Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: showPanel ? 320 : 0,
                // Escolhido o versículo, o painel se fecha sozinho.
                child: showPanel
                    ? Material(elevation: 1, child: BookChapterPanel(onSelected: () => setState(() => _panelChoice = false)))
                    : null,
              ),
              if (showPanel) const VerticalDivider(width: 1),
              Expanded(child: reader),
            ])
          : reader;
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => Stack(children: [
          Column(children: [
            topBar,
            Expanded(child: body),
            if (!_focus) MiniMusicBar(onOpen: () => _push(const MusicScreen())),
          ]),
          if (_focus) _focusPill(app, box),
        ]),
      ),
    );
  }
}

class _NoBible extends StatelessWidget {
  final String? error;
  final VoidCallback onImport;
  const _NoBible({this.error, required this.onImport});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.menu_book, size: 72),
            const SizedBox(height: 16),
            const Text('Nenhuma versão da Bíblia instalada.', style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.download), label: const Text('Importar versão')),
          ]),
        ),
      );
}

// ======================================================================
// Abas Estudo, Biblioteca e Mais
// ======================================================================

class _HubItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final void Function(BuildContext) open;
  const _HubItem(this.icon, this.color, this.title, this.subtitle, this.open);
}

void _go(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class _HubPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_HubItem> items;
  const _HubPage({required this.title, required this.subtitle, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                sliver: SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340, mainAxisExtent: 96, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: InkWell(
                        onTap: () => it.open(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: it.color.withValues(alpha: 0.14),
                              child: Icon(it.icon, color: it.color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(it.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class StudyHub extends StatelessWidget {
  const StudyHub({super.key});

  @override
  Widget build(BuildContext context) => _HubPage(
        title: 'Estudo',
        subtitle: 'Ferramentas para entender e guardar a Palavra',
        items: [
          _HubItem(Icons.auto_awesome, const Color(0xFF5E35B1), 'Assistente bíblico (IA)', 'Tire dúvidas com referências', openAssistant),
          _HubItem(Icons.search, const Color(0xFF1565C0), 'Pesquisar na Bíblia', 'Palavras, frases e temas', (c) => _go(c, const SearchScreen())),
          _HubItem(Icons.event_note, const Color(0xFF2E7D32), 'Planos de leitura', 'No seu ritmo, sem atraso', (c) => _go(c, const ReadingPlansScreen())),
          _HubItem(Icons.volunteer_activism_outlined, const Color(0xFFD81B60), 'Palavra para o momento', 'Versículos para ansiedade, medo, luto…', (c) => _go(c, const NeedsScreen())),
          _HubItem(Icons.psychology_alt_outlined, const Color(0xFF00897B), 'Memorização', 'Guarde versículos no coração', (c) => _go(c, const MemorizeScreen())),
          _HubItem(Icons.self_improvement, const Color(0xFF6A1B9A), 'Diário de oração', 'Pedidos e orações respondidas', (c) => _go(c, const PrayerScreen())),
          _HubItem(Icons.wb_sunny_outlined, const Color(0xFFEF6C00), 'Devocional sob medida', 'Feito para o seu objetivo e a sua rotina',
              (c) => _go(c, const DevotionalScreen())),
          _HubItem(Icons.record_voice_over_outlined, const Color(0xFF6D4C41), 'Pregações', 'Esboços, ajuda da IA e modo púlpito',
              (c) => _go(c, const SermonsScreen())),
          _HubItem(Icons.abc, const Color(0xFF455A64), 'Dicionário bíblico', 'Pessoas, lugares e termos', (c) => _go(c, const DictionaryScreen())),
          _HubItem(Icons.account_tree, const Color(0xFF1B2A4A), 'Panorama bíblico', 'Árvore de Abraão, reis, profetas e os 66 livros', (c) => _go(c, const PanoramaScreen())),
          _HubItem(Icons.public, const Color(0xFF00838F), 'Mapas bíblicos', 'Atlas, viagens de Paulo e lugares no satélite', (c) => _go(c, const MapsScreen())),
          _HubItem(Icons.auto_stories, const Color(0xFF8D6E63), 'Histórias bíblicas', 'Ilustradas e narradas, com mapa', (c) => _go(c, const StoriesScreen())),
          _HubItem(Icons.quiz_outlined, const Color(0xFFC62828), 'Perguntas bíblicas', 'Teste o que você sabe', (c) => _go(c, const QuizScreen())),
        ],
      );
}

class LibraryHub extends StatelessWidget {
  const LibraryHub({super.key});

  @override
  Widget build(BuildContext context) => _HubPage(
        title: 'Biblioteca',
        subtitle: 'Seus livros, revistas, hinos e anotações',
        items: [
          _HubItem(Icons.school, const Color(0xFF1565C0), 'EBD', 'Revista, lições e preparo da aula', (c) => _go(c, const LibraryScreen(initialTab: 1))),
          _HubItem(Icons.picture_as_pdf_outlined, const Color(0xFFC62828), 'Livros (PDF)', 'Leia e anote à mão', (c) => _go(c, const LibraryScreen())),
          _HubItem(Icons.library_music, const Color(0xFF6A1B9A), 'Hinário', 'Hinos e o seu hinário', (c) => _go(c, const HymnalScreen())),
          _HubItem(Icons.music_note, const Color(0xFF00897B), 'Músicas de fundo', 'Instrumentais para ler e orar', (c) => _go(c, const MusicScreen())),
          _HubItem(Icons.edit_note, const Color(0xFFEF6C00), 'Anotações', 'Tudo o que você escreveu', (c) => _go(c, const NotesScreen())),
          _HubItem(Icons.bookmark, const Color(0xFFB8860B), 'Favoritos e marcações', 'Versículos marcados com cores', (c) => _go(c, const MarksScreen())),
          _HubItem(Icons.history, const Color(0xFF455A64), 'Histórico', 'Capítulos abertos recentemente', (c) => _go(c, const HistoryScreen())),
        ],
      );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountService>();
    final theme = Theme.of(context);
    Widget tile(IconData icon, String title, String subtitle, Widget page) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _go(context, page),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 18, 12, 28), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text('Mais', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: account.signedIn && account.photoUrl != null
                      ? CircleAvatar(backgroundImage: NetworkImage(account.photoUrl!))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(account.signedIn ? (account.name ?? account.email ?? 'Conta Google') : 'Entrar com Google',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(!account.signedIn
                      ? 'Salve marcações, anotações e progresso na sua conta'
                      : account.sessionExpired
                          ? 'Sessão vencida: toque para entrar de novo'
                          : 'Seus dados estão sincronizados na sua conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _go(context, const AccountScreen()),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(children: [
                  tile(Icons.insights, 'Progresso de leitura', 'Quanto da Bíblia você já leu', const ProgressScreen()),
                  tile(Icons.translate, 'Versões da Bíblia', 'Escolher ou importar versões', const VersionsScreen()),
                  tile(Icons.record_voice_over, 'Voz da leitura', 'Voz, velocidade e tom', const VoiceScreen()),
                  tile(Icons.settings, 'Configurações', 'Leitura, tema e notificações', const SettingsScreen()),
                  tile(Icons.backup, 'Backup', 'Salvar ou restaurar seus dados', const BackupScreen()),
                  tile(Icons.info_outline, 'Sobre', 'Versão, atualização e créditos', const AboutScreen()),
                ]),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Bíblia JG · Produzido por Joabe Gonçalves',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
