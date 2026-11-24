import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/account_service.dart';
import '../services/dictionary_service.dart';
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

  /// Entra e sincroniza. Na primeira vez neste aparelho os dados daqui e os da
  /// nuvem são JUNTADOS (nada é apagado de nenhum dos lados).
  Future<void> _signIn() async {
    final account = context.read<AccountService>();
    final app = context.read<AppState>();
    final dict = context.read<DictionaryService>();
    await _run(() async {
      await account.signIn();
      if (!await autoSync(app, account, dict)) {
        throw 'Conta conectada, mas não consegui sincronizar agora. Tento de novo sozinho mais tarde.';
      }
    }, done: 'Conta conectada e dados sincronizados');
  }

  Future<void> _syncNow() async {
    final account = context.read<AccountService>();
    final app = context.read<AppState>();
    final dict = context.read<DictionaryService>();
    await _run(() async {
      if (!await autoSync(app, account, dict)) {
        throw account.sessionExpired
            ? 'Sua sessão venceu. Toque em "Entrar de novo".'
            : 'Não consegui sincronizar. Confira a internet.';
      }
    }, done: 'Tudo sincronizado');
  }

  Future<void> _bringFromCloud() async {
    final account = context.read<AccountService>();
    final app = context.read<AppState>();
    final dict = context.read<DictionaryService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Substituir pelos dados da nuvem?'),
        content: const Text(
            'As marcações, favoritos, anotações, histórico e progresso deste tablet serão trocados pelos da nuvem. '
            'O que só existe neste tablet será apagado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Substituir')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final cloud = await account.pull();
      if (cloud == null) throw 'Ainda não há nada salvo na nuvem.';
      await applySnapshot(app, cloud.data, dict);
      await account.markSynced(cloud.updatedAt, hash: snapshotHash(await localSnapshot(app, dict)));
    }, done: 'Dados da nuvem aplicados');
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountService>();
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
              Text('Entre com a sua conta Google', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Suas marcações, favoritos, anotações, orações, memorização, progresso e ajustes de leitura '
                'ficam salvos na sua conta e aparecem em qualquer aparelho. Nada do que já está neste tablet é apagado.',
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
              Text(account.name ?? 'Conectado', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              Text(account.email ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                account.lastSync == null ? 'Ainda não sincronizado' : 'Última sincronização: ${_when(account.lastSync!)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (account.sessionExpired)
                Card(
                  margin: const EdgeInsets.only(top: 16),
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: const Text('Sua sessão venceu'),
                    subtitle: const Text('Seus dados não estão sendo salvos na nuvem. Entre de novo para continuar.'),
                    trailing: FilledButton(onPressed: busy ? null : _signIn, child: const Text('Entrar de novo')),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sincronizar agora'),
                  subtitle: const Text('Junta o que há neste tablet com o que está na conta'),
                  enabled: !busy,
                  onTap: _syncNow,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Substituir pelos dados da nuvem'),
                  subtitle: const Text('Descarta o que há neste tablet e usa só o que está na conta'),
                  enabled: !busy,
                  onTap: _bringFromCloud,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A sincronização também acontece sozinha quando você abre, volta e sai do app.',
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
