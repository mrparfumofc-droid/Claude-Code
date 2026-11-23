import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class VersionsScreen extends StatefulWidget {
  const VersionsScreen({super.key});

  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> {
  bool _busy = false;

  Future<void> _import() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final f in files) {
        final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
        await app.importVersion(text, f.name);
      }
      messenger.showSnackBar(const SnackBar(content: Text('Versão importada')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível importar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Versões da Bíblia')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: const Icon(Icons.file_open),
        label: const Text('Importar versão (.json)'),
      ),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: app.versions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhuma versão instalada.\nToque em "Importar versão" e escolha o arquivo .json da Bíblia.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RadioGroup<String>(
                  groupValue: app.bible?.id,
                  onChanged: (id) {
                    if (id != null) app.selectVersion(id);
                  },
                  child: ListView(children: [
                    for (final v in app.versions)
                      RadioListTile<String>(
                        value: v.id,
                        title: Text('${v.abbrev} · ${v.name}'),
                        subtitle: Text(v.builtIn ? 'Incluída no app' : 'Importada'),
                        secondary: v.builtIn
                            ? null
                            : IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => app.removeVersion(v),
                              ),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }
}
