import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/daily.dart';
import '../state/app_state.dart';
import '../widgets/book_chapter_panel.dart';
import '../widgets/quick_settings_sheet.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'history_screen.dart';
import 'marks_screen.dart';
import 'notes_screen.dart';
import 'progress_screen.dart';
import 'reader_view.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'versions_screen.dart';

/// Largura a partir da qual usamos o layout de tablet (duas colunas).
const tabletBreakpoint = 840.0;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Desligado nos testes (evita acesso à rede).
  static bool autoCheckUpdates = true;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _barsVisible = true;
  bool _panelOpen = true;
  bool? _lastFullScreen;

  @override
  void initState() {
    super.initState();
    // Procura atualização alguns segundos depois de abrir o app.
    if (!HomeShell.autoCheckUpdates) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkForUpdates(context);
    });
  }

  void _applyFullScreen(bool full) {
    if (_lastFullScreen == full) return;
    _lastFullScreen = full;
    SystemChrome.setEnabledSystemUIMode(
        full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _applyFullScreen(app.settings.fullScreen);
    final wide = MediaQuery.sizeOf(context).width >= tabletBreakpoint;

    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final book = app.currentBook;
    final title = book == null ? 'Bíblia JG' : '${book.name} ${app.chapter}';

    final topBar = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: _barsVisible
          ? AppBar(
              title: InkWell(
                onTap: book == null
                    ? null
                    : () => wide
                        ? setState(() => _panelOpen = !_panelOpen)
                        : _push(const BookChapterPage()),
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
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).appBarTheme.foregroundColor),
                    child: Text(app.bible!.abbrev,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                IconButton(
                  tooltip: 'Ajustes de leitura',
                  icon: const Icon(Icons.text_fields),
                  onPressed: () => showQuickSettings(context),
                ),
                IconButton(
                  tooltip: 'Pesquisar',
                  icon: const Icon(Icons.search),
                  onPressed: () => _push(const SearchScreen()),
                ),
              ],
            )
          : SizedBox(height: MediaQuery.paddingOf(context).top),
    );

    Widget body;
    if (app.bible == null) {
      body = _NoBible(error: app.loadError, onImport: () => _push(const VersionsScreen()));
    } else {
      final reader = ReaderView(
        onScrollDirection: (down) {
          if (!app.settings.hideMenusOnScroll) return;
          if (_barsVisible == down) setState(() => _barsVisible = !down);
        },
      );
      body = wide
          ? Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _panelOpen ? 320 : 0,
                child: _panelOpen
                    ? const Material(elevation: 1, child: BookChapterPanel())
                    : null,
              ),
              if (_panelOpen) const VerticalDivider(width: 1),
              Expanded(child: reader),
            ])
          : reader;
    }

    return Scaffold(
      drawer: _MainDrawer(onOpen: _push),
      body: Column(children: [topBar, Expanded(child: body)]),
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
            const Text('Nenhuma versão da Bíblia instalada.',
                style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.download),
              label: const Text('Importar versão'),
            ),
          ]),
        ),
      );
}

class _MainDrawer extends StatelessWidget {
  final void Function(Widget) onOpen;
  const _MainDrawer({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final bible = app.bible;
    final vod = verseOfDay(DateTime.now());
    final vodText = bible == null ? null : verseText(bible, vod);

    void open(Widget w) {
      Navigator.pop(context);
      onOpen(w);
    }

    Widget item(IconData icon, String label, Widget page) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () => open(page),
        );

    Widget soon(IconData icon, String label) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          enabled: false,
          trailing: const Chip(label: Text('em breve'), visualDensity: VisualDensity.compact),
        );

    return Drawer(
      width: 340,
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: BoxDecoration(color: app.settings.themeColor),
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: bible == null
                ? null
                : () {
                    Navigator.pop(context);
                    app.goTo(vod.book, vod.chapter, verse: vod.verse);
                  },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bíblia · JG Company',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Versículo do dia',
                  style: TextStyle(color: Color(0xFFC9A227), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  vodText == null ? '' : '“$vodText” — ${vod.label(bible)}',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.fade,
                ),
              ),
            ]),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: const Text('Bíblia'),
          onTap: () => Navigator.pop(context),
        ),
        item(Icons.edit_note, 'Anotações', const NotesScreen()),
        item(Icons.bookmark, 'Favoritos & Marcações', const MarksScreen()),
        item(Icons.insights, 'Progresso de Leitura', const ProgressScreen()),
        item(Icons.search, 'Pesquisa', const SearchScreen()),
        item(Icons.translate, 'Versões', const VersionsScreen()),
        item(Icons.history, 'Histórico', const HistoryScreen()),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Próximas etapas', style: theme.textTheme.labelLarge),
        ),
        soon(Icons.event_note, 'Planos de Leitura'),
        soon(Icons.wb_sunny_outlined, 'Devocional Diário'),
        soon(Icons.auto_stories, 'Histórias Bíblicas'),
        soon(Icons.library_music, 'Hinários'),
        soon(Icons.music_note, 'Músicas de fundo'),
        soon(Icons.picture_as_pdf, 'Leitor de PDF'),
        soon(Icons.public, 'Mapas 3D'),
        soon(Icons.abc, 'Dicionário'),
        soon(Icons.quiz, 'Perguntas Bíblicas'),
        const Divider(),
        item(Icons.backup, 'Backup', const BackupScreen()),
        item(Icons.settings, 'Configurações', const SettingsScreen()),
        item(Icons.info_outline, 'Sobre', const AboutScreen()),
      ]),
    );
  }
}
