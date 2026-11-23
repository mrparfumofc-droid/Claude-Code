import 'package:flutter/material.dart';

import '../data/user_db.dart';
import '../models/bible.dart';
import '../state/app_state.dart';

/// Abre o editor de anotação. Retorna true se salvou.
Future<bool> showNoteEditor(BuildContext context, AppState app, VerseRef ref,
    {Note? existing}) async {
  final controller = TextEditingController(text: existing?.text ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Anotação · ${ref.label(app.bible)}'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Escreva sua anotação…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        if (existing?.id != null)
          TextButton(
            onPressed: () async {
              await app.deleteNote(existing!.id!);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Excluir'),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            final now = DateTime.now();
            await app.saveNote(Note(
              id: existing?.id,
              ref: ref,
              text: text,
              created: existing?.created ?? now,
              updated: now,
            ));
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return saved ?? false;
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
            title: Text('Anotações · ${ref.label(app.bible)}',
                style: Theme.of(ctx).textTheme.titleMedium),
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
