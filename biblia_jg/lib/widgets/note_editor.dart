import 'dart:async';

import 'package:flutter/material.dart';

import '../data/user_db.dart';
import '../models/bible.dart';
import '../state/app_state.dart';

OverlayEntry? _openEntry;
Completer<bool>? _openDone;

/// Onde a caixa pode ficar: inteira dentro da tela (acima do teclado), com folga nas bordas.
Offset clampNoteBox(Offset p, Size screen, Size box, {double bottomInset = 0, double top = 24}) {
  const m = 8.0;
  final maxX = (screen.width - box.width - m).clamp(m, double.infinity);
  final maxY = (screen.height - bottomInset - box.height - m).clamp(top, double.infinity);
  return Offset(p.dx.clamp(m, maxX), p.dy.clamp(top, maxY));
}

/// Abre o editor de anotação numa caixa flutuante que pode ser arrastada pela tela (pela faixa
/// de cima). A Bíblia atrás continua visível e rolável. Retorna true se salvou.
Future<bool> showNoteEditor(BuildContext context, AppState app, VerseRef ref, {Note? existing}) {
  // Só uma caixa por vez.
  _openEntry?.remove();
  _openDone?.complete(false);
  final done = Completer<bool>();
  late OverlayEntry entry;
  void close(bool saved) {
    if (identical(_openEntry, entry)) {
      _openEntry = null;
      _openDone = null;
    }
    entry.remove();
    if (!done.isCompleted) done.complete(saved);
  }

  entry = OverlayEntry(builder: (_) => _NoteBox(app: app, ref: ref, existing: existing, onClose: close));
  _openEntry = entry;
  _openDone = done;
  Overlay.of(context, rootOverlay: true).insert(entry);
  return done.future;
}

class _NoteBox extends StatefulWidget {
  final AppState app;
  final VerseRef ref;
  final Note? existing;
  final void Function(bool saved) onClose;
  const _NoteBox({required this.app, required this.ref, required this.existing, required this.onClose});

  @override
  State<_NoteBox> createState() => _NoteBoxState();
}

class _NoteBoxState extends State<_NoteBox> {
  late final _controller = TextEditingController(text: widget.existing?.text ?? '');
  final _pos = ValueNotifier<Offset?>(null);
  Offset _raw = Offset.zero;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _pos.dispose();
    super.dispose();
  }

  Size _boxSize(Size screen) => Size((screen.width - 24).clamp(280, 520), 330);

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _busy = true;
    final now = DateTime.now();
    await widget.app.saveNote(Note(
      id: widget.existing?.id,
      ref: widget.ref,
      text: text,
      created: widget.existing?.created ?? now,
      updated: now,
    ));
    widget.onClose(true);
  }

  Future<void> _delete() async {
    if (_busy) return;
    _busy = true;
    await widget.app.deleteNote(widget.existing!.id!);
    widget.onClose(true);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final box = _boxSize(screen);
    final inset = mq.viewInsets.bottom;
    final prefs = widget.app.prefs;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final card = Material(
      elevation: 14,
      shadowColor: Colors.black54,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.fromSize(
        size: box,
        child: Column(children: [
          // Faixa de arrastar: segure e leve a caixa para qualquer lado.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _raw = _pos.value ?? Offset.zero,
            onPanUpdate: (d) {
              _raw += d.delta;
              _pos.value = clampNoteBox(_raw, screen, box, bottomInset: inset, top: mq.padding.top + 4);
            },
            onPanEnd: (_) {
              final p = _pos.value;
              if (p == null) return;
              prefs.setDouble('nota.px', p.dx / screen.width);
              prefs.setDouble('nota.py', p.dy / screen.height);
            },
            child: Container(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(children: [
                Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Anotação · ${widget.ref.label(widget.app.bible)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: 'Fechar sem salvar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: () => widget.onClose(false),
                ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Escreva sua anotação…', border: OutlineInputBorder()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
            child: Row(children: [
              if (widget.existing?.id != null) TextButton(onPressed: _delete, child: const Text('Excluir')),
              const Spacer(),
              TextButton(onPressed: () => widget.onClose(false), child: const Text('Cancelar')),
              const SizedBox(width: 4),
              FilledButton(onPressed: _save, child: const Text('Salvar')),
            ]),
          ),
        ]),
      ),
    );

    return ValueListenableBuilder<Offset?>(
      valueListenable: _pos,
      child: card,
      builder: (context, p, child) {
        var at = p;
        if (at == null) {
          final sx = prefs.getDouble('nota.px'), sy = prefs.getDouble('nota.py');
          at = sx != null && sy != null
              ? Offset(sx * screen.width, sy * screen.height)
              : Offset((screen.width - box.width) / 2, screen.height * 0.18);
        }
        // Sempre dentro da tela e acima do teclado (sem mexer onde o usuário deixou).
        final shown = clampNoteBox(at, screen, box, bottomInset: inset, top: mq.padding.top + 4);
        if (p == null) WidgetsBinding.instance.addPostFrameCallback((_) => _pos.value ??= shown);
        return Positioned(left: shown.dx, top: shown.dy, child: child!);
      },
    );
  }
}

/// Mostra as anotações de um versículo, com opção de editar ou criar nova.
Future<void> showVerseNotes(BuildContext context, AppState app, VerseRef ref) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final notes = app.notes[ref.verse] ?? const <Note>[];
      return SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            title: Text('Anotações · ${ref.label(app.bible)}', style: Theme.of(ctx).textTheme.titleMedium),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova anotação',
              onPressed: () {
                Navigator.pop(ctx);
                showNoteEditor(context, app, ref);
              },
            ),
          ),
          for (final n in notes)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(n.text),
              onTap: () {
                Navigator.pop(ctx);
                showNoteEditor(context, app, ref, existing: n);
              },
            ),
        ]),
      );
    },
  );
}
