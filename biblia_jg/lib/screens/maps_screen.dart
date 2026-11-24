import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/reference_parser.dart';
import '../services/places.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'dictionary_screen.dart' show showBiblePassage;

const _tileUrl = 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2020_3857/default/g/{z}/{y}/{x}.jpg';
const _credit = 'Satélite: Sentinel-2 cloudless – s2maps.eu, EOX (Copernicus 2020) · Lugares: OpenBible.info (CC BY)';
const _cardBg = Color(0xE60E1626);

/// Mapa de satélite com os créditos.
class _SatMap extends StatelessWidget {
  final MapController controller;
  final MapOptions options;
  final List<Widget> layers;
  const _SatMap({required this.controller, required this.options, required this.layers});

  @override
  Widget build(BuildContext context) => Stack(children: [
        FlutterMap(
          mapController: controller,
          options: options,
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: 'com.jgcompany.biblia_jg',
              maxNativeZoom: 15,
            ),
            ...layers,
          ],
        ),
        Positioned(
          left: 6,
          bottom: 2,
          child: IgnorePointer(
            child: Text(_credit, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8))),
          ),
        ),
      ]);
}

/// Ponto que pulsa (como no vídeo de referência).
class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseDot({required this.color, this.size = 18});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return SizedBox(
            width: widget.size * 3,
            height: widget.size * 3,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: widget.size * (1 + 2 * t),
                height: widget.size * (1 + 2 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: widget.color, width: 3),
                  boxShadow: [BoxShadow(color: widget.color, blurRadius: 14, spreadRadius: 2)],
                ),
              ),
            ]),
          );
        },
      );
}

/// Etiqueta no estilo do vídeo: nome grande, legenda colorida e referência.
class _LabelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? reference;
  final Color color;
  final VoidCallback? onReference;
  const _LabelCard({required this.title, required this.color, this.subtitle, this.reference, this.onReference});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: TextStyle(color: color, fontSize: 13, height: 1.25)),
            ),
          if (reference != null && reference!.isNotEmpty)
            GestureDetector(
              onTap: onReference,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.menu_book, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(reference!,
                      style: TextStyle(
                          color: color, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline,
                          decorationColor: color)),
                ]),
              ),
            ),
        ]),
      );
}

void _openRef(BuildContext context, String ref) {
  final p = parseReference(ref);
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

  @override
  void initState() {
    super.initState();
    PlacesData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Mapas bíblicos')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
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
              const SizedBox(height: 12),
              Text('Histórias no mapa', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    for (final s in d.stories)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryPlayerScreen(story: s))),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(colors: [const Color(0xFF0E1626), s.color.withValues(alpha: 0.55)]),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.play_circle_fill, color: s.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(s.subtitle, style: const TextStyle(color: Colors.white70)),
                            const Spacer(),
                            Text('${s.steps.length} etapas', style: TextStyle(color: s.color, fontSize: 12)),
                          ]),
                        ),
                      ),
                  ],
                );
              }),
            ]),
    );
  }
}

// ======================================================================
// História animada
// ======================================================================

class StoryPlayerScreen extends StatefulWidget {
  final MapStory story;
  const StoryPlayerScreen({super.key, required this.story});

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _fly = AnimationController(vsync: this);
  int _step = 0;
  bool _playing = true;
  bool _flying = false;
  LatLng? _flyPos;
  Timer? _auto;
  bool _ready = false;
  double _zoom = 4;

  MapStory get story => widget.story;

  @override
  void dispose() {
    _auto?.cancel();
    _fly.dispose();
    super.dispose();
  }

  void _onReady() {
    _ready = true;
    final first = story.steps.first;
    _map.move(first.point, math.max(3, first.zoom - 1.5));
    _zoom = _map.camera.zoom;
    Future.delayed(const Duration(milliseconds: 400), () => _goTo(0));
  }

  Future<void> _goTo(int i) async {
    if (!_ready || i < 0 || i >= story.steps.length) return;
    _auto?.cancel();
    final cam = _map.camera;
    final from = cam.center;
    final z0 = cam.zoom;
    final target = story.steps[i];
    final dist = const Distance().as(LengthUnit.Kilometer, from, target.point);
    final bump = math.min(3.0, dist / 300);
    final ms = (1400 + math.min(2600, dist * 2.2)).round();
    setState(() {
      _step = i;
      _flying = true;
    });
    _fly
      ..stop()
      ..duration = Duration(milliseconds: ms);
    void tick() {
      final t = Curves.easeInOutCubic.transform(_fly.value);
      final lat = from.latitude + (target.point.latitude - from.latitude) * t;
      final lon = from.longitude + (target.point.longitude - from.longitude) * t;
      final z = math.max(3.0, z0 + (target.zoom - z0) * t - bump * math.sin(math.pi * _fly.value));
      _flyPos = LatLng(lat, lon);
      _map.move(_flyPos!, z);
      _zoom = z;
      if (mounted) setState(() {});
    }

    _fly.addListener(tick);
    await _fly.forward(from: 0).orCancel.catchError((_) {});
    _fly.removeListener(tick);
    if (!mounted) return;
    setState(() {
      _flying = false;
      _flyPos = null;
    });
    if (_playing && i < story.steps.length - 1) {
      _auto = Timer(const Duration(seconds: 7), () => _goTo(i + 1));
    } else if (i == story.steps.length - 1) {
      setState(() => _playing = false);
    }
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      if (_step >= story.steps.length - 1) {
        _goTo(0);
      } else if (!_flying) {
        _goTo(_step + 1);
      }
    } else {
      _auto?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = story.steps;
    final cur = steps[_step];
    final routePoints = <LatLng>[
      for (var k = 0; k < _step; k++) steps[k].point,
      if (_flying && _flyPos != null) _flyPos! else if (!_flying) cur.point,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final layers = <Widget>[
      if (story.regions.isNotEmpty)
        PolygonLayer(polygons: [
          for (final r in story.regions)
            Polygon(
              points: r.points,
              color: r.color.withValues(alpha: 0.28),
              borderColor: r.color,
              borderStrokeWidth: 2,
            ),
        ]),
      if (story.route && routePoints.length > 1)
        PolylineLayer(polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: 4,
            color: story.color,
            borderStrokeWidth: 2,
            borderColor: Colors.black.withValues(alpha: 0.4),
          ),
        ]),
      MarkerLayer(markers: [
        for (final r in story.regions)
          Marker(
            point: r.center,
            width: 160,
            height: 30,
            child: IgnorePointer(
              child: Center(
                child: Text(r.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'serif',
                        fontSize: (9 + (_zoom - 3) * 2.5).clamp(9, 18).toDouble(),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: r.color, blurRadius: 8), const Shadow(color: Colors.black, blurRadius: 4)])),
              ),
            ),
          ),
        // Etapas anteriores: ponto pequeno com o nome.
        for (var k = 0; k < _step; k++)
          Marker(
            point: steps[k].point,
            width: 160,
            height: 40,
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _goTo(k),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: story.color, border: Border.all(color: Colors.white, width: 2)),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(steps[k].place,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                ),
              ]),
            ),
          ),
        if (!_flying)
          Marker(point: cur.point, width: 60, height: 60, child: _PulseDot(color: story.color)),
        if (!_flying)
          Marker(
            point: cur.point,
            width: 320,
            height: 150,
            alignment: const Alignment(1.15, -1.25),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _LabelCard(
                title: cur.place,
                subtitle: cur.title,
                reference: cur.reference,
                color: story.color,
                onReference: () => _openRef(context, cur.reference),
              ),
            ),
          ),
      ]),
    ];

    final panel = Container(
      constraints: const BoxConstraints(maxWidth: 620),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: story.color.withValues(alpha: 0.6)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${story.title} · ${_step + 1} de ${steps.length}',
            style: TextStyle(color: story.color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(cur.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif')),
        const SizedBox(height: 4),
        Text(cur.text, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.35)),
        const SizedBox(height: 6),
        Row(children: [
          ActionChip(
            avatar: const Icon(Icons.menu_book, size: 16),
            label: Text(cur.reference),
            onPressed: () => _openRef(context, cur.reference),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Etapa anterior',
            color: Colors.white,
            icon: const Icon(Icons.skip_previous),
            onPressed: _step > 0 ? () => _goTo(_step - 1) : null,
          ),
          IconButton.filled(
            tooltip: _playing ? 'Pausar' : 'Tocar',
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          IconButton(
            tooltip: 'Próxima etapa',
            color: Colors.white,
            icon: const Icon(Icons.skip_next),
            onPressed: _step < steps.length - 1 ? () => _goTo(_step + 1) : null,
          ),
        ]),
      ]),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        _SatMap(
          controller: _map,
          options: MapOptions(
            initialCenter: steps.first.point,
            initialZoom: math.max(3, steps.first.zoom - 1.5),
            minZoom: 3,
            maxZoom: 15,
            backgroundColor: const Color(0xFF0B1A2B),
            onMapReady: _onReady,
            onMapEvent: (e) {
              if (!_flying && (e.camera.zoom - _zoom).abs() > 0.2) setState(() => _zoom = e.camera.zoom);
            },
          ),
          layers: layers,
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
                  decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20)),
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
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: jgGold)),
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
        _SatMap(
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
                            const _PulseDot(color: jgGold, size: 14),
                            Flexible(child: _LabelCard(title: p.name, subtitle: p.typeLabel, color: jgGold)),
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
                    decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20)),
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
                        fillColor: _cardBg,
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
                  decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
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
