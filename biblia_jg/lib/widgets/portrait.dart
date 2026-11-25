import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/portraits.dart';
import '../services/stories.dart' show StoryMedia;
import 'parallax_image.dart' show StoryThumb;

/// Retrato redondo de um personagem. Sem retrato, mostra [child] (ou a inicial do nome) sobre
/// [color]; com [hideWhenMissing], some e não ocupa espaço.
class PortraitAvatar extends StatefulWidget {
  final String name;

  /// Raio com retrato.
  final double radius;

  /// Raio sem retrato (padrão: o mesmo).
  final double? fallbackRadius;
  final Color color;

  /// Cor do aro em volta do retrato (sem aro se null).
  final Color? ring;
  final Widget? child;
  final bool hideWhenMissing;

  /// Espaço em volta, só quando o retrato (ou a inicial) aparece.
  final EdgeInsets margin;

  /// Toque no retrato abre a imagem maior.
  final bool zoomable;

  const PortraitAvatar({
    super.key,
    required this.name,
    this.radius = 18,
    this.fallbackRadius,
    this.color = Colors.white24,
    this.ring,
    this.child,
    this.hideWhenMissing = false,
    this.margin = EdgeInsets.zero,
    this.zoomable = false,
  });

  @override
  State<PortraitAvatar> createState() => _PortraitAvatarState();
}

class _PortraitAvatarState extends State<PortraitAvatar> {
  Uint8List? _bytes;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    Portraits.revision.addListener(_resolve);
    _resolve();
  }

  @override
  void didUpdateWidget(PortraitAvatar old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _bytes = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    Portraits.revision.removeListener(_resolve);
    super.dispose();
  }

  Future<void> _resolve() async {
    final run = ++_run;
    final id = (await Portraits.load()).idFor(widget.name);
    if (id == null) return;
    final b = await StoryMedia.bytes(Portraits.path(id));
    if (mounted && run == _run && b != null) setState(() => _bytes = b);
  }

  void _zoom(Uint8List b) => showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AspectRatio(aspectRatio: 1, child: Image.memory(b, fit: BoxFit.cover)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.name.replaceFirst(RegExp(r'^(Rei|Profeta) '), ''),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null && widget.hideWhenMissing) return const SizedBox.shrink();
    final r = b == null ? (widget.fallbackRadius ?? widget.radius) : widget.radius;
    Widget avatar = CircleAvatar(
      radius: r,
      backgroundColor: widget.color,
      foregroundImage: b == null ? null : MemoryImage(b),
      child: b != null
          ? null
          : (widget.child ??
              Text(widget.name.characters.first,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r * 0.9))),
    );
    if (b != null && widget.ring != null) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.ring),
        child: avatar,
      );
    }
    if (b != null && widget.zoomable) {
      avatar = GestureDetector(onTap: () => _zoom(b), child: avatar);
    }
    return Padding(padding: widget.margin, child: avatar);
  }
}

/// Nome de um personagem numa pastilha, com o retrato (quando existe) à esquerda.
class PersonChip extends StatelessWidget {
  final String name;
  final Color background;
  final Color foreground;
  final double radius;
  const PersonChip(this.name, {super.key, this.background = Colors.white24, this.foreground = Colors.white, this.radius = 11});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(3, 3, radius * 0.85, 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius + 4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PortraitAvatar(name: name, radius: radius, hideWhenMissing: true, zoomable: true),
          SizedBox(width: radius * 0.55, height: radius * 2),
          Text(name, style: TextStyle(color: foreground, fontSize: radius + 1.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Fundo ilustrado: uma ilustração das histórias por baixo, coberta por um véu da cor do quadro
/// (mais fechado do lado do texto) para as letras brancas continuarem legíveis.
class ArtBackdrop extends StatelessWidget {
  /// Chave da ilustração; null = só a cor.
  final String? art;
  final Color color;
  final Widget child;
  final BorderRadius borderRadius;

  /// Quanto da ilustração aparece do lado direito (0 = nada, 1 = toda).
  final double reveal;
  const ArtBackdrop({
    super.key,
    required this.art,
    required this.color,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.reveal = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    const night = Color(0xFF0E1626);
    final deep = Color.lerp(color, night, 0.45)!;
    return ClipRRect(
      borderRadius: borderRadius,
      // passthrough: o conteúdo recebe o mesmo espaço do quadro (preenche a grade ou cresce com o texto).
      child: Stack(fit: StackFit.passthrough, children: [
        Positioned.fill(
          child: art == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, deep]),
                  ),
                )
              : StoryThumb(imageKey: art, tint: color, large: true, cacheWidth: 1000),
        ),
        if (art != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0, 0.45, 1],
                  colors: [
                    color.withValues(alpha: 0.96),
                    deep.withValues(alpha: 0.96 - 0.38 * reveal),
                    night.withValues(alpha: 0.9 - 0.75 * reveal),
                  ],
                ),
              ),
            ),
          ),
        child,
      ]),
    );
  }
}
