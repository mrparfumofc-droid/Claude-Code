import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bible.dart' show normalizeForSearch;
import '../services/account_service.dart';
import '../services/notebook_models.dart';
import '../services/notebook_store.dart';
import '../widgets/notebook_painters.dart';
import 'account_screen.dart';
import 'notebook_editor_screen.dart';

enum _Sort { recent, name, created }

/// Estudo > Caderno: a estante de cadernos de anotação à mão.
class NotebooksScreen extends StatefulWidget {
  /// Só para testes e prévia: usa este depósito em vez do da conta.
  final NotebookStore? store;
  const NotebooksScreen({super.key, this.store});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  late final NotebookStore _store = widget.store ?? NotebookStore.of(context.read<AccountService>());
  final _search = TextEditingController();
  bool _searching = false;
  String _folder = ''; // '' = todos; '*' = favoritos
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<NbBook> get _shown {
    final q = normalizeForSearch(_search.text.trim());
    final list = [
      for (final b in _store.books)
        if ((_folder.isEmpty || (_folder == '*' ? b.favorite : b.folder == _folder)) &&
            (q.isEmpty || normalizeForSearch('${b.title} ${b.folder}').contains(q)))
          b
    ];
    switch (_sort) {
      case _Sort.recent:
        list.sort((a, b) => b.updated.compareTo(a.updated));
      case _Sort.name:
        list.sort((a, b) => normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title)));
      case _Sort.created:
        list.sort((a, b) => b.created.compareTo(a.created));
    }
    return list;
  }

  Future<void> _open(NbBook b) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotebookEditorScreen(store: _store, book: b)));
    if (mounted) setState(() {});
  }

  Future<void> _create({String? title, NbTemplate? template}) async {
    final made = await showModalBottomSheet<NbBook>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BookSheet(store: _store, title: title, template: template, folder: _folder.length > 1 ? _folder : ''),
    );
    if (made != null && mounted) await _open(made);
  }

  Future<void> _edit(NbBook b) async {
    await showModalBottomSheet<NbBook>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BookSheet(store: _store, book: b),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(NbBook b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apagar "${b.title}"?'),
        content: Text('As ${b.pageIds.length} página(s) deste caderno serão apagadas deste tablet'
            '${_store.cloud ? ' e da sua conta' : ''}. Não dá para desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) await _store.deleteBook(b);
  }

  void _menu(NbBook b) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          Widget item(IconData icon, String text, VoidCallback onTap) => ListTile(
                leading: Icon(icon),
                title: Text(text),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap();
                },
              );
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_details(b)),
                ),
                item(Icons.edit_note, 'Nome, capa e pasta', () => _edit(b)),
                item(b.favorite ? Icons.star : Icons.star_border, b.favorite ? 'Tirar dos favoritos' : 'Marcar como favorito', () {
                  b.favorite = !b.favorite;
                  _store.saveBook(b, touch: false);
                }),
                item(Icons.copy_all_outlined, 'Duplicar o caderno', () => _store.duplicate(b)),
                item(Icons.delete_outline, 'Apagar', () => _delete(b)),
              ]),
            ),
          );
        },
      );

  static String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'hoje';
    if (days == 1) return 'ontem';
    if (days < 30) return 'há $days dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _details(NbBook b) =>
      '${b.pageIds.length} ${b.pageIds.length == 1 ? 'página' : 'páginas'} · ${_when(b.updated)}${b.folder.isEmpty ? '' : ' · ${b.folder}'}';

  Widget _cloudLine(ThemeData theme) {
    final signedIn = _store.cloud;
    final text = !signedIn
        ? 'Guardado neste tablet. Entre com a sua conta Google para ter uma cópia na nuvem.'
        : _store.syncError ??
            (_store.syncing
                ? 'Sincronizando com a sua conta…'
                : _store.pendingCount > 0
                    ? 'Enviando alterações para a sua conta…'
                    : 'Cópia na sua conta em dia.');
    return Row(children: [
      Icon(signedIn ? (_store.syncError == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined) : Icons.tablet_android,
          size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      if (!signedIn)
        TextButton(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
            if (mounted) _store.load();
          },
          child: const Text('Entrar'),
        ),
    ]);
  }

  Widget _empty(ThemeData theme) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 150,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final (i, c) in const [0xFF7A1F2B, 0xFF1B2A49, 0xFF1F5B4A].indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: i == 1 ? 96 : 78,
                        height: i == 1 ? 136 : 110,
                        child: CustomPaint(painter: NbCoverPainter(Color(c), i + 1)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 22),
              Text('Seu caderno de estudo', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Escreva à mão com a caneta, cole versículos, desenhe esquemas e monte esboços. '
                'Tudo fica salvo sozinho.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Anotações livres'),
                    onPressed: () => _create(title: 'Anotações', template: NbTemplate.ruled)),
                OutlinedButton(
                    onPressed: () => _create(title: 'Sermões', template: NbTemplate.sermon), child: const Text('Esboços de sermão')),
                OutlinedButton(
                    onPressed: () => _create(title: 'Estudos bíblicos', template: NbTemplate.study), child: const Text('Estudo bíblico')),
              ]),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final folders = _store.folders;
        if (_folder.length > 1 && !folders.contains(_folder)) _folder = '';
        final shown = _shown;
        final hasBooks = _store.books.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: theme.appBarTheme.foregroundColor),
                    cursorColor: theme.appBarTheme.foregroundColor,
                    decoration: InputDecoration(
                      hintText: 'Procurar caderno',
                      hintStyle: TextStyle(color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                    ),
                  )
                : const Text('Caderno'),
            actions: [
              if (hasBooks)
                IconButton(
                  tooltip: _searching ? 'Fechar a busca' : 'Procurar',
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _search.clear();
                  }),
                ),
              if (hasBooks)
                PopupMenuButton<_Sort>(
                  tooltip: 'Ordenar',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Sort.recent, child: Text('Usados por último')),
                    PopupMenuItem(value: _Sort.name, child: Text('Nome')),
                    PopupMenuItem(value: _Sort.created, child: Text('Criados por último')),
                  ],
                ),
            ],
          ),
          floatingActionButton: hasBooks
              ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Novo caderno'))
              : null,
          body: !_store.loaded
              ? const Center(child: CircularProgressIndicator())
              : !hasBooks
                  ? _empty(theme)
                  : SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: CustomScrollView(slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                              sliver: SliverToBoxAdapter(child: _cloudLine(theme)),
                            ),
                            SliverToBoxAdapter(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                                child: Row(children: [
                                  for (final (key, label, icon) in [
                                    ('', 'Todos', null),
                                    ('*', 'Favoritos', Icons.star),
                                    for (final f in folders) (f, f, Icons.folder_outlined),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        avatar: icon == null ? null : Icon(icon, size: 18),
                                        label: Text(label),
                                        selected: _folder == key,
                                        onSelected: (_) => setState(() => _folder = key),
                                      ),
                                    ),
                                ]),
                              ),
                            ),
                            if (shown.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                      _search.text.trim().isEmpty ? 'Nenhum caderno aqui ainda.' : 'Nenhum caderno com esse nome.',
                                      style: theme.textTheme.bodyLarge),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(18, 10, 18, 96),
                                sliver: SliverGrid.builder(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 196, mainAxisExtent: 296, crossAxisSpacing: 18, mainAxisSpacing: 18),
                                  itemCount: shown.length,
                                  itemBuilder: (context, i) => _BookCard(
                                    key: ValueKey(shown[i].id),
                                    store: _store,
                                    book: shown[i],
                                    details: _details(shown[i]),
                                    onOpen: () => _open(shown[i]),
                                    onMenu: () => _menu(shown[i]),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

/// Um caderno na estante: capa desenhada, a primeira página aparecendo no canto, nome e detalhes.
class _BookCard extends StatelessWidget {
  final NotebookStore store;
  final NbBook book;
  final String details;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  const _BookCard({super.key, required this.store, required this.book, required this.details, required this.onOpen, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Caderno ${book.title}, $details',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        onLongPress: onMenu,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(2, 5))],
                ),
                child: CustomPaint(painter: NbCoverPainter(Color(book.coverColor), book.coverStyle)),
              ),
              // Etiqueta com o nome, como a de um caderno de verdade.
              Positioned(
                left: 26,
                right: 30,
                top: 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFBF4DF), borderRadius: BorderRadius.circular(4)),
                  child: Text(book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF2A2212), fontFamily: 'serif', fontSize: 14.5, height: 1.2, fontWeight: FontWeight.w700)),
                ),
              ),
              if (book.pageIds.isNotEmpty)
                Positioned(
                  right: 10,
                  bottom: 10,
                  width: 64,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: FutureBuilder<NbPage>(
                      future: store.page(book, book.pageIds.first),
                      builder: (context, snap) => snap.data == null
                          ? const AspectRatio(aspectRatio: 1 / nbPageRatio, child: ColoredBox(color: Colors.white))
                          : NbPageThumb(page: snap.data!),
                    ),
                  ),
                ),
              if (book.favorite) const Positioned(left: 22, bottom: 12, child: Icon(Icons.star, color: Color(0xFFE8C65A), size: 22)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Opções de ${book.title}',
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: onMenu,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Criar um caderno novo ou mudar nome, capa e pasta de um que já existe.
class _BookSheet extends StatefulWidget {
  final NotebookStore store;
  final NbBook? book;
  final String? title;
  final NbTemplate? template;
  final String folder;
  const _BookSheet({required this.store, this.book, this.title, this.template, this.folder = ''});

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  late final _title = TextEditingController(text: widget.book?.title ?? widget.title ?? '');
  late final _folder = TextEditingController(text: widget.book?.folder ?? widget.folder);
  late int _color = widget.book?.coverColor ?? nbCoverColors.first;
  late int _style = widget.book?.coverStyle ?? 1;
  late NbTemplate _template = widget.book?.template ?? widget.template ?? NbTemplate.ruled;
  late NbPaper _paper = widget.book?.paper ?? NbPaper.white;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final b = widget.book;
    if (b == null) {
      final made = await widget.store.create(
          title: _title.text, coverColor: _color, coverStyle: _style, template: _template, paper: _paper, folder: _folder.text);
      navigator.pop(made);
    } else {
      b
        ..title = _title.text.trim().isEmpty ? b.title : _title.text.trim()
        ..coverColor = _color
        ..coverStyle = _style
        ..folder = _folder.text.trim();
      await widget.store.saveBook(b);
      navigator.pop(b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final creating = widget.book == null;
    final folders = widget.store.folders;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(creating ? 'Novo caderno' : 'Nome, capa e pasta', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 84, height: 118, child: CustomPaint(painter: NbCoverPainter(Color(_color), _style))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _title,
                  autofocus: creating && _title.text.isEmpty,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Estudo de Romanos', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _folder,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Pasta (opcional)', hintText: 'Ex.: EBD, Sermões', border: OutlineInputBorder()),
                ),
                if (folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, children: [
                      for (final f in folders) ActionChip(label: Text(f), onPressed: () => setState(() => _folder.text = f)),
                    ]),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Text('Cor da capa', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(children: [
            for (final c in nbCoverColors)
              Semantics(
                button: true,
                selected: c == _color,
                label: 'Cor da capa',
                child: InkResponse(
                  radius: 26,
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Container(
                      width: c == _color ? 38 : 32,
                      height: c == _color ? 38 : 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: c == _color ? scheme.primary : scheme.outlineVariant, width: c == _color ? 3 : 1),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text('Estilo da capa', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, name) in nbCoverStyles.indexed)
              ChoiceChip(label: Text(name), selected: _style == i, onSelected: (_) => setState(() => _style = i)),
          ]),
          if (creating) ...[
            const SizedBox(height: 14),
            Text('Folhas', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: NbTemplate.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final t = NbTemplate.values[i];
                  final on = t == _template;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _template = t),
                    child: SizedBox(
                      width: 86,
                      child: Column(children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: on ? scheme.primary : scheme.outlineVariant, width: on ? 2.5 : 1),
                          ),
                          child: NbPageThumb(page: NbPage('n$i-${_paper.index}', t, _paper, const [], 0)),
                        ),
                        const SizedBox(height: 6),
                        Text(t.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<NbPaper>(
              showSelectedIcon: false,
              segments: [for (final p in NbPaper.values) ButtonSegment(value: p, label: Text('Papel ${p.label.toLowerCase()}'))],
              selected: {_paper},
              onSelectionChanged: (v) => setState(() => _paper = v.first),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(creating ? 'Criar caderno' : 'Salvar')),
          ),
        ]),
      ),
    );
  }
}
