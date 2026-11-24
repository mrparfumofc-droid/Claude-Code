import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../services/updater.dart';

/// Procura atualização e, se houver, mostra o aviso.
/// Com [silentIfNone] = false, também avisa quando já está atualizado.
Future<void> checkForUpdates(BuildContext context, {bool silentIfNone = true}) async {
  UpdateInfo? info;
  try {
    info = await Updater().check();
  } catch (_) {
    info = null;
  }
  if (!context.mounted) return;
  if (info == null) {
    if (!silentIfNone) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já está com a versão mais recente.')));
    }
    return;
  }
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(info: info!),
  );
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  bool _running = false;
  double? _progress;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _error = null;
      _progress = 0;
    });
    try {
      _sub = OtaUpdate()
          .execute(
        widget.info.apkUrl,
        destinationFilename: 'biblia-jg-update.apk',
        sha256checksum: widget.info.sha256,
      )
          .listen((e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              _progress = (double.tryParse(e.value ?? '') ?? 0) / 100;
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              _progress = 1;
              Navigator.of(context).pop();
            case OtaStatus.ALREADY_RUNNING_ERROR:
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _fail('Permita que o app instale atualizações e tente de novo.');
            case OtaStatus.CHECKSUM_ERROR:
              _fail('O arquivo baixado veio corrompido. Tente de novo.');
            case OtaStatus.CANCELED:
              _fail('Download cancelado.');
            default:
              _fail('Não foi possível atualizar: ${e.value ?? e.status.name}');
          }
        });
      }, onError: (Object e) {
        if (mounted) setState(() => _fail('Não foi possível atualizar: $e'));
      });
    } catch (e) {
      _fail('Não foi possível atualizar: $e');
    }
  }

  void _fail(String msg) {
    _running = false;
    _progress = null;
    _error = msg;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.system_update, size: 40),
      title: const Text('Nova versão disponível'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('A versão ${widget.info.build} da Bíblia JG está pronta'
              '${widget.info.sizeBytes > 0 ? ' (${widget.info.sizeLabel})' : ''}.'),
          const SizedBox(height: 8),
          const Text('Suas marcações, anotações e configurações são mantidas.'),
          if (_running) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Text('Baixando… ${((_progress ?? 0) * 100).round()}%'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
      ),
      actions: [
        if (!_running)
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: const Text('Depois')),
        if (_running)
          TextButton(
            onPressed: () {
              OtaUpdate().cancel();
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          )
        else
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.download),
            label: Text(_error == null ? 'Atualizar' : 'Tentar de novo'),
          ),
      ],
    );
  }
}
