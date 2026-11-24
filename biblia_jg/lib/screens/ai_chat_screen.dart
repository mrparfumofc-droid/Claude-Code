import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reference_parser.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import 'dictionary_screen.dart' show showBiblePassage;

/// Conversa com a IA (Gemini). Usada no Estudo bíblico, devocional, histórias etc.
class AiChatScreen extends StatefulWidget {
  final String title;
  final String task;
  final String? reference;
  final String? version;
  final String? verseText;

  /// Primeira pergunta enviada automaticamente ao abrir.
  final String? initialPrompt;

  /// Se informado, a primeira resposta fica guardada no aparelho (ex.: devocional do dia).
  final String? cacheKey;

  /// Atalhos de perguntas mostrados abaixo da resposta.
  final List<(String, String, String)> quickActions; // (rótulo, tarefa, pergunta)

  /// Se informado, aparece um botão para levar a última resposta de volta (ex.: para o esboço da pregação).
  final void Function(String answer)? onUse;
  final String useLabel;

  const AiChatScreen({
    super.key,
    required this.title,
    required this.task,
    this.reference,
    this.version,
    this.verseText,
    this.initialPrompt,
    this.cacheKey,
    this.quickActions = const [],
    this.onUse,
    this.useLabel = 'Usar esta resposta',
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _turns = <AiTurn>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  String? _error;
  String? _lastText;
  String? _lastTask;
  String _profile = 'assembleiano';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _profile = await AiService.profile();
    if (widget.cacheKey != null) {
      final cached = (await SharedPreferences.getInstance()).getString('ai_cache_${widget.cacheKey}');
      if (cached != null && widget.initialPrompt != null) {
        setState(() {
          _turns.add(AiTurn(true, widget.initialPrompt!));
          _turns.add(AiTurn(false, cached));
        });
        return;
      }
    }
    if (widget.initialPrompt != null) await _send(widget.initialPrompt!, widget.task);
    if (mounted) setState(() {});
  }

  Future<void> _send(String text, String task) async {
    if (text.trim().isEmpty || _busy) return;
    _lastText = text.trim();
    _lastTask = task;
    setState(() {
      _turns.add(AiTurn(true, text.trim()));
      _busy = true;
      _error = null;
    });
    _scrollDown();
    try {
      final answer = await AiService.ask(
        task: task,
        messages: _turns,
        reference: widget.reference,
        version: widget.version,
        verseText: widget.verseText,
        profileOverride: _profile,
      );
      if (!mounted) return;
      setState(() => _turns.add(AiTurn(false, answer)));
      if (widget.cacheKey != null && _turns.length == 2) {
        (await SharedPreferences.getInstance()).setString('ai_cache_${widget.cacheKey}', answer);
      }
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.removeLast();
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String get _lastAnswer => _turns.lastWhere((t) => !t.fromUser, orElse: () => const AiTurn(false, '')).text;

  void _openPassage(Passage p) {
    // Abre num painel por cima, para não perder o estudo gerado pela IA.
    showBiblePassage(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bible = context.watch<AppState>().bible;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Perfil teológico',
            icon: const Icon(Icons.school_outlined),
            initialValue: _profile,
            onSelected: (p) {
              setState(() => _profile = p);
              AiService.setProfile(p);
            },
            itemBuilder: (_) => [
              for (final e in aiProfiles.entries)
                CheckedPopupMenuItem(value: e.key, checked: e.key == _profile, child: Text(e.value)),
            ],
          ),
          if (widget.onUse != null)
            IconButton(
              tooltip: widget.useLabel,
              icon: const Icon(Icons.playlist_add_check),
              onPressed: _lastAnswer.isEmpty
                  ? null
                  : () {
                      widget.onUse!(_lastAnswer);
                      Navigator.pop(context);
                    },
            ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: _lastAnswer.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _lastAnswer));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Resposta copiada')));
                  },
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share),
            onPressed: _lastAnswer.isEmpty
                ? null
                : () => SharePlus.instance.share(ShareParams(
                    text: '${widget.title}${widget.reference != null ? ' — ${widget.reference}' : ''}\n\n$_lastAnswer')),
          ),
        ],
      ),
      body: Column(children: [
        if (widget.reference != null)
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.all(12),
            child: Text('${widget.reference}${widget.version != null ? ' (${widget.version})' : ''}\n${widget.verseText ?? ''}',
                maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              for (final t in _turns) _bubble(t, theme, bible),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('A IA está estudando o texto…'),
                  ]),
                ),
              if (_error != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(_error!),
                    trailing: TextButton(
                      onPressed: () {
                        // Repete a última pergunta que falhou (a primeira ou uma seguinte).
                        if (_lastText != null) _send(_lastText!, _lastTask ?? widget.task);
                      },
                      child: const Text('Tentar de novo'),
                    ),
                  ),
                ),
              if (!_busy && _turns.isNotEmpty && widget.quickActions.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (label, task, prompt) in widget.quickActions)
                    ActionChip(label: Text(label), onPressed: () => _send(prompt, task)),
                ]),
              if (!_busy && _turns.any((t) => !t.fromUser))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Resposta gerada por IA: pode conter erros. Confira sempre no texto bíblico (toque nas referências).',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) {
                    if (_busy) return; // não apaga o que foi digitado enquanto a IA responde
                    _send(v, widget.task == 'explain' ? 'explain' : 'chat');
                    _input.clear();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Pergunte algo à IA…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy
                    ? null
                    : () {
                        _send(_input.text, widget.task == 'explain' ? 'explain' : 'chat');
                        _input.clear();
                      },
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(AiTurn t, ThemeData theme, bible) {
    if (t.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(t.text),
        ),
      );
    }
    final refs = findReferences(t.text);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MarkdownBody(data: t.text, selectable: true),
          if (refs.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Abrir na Bíblia', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in refs.take(24))
                ActionChip(
                  avatar: const Icon(Icons.menu_book, size: 16),
                  label: Text(p.label(bible)),
                  onPressed: () => _openPassage(p),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
