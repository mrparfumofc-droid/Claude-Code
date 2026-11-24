import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/stories.dart';

/// Programa do efeito 3D (carregado uma vez). Se o aparelho não aceitar, cai no zoom simples.
class _Parallax {
  static ui.FragmentProgram? program;
  static bool flip = false;
  static Future<void>? _init;

  static Future<void> ensure() => _init ??= _load();

  static Future<void> _load() async {
    try {
      final p = await ui.FragmentProgram.fromAsset('shaders/parallax.frag');
      // Teste de orientação: em alguns aparelhos (OpenGL ES) a textura chega de cabeça para
      // baixo dentro do shader. Desenha um quadro vermelho em cima / azul embaixo e confere.
      final px = Uint8List(4 * 4 * 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final i = (y * 4 + x) * 4;
          px[i] = y < 2 ? 255 : 0;
          px[i + 2] = y < 2 ? 0 : 255;
          px[i + 3] = 255;
        }
      }
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(px, 4, 4, ui.PixelFormat.rgba8888, done.complete);
      final test = await done.future;
      final shader = p.fragmentShader();
      setUniforms(shader, const Size(4, 4), test, test, Offset.zero, 1, 0, false);
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..shader = shader);
      final out = await rec.endRecording().toImage(4, 4);
      final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data != null) flip = data.getUint8(2) > data.getUint8(0);
      shader.dispose();
      test.dispose();
      out.dispose();
      program = p;
    } catch (_) {
      program = null;
    }
  }

  static void setUniforms(ui.FragmentShader s, Size size, ui.Image image, ui.Image depth, Offset shift, double zoom,
      double strength, bool flipY) {
    s
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, image.width.toDouble())
      ..setFloat(3, image.height.toDouble())
      ..setFloat(4, shift.dx)
      ..setFloat(5, shift.dy)
      ..setFloat(6, zoom)
      ..setFloat(7, strength)
      ..setFloat(8, flipY ? 1 : 0)
      ..setImageSampler(0, image)
      ..setImageSampler(1, depth);
  }
}

/// Ilustração da história com movimento: a câmera se aproxima e balança devagar e, com o mapa de
/// profundidade, o que está perto se move mais do que o fundo (efeito 3D).
class ParallaxImage extends StatefulWidget {
  final String imageKey;

  /// false = só zoom suave, sem profundidade (opção do usuário ou miniatura).
  final bool depthEffect;
  final Color tint;
  const ParallaxImage({super.key, required this.imageKey, this.depthEffect = true, this.tint = const Color(0xFF0E1626)});

  @override
  State<ParallaxImage> createState() => _ParallaxImageState();
}

class _ParallaxImageState extends State<ParallaxImage> with SingleTickerProviderStateMixin {
  ui.Image? _image;
  ui.Image? _depth;
  ui.FragmentShader? _shader;
  bool _failed = false;
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);

  @override
  void initState() {
    super.initState();
    _load();
    _ticker.start();
  }

  Future<void> _load() async {
    final key = widget.imageKey;
    final image = await StoryMedia.decode(StoryMedia.image(key)) ?? await StoryMedia.decode(StoryMedia.thumb(key));
    if (!mounted) {
      image?.dispose();
      return;
    }
    if (image == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _image = image);
    if (!widget.depthEffect) return;
    await _Parallax.ensure();
    final program = _Parallax.program;
    if (program == null || !mounted) return;
    final depth = await StoryMedia.decode(StoryMedia.depth(key));
    if (!mounted) {
      depth?.dispose();
      return;
    }
    if (depth == null) return;
    setState(() {
      _depth = depth;
      _shader = program.fragmentShader();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    _image?.dispose();
    _depth?.dispose();
    super.dispose();
  }

  /// Movimento da câmera no instante [t] (segundos): aproxima no começo e depois "respira".
  static (Offset, double) camera(double t) => (
        Offset(math.sin(t * 0.42) * 0.95, math.cos(t * 0.31) * 0.6),
        1.085 + 0.06 * math.exp(-t / 4) + 0.018 * math.sin(t * 0.17),
      );

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0B1220), Color.lerp(const Color(0xFF0B1220), widget.tint, 0.45)!],
          ),
        ),
        child: Center(
          child: _failed
              ? const Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 48)
              : const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
        ),
      );
    }
    final shader = _shader;
    final depth = _depth;
    if (shader != null && depth != null) {
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ParallaxPainter(shader, image, depth, _time, _Parallax.flip),
        ),
      );
    }
    // Sem profundidade: zoom e deslocamento suaves (Ken Burns).
    return ClipRect(
      child: AnimatedBuilder(
        animation: _time,
        builder: (context, child) {
          final (shift, zoom) = camera(_time.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(shift.dx * 6, shift.dy * 4, 0, 1)
              ..scaleByDouble(zoom, zoom, 1, 1),
            child: child,
          );
        },
        child: RawImage(image: image, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      ),
    );
  }
}

class _ParallaxPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image depth;
  final ValueNotifier<double> time;
  final bool flip;
  _ParallaxPainter(this.shader, this.image, this.depth, this.time, this.flip) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final (shift, zoom) = _ParallaxImageState.camera(time.value);
    _Parallax.setUniforms(shader, size, image, depth, shift, zoom, 0.045, flip);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ParallaxPainter old) => old.image != image || old.depth != depth || old.shader != shader;
}

/// Ilustração parada (capas e miniaturas), com cópia guardada no aparelho.
class StoryThumb extends StatelessWidget {
  /// null = a ilustração ainda não existe: mostra só o fundo colorido.
  final String? imageKey;
  final Color tint;
  final BoxFit fit;

  /// true = ilustração em tamanho grande (destaques); false = miniatura.
  final bool large;
  const StoryThumb(
      {super.key, required this.imageKey, this.tint = const Color(0xFF0E1626), this.fit = BoxFit.cover, this.large = false});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: imageKey == null
            ? Future<Uint8List?>.value()
            : StoryMedia.bytes(large ? StoryMedia.image(imageKey!) : StoryMedia.thumb(imageKey!)),
        builder: (context, snap) {
          final b = snap.data;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: b == null
                ? DecoratedBox(
                    key: const ValueKey('vazio'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF0E1626), Color.lerp(const Color(0xFF0E1626), tint, 0.55)!],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  )
                : Image.memory(b,
                    key: ValueKey(imageKey), fit: fit, width: double.infinity, height: double.infinity, gaplessPlayback: true),
          );
        },
      );
}
