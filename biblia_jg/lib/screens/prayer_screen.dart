import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/user_db.dart';
import '../state/app_state.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Diário de oração: pedidos, orações respondidas e um momento de oração guiado.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  List<Prayer>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppState>().db.prayers();
    if (mounted) setState(() => _all = list);
  }

  Future<String?> _ask(String title, String hint, {String initial = '', String ok = 'Salvar'}) async {
    final ctrl = TextEditingController(text: initial);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(ok)),
        ],
      ),
    );
    ctrl.dispose();
    return text;
  }

  Future<void> _add() async {
    final db = context.read<AppState>().db;
    final text = await _ask('Novo pedido de oração', 'Pelo que você quer orar?');
    if (text == null || text.isEmpty) return;
    await db.savePrayer(Prayer(text: text, created: DateTime.now()));
    await _load();
  }

  Future<void> _edit(Prayer p) async {
    final db = context.read<AppState>().db;
    final text = await _ask('Editar pedido', '', initial: p.text);
    if (text == null || text.isEmpty) return;
    await db.savePrayer(Prayer(id: p.id, text: text, created: p.created, answered: p.answered, answer: p.answer));
    await _load();
  }

  Future<void> _answer(Prayer p) async {
    final db = context.read<AppState>().db;
    final text = await _ask('Oração respondida 🙌', 'Como Deus respondeu? (opcional)', ok: 'Marcar como respondida');
    if (text == null) return;
    await db.savePrayer(
        Prayer(id: p.id, text: p.text, created: p.created, answered: DateTime.now(), answer: text.isEmpty ? null : text));
    await _load();
  }

  Future<void> _reopen(Prayer p) async {
    await context.read<AppState>().db.savePrayer(Prayer(id: p.id, text: p.text, created: p.created));
    await _load();
  }

  Future<void> _delete(Prayer p) async {
    final db = context.read<AppState>().db;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar este pedido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await db.deletePrayer(p.id!);
    await _load();
  }

  Widget _tile(Prayer p) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          leading: Icon(p.answered == null ? Icons.volunteer_activism_outlined : Icons.check_circle,
              color: p.answered == null ? null : Colors.green),
          title: Text(p.text),
          subtitle: Text(p.answered == null
              ? 'Desde ${_date(p.created)}'
              : 'Respondida em ${_date(p.answered!)}${p.answer == null ? '' : '\n${p.answer}'}'),
          isThreeLine: p.answer != null,
          trailing: PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'answer' => _answer(p),
              'reopen' => _reopen(p),
              'edit' => _edit(p),
              _ => _delete(p),
            },
            itemBuilder: (_) => [
              if (p.answered == null)
                const PopupMenuItem(value: 'answer', child: Text('Marcar como respondida'))
              else
                const PopupMenuItem(value: 'reopen', child: Text('Voltar a orar por isso')),
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(value: 'delete', child: Text('Apagar')),
            ],
          ),
          onTap: p.answered == null ? () => _answer(p) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final open = all?.where((p) => p.answered == null).toList() ?? const <Prayer>[];
    final answered = all?.where((p) => p.answered != null).toList() ?? const <Prayer>[];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diário de oração'),
          bottom: TabBar(tabs: [
            Tab(text: 'Em oração (${open.length})'),
            Tab(text: 'Respondidas (${answered.length})'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Novo pedido'),
        ),
        body: all == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: TabBarView(children: [
                    ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
                      if (open.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          child: FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(fullscreenDialog: true, builder: (_) => PrayerMoment(prayers: open))),
                            icon: const Icon(Icons.self_improvement),
                            label: const Text('Orar agora (sem distrações)'),
                          ),
                        ),
                      if (open.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Anote aqui seus pedidos de oração.\nQuando Deus responder, marque como respondida e guarde o testemunho.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final p in open) _tile(p),
                    ]),
                    ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
                      if (answered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('As orações respondidas aparecem aqui, como memorial.', textAlign: TextAlign.center),
                        ),
                      for (final p in answered) _tile(p),
                    ]),
                  ]),
                ),
              ),
      ),
    );
  }
}

/// Momento de oração: um pedido por vez, tela escura, com o tempo correndo.
class PrayerMoment extends StatefulWidget {
  final List<Prayer> prayers;
  const PrayerMoment({super.key, required this.prayers});

  @override
  State<PrayerMoment> createState() => _PrayerMomentState();
}

class _PrayerMomentState extends State<PrayerMoment> {
  int _i = 0;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.prayers.length;
    final p = widget.prayers[_i];
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              Text('$mm:$ss', style: const TextStyle(color: Colors.white54, fontSize: 18)),
              const Spacer(),
              Text('${_i + 1} de $n', style: const TextStyle(color: Colors.white54)),
              IconButton(
                tooltip: 'Encerrar',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: SingleChildScrollView(
                    child: Text(p.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.4, fontFamily: 'serif')),
                  ),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(
                onPressed: _i > 0 ? () => setState(() => _i--) : null,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Anterior'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => _i < n - 1 ? setState(() => _i++) : Navigator.pop(context),
                child: Text(_i < n - 1 ? 'Próximo pedido' : 'Amém'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
