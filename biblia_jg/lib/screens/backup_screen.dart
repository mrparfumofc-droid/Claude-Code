import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  String _fileName() {
    final d = DateTime.now();
    return 'backup-biblia-jg-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
  }

  Future<Uint8List> _exportBytes() async {
    final data = await context.read<AppState>().db.exportAll();
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(data)));
  }

  Future<void> _run(Future<void> Function() job, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await job();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDevice() => _run(() async {
        final bytes = await _exportBytes();
        final uri = await FilePicker.saveFile(
            fileName: _fileName(), bytes: bytes, mimeType: 'application/json');
        if (uri == null) throw 'salvamento cancelado';
      }, 'Backup salvo');

  Future<void> _share() => _run(() async {
        final bytes = await _exportBytes();
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, name: _fileName(), mimeType: 'application/json')],
          fileNameOverrides: [_fileName()],
          subject: 'Backup Bíblia JG',
        ));
      }, 'Backup pronto para enviar');

  Future<void> _restore() async {
    final app = context.read<AppState>();
    final files = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: const ['json']);
    if (files.isEmpty || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text(
            'Suas marcações, favoritos, anotações, histórico e progresso atuais serão substituídos pelos do backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final text = utf8.decode(await files.first.readAsBytes());
      await app.restoreBackup(jsonDecode(text) as Map<String, dynamic>);
    }, 'Backup restaurado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_busy) const LinearProgressIndicator(),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                  'O backup guarda suas marcações, favoritos, anotações, histórico e progresso de leitura. '
                  'Entrando com a conta Google (no menu), isso também é salvo sozinho na sua conta.'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Salvar backup no tablet'),
                subtitle: const Text('Escolha uma pasta (ex.: Downloads ou Google Drive)'),
                onTap: _busy ? null : _saveToDevice,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Enviar backup'),
                subtitle: const Text('WhatsApp, e-mail, Drive…'),
                onTap: _busy ? null : _share,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restaurar backup'),
                subtitle: const Text('Escolha um arquivo de backup .json'),
                onTap: _busy ? null : _restore,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
