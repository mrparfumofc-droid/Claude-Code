import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/stories.dart' show StoryMedia;

/// Ilustração de um quadro de estudo (linha do tempo, guia dos livros).
///
/// As ilustrações ficam na nuvem, junto com as das histórias. Quando a de uma chave ainda não foi
/// publicada, aparece um quadro com a cor do assunto e um ícone; a ilustração entra sozinha
/// assim que chegar à nuvem, sem atualizar o app. Ao trocar de chave, a ilustração anterior fica
/// na tela até a nova carregar (sem piscar).
class StudyArt extends StatefulWidget {
  final String? art;
  final Color color;
  final IconData icon;

  /// true = ilustração grande (destaques); false = miniatura.
  final bool large;
  final int? cacheWidth;

  /// Duração da passagem de uma ilustração para outra.
  final Duration fade;
  const StudyArt({
    super.key,
    required this.art,
    required this.color,
    this.icon = Icons.auto_stories,
    this.large = false,
    this.cacheWidth,
    this.fade = const Duration(milliseconds: 350),
  });

  /// Chaves que não estavam na nuvem na última tentativa (não insiste a cada reconstrução da tela).
  static final _missing = <String, DateTime>{};
  static const _retry = Duration(minutes: 20);

  static Future<Uint8List?> _fetch(String key, bool large) async {
    final last = _missing[key];
    if (last != null && DateTime.now().difference(last) < _retry) return null;
    var b = await StoryMedia.bytes(large ? StoryMedia.image(key) : StoryMedia.thumb(key));
    // Sem a grande (ou sem a miniatura), serve a outra.
    b ??= await StoryMedia.bytes(large ? StoryMedia.thumb(key) : StoryMedia.image(key));
    if (b == null) {
      _missing[key] = DateTime.now();
    } else {
      _missing.remove(key);
    }
    return b;
  }

  /// Adianta o download de uma ilustração (a do próximo passo de uma apresentação).
  static void warm(String? key, {bool large = false}) {
    if (key != null && key.isNotEmpty) unawaited(_fetch(key, large));
  }

  @override
  State<StudyArt> createState() => _StudyArtState();
}

class _StudyArtState extends State<StudyArt> {
  Uint8List? _bytes;
  String? _shown; // chave da ilustração que está na tela
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(StudyArt old) {
    super.didUpdateWidget(old);
    if (old.art != widget.art || old.large != widget.large) _resolve();
  }

  Future<void> _resolve() async {
    final run = ++_run;
    final key = widget.art;
    Uint8List? b;
    if (key != null && key.isNotEmpty) {
      b = await StudyArt._fetch(key, widget.large);
      if (!mounted || run != _run) return;
    } else {
      // Sem chave: mostra o quadro colorido (a troca acontece depois deste quadro, fora do build).
      await null;
      if (!mounted || run != _run) return;
    }
    setState(() {
      _bytes = b;
      _shown = b == null ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    final placeholder = _Placeholder(key: const ValueKey('sem-arte'), color: widget.color, icon: widget.icon);
    return AnimatedSwitcher(
      duration: widget.fade,
      child: b == null
          ? placeholder
          : Image.memory(b,
              key: ValueKey(_shown),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: widget.cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _Placeholder(color: widget.color, icon: widget.icon)),
    );
  }
}

/// Quadro colorido para quando a ilustração ainda não existe: degradê na cor do assunto,
/// um brilho no canto e o ícone grande, esmaecido.
class _Placeholder extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Placeholder({super.key, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    const night = Color(0xFF0E1626);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.12)!, color, Color.lerp(color, night, 0.6)!],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.7, -0.8),
              radius: 1.1,
              colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
            ),
          ),
        ),
        // O ícone acompanha o tamanho do quadro, seja ele uma miniatura ou a tela inteira.
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.4,
            heightFactor: 0.4,
            child: FittedBox(child: Icon(icon, color: Colors.white.withValues(alpha: 0.26))),
          ),
        ),
      ]),
    );
  }
}
