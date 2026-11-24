import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/hymn_service.dart';
import '../theme.dart';

/// Hinário: hinos de domínio público + hinários importados pelo usuário.
class HymnalScreen extends StatefulWidget {
  const HymnalScreen({super.key});

  @override
  State<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends State<HymnalScreen> {
  final _search = TextEditingController();
  String? _hymnal;
  bool _onlyFav = false;
  Hymn? _open;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HymnService>().init();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final service = context.read<HymnService>();
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'txt']);
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    setState(() => _importing = true);
    try {
      final bytes = await f.readAsBytes();
      String text;
      if (f.name.toLowerCase().endsWith('.pdf')) {
        final doc = await PdfDocument.openData(bytes);
        final buf = StringBuffer();
        for (final page in doc.pages) {
          buf.writeln((await page.loadStructuredText()).fullText);
          buf.writeln();
        }
        await doc.dispose();
        text = buf.toString();
      } else {
        text = utf8.decode(bytes, allowMalformed: true);
      }
      final name = f.name.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
      final hymns = parseHymnText('novo', text);
      if (!mounted) return;
      if (hymns.isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Não achei hinos numerados ("1 - Título") nesse arquivo.')));
        return;
      }
      final nameCtrl = TextEditingController(text: name);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Encontrei ${hymns.length} hinos'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome do hinário')),
              const SizedBox(height: 12),
              Text('Primeiros: ${hymns.take(4).map((h) => '${h.number}. ${h.title}').join(' · ')}'),
              const SizedBox(height: 8),
              const Text('Fica guardado só na sua conta (ou no tablet, se não estiver conectado).',
                  style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      );
      final finalName = nameCtrl.text.trim().isEmpty ? name : nameCtrl.text.trim();
      nameCtrl.dispose();
      if (ok != true) return;
      await service.saveOwn(finalName, hymns);
      messenger.showSnackBar(SnackBar(content: Text('Hinário "$finalName" importado')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não consegui importar: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _openHymn(Hymn h, bool wide) {
    if (wide) {
      setState(() => _open = h);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(body: SafeArea(child: HymnView(hymn: h)))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<HymnService>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    var results = s.search(_hymnal, _search.text);
    if (_onlyFav) results = results.where((h) => s.favorites.contains(h.id)).toList();
    final own = s.hymnals.where((h) => h.own).toList();

    final list = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Número, título ou trecho do hino',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: const Text('Todos'), selected: _hymnal == null, onSelected: (_) => setState(() => _hymnal = null)),
            ),
            for (final h in s.hymnals)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: h.own ? const Icon(Icons.person, size: 16) : null,
                  label: Text('${h.name} (${h.hymns.length})'),
                  selected: _hymnal == h.id,
                  onSelected: (_) => setState(() => _hymnal = h.id),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: const Icon(Icons.star, size: 16),
                label: const Text('Favoritos'),
                selected: _onlyFav,
                onSelected: (v) => setState(() => _onlyFav = v),
              ),
            ),
          ],
        ),
      ),
      if (s.loading || _importing) const LinearProgressIndicator(),
      if (s.error != null) Padding(padding: const EdgeInsets.all(8), child: Text(s.error!)),
      Expanded(
        child: ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final h = results[i];
            return ListTile(
              selected: wide && _open?.id == h.id,
              leading: CircleAvatar(
                radius: 18,
                child: Text(h.number?.toString() ?? '•', style: const TextStyle(fontSize: 12)),
              ),
              title: Text(h.title),
              subtitle: Text(
                h.stanzas.isEmpty ? '' : h.stanzas.first.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: s.favorites.contains(h.id) ? const Icon(Icons.star, color: jgGold, size: 18) : null,
              onTap: () => _openHymn(h, wide),
            );
          },
        ),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hinário'),
        actions: [
          if (own.isNotEmpty)
            PopupMenuButton<Hymnal>(
              tooltip: 'Apagar hinário importado',
              icon: const Icon(Icons.delete_outline),
              itemBuilder: (_) => [for (final h in own) PopupMenuItem(value: h, child: Text('Apagar "${h.name}"'))],
              onSelected: (h) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Apagar "${h.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
                    ],
                  ),
                );
                if (ok == true) await s.deleteOwn(h);
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: const Icon(Icons.library_add),
        label: const Text('Importar meu hinário'),
      ),
      body: wide
          ? Row(children: [
              SizedBox(width: 380, child: Material(elevation: 1, child: list)),
              const VerticalDivider(width: 1),
              Expanded(
                child: _open == null
                    ? const Center(child: Text('Escolha um hino na lista'))
                    : HymnView(key: ValueKey(_open!.id), hymn: _open!, embedded: true),
              ),
            ])
          : list,
    );
  }
}

/// Letra do hino, com tamanho ajustável e modo apresentação (tela cheia).
class HymnView extends StatefulWidget {
  final Hymn hymn;
  final bool embedded;
  const HymnView({super.key, required this.hymn, this.embedded = false});

  @override
  State<HymnView> createState() => _HymnViewState();
}

class _HymnViewState extends State<HymnView> {
  double _size = 24;

  String get _plain =>
      '${widget.hymn.number == null ? '' : '${widget.hymn.number}. '}${widget.hymn.title}\n\n${widget.hymn.stanzas.join('\n\n')}';

  void _present() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _Presentation(hymn: widget.hymn),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<HymnService>();
    final h = widget.hymn;
    final fav = s.favorites.contains(h.id);
    return Column(children: [
      Material(
        elevation: 1,
        child: Row(children: [
          if (!widget.embedded) const BackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${h.number == null ? '' : '${h.number}. '}${h.title}',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(tooltip: 'Letra menor', icon: const Icon(Icons.text_decrease), onPressed: () => setState(() => _size = (_size - 2).clamp(14, 60))),
          IconButton(tooltip: 'Letra maior', icon: const Icon(Icons.text_increase), onPressed: () => setState(() => _size = (_size + 2).clamp(14, 60))),
          IconButton(
            tooltip: fav ? 'Tirar dos favoritos' : 'Favoritar',
            icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? jgGold : null),
            onPressed: () => s.toggleFavorite(h),
          ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _plain));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hino copiado')));
            },
          ),
          IconButton(tooltip: 'Compartilhar', icon: const Icon(Icons.share), onPressed: () => SharePlus.instance.share(ShareParams(text: _plain))),
          IconButton(tooltip: 'Apresentar (tela cheia)', icon: const Icon(Icons.slideshow), onPressed: _present),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
          children: [
            if (h.author.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Letra: ${h.author}', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
            for (var i = 0; i < h.stanzas.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 32,
                    child: Text('${i + 1}', style: TextStyle(fontSize: _size * 0.6, color: Theme.of(context).hintColor)),
                  ),
                  Expanded(child: Text(h.stanzas[i], style: TextStyle(fontSize: _size, height: 1.45))),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }
}

/// Apresentação: uma estrofe por tela, fundo escuro, letra grande.
class _Presentation extends StatefulWidget {
  final Hymn hymn;
  const _Presentation({required this.hymn});

  @override
  State<_Presentation> createState() => _PresentationState();
}

class _PresentationState extends State<_Presentation> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final h = widget.hymn;
    final n = h.stanzas.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.sizeOf(context).width;
          setState(() => _i = (d.globalPosition.dx > w / 2 ? _i + 1 : _i - 1).clamp(0, n - 1));
        },
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    h.stanzas[_i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 44, height: 1.4),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 8,
              child: Text('${h.number == null ? '' : '${h.number}. '}${h.title}  ·  ${_i + 1}/$n',
                  style: const TextStyle(color: Colors.white54)),
            ),
            Positioned(
              right: 4,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
