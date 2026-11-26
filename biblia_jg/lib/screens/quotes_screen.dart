import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/quotes.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'verse_image_screen.dart';

const _groupColors = <String, Color>{
  'antiga': Color(0xFF6D4C41),
  'reforma': Color(0xFF1B2A4A),
  'anglicana': Color(0xFF6A1B9A),
  'puritana': Color(0xFF2E7D32),
  'avivamento': Color(0xFFEF6C00),
  'missoes': Color(0xFF00838F),
  'pentecostal': Color(0xFFC62828),
  'outros': Color(0xFF455A64),
  Quote.mineGroup: Color(0xFFB8860B),
};

Color quoteColor(String group) => _groupColors[group] ?? jgNavy;

/// Abre o editor de imagem (o mesmo dos versículos) com a frase.
void openQuoteImage(BuildContext context, Quote q) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => VerseImageScreen(text: q.text, reference: q.author)));

/// Frases de autores cristãos (pais da igreja, reformadores, anglicanos, puritanos, avivalistas,
/// missionários, pentecostais) e as frases que o próprio usuário guarda.
class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  QuotesData? _data;
  String _filter = 'todas'; // todas, fav, minhas ou o id de um grupo
  String _query = '';
  bool _searching = false;
  Set<String> _fav = {};
  List<Quote> _mine = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AppState>().prefs;
    _fav = MyQuotes.favorites(prefs);
    _mine = MyQuotes.mine(prefs);
    QuotesData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _fold(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ', to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  List<Quote> _visible(QuotesData d) {
    final all = [..._mine, ...d.quotes];
    final q = _fold(_query.trim());
    return [
      for (final x in all)
        if ((_filter == 'todas' ||
                (_filter == 'fav' && _fav.contains(x.id)) ||
                (_filter == Quote.mineGroup && x.mine) ||
                x.group == _filter) &&
            (q.isEmpty || _fold('${x.text} ${x.author} ${x.source}').contains(q)))
          x,
    ];
  }

  Future<void> _toggleFav(Quote q) async {
    final set = await MyQuotes.toggleFavorite(context.read<AppState>().prefs, q.id);
    if (mounted) setState(() => _fav = set);
  }

  void _copy(Quote q) {
    Clipboard.setData(ClipboardData(text: q.shareText));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Frase copiada')));
  }

  /// Nova frase do usuário, ou edição de uma já guardada.
  Future<void> _edit([Quote? old]) async {
    final text = TextEditingController(text: old?.text ?? '');
    final author = TextEditingController(text: old?.author ?? '');
    final source = TextEditingController(text: old?.source ?? '');
    final saved = await showDialog<Quote>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'Nova frase' : 'Editar frase'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: text,
                autofocus: old == null,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Frase', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: author,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Autor', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: source,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Livro ou ocasião (opcional)', border: OutlineInputBorder()),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final t = text.text.trim();
              if (t.isEmpty) return;
              final a = author.text.trim();
              Navigator.pop(ctx, Quote(t, a.isEmpty ? 'Autor desconhecido' : a, source: source.text.trim()));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    text.dispose();
    author.dispose();
    source.dispose();
    if (saved == null || !mounted) return;
    final prefs = context.read<AppState>().prefs;
    final list = [..._mine];
    final at = old == null ? -1 : list.indexWhere((q) => q.id == old.id);
    if (at >= 0) {
      list[at] = saved;
    } else {
      list.insert(0, saved);
    }
    await MyQuotes.save(prefs, list);
    if (!mounted) return;
    setState(() {
      _mine = list;
      if (old == null) _filter = Quote.mineGroup;
    });
  }

  Future<void> _delete(Quote q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar esta frase?'),
        content: Text('“${q.text}”', maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final list = [for (final x in _mine) if (x.id != q.id) x];
    await MyQuotes.save(context.read<AppState>().prefs, list);
    if (mounted) setState(() => _mine = list);
  }

  Widget _chip(String id, String label, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 18),
          label: Text(label),
          selected: _filter == id,
          onSelected: (_) => setState(() => _filter = id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(hintText: 'Procurar por palavra ou autor', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Frases'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Fechar a busca' : 'Procurar',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
          ),
          IconButton(tooltip: 'Guardar uma frase minha', icon: const Icon(Icons.add), onPressed: _edit),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final list = _visible(data);
              final two = box.maxWidth >= 860;
              Widget card(Quote q) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _QuoteCard(
                      quote: q,
                      group: data.groupName(q.group),
                      favorite: _fav.contains(q.id),
                      onFavorite: () => _toggleFav(q),
                      onCopy: () => _copy(q),
                      onShare: () => SharePlus.instance.share(ShareParams(text: q.shareText)),
                      onImage: () => openQuoteImage(context, q),
                      onEdit: q.mine ? () => _edit(q) : null,
                      onDelete: q.mine ? () => _delete(q) : null,
                    ),
                  );
              final showDay = _filter == 'todas' && _query.trim().isEmpty;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
                    if (showDay) ...[
                      _DayQuote(quote: data.ofDay(DateTime.now()), onImage: (q) => openQuoteImage(context, q), onCopy: _copy),
                      const SizedBox(height: 14),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _chip('todas', 'Todas'),
                        _chip('fav', 'Favoritas', icon: Icons.favorite),
                        _chip(Quote.mineGroup, 'Minhas frases', icon: Icons.edit_note),
                        for (final (id, name) in data.groups) _chip(id, name),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(children: [
                          Icon(Icons.format_quote, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            _filter == 'fav'
                                ? 'Toque no coração de uma frase para guardá-la aqui.'
                                : _filter == Quote.mineGroup
                                    ? 'Guarde aqui as frases que você ouvir ou ler.'
                                    : 'Nenhuma frase encontrada.',
                            textAlign: TextAlign.center,
                          ),
                          if (_filter == Quote.mineGroup) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('Nova frase')),
                          ],
                        ]),
                      )
                    else if (two)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(children: [for (var i = 0; i < list.length; i += 2) card(list[i])])),
                        const SizedBox(width: 14),
                        Expanded(child: Column(children: [for (var i = 1; i < list.length; i += 2) card(list[i])])),
                      ])
                    else
                      for (final q in list) card(q),
                    const SizedBox(height: 8),
                    Text(
                      'Autores em domínio público, com tradução própria. “Atribuída” quer dizer que a tradição liga a frase '
                      'ao autor, mas não há fonte escrita segura. Para guardar frases de outros autores, use o botão +.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ]),
                ),
              );
            }),
    );
  }
}

/// Destaque do topo: a frase do dia.
class _DayQuote extends StatelessWidget {
  final Quote quote;
  final ValueChanged<Quote> onImage;
  final ValueChanged<Quote> onCopy;
  const _DayQuote({required this.quote, required this.onImage, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final color = quoteColor(quote.group);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, const Color(0xFF0E1626), 0.55)!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FRASE DO DIA',
                style: TextStyle(color: jgGold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('“${quote.text}”',
                  style: const TextStyle(color: Colors.white, fontSize: 21, height: 1.4, fontFamily: 'serif')),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(quote.byline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  if (quote.note.isNotEmpty) Text(quote.note, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              IconButton(
                tooltip: 'Copiar',
                color: Colors.white,
                icon: const Icon(Icons.copy),
                onPressed: () => onCopy(quote),
              ),
              IconButton(
                tooltip: 'Criar imagem para compartilhar',
                color: Colors.white,
                icon: const Icon(Icons.image_outlined),
                onPressed: () => onImage(quote),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final String group;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onImage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _QuoteCard({
    required this.quote,
    required this.group,
    required this.favorite,
    required this.onFavorite,
    required this.onCopy,
    required this.onShare,
    required this.onImage,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = quoteColor(quote.group);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('“${quote.text}”', style: const TextStyle(fontSize: 18, height: 1.42, fontFamily: 'serif')),
                ),
                const SizedBox(height: 10),
                Text(quote.byline, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text([group, if (quote.note.isNotEmpty) quote.note].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Row(children: [
                  IconButton(
                    tooltip: favorite ? 'Tirar das favoritas' : 'Favoritar',
                    icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.redAccent : null),
                    onPressed: onFavorite,
                  ),
                  IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: onCopy),
                  IconButton(tooltip: 'Compartilhar', icon: const Icon(Icons.share), onPressed: onShare),
                  const Spacer(),
                  if (onEdit != null) IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
                  if (onDelete != null)
                    IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
                  TextButton.icon(
                    onPressed: onImage,
                    icon: const Icon(Icons.image_outlined, size: 20),
                    label: const Text('Criar imagem'),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
