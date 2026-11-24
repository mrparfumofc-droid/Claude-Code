import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/account_service.dart';
import '../services/books_service.dart';
import 'account_screen.dart';
import 'pdf_reader_screen.dart';

String _mb(int? bytes) => bytes == null ? '' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Biblioteca: livros em PDF (por pasta) e revistas da EBD (por ano e trimestre).
class LibraryScreen extends StatefulWidget {
  final int initialTab; // 0 = Livros, 1 = EBD
  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BooksService>().refresh();
    });
  }

  Future<void> _add(String kind) async {
    final books = context.read<BooksService>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final name = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final info = await showDialog<_BookInfo>(
      context: context,
      builder: (_) => _BookInfoDialog(
        kind: kind,
        initialTitle: name,
        folders: {for (final b in books.books) if (b.folder != null && b.folder!.isNotEmpty) b.folder!}.toList()..sort(),
      ),
    );
    if (info == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final book = await books.add(
        bytes: bytes,
        title: info.title,
        kind: kind,
        folder: info.folder,
        year: info.year,
        quarter: info.quarter,
      );
      messenger.showSnackBar(SnackBar(content: Text('"${book.title}" salvo na nuvem')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _manage(Book b) async {
    final books = context.read<BooksService>();
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(b.isEbd ? 'Editar título, ano e trimestre' : 'Editar título e pasta'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Apagar da nuvem'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final info = await showDialog<_BookInfo>(
        context: context,
        builder: (_) => _BookInfoDialog(
          kind: b.kind,
          initialTitle: b.title,
          initialFolder: b.folder,
          initialYear: b.year,
          initialQuarter: b.quarter,
          folders: {for (final x in books.books) if (x.folder != null && x.folder!.isNotEmpty) x.folder!}.toList()..sort(),
        ),
      );
      if (info == null) return;
      try {
        await books.update(b, {'title': info.title, 'folder': info.folder, 'year': info.year, 'quarter': info.quarter});
        b
          ..title = info.title
          ..folder = info.folder
          ..year = info.year
          ..quarter = info.quarter;
        setState(() {});
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apagar da nuvem?'),
          content: Text('"${b.title}" e as anotações feitas nele serão apagados para sempre.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await books.remove(b);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _open(Book b) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfReaderScreen(book: b)));

  Widget _tile(Book b) => ListTile(
        leading: Icon(b.isEbd ? Icons.school_outlined : Icons.picture_as_pdf_outlined),
        title: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (b.pages != null) '${b.pages} páginas',
          if (b.lastPage > 1) 'parou na pág. ${b.lastPage}',
          if (b.isEbd && b.lessons.isNotEmpty) '${b.lessons.length} lições',
          _mb(b.bytes),
        ].where((s) => s.isNotEmpty).join(' · ')),
        trailing: IconButton(
          tooltip: 'Opções',
          icon: const Icon(Icons.more_vert),
          onPressed: () => _manage(b),
        ),
        onTap: () => _open(b),
        onLongPress: () => _manage(b),
      );

  Widget _list(BooksService s, String kind) {
    final items = s.books.where((b) => b.kind == kind).toList();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(kind == 'ebd' ? Icons.school_outlined : Icons.menu_book_outlined, size: 64),
            const SizedBox(height: 12),
            Text(
              s.loading
                  ? 'Carregando…'
                  : kind == 'ebd'
                      ? 'Nenhuma revista da EBD ainda.\nToque em "Adicionar revista" e escolha o PDF.'
                      : 'Nenhum livro ainda.\nToque em "Adicionar livro" e escolha o PDF.',
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }
    // Agrupa: livros por pasta; revistas por ano e trimestre.
    final groups = <String, List<Book>>{};
    for (final b in items) {
      final key = kind == 'ebd'
          ? '${b.year ?? 'Sem ano'}${b.quarter == null ? '' : ' · ${b.quarter}º trimestre'}'
          : (b.folder == null || b.folder!.isEmpty ? 'Sem pasta' : b.folder!);
      (groups[key] ??= []).add(b);
    }
    final keys = groups.keys.toList();
    if (kind != 'ebd') keys.sort();
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      for (final k in keys)
        ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(kind == 'ebd' ? Icons.calendar_month : Icons.folder_outlined),
          title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [for (final b in groups[k]!) _tile(b)],
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountService>();
    final s = context.watch<BooksService>();
    if (!account.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Livros e EBD')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_outlined, size: 72),
              const SizedBox(height: 12),
              const Text(
                'Seus livros e revistas da EBD ficam guardados na nuvem, na sua conta Google.\n'
                'Entre com a conta para começar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AccountScreen()))
                    .then((_) => s.refresh()),
                icon: const Icon(Icons.login),
                label: const Text('Entrar com Google'),
              ),
            ]),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Builder(builder: (context) {
        final tab = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Livros e EBD'),
            actions: [
              IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: s.refresh),
            ],
            bottom: const TabBar(tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Livros'),
              Tab(icon: Icon(Icons.school_outlined), text: 'EBD'),
            ]),
          ),
          body: Column(children: [
            if (s.loading || _uploading) const LinearProgressIndicator(),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Enviando o PDF para a nuvem…'),
              ),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(s.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: TabBarView(children: [_list(s, 'livro'), _list(s, 'ebd')]),
                ),
              ),
            ),
          ]),
          floatingActionButton: AnimatedBuilder(
            animation: tab,
            builder: (context, _) => FloatingActionButton.extended(
              onPressed: _uploading ? null : () => _add(tab.index == 1 ? 'ebd' : 'livro'),
              icon: const Icon(Icons.upload_file),
              label: Text(tab.index == 1 ? 'Adicionar revista' : 'Adicionar livro'),
            ),
          ),
        );
      }),
    );
  }
}

class _BookInfo {
  final String title;
  final String? folder;
  final int? year;
  final int? quarter;
  const _BookInfo(this.title, this.folder, this.year, this.quarter);
}

class _BookInfoDialog extends StatefulWidget {
  final String kind;
  final String initialTitle;
  final String? initialFolder;
  final int? initialYear;
  final int? initialQuarter;
  final List<String> folders;
  const _BookInfoDialog({
    required this.kind,
    required this.initialTitle,
    required this.folders,
    this.initialFolder,
    this.initialYear,
    this.initialQuarter,
  });

  @override
  State<_BookInfoDialog> createState() => _BookInfoDialogState();
}

class _BookInfoDialogState extends State<_BookInfoDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _folder = TextEditingController(text: widget.initialFolder ?? '');
  late int _year = widget.initialYear ?? DateTime.now().year;
  late int _quarter = widget.initialQuarter ?? ((DateTime.now().month - 1) ~/ 3 + 1);

  @override
  void dispose() {
    _title.dispose();
    _folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ebd = widget.kind == 'ebd';
    final now = DateTime.now().year;
    return AlertDialog(
      title: Text(ebd ? 'Revista da EBD' : 'Livro'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (ebd)
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: 'Ano', border: OutlineInputBorder()),
                  items: [for (var y = now + 1; y >= now - 10; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (v) => setState(() => _year = v ?? _year),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _quarter,
                  decoration: const InputDecoration(labelText: 'Trimestre', border: OutlineInputBorder()),
                  items: [for (var q = 1; q <= 4; q++) DropdownMenuItem(value: q, child: Text('$qº'))],
                  onChanged: (v) => setState(() => _quarter = v ?? _quarter),
                ),
              ),
            ])
          else ...[
            TextField(
              controller: _folder,
              decoration: const InputDecoration(
                labelText: 'Pasta (opcional)',
                hintText: 'Ex.: Teologia, Devocionais',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.folders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final f in widget.folders)
                  ActionChip(label: Text(f), onPressed: () => setState(() => _folder.text = f)),
              ]),
            ],
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final t = _title.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(
              context,
              _BookInfo(
                t,
                ebd ? null : (_folder.text.trim().isEmpty ? null : _folder.text.trim()),
                ebd ? _year : null,
                ebd ? _quarter : null,
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
