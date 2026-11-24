import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/places.dart';

const mapTileUrl = 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2020_3857/default/g/{z}/{y}/{x}.jpg';
const mapCredit =
    'Satélite: Sentinel-2 cloudless – s2maps.eu, EOX (Copernicus 2020) · Lugares: OpenBible.info (CC BY)';
const mapCardBg = Color(0xE60E1626);

/// Mapa de satélite com os créditos.
class SatMap extends StatelessWidget {
  final MapController controller;
  final MapOptions options;
  final List<Widget> layers;
  final bool credit;
  const SatMap({super.key, required this.controller, required this.options, required this.layers, this.credit = true});

  @override
  Widget build(BuildContext context) => Stack(children: [
        FlutterMap(
          mapController: controller,
          options: options,
          children: [
            TileLayer(
              urlTemplate: mapTileUrl,
              userAgentPackageName: 'com.jgcompany.biblia_jg',
              maxNativeZoom: 15,
            ),
            ...layers,
          ],
        ),
        if (credit)
          Positioned(
            left: 6,
            bottom: 2,
            child: IgnorePointer(
              child: Text(mapCredit, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.8))),
            ),
          ),
      ]);
}

/// Ponto que pulsa (como no vídeo de referência).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, required this.color, this.size = 18});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
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
class LabelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? reference;
  final Color color;
  final VoidCallback? onReference;
  const LabelCard({super.key, required this.title, required this.color, this.subtitle, this.reference, this.onReference});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: mapCardBg,
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

/// Parada de uma história no mapa.
class MapStop {
  final String place;
  final LatLng point;
  final double zoom;
  final String title;
  final String reference;
  const MapStop(this.place, this.point, this.zoom, this.title, [this.reference = '']);
}

/// Mapa que "voa" de parada em parada, desenhando a rota (como no vídeo de referência).
/// Muda de parada quando [index] muda. Paradas nulas (cena sem lugar) mantêm a câmera.
class StoryMapView extends StatefulWidget {
  final List<MapStop?> stops;
  final int index;
  final Color color;
  final bool route;
  final List<StoryRegion> regions;
  final List<StoryLine> lines;

  /// Etiqueta grande no lugar atual; desligada no mapa pequeno.
  final bool labels;
  final bool interactive;

  /// Quanto afastar a câmera em relação ao zoom da parada (mapa pequeno = mais afastado).
  final double zoomOut;
  final ValueChanged<int>? onTapStop;
  final ValueChanged<String>? onReference;
  final VoidCallback? onTap;

  const StoryMapView({
    super.key,
    required this.stops,
    required this.index,
    required this.color,
    this.route = true,
    this.regions = const [],
    this.lines = const [],
    this.labels = true,
    this.interactive = true,
    this.zoomOut = 0,
    this.onTapStop,
    this.onReference,
    this.onTap,
  });

  @override
  State<StoryMapView> createState() => _StoryMapViewState();
}

class _StoryMapViewState extends State<StoryMapView> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _fly = AnimationController(vsync: this);
  bool _ready = false;
  bool _flying = false;
  LatLng? _flyPos;
  double _zoom = 4;
  int _at = -1; // parada para onde a câmera já voou
  int _run = 0;

  /// Índice da parada com lugar em [i] ou antes (ou a primeira depois, se não houver).
  int _resolve(int i) {
    final s = widget.stops;
    for (var k = math.min(i, s.length - 1); k >= 0; k--) {
      if (s[k] != null) return k;
    }
    for (var k = 0; k < s.length; k++) {
      if (s[k] != null) return k;
    }
    return -1;
  }

  MapStop? get _first {
    final k = _resolve(0);
    return k < 0 ? null : widget.stops[k];
  }

  double _targetZoom(MapStop s) => math.max(3.0, s.zoom - widget.zoomOut);

  @override
  void didUpdateWidget(StoryMapView old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || old.zoomOut != widget.zoomOut) _goTo(widget.index);
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  void _onReady() {
    _ready = true;
    final first = _first;
    if (first == null) return;
    _map.move(first.point, math.max(3, _targetZoom(first) - 1.5));
    _zoom = _map.camera.zoom;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _goTo(widget.index);
    });
  }

  Future<void> _goTo(int index) async {
    final i = _resolve(index);
    if (!_ready || i < 0) return;
    final run = ++_run;
    final cam = _map.camera;
    final from = cam.center;
    final z0 = cam.zoom;
    final target = widget.stops[i]!;
    final z1 = _targetZoom(target);
    final dist = const Distance().as(LengthUnit.Kilometer, from, target.point);
    if (dist < 0.5 && (z0 - z1).abs() < 0.2) {
      setState(() => _at = i);
      return;
    }
    final bump = math.min(3.0, dist / 300);
    final ms = (1400 + math.min(2600, dist * 2.2)).round();
    setState(() {
      _at = i;
      _flying = true;
    });
    _fly
      ..stop()
      ..duration = Duration(milliseconds: ms);
    void tick() {
      if (run != _run) return;
      final t = Curves.easeInOutCubic.transform(_fly.value);
      final lat = from.latitude + (target.point.latitude - from.latitude) * t;
      final lon = from.longitude + (target.point.longitude - from.longitude) * t;
      final z = math.max(3.0, z0 + (z1 - z0) * t - bump * math.sin(math.pi * _fly.value));
      _flyPos = LatLng(lat, lon);
      _map.move(_flyPos!, z);
      _zoom = z;
      if (mounted) setState(() {});
    }

    _fly.addListener(tick);
    await _fly.forward(from: 0).orCancel.catchError((_) {});
    _fly.removeListener(tick);
    if (!mounted || run != _run) return;
    setState(() {
      _flying = false;
      _flyPos = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final first = _first;
    if (first == null) return const ColoredBox(color: Color(0xFF0B1A2B));
    final at = _at < 0 ? _resolve(widget.index) : _at;
    final cur = stops[at]!;
    final routePoints = <LatLng>[
      for (var k = 0; k < at; k++)
        if (stops[k] != null) stops[k]!.point,
      if (_flying && _flyPos != null) _flyPos! else if (!_flying) cur.point,
    ];
    final small = !widget.labels;

    final layers = <Widget>[
      if (widget.regions.isNotEmpty)
        PolygonLayer(polygons: [
          for (final r in widget.regions)
            Polygon(
              points: r.points,
              color: r.color.withValues(alpha: 0.28),
              borderColor: r.color,
              borderStrokeWidth: 2,
            ),
        ]),
      if (widget.lines.isNotEmpty)
        PolylineLayer(polylines: [
          for (final l in widget.lines)
            Polyline(
              points: l.points,
              strokeWidth: 3.5,
              color: l.color,
              borderStrokeWidth: 1.5,
              borderColor: Colors.black.withValues(alpha: 0.45),
            ),
        ]),
      if (widget.route && routePoints.length > 1)
        PolylineLayer(polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: small ? 3 : 4,
            color: widget.color,
            borderStrokeWidth: 2,
            borderColor: Colors.black.withValues(alpha: 0.4),
          ),
        ]),
      MarkerLayer(markers: [
        for (final r in widget.regions)
          Marker(
            point: r.center,
            width: 170,
            height: 30,
            child: IgnorePointer(
              child: Center(
                child: Text(r.name,
                    textAlign: TextAlign.center,
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
        for (var k = 0; k < at; k++)
          if (stops[k] != null && stops[k]!.point != cur.point)
            Marker(
              point: stops[k]!.point,
              width: small ? 16 : 160,
              height: small ? 16 : 40,
              alignment: small ? Alignment.center : Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onTapStop == null ? null : () => widget.onTapStop!(k),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: small ? 9 : 12,
                    height: small ? 9 : 12,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                        border: Border.all(color: Colors.white, width: small ? 1.5 : 2)),
                  ),
                  if (!small) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(stops[k]!.place,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                    ),
                  ],
                ]),
              ),
            ),
        if (!_flying)
          Marker(
              point: cur.point,
              width: small ? 42 : 60,
              height: small ? 42 : 60,
              child: PulseDot(color: widget.color, size: small ? 12 : 18)),
        // Em tela estreita a etiqueta grande sairia da tela; o painel de baixo já diz o lugar.
        if (!_flying && !small && MediaQuery.sizeOf(context).width >= 600)
          Marker(
            point: cur.point,
            width: 320,
            height: 150,
            alignment: const Alignment(1.15, -1.25),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: LabelCard(
                title: cur.place,
                subtitle: cur.title,
                reference: cur.reference,
                color: widget.color,
                onReference: widget.onReference == null ? null : () => widget.onReference!(cur.reference),
              ),
            ),
          ),
      ]),
    ];

    return Stack(children: [
      SatMap(
        controller: _map,
        credit: !small,
        options: MapOptions(
          initialCenter: first.point,
          initialZoom: math.max(3, _targetZoom(first) - 1.5),
          minZoom: 2.5,
          maxZoom: 15,
          backgroundColor: const Color(0xFF0B1A2B),
          interactionOptions:
              InteractionOptions(flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
          onMapReady: _onReady,
          onTap: widget.onTap == null ? null : (_, _) => widget.onTap!(),
          onMapEvent: (e) {
            if (!_flying && (e.camera.zoom - _zoom).abs() > 0.2) setState(() => _zoom = e.camera.zoom);
          },
        ),
        layers: layers,
      ),
      if (small)
        Positioned(
          left: 6,
          bottom: 4,
          right: 6,
          child: IgnorePointer(
            child: Text(cur.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
          ),
        ),
    ]);
  }
}
