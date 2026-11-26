import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rejeição da palma da mão no app inteiro.
///
/// Quem escreve com caneta apoia a mão na tela. Com a rejeição ligada (e depois que uma caneta
/// já foi usada no aparelho), os toques de dedo/mão são ignorados enquanto a caneta está na tela
/// ou perto dela (e um pouco depois de levantá-la), e os toques com área grande (palma) também.
/// Quando a caneta chega, toques de mão que já estavam na tela são cancelados (não viram clique).
class PalmGuard {
  PalmGuard._();

  /// 0 = desligada, 1 = normal, 2 = forte.
  static int mode = 1;
  static bool stylusSeen = false;
  static SharedPreferences? _prefs;

  /// Último instante (relógio dos eventos) em que a caneta esteve na tela ou perto dela.
  static Duration _lastStylus = const Duration(days: -1);
  static final Set<int> _dropped = {};
  static final Map<int, PointerEvent> _touches = {};

  static void load(SharedPreferences prefs) {
    _prefs = prefs;
    mode = (prefs.getInt('palma.modo') ?? 1).clamp(0, 2);
    stylusSeen = prefs.getBool('palma.caneta') ?? false;
  }

  static void setMode(int m) {
    mode = m.clamp(0, 2);
    _prefs?.setInt('palma.modo', mode);
  }

  static bool isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  static Duration get _window => mode == 2 ? const Duration(milliseconds: 1800) : const Duration(milliseconds: 700);

  /// Raio (px lógicos) acima do qual o toque é tratado como palma. 0 = o aparelho não informa.
  static double get _palmRadius => mode == 2 ? 16 : 24;

  static bool get active => mode > 0 && stylusSeen;

  /// Decide o que fazer com o evento. Devolve os eventos a entregar ao app (pode ser vazio,
  /// o próprio evento ou cancelamentos dos toques de mão seguidos do evento).
  static List<PointerEvent> filter(PointerEvent e) {
    if (isStylus(e)) {
      if (e is! PointerRemovedEvent) _lastStylus = e.timeStamp;
      if (!stylusSeen && (e is PointerDownEvent || e is PointerHoverEvent)) {
        stylusSeen = true;
        _prefs?.setBool('palma.caneta', true);
      }
      if (!active || _touches.isEmpty) return [e];
      // A caneta chegou: a mão que já estava apoiada não deve virar clique nem rolagem.
      final out = <PointerEvent>[
        for (final t in _touches.values)
          PointerCancelEvent(
            timeStamp: e.timeStamp,
            pointer: t.pointer,
            kind: t.kind,
            device: t.device,
            position: t.position,
            embedderId: t.embedderId,
            viewId: t.viewId,
          ),
        e,
      ];
      _dropped.addAll(_touches.keys);
      _touches.clear();
      return out;
    }
    if (e.kind != PointerDeviceKind.touch || e is PointerAddedEvent || e is PointerRemovedEvent) return [e];
    if (_dropped.contains(e.pointer)) {
      if (e is PointerUpEvent || e is PointerCancelEvent) _dropped.remove(e.pointer);
      return const [];
    }
    if (e is PointerDownEvent) {
      final near = e.timeStamp - _lastStylus < _window;
      final big = e.radiusMajor > _palmRadius;
      if (active && (near || big)) {
        _dropped.add(e.pointer);
        return const [];
      }
      _touches[e.pointer] = e;
    } else if (e is PointerMoveEvent) {
      if (active && e.radiusMajor > _palmRadius * 1.3 && _touches.containsKey(e.pointer)) {
        // O toque cresceu (a mão deitou na tela): cancela.
        final t = _touches.remove(e.pointer)!;
        _dropped.add(e.pointer);
        return [
          PointerCancelEvent(
              timeStamp: e.timeStamp, pointer: t.pointer, kind: t.kind, device: t.device, position: e.position, viewId: e.viewId),
        ];
      }
      if (_touches.containsKey(e.pointer)) _touches[e.pointer] = e;
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      _touches.remove(e.pointer);
    }
    return [e];
  }

  static const labels = ['Desligada', 'Normal', 'Forte'];
}

/// Binding do app: passa cada toque pela rejeição da palma antes de entregá-lo às telas.
class PalmBinding extends WidgetsFlutterBinding {
  /// Chamar uma vez, no começo do main (no lugar de WidgetsFlutterBinding.ensureInitialized).
  static void init() => PalmBinding();

  @override
  void handlePointerEvent(PointerEvent event) {
    for (final e in PalmGuard.filter(event)) {
      super.handlePointerEvent(e);
    }
  }
}

/// Escolha da rejeição da palma (Ajustes e barras de caneta).
class PalmModeSelector extends StatefulWidget {
  const PalmModeSelector({super.key});

  @override
  State<PalmModeSelector> createState() => _PalmModeSelectorState();
}

class _PalmModeSelectorState extends State<PalmModeSelector> {
  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Rejeição da palma da mão'),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [for (var i = 0; i < 3; i++) ButtonSegment(value: i, label: Text(PalmGuard.labels[i]))],
        selected: {PalmGuard.mode},
        onSelectionChanged: (v) => setState(() => PalmGuard.setMode(v.first)),
      ),
      const SizedBox(height: 6),
      Text(
        PalmGuard.stylusSeen
            ? 'Com a caneta na tela ou perto dela, a mão apoiada não clica nem rola. '
                'Forte: ignora a mão por mais tempo depois de levantar a caneta e toques maiores.'
            : 'Liga sozinha na primeira vez que a caneta tocar a tela.',
        style: small,
      ),
    ]);
  }
}
