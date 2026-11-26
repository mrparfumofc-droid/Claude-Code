import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bible.dart' show canonicalBooks, normalizeForSearch;
import '../services/timeline.dart';
import '../theme.dart';
import '../widgets/portrait.dart';
import '../widgets/study_art.dart';
import 'panorama_diagrams.dart' show TabernacleScreen;
import 'panorama_kings.dart';
import 'panorama_nt.dart';
import 'panorama_presenter.dart';
import 'panorama_tree.dart';
import 'stories_screen.dart';

const _icons = <String, IconData>{
  'public': Icons.public,
  'groups': Icons.groups_2,
  'landscape': Icons.landscape,
  'shield': Icons.shield,
  'account_balance': Icons.account_balance,
  'call_split': Icons.call_split,
  'lock_clock': Icons.lock_clock,
  'home_work': Icons.home_work,
  'hourglass_bottom': Icons.hourglass_bottom,
  'wb_sunny': Icons.wb_sunny,
  'local_fire_department': Icons.local_fire_department,
  'mail': Icons.mail_outline,
  'volunteer_activism': Icons.volunteer_activism,
  'gavel': Icons.gavel,
  'castle': Icons.castle,
  'auto_stories': Icons.auto_stories,
  'campaign': Icons.campaign,
};

IconData _iconOf(TimeEra e) => _icons[e.icon] ?? Icons.history_edu;

/// Linha do tempo: as épocas da Bíblia e da história da igreja, cada uma com os seus
/// acontecimentos datados, ilustrados e ligados ao texto bíblico.
class BibleTimelineScreen extends StatefulWidget {
  const BibleTimelineScreen({super.key});

  @override
  State<BibleTimelineScreen> createState() => _BibleTimelineScreenState();
}

class _BibleTimelineScreenState extends State<BibleTimelineScreen> {
  static const _prefKey = 'panorama.epoca';
  final _search = TextEditingController();
  final _pane = ScrollController();
  final _chips = ScrollController();
  TimelineData? _data;
  int _sel = 0;
  bool _searching = false;
  String _query = '';
  List<GlobalKey> _keys = const [];
  final _chipKeys = <int, GlobalKey>{};
  int? _flash; // acontecimento realçado depois de vir da busca

  @override
  void initState() {
    super.initState();
    TimelineData.load().then((d) async {
      String? last;
      try {
        last = (await SharedPreferences.getInstance()).getString(_prefKey);
      } catch (_) {}
      if (!mounted) return;
      final i = d.eras.indexWhere((e) => e.id == last);
      setState(() {
        _data = d;
        _sel = i < 0 ? 0 : i;
        _keys = [for (final _ in d.eras[_sel].events) GlobalKey()];
      });
      _showChip();
    });
  }

  /// No celular, traz para a vista o botão da época escolhida.
  void _showChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[_sel]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _pane.dispose();
    _chips.dispose();
    super.dispose();
  }

  void _select(int i, {int? event}) {
    final d = _data!;
    setState(() {
      _sel = i;
      _keys = [for (final _ in d.eras[i].events) GlobalKey()];
      _flash = event;
      _searching = false;
      _query = '';
      _search.clear();
    });
    SharedPreferences.getInstance().then((p) => p.setString(_prefKey, d.eras[i].id)).catchError((_) => false);
    _showChip();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (event == null) {
        if (_pane.hasClients) _pane.jumpTo(0);
        return;
      }
      final ctx = _keys[event].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _flash == event) setState(() => _flash = null);
      });
    });
  }

  void _present(TimeEra e, {int at = 0, bool play = true}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyPresenter(
        title: e.title,
        color: e.color,
        icon: _iconOf(e),
        initialStep: at,
        autoPlay: play,
        steps: [
          PresenterStep(kicker: e.dates, title: e.title, text: e.text, refs: e.refs, people: e.people, art: e.art),
          for (final v in e.events)
            PresenterStep(kicker: v.year, title: v.title, text: v.text, refs: v.refs, people: v.people, art: v.art ?? e.art),
        ],
      ),
    ));
  }

  (String, Widget)? _linkOf(TimeEra e) => switch (e.link) {
        'arvore' => ('Ver a família de Abraão', const FamilyTreeScreen()),
        'tabernaculo' => ('Ver o tabernáculo', const TabernacleScreen()),
        'reis' => ('Ver a linha dos reis', const KingsScreen()),
        'historias' => ('Ver as histórias ilustradas', const StoriesScreen()),
        'nt' => ('Estudar livro por livro', const NtGuideScreen()),
        _ => null,
      };

  /// Acontecimentos que combinam com a busca: (época, índice do acontecimento).
  List<(int, int)> _matches(TimelineData d) {
    final q = normalizeForSearch(_query.trim());
    if (q.length < 2) return const [];
    final out = <(int, int)>[];
    for (var i = 0; i < d.eras.length; i++) {
      final ev = d.eras[i].events;
      for (var k = 0; k < ev.length; k++) {
        final v = ev[k];
        final hay = normalizeForSearch('${v.year} ${v.title} ${v.text} ${v.people.join(' ')}');
        if (hay.contains(q)) out.add((i, k));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- partes da tela

  Widget _rail(TimelineData d, ThemeData theme) {
    final children = <Widget>[];
    String? group;
    for (var i = 0; i < d.eras.length; i++) {
      final e = d.eras[i];
      if (e.group != group) {
        group = e.group;
        final name = d.groups.firstWhere((g) => g.$1 == e.group, orElse: () => (e.group, e.group)).$2;
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 12 : 20, 12, 6),
          child: Text(name.toUpperCase(),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        ));
      }
      final on = i == _sel;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: on ? e.color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _select(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                CircleAvatar(radius: 17, backgroundColor: e.color, child: Icon(_iconOf(e), size: 18, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, fontSize: 14.5, height: 1.15)),
                    Text(e.dates, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                ),
                Text('${e.events.length}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: children);
  }

  // Todos os botões ficam montados (são poucos), para o escolhido poder ser trazido à vista.
  Widget _chipBar(TimelineData d) => SingleChildScrollView(
        controller: _chips,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          for (var i = 0; i < d.eras.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i < d.eras.length - 1 ? 8 : 0),
              child: ChoiceChip(
                key: _chipKeys.putIfAbsent(i, GlobalKey.new),
                avatar: Icon(_iconOf(d.eras[i]), size: 16, color: i == _sel ? Colors.white : d.eras[i].color),
                label: Text(d.eras[i].title),
                selected: i == _sel,
                showCheckmark: false,
                selectedColor: d.eras[i].color,
                labelStyle: TextStyle(color: i == _sel ? Colors.white : null, fontWeight: FontWeight.w600),
                onSelected: (_) => _select(i),
              ),
            ),
        ]),
      );

  Widget _header(TimeEra e) {
    final link = _linkOf(e);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: e.color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              StudyArt(art: e.art, color: e.color, icon: _iconOf(e), large: true, cacheWidth: 1400),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1],
                    colors: [e.color.withValues(alpha: 0), e.color],
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_iconOf(e), color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold, fontFamily: 'serif', height: 1.1)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(e.dates, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(e.text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.45)),
              if (e.people.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final p in e.people) PersonChip(p, radius: 13)]),
              ],
              if (e.books.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Onde ler: ${e.books}', style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [for (final r in e.refs) RefChip(r, color: e.color)]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Apresentar'),
                  onPressed: () => _present(e),
                ),
                if (link != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(link.$1),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => link.$2)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _event(TimeEra e, int k, ThemeData theme, bool roomy) {
    final v = e.events[k];
    final scheme = theme.colorScheme;
    final flash = _flash == k;
    final year = Text(v.year,
        textAlign: roomy ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: e.color, fontWeight: FontWeight.w800, fontSize: roomy ? 14.5 : 13.5, height: 1.2));
    final card = Material(
      key: _keys[k],
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: flash ? e.color : scheme.outlineVariant.withValues(alpha: 0.6), width: flash ? 2.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _present(e, at: k + 1, play: false),
        child: LayoutBuilder(builder: (context, box) {
          final side = box.maxWidth >= 500;
          final art = v.art == null
              ? null
              : StudyArt(art: v.art, color: e.color, icon: _iconOf(e), cacheWidth: 520);
          final body = Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 6),
              Text(v.text, style: const TextStyle(fontSize: 15.5, height: 1.45)),
              if (v.people.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in v.people)
                    PersonChip(p, background: e.color.withValues(alpha: 0.14), foreground: scheme.onSurface, radius: 12),
                ]),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 2, children: [
                for (final r in v.refs) RefChip(r, color: e.color),
                if (v.book != null)
                  ActionChip(
                    avatar: Icon(Icons.school_outlined, size: 16, color: e.color),
                    label: Text('Estudar ${canonicalBooks[v.book! - 1].name}', style: const TextStyle(fontSize: 12.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => NtBookScreen(number: v.book!))),
                  ),
                if (v.story != null)
                  ActionChip(
                    avatar: Icon(Icons.play_circle_outline, size: 16, color: e.color),
                    label: const Text('História ilustrada', style: TextStyle(fontSize: 12.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => openIllustratedStory(context, v.story!),
                  ),
              ]),
            ]),
          );
          if (art == null) return body;
          return side
              ? Stack(children: [
                  Positioned(left: 0, top: 0, bottom: 0, width: 150, child: art),
                  Padding(padding: const EdgeInsets.only(left: 150), child: body),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(height: 140, child: art), body]);
        }),
      ),
    );
    final line = Container(width: 3, color: scheme.outlineVariant);
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: e.color, shape: BoxShape.circle, border: Border.all(color: theme.scaffoldBackgroundColor, width: 3)),
    );
    final gutter = roomy ? 116.0 : 0.0;
    return Stack(children: [
      Positioned(left: gutter + 13.5, top: 0, bottom: 0, child: line),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (roomy) SizedBox(width: gutter, child: Padding(padding: const EdgeInsets.only(top: 14, right: 8), child: year)),
        SizedBox(width: 30, child: Padding(padding: const EdgeInsets.only(top: 15), child: Center(child: dot))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: roomy
                ? card
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(padding: const EdgeInsets.only(top: 12, bottom: 6, left: 2), child: year),
                    card,
                  ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _eraPane(TimelineData d, ThemeData theme) {
    final e = d.eras[_sel];
    return LayoutBuilder(builder: (context, box) {
      final roomy = box.maxWidth >= 640;
      return SingleChildScrollView(
        controller: _pane,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(e),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                child: Text('${e.events.length} acontecimentos · toque num deles para ver em tela cheia',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              for (var k = 0; k < e.events.length; k++) _event(e, k, theme, roomy),
              const SizedBox(height: 6),
              // Passagem para a época vizinha.
              Row(children: [
                if (_sel > 0)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: Text(d.eras[_sel - 1].title, overflow: TextOverflow.ellipsis),
                        onPressed: () => _select(_sel - 1),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (_sel < d.eras.length - 1)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(d.eras[_sel + 1].title, overflow: TextOverflow.ellipsis),
                        onPressed: () => _select(_sel + 1),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Text('Datas aproximadas. As do Antigo Testamento seguem a cronologia tradicional; as da história da igreja, o consenso dos historiadores.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      );
    });
  }

  Widget _results(TimelineData d, ThemeData theme) {
    final found = _matches(d);
    if (_query.trim().length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Digite um nome, um lugar ou um ano: Davi, Pentecostes, Lutero, 1911…',
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }
    if (found.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Nada encontrado para “${_query.trim()}”.', style: theme.textTheme.bodyLarge),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: found.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final (ei, k) = found[i];
        final e = d.eras[ei];
        final v = e.events[k];
        return ListTile(
          leading: CircleAvatar(backgroundColor: e.color, child: Icon(_iconOf(e), color: Colors.white, size: 20)),
          title: Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${v.year} · ${e.title}\n${v.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          onTap: () => _select(ei, event: k),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                cursorColor: fg,
                style: TextStyle(color: fg, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Buscar na linha do tempo',
                  hintStyle: TextStyle(color: fg?.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Linha do tempo'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: _searching ? 'Fechar a busca' : 'Buscar um acontecimento',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                _query = '';
                _search.clear();
              }),
            ),
        ],
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 860;
              final main = _searching ? _results(d, theme) : _eraPane(d, theme);
              if (wide) {
                return Row(children: [
                  SizedBox(width: 292, child: _rail(d, theme)),
                  const VerticalDivider(width: 1),
                  Expanded(child: main),
                ]);
              }
              return Column(children: [
                if (!_searching) _chipBar(d),
                if (!_searching) const Divider(height: 1),
                Expanded(child: main),
              ]);
            }),
    );
  }
}
