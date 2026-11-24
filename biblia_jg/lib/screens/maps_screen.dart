import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/reference_parser.dart';
import '../services/places.dart';
import '../services/stories.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/parallax_image.dart';
import '../widgets/story_map.dart';
import 'dictionary_screen.dart' show showBiblePassage;
import 'story_player_screen.dart';

void _openRef(BuildContext context, String ref) {
  final p = parseStoryReference(ref);
  if (p != null) showBiblePassage(context, p);
}

// ======================================================================
// Tela inicial dos mapas
// ======================================================================

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  PlacesData? _data;
  StoriesData? _stories;

  @override
  void initState() {
    super.initState();
    PlacesData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
    StoriesData.load().then((s) {
      if (mounted) setState(() => _stories = s);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final theme = Theme.of(context);
    // Viagens: histórias com rota no mapa (Paulo primeiro).
    final journeys = [
      for (final (cat, _, _) in storyCategories)
        for (final s in _stories?.byCategory(cat) ?? const <BibleStory>[])
          if (s.hasMap && s.route) s,
    ];
    Widget section(String title, String subtitle) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Mapas bíblicos')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 900 ? 3 : (box.maxWidth > 560 ? 2 : 1);
              return ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.travel_explore, size: 40),
                    title: const Text('Explorar o mapa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(d.places.isEmpty
                        ? 'Os lugares estão sendo preparados.'
                        : '${d.places.length} lugares bíblicos no mapa de satélite. Toque num lugar para ver os versículos.'),
                    onTap: d.places.isEmpty
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlacesMapScreen(data: d))),
                  ),
                ),
                if (d.stories.isNotEmpty) ...[
                  section('Atlas bíblico', 'Rotas, reinos e regiões lado a lado no satélite'),
                  GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.6,
                    children: [
                      for (final s in d.stories)
                        _MapCard(
                          title: s.title,
                          subtitle: s.subtitle,
                          footer: '${s.steps.length} pontos',
                          color: s.color,
                          icon: Icons.map,
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => AtlasMapScreen(story: s))),
                        ),
                    ],
                  ),
                ],
                if (journeys.isNotEmpty) ...[
                  section('Viagens e rotas', 'A câmera voa de lugar em lugar, com a história narrada e ilustrada'),
                  GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.6,
                    children: [
                      for (final s in journeys)
                        _MapCard(
                          title: s.title,
                          subtitle: s.subtitle,
                          footer: '${s.scenes.length} etapas · ${s.reference}',
                          color: s.color,
                          icon: Icons.play_circle_fill,
                          image: s.hasCover ? s.cover : null,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => BibleStoryPlayer(story: s, startOnMap: true))),
                        ),
                    ],
                  ),
                ],
              ]);
            }),
    );
  }
}

class _MapCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footer;
  final Color color;
  final IconData icon;
  final String? image;
  final VoidCallback onTap;
  const _MapCard({
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.color,
    required this.icon,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            if (image != null) StoryThumb(imageKey: image!, tint: color),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xF20E1626),
                  image != null ? const Color(0x800E1626) : Color.lerp(const Color(0xFF0E1626), color, 0.42)!,
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                Text(footer,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );
}

// ======================================================================
// Atlas: mapa com regiões, rotas e pontos explicados um a um
// ======================================================================

class AtlasMapScreen extends StatefulWidget {
  final MapStory story;
  const AtlasMapScreen({super.key, required this.story});

  @override
  State<AtlasMapScreen> createState() => _AtlasMapScreenState();
}

class _AtlasMapScreenState extends State<AtlasMapScreen> {
  int _step = 0;
  bool _playing = true;
  Timer? _auto;

  MapStory get story => widget.story;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  void _schedule() {
    _auto?.cancel();
    if (!_playing) return;
    _auto = Timer(const Duration(seconds: 11), () {
      if (!mounted) return;
      if (_step < story.steps.length - 1) {
        _goTo(_step + 1);
      } else {
        setState(() => _playing = false);
      }
    });
  }

  void _goTo(int i) {
    if (i < 0 || i >= story.steps.length) return;
    setState(() => _step = i);
    _schedule();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing && _step >= story.steps.length - 1) {
      _goTo(0);
    } else {
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = story.steps;
    final cur = steps[_step];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final panel = Container(
      constraints: const BoxConstraints(maxWidth: 620),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: BoxDecoration(
        color: mapCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: story.color.withValues(alpha: 0.6)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${story.title} · ${_step + 1} de ${steps.length}',
            style: TextStyle(color: story.color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(cur.title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif')),
        const SizedBox(height: 4),
        Text(cur.text, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.35)),
        if (story.lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final l in story.lines)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 18, height: 4, decoration: BoxDecoration(color: l.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 5),
                Text(l.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [
          if (cur.reference.isNotEmpty)
            Flexible(
              child: ActionChip(
                avatar: const Icon(Icons.menu_book, size: 16),
                label: Text(cur.reference, overflow: TextOverflow.ellipsis),
                onPressed: () => _openRef(context, cur.reference),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Ponto anterior',
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.skip_previous),
            onPressed: _step > 0 ? () => _goTo(_step - 1) : null,
          ),
          IconButton.filled(
            tooltip: _playing ? 'Pausar' : 'Tocar',
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          IconButton(
            tooltip: 'Próximo ponto',
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.skip_next),
            onPressed: _step < steps.length - 1 ? () => _goTo(_step + 1) : null,
          ),
        ]),
      ]),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        StoryMapView(
          stops: [for (final s in steps) MapStop(s.place, s.point, s.zoom, s.title, s.reference)],
          index: _step,
          color: story.color,
          route: story.route,
          regions: story.regions,
          lines: story.lines,
          onTapStop: _goTo,
          onReference: (r) => _openRef(context, r),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton.filledTonal(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(story.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
        Align(
          alignment: wide ? Alignment.bottomLeft : Alignment.bottomCenter,
          child: SafeArea(child: panel),
        ),
      ]),
    );
  }
}

// ======================================================================
// Explorar / lugares de um versículo
// ======================================================================

class PlacesMapScreen extends StatefulWidget {
  final PlacesData data;
  final List<Place>? only; // lugares de um versículo
  final String? title;
  const PlacesMapScreen({super.key, required this.data, this.only, this.title});

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  Place? _selected;
  List<Place> _visible = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _updateVisible() {
    if (widget.only != null) {
      setState(() => _visible = widget.only!);
      return;
    }
    final cam = _map.camera;
    final b = cam.visibleBounds;
    // Mais zoom, mais lugares (os mais conhecidos primeiro).
    final limit = (cam.zoom * cam.zoom * 2).clamp(20, 220).round();
    final list = widget.data.places.where((p) => b.contains(p.point)).take(limit).toList();
    setState(() => _visible = list);
  }

  void _onEvent(MapEvent e) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _updateVisible);
  }

  void _focus(Place p) {
    _map.move(p.point, math.max(_map.camera.zoom, 9));
    setState(() => _selected = p);
    _updateVisible();
  }

  Widget _placeSheet(Place p) {
    final app = context.read<AppState>();
    final refs = [
      for (final v in p.verses.take(40))
        if (osisToRef(v) case (final b, final c, final vv)) (Passage(b, c, vv)),
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 280),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: jgGold)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(p.name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'serif')),
          ),
          IconButton(color: Colors.white70, icon: const Icon(Icons.close), onPressed: () => setState(() => _selected = null)),
        ]),
        Text('${p.typeLabel}${p.english != p.name ? ' · ${p.english}' : ''} · citado em ${p.verses.length} versículos',
            style: const TextStyle(color: jgGold, fontSize: 13)),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in refs)
                ActionChip(
                  label: Text(r.label(app.bible), style: const TextStyle(fontSize: 12)),
                  onPressed: () => showBiblePassage(context, r),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final only = widget.only;
    final results = widget.data.search(_search.text);
    final initial = only == null || only.isEmpty ? const LatLng(31.8, 35.2) : only.first.point;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SatMap(
          controller: _map,
          options: MapOptions(
            initialCenter: initial,
            initialZoom: only == null ? 7 : 9,
            initialCameraFit: only != null && only.length > 1
                ? CameraFit.coordinates(coordinates: [for (final p in only) p.point], padding: const EdgeInsets.all(90), maxZoom: 11)
                : null,
            minZoom: 2,
            maxZoom: 15,
            backgroundColor: const Color(0xFF0B1A2B),
            onMapReady: _updateVisible,
            onMapEvent: _onEvent,
            onTap: (_, _) => setState(() => _selected = null),
          ),
          layers: [
            MarkerLayer(markers: [
              for (final p in _visible)
                Marker(
                  point: p.point,
                  width: only != null ? 260 : 150,
                  height: only != null ? 90 : 34,
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = p),
                    child: only != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            const PulseDot(color: jgGold, size: 14),
                            Flexible(child: LabelCard(title: p.name, subtitle: p.typeLabel, color: jgGold)),
                          ])
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: _selected == p ? 16 : 10,
                              height: _selected == p ? 16 : 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selected == p ? jgGold : Colors.white,
                                border: Border.all(color: Colors.black54),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                            ),
                          ]),
                  ),
                ),
            ]),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton.filledTonal(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                if (only != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.title ?? 'Lugares do versículo',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: mapCardBg,
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        hintText: 'Buscar lugar (ex.: Betel, Nínive)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
              ]),
              if (only == null && _search.text.trim().isNotEmpty)
                Container(
                  width: 340,
                  margin: const EdgeInsets.only(left: 56, top: 4),
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(color: mapCardBg, borderRadius: BorderRadius.circular(12)),
                  child: ListView(shrinkWrap: true, children: [
                    for (final p in results)
                      ListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${p.typeLabel} · ${p.english}', style: const TextStyle(color: Colors.white54)),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _search.clear();
                          _focus(p);
                        },
                      ),
                  ]),
                ),
            ]),
          ),
        ),
        if (_selected != null) Align(alignment: Alignment.bottomCenter, child: SafeArea(child: _placeSheet(_selected!))),
      ]),
    );
  }
}

/// Abre o mapa com os lugares citados num versículo (ou avisa se não houver).
/// Recebe o Navigator e o ScaffoldMessenger (e não o contexto), porque a barra
/// de ações do versículo some logo depois do toque.
Future<void> openVersePlaces(NavigatorState navigator, ScaffoldMessengerState messenger, int book, int chapter,
    int verse, String label) async {
  final data = await PlacesData.load();
  final places = data.forVerse(book, chapter, verse);
  if (places.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text('Nenhum lugar do mapa citado em $label.')));
    return;
  }
  await navigator.push(MaterialPageRoute(
    builder: (_) => PlacesMapScreen(data: data, only: places, title: 'Lugares em $label'),
  ));
}
