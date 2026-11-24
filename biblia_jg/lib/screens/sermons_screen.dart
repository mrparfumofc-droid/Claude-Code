import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/user_db.dart';
import '../models/reference_parser.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'ai_chat_screen.dart';
import 'dictionary_screen.dart' show showBiblePassage;

const _template = '''INTRODUÇÃO
- Como vou prender a atenção:
- A pergunta ou o problema que o texto responde:

1º PONTO:
- Texto:
- Explicação:
- Ilustração:
- Aplicação:

2º PONTO:
- Texto:
- Explicação:
- Ilustração:
- Aplicação:

3º PONTO:
- Texto:
- Explicação:
- Ilustração:
- Aplicação:

CONCLUSÃO
- A ideia central em uma frase:
- Apelo:
''';

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Pregações: os esboços do usuário, com ajuda da IA e um modo púlpito para pregar pelo aparelho.
class SermonsScreen extends StatefulWidget {
  const SermonsScreen({super.key});

  @override
  State<SermonsScreen> createState() => _SermonsScreenState();
}

class _SermonsScreenState extends State<SermonsScreen> {
  late final UserDb _db = context.read<AppState>().db;
  List<Sermon>? _list;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await _db.sermons();
    if (mounted) setState(() => _list = list);
  }

  Future<void> _open(Sermon? s) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SermonEditorScreen(sermon: s)));
    _reload();
  }

  Future<void> _delete(Sermon s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar esta pregação?'),
        content: Text('"${s.title}" será apagada deste aparelho e da sua conta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true && s.id != null) {
      await _db.deleteSermon(s.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _list;
    final q = _query.trim().toLowerCase();
    final list = all == null
        ? null
        : [
            for (final s in all)
              if (q.isEmpty || '${s.title} ${s.passage} ${s.body} ${s.preached}'.toLowerCase().contains(q)) s,
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('Pregações')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nova pregação'),
        onPressed: () => _open(null),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : all!.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.record_voice_over_outlined, size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Seus esboços ficam aqui', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      const Text(
                        'Escreva o esboço, peça ajuda à IA para montar os pontos e pregue pelo modo púlpito, com letra grande e relógio.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Criar a primeira'), onPressed: () => _open(null)),
                    ]),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Procurar por título, texto ou palavra',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final s in list)
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.article_outlined)),
                            title: Text(s.title.isEmpty ? 'Sem título' : s.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              [
                                if (s.passage.isNotEmpty) s.passage,
                                if (s.preached.isNotEmpty) s.preached,
                                'alterada em ${_date(s.updated)}',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _open(s),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'pregar') {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PulpitScreen(sermon: s)));
                                } else if (v == 'apagar') {
                                  _delete(s);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'pregar', child: Text('Modo púlpito')),
                                PopupMenuItem(value: 'apagar', child: Text('Apagar')),
                              ],
                            ),
                          ),
                        ),
                      if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nada encontrado.', textAlign: TextAlign.center)),
                    ]),
                  ),
                ),
    );
  }
}

/// Editor do esboço: título, texto base, onde foi pregada e o corpo. Salva sozinho.
class SermonEditorScreen extends StatefulWidget {
  final Sermon? sermon;
  const SermonEditorScreen({super.key, this.sermon});

  @override
  State<SermonEditorScreen> createState() => _SermonEditorScreenState();
}

class _SermonEditorScreenState extends State<SermonEditorScreen> {
  late final AppState _app = context.read<AppState>();
  late final _title = TextEditingController(text: widget.sermon?.title ?? '');
  late final _passage = TextEditingController(text: widget.sermon?.passage ?? '');
  late final _preached = TextEditingController(text: widget.sermon?.preached ?? '');
  late final _body = TextEditingController(text: widget.sermon?.body ?? '');
  late int? _id = widget.sermon?.id;
  late final DateTime _created = widget.sermon?.created ?? DateTime.now();
  Timer? _debounce;
  bool _dirty = false;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) _save();
    for (final c in [_title, _passage, _preached, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _blank => _title.text.trim().isEmpty && _passage.text.trim().isEmpty && _body.text.trim().isEmpty;

  Sermon get _current => Sermon(
        id: _id,
        title: _title.text.trim(),
        passage: _passage.text.trim(),
        preached: _preached.text.trim(),
        body: _body.text,
        created: _created,
        updated: DateTime.now(),
      );

  Future<void> _save() async {
    _dirty = false;
    if (_blank && _id == null) return;
    _id = await _app.db.saveSermon(_current);
  }

  void _changed() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _save);
  }

  void _insertTemplate() {
    final sep = _body.text.trim().isEmpty ? '' : '\n\n';
    _body.text = '${_body.text.trimRight()}$sep$_template';
    _changed();
    setState(() {});
  }

  void _askAi() {
    final title = _title.text.trim();
    final passage = _passage.text.trim();
    if (title.isEmpty && passage.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escreva o título ou o texto base para a IA ajudar.')));
      return;
    }
    final draft = _body.text.trim();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiChatScreen(
        title: 'Ajuda no esboço',
        task: 'chat',
        reference: passage.isEmpty ? null : passage,
        version: _app.bible?.abbrev,
        useLabel: 'Colocar no esboço',
        onUse: (answer) {
          final sep = _body.text.trim().isEmpty ? '' : '\n\n';
          _body.text = '${_body.text.trimRight()}$sep$answer';
          _changed();
        },
        initialPrompt: 'Ajude-me a preparar um esboço de pregação expositiva'
            '${title.isEmpty ? '' : ' com o título "$title"'}${passage.isEmpty ? '' : ', texto base $passage'}. '
            'Entregue em texto simples, sem tabelas: 1) a ideia central em uma frase; 2) introdução com um jeito de começar; '
            '3) três pontos tirados do próprio texto, cada um com referência, explicação curta, uma ilustração do dia a dia e uma aplicação; '
            '4) conclusão e apelo. Seja fiel ao texto bíblico.'
            '${draft.isEmpty ? '' : '\n\nO que já escrevi (aproveite e melhore):\n${draft.length > 2500 ? draft.substring(0, 2500) : draft}'}',
        quickActions: const [
          ('Mais ilustrações', 'chat', 'Sugira mais três ilustrações do dia a dia para este esboço.'),
          ('Versão para jovens', 'chat', 'Adapte este esboço para um culto de jovens, com linguagem direta.'),
          ('Perguntas para célula', 'chat', 'Transforme este esboço em 6 perguntas para estudo em pequeno grupo.'),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final passage = parseReference(_passage.text.trim().split(RegExp(r'[;,]')).first);
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? 'Nova pregação' : 'Pregação'),
        actions: [
          IconButton(tooltip: 'Ajuda da IA para montar o esboço', icon: const Icon(Icons.auto_awesome), onPressed: _askAi),
          IconButton(
            tooltip: 'Modo púlpito',
            icon: const Icon(Icons.present_to_all),
            onPressed: () async {
              await _save();
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PulpitScreen(sermon: _current)));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'modelo') _insertTemplate();
              if (v == 'enviar') {
                SharePlus.instance.share(ShareParams(
                    text: '${_title.text.trim()}\n${_passage.text.trim()}\n\n${_body.text}'.trim(), subject: _title.text.trim()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'modelo', child: Text('Inserir modelo de esboço')),
              PopupMenuItem(value: 'enviar', child: Text('Compartilhar')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            TextField(
              controller: _title,
              onChanged: (_) => _changed(),
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif'),
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _passage,
                  onChanged: (_) {
                    _changed();
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: 'Texto base',
                    hintText: 'Ex.: Jo 3:16',
                    border: const OutlineInputBorder(),
                    suffixIcon: passage == null
                        ? null
                        : IconButton(
                            tooltip: 'Ler na Bíblia',
                            icon: const Icon(Icons.menu_book),
                            onPressed: () => showBiblePassage(context, passage),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _preached,
                  onChanged: (_) => _changed(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Onde e quando', hintText: 'Ex.: culto de domingo, 30/11', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              onChanged: (_) => _changed(),
              minLines: 16,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17, height: 1.5),
              decoration: const InputDecoration(
                labelText: 'Esboço',
                alignLabelWithHint: true,
                hintText: 'Escreva o esboço. No menu ⋮ há um modelo pronto, e a estrela pede ajuda à IA.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Salva sozinho. As referências (ex.: Rm 8:28) viram toque para abrir a Bíblia no modo púlpito.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

/// Modo púlpito: o esboço em letra grande, com relógio, cronômetro e tela sempre ligada.
class PulpitScreen extends StatefulWidget {
  final Sermon sermon;
  const PulpitScreen({super.key, required this.sermon});

  @override
  State<PulpitScreen> createState() => _PulpitScreenState();
}

class _PulpitScreenState extends State<PulpitScreen> {
  late final AppState _app = context.read<AppState>();
  late double _size = _app.prefs.getDouble('pulpito.letra') ?? 26;
  late bool _dark = _app.prefs.getBool('pulpito.escuro') ?? true;
  final _started = DateTime.now();
  final _taps = <TapGestureRecognizer>[];
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final t in _taps) {
      t.dispose();
    }
    WakelockPlus.toggle(enable: _app.settings.keepScreenOn).catchError((_) {});
    super.dispose();
  }

  void _setSize(double v) {
    setState(() => _size = v.clamp(16, 54));
    _app.prefs.setDouble('pulpito.letra', _size);
  }

  /// Texto com as referências bíblicas tocáveis e os títulos em destaque.
  List<InlineSpan> _spans(String body, Color fg, Color accent) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    for (final line in body.split('\n')) {
      final heading = line.trim().isNotEmpty && line.trim() == line.trim().toUpperCase() && RegExp(r'[A-ZÀ-Ý]').hasMatch(line);
      final style = heading ? TextStyle(color: accent, fontWeight: FontWeight.bold) : null;
      var last = 0;
      for (final (start, end, p) in locateReferences(line)) {
        if (start > last) spans.add(TextSpan(text: line.substring(last, start), style: style));
        final tap = TapGestureRecognizer()..onTap = () => showBiblePassage(context, p);
        _taps.add(tap);
        spans.add(TextSpan(
          text: line.substring(start, end),
          recognizer: tap,
          style: TextStyle(color: accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: accent),
        ));
        last = end;
      }
      spans.add(TextSpan(text: '${line.substring(last)}\n', style: style));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sermon;
    final bg = _dark ? const Color(0xFF0B0F17) : const Color(0xFFFFFBF2);
    final fg = _dark ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B);
    // O corpo vem primeiro: ele renova a lista de toques; o texto base acrescenta o dele depois.
    final bodySpans = _spans(s.body, fg, jgGold);
    final passageSpans = _spansFor(s.passage, fg);
    final now = DateTime.now();
    final e = now.difference(_started);
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final elapsed = '${e.inMinutes.toString().padLeft(2, '0')}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              IconButton(tooltip: 'Sair', color: fg, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              Text(clock, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 14),
              Icon(Icons.timer_outlined, color: jgGold, size: 18),
              const SizedBox(width: 4),
              Text(elapsed, style: const TextStyle(color: jgGold, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()])),
              const Spacer(),
              IconButton(tooltip: 'Letra menor', color: fg, icon: const Icon(Icons.text_decrease), onPressed: () => _setSize(_size - 2)),
              IconButton(tooltip: 'Letra maior', color: fg, icon: const Icon(Icons.text_increase), onPressed: () => _setSize(_size + 2)),
              IconButton(
                tooltip: _dark ? 'Fundo claro' : 'Fundo escuro',
                color: fg,
                icon: Icon(_dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: () {
                  setState(() => _dark = !_dark);
                  _app.prefs.setBool('pulpito.escuro', _dark);
                },
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 80), children: [
                  Text(s.title.isEmpty ? 'Sem título' : s.title,
                      style: TextStyle(color: fg, fontSize: _size * 1.35, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.15)),
                  if (s.passage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 14),
                      child: Text.rich(
                        TextSpan(children: passageSpans),
                        style: TextStyle(color: jgGold, fontSize: _size * 0.9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Text.rich(
                    TextSpan(children: bodySpans),
                    style: TextStyle(color: fg, fontSize: _size, height: 1.5),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Texto base no topo: toca para abrir a passagem.
  List<InlineSpan> _spansFor(String passage, Color fg) {
    final p = parseReference(passage.split(RegExp(r'[;,]')).first.trim());
    if (p == null) return [TextSpan(text: passage)];
    final tap = TapGestureRecognizer()..onTap = () => showBiblePassage(context, p);
    _taps.add(tap);
    return [TextSpan(text: passage, recognizer: tap, style: const TextStyle(decoration: TextDecoration.underline, decorationColor: jgGold))];
  }
}
