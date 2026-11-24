import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/account_service.dart';
import '../services/sync.dart';
import '../state/app_state.dart';

String _when(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} às ${two(l.hour)}:${two(l.minute)}';
}

/// Conta Google: entrar, sair e sincronizar os dados entre aparelhos.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _working = false;

  Future<void> _run(Future<void> Function() job, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await job();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signIn() async {
    final account = context.read<AccountService>();
    final app = context.read<AppState>();
    await _run(() async {
      await account.signIn();
      final cloud = await account.pull();
      if (cloud == null) {
        await account.push(await localSnapshot(app));
        return;
      }
      if (!mounted) return;
      final useCloud = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Você já tem dados na nuvem'),
          content: Text(
              'Encontrei uma cópia salva em ${_when(cloud.updatedAt)}${cloud.device == null ? '' : ' (${cloud.device})'}.\n\n'
              'Qual você quer manter?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('A deste tablet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('A da nuvem'),
            ),
          ],
        ),
      );
      if (useCloud == true) {
        await applySnapshot(app, cloud.data);
        await account.markSynced(cloud.updatedAt);
      } else {
        await account.push(await localSnapshot(app));
      }
    }, done: 'Conta conectada e dados sincronizados');
  }

  Future<void> _bringFromCloud() async {
    final account = context.read<AccountService>();
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trazer os dados da nuvem?'),
        content: const Text(
            'As marcações, favoritos, anotações, histórico e progresso deste tablet serão trocados pelos da nuvem.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trazer')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final cloud = await account.pull();
      if (cloud == null) throw 'Ainda não há nada salvo na nuvem.';
      await applySnapshot(app, cloud.data);
      await account.markSynced(cloud.updatedAt);
    }, done: 'Dados da nuvem aplicados');
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountService>();
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final busy = _working || account.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta Google')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            if (!account.signedIn) ...[
              const Icon(Icons.account_circle, size: 96),
              const SizedBox(height: 16),
              Text('Entre com a sua conta Google',
                  style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Suas marcações, favoritos, anotações, histórico, progresso e ajustes de leitura '
                'ficam salvos na sua conta e aparecem em qualquer aparelho.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Entrar com Google'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ] else ...[
              CircleAvatar(
                radius: 44,
                backgroundImage: account.photoUrl == null ? null : NetworkImage(account.photoUrl!),
                child: account.photoUrl == null ? const Icon(Icons.person, size: 44) : null,
              ),
              const SizedBox(height: 12),
              Text(account.name ?? 'Conectado',
                  style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              Text(account.email ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                account.lastSync == null
                    ? 'Ainda não sincronizado'
                    : 'Última sincronização: ${_when(account.lastSync!)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Sincronizar agora'),
                  subtitle: const Text('Salva na nuvem o que está neste tablet'),
                  enabled: !busy,
                  onTap: () => _run(() async => account.push(await localSnapshot(app)),
                      done: 'Salvo na nuvem'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Trazer da nuvem'),
                  subtitle: const Text('Usa neste tablet o que está salvo na conta'),
                  enabled: !busy,
                  onTap: _bringFromCloud,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A sincronização também acontece sozinha quando você abre e quando sai do app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _run(account.signOut, done: 'Você saiu da conta'),
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
