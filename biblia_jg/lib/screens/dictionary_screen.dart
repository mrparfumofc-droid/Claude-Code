import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reader_settings.dart';
import '../models/reference_parser.dart';
import '../services/dictionary_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'reader_view.dart';

/// Abre a Bíblia num painel por cima (para as referências dos verbetes).
Future<void> showBiblePassage(BuildContext context, Passage p) async {
  final app = context.read<AppState>();
  await app.goTo(p.book, p.chapter, verse: p.verse);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.8,
      child: Column(children: [
        ListTile(
          title: Text(p.label(app.bible), style: Theme.of(ctx).textTheme.titleMedium),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
        ),
        const Divider(height: 1),
        Expanded(child: ReaderView(onScrollDirection: (_) {})),
      ]),
    ),
  );
}

/// Dicionários bíblicos: lista com busca e leitura do verbete no estilo da Bíblia.
class DictionaryScreen extends StatefulWidget {
  final String? initialQuery;
  const DictionaryScreen({super.key, this.initialQuery});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  late String _query = widget.initialQuery ?? '';
  Timer? _debounce;
  String? _dict; // null = todos
  bool _inText = false;
  bool _onlyMarked = false;
  DictEntry? _open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DictionaryService>().init();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _select(DictEntry e, bool wide) {
    if (wide) {
      setState(() => _open = e);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(e.term)),
          body: EntryView(entry: e),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DictionaryService>();
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    var results = s.search(_dict, _query, inText: _inText);
    if (_onlyMarked) results = results.where((e) => s.marks.containsKey(e.id)).toList();
    final names = {for (final d in s.dicts) d.code: d.name};

    final list = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          onChanged: (_) {
            // Espera a pessoa parar de digitar (a busca no texto é pesada).
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _query = _search.text);
            });
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar palavra (ex.: graça, Arão)',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: const Text('Todos'), selected: _dict == null, onSelected: (_) => setState(() => _dict = null)),
            ),
            for (final d in s.dicts)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(d.name),
                  tooltip: d.about,
                  selected: _dict == d.code,
                  onSelected: (_) => setState(() => _dict = d.code),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(spacing: 6, children: [
          FilterChip(
            label: const Text('Buscar dentro do texto'),
            selected: _inText,
            onSelected: (v) => setState(() => _inText = v),
          ),
          FilterChip(
            avatar: const Icon(Icons.star, size: 16),
            label: const Text('Só marcados'),
            selected: _onlyMarked,
            onSelected: (v) => setState(() => _onlyMarked = v),
          ),
        ]),
      ),
      if (s.loading) const LinearProgressIndicator(),
      if (s.error != null) Padding(padding: const EdgeInsets.all(12), child: Text(s.error!)),
      Expanded(
        child: results.isEmpty && !s.loading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.dicts.isEmpty ? 'Os dicionários ainda estão sendo preparados.' : 'Nada encontrado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final e = results[i];
                  final m = s.marks[e.id];
                  return ListTile(
                    dense: true,
                    selected: wide && _open?.id == e.id,
                    title: Text(e.term, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _dict == null ? '${names[e.dict] ?? e.dict} · ${e.text}' : e.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: m == null
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            if (m.favorite) Icon(Icons.star, size: 16, color: theme.colorScheme.secondary),
                            if (m.note.isNotEmpty) const Icon(Icons.edit_note, size: 16),
                            if (m.colors.isNotEmpty) Icon(Icons.circle, size: 12, color: highlightColors[m.colors.values.first % highlightColors.length]),
                          ]),
                    onTap: () => _select(e, wide),
                  );
                },
              ),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Dicionário bíblico')),
      body: wide
          ? Row(children: [
              SizedBox(width: 380, child: Material(elevation: 1, child: list)),
              const VerticalDivider(width: 1),
              Expanded(
                child: _open == null
                    ? const Center(child: Text('Escolha uma palavra na lista'))
                    : EntryView(key: ValueKey(_open!.id), entry: _open!),
              ),
            ])
          : list,
    );
  }
}

/// Leitura de um verbete: parágrafos com marcação em cores, anotação,
/// favorito e referências bíblicas que abrem a Bíblia.
class EntryView extends StatefulWidget {
  final DictEntry entry;
  const EntryView({super.key, required this.entry});

  @override
  State<EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<EntryView> {
  int? _selected;

  DictEntry get e => widget.entry;

  Future<void> _editNote(DictionaryService s, DictMark m) async {
    final ctrl = TextEditingController(text: m.note);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anotação — ${e.term}'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escreva sua anotação'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null) return;
    m.note = text;
    await s.saveMark(e, m);
  }

  List<InlineSpan> _spans(String text, TextStyle base, Color link) {
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final (start, end, p) in locateReferences(text)) {
      if (start > pos) spans.add(TextSpan(text: text.substring(pos, start)));
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: TextStyle(color: link, decoration: TextDecoration.underline, decorationColor: link),
        recognizer: TapGestureRecognizer()..onTap = () => showBiblePassage(context, p),
      ));
      pos = end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DictionaryService>();
    final settings = context.select<AppState, ReaderSettings>((a) => a.settings);
    final theme = Theme.of(context);
    final m = s.markOf(e);
    final night = theme.brightness == Brightness.dark;
    final bg = night ? theme.colorScheme.surface : settings.background;
    final fg = night ? theme.colorScheme.onSurface : settings.foreground;
    final style = TextStyle(
      fontSize: settings.fontSize * 0.9,
      height: settings.lineHeight,
      fontFamily: settings.fontFamily,
      color: fg,
    );
    final link = night ? theme.colorScheme.primary : const Color(0xFF1565C0);
    final paras = e.paragraphs;
    final dictName = s.dicts.where((d) => d.code == e.dict).map((d) => d.name).firstOrNull ?? e.dict;

    return ColoredBox(
      color: bg,
      child: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.term,
                        style: style.copyWith(fontSize: style.fontSize! * 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$dictName${e.english != e.term ? ' · no original: ${e.english}' : ''}',
                        style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 13)),
                  ]),
                ),
                IconButton(
                  tooltip: m.favorite ? 'Tirar dos favoritos' : 'Favoritar',
                  icon: Icon(m.favorite ? Icons.star : Icons.star_border, color: m.favorite ? jgGold : fg),
                  onPressed: () {
                    m.favorite = !m.favorite;
                    s.saveMark(e, m);
                  },
                ),
                IconButton(
                  tooltip: 'Anotar',
                  icon: Icon(Icons.edit_note, color: fg),
                  onPressed: () => _editNote(s, m),
                ),
              ]),
              if (m.note.trim().isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  color: jgGold.withValues(alpha: 0.15),
                  child: ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Minha anotação'),
                    subtitle: Text(m.note),
                    onTap: () => _editNote(s, m),
                  ),
                ),
              const SizedBox(height: 16),
              for (var i = 0; i < paras.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _selected = _selected == i ? null : i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.colors[i] == null
                          ? null
                          : highlightColors[m.colors[i]! % highlightColors.length].withValues(alpha: night ? 0.35 : 0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: _selected == i ? Border(bottom: BorderSide(color: fg, width: 1.5)) : null,
                    ),
                    child: Text.rich(TextSpan(style: style, children: _spans(paras[i], style, link))),
                  ),
                ),
            ],
          ),
        ),
        if (_selected != null)
          Material(
            elevation: 6,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  for (var c = 0; c < highlightColors.length; c++)
                    GestureDetector(
                      onTap: () {
                        m.colors[_selected!] = c;
                        s.saveMark(e, m);
                        setState(() => _selected = null);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: highlightColors[c], shape: BoxShape.circle),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Tirar a cor',
                    icon: const Icon(Icons.format_color_reset),
                    onPressed: () {
                      m.colors.remove(_selected);
                      s.saveMark(e, m);
                      setState(() => _selected = null);
                    },
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${paras[_selected!]}\n— ${e.term} ($dictName)'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado')));
                      setState(() => _selected = null);
                    },
                  ),
                  IconButton(
                    tooltip: 'Compartilhar',
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      SharePlus.instance.share(ShareParams(text: '${paras[_selected!]}\n— ${e.term} ($dictName)'));
                      setState(() => _selected = null);
                    },
                  ),
                  IconButton(
                    tooltip: 'Anotar',
                    icon: const Icon(Icons.edit_note),
                    onPressed: () {
                      setState(() => _selected = null);
                      _editNote(s, m);
                    },
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selected = null),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
