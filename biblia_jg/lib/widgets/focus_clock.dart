import 'dart:async';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tempo da sessão de leitura em modo foco. Só o relógio escuta: a página de leitura não é
/// reconstruída a cada segundo.
class FocusSession extends ChangeNotifier {
  int seconds = 0;

  /// Minutos escolhidos (0 = sem limite).
  int goal = 10;
  bool alarmed = false;

  int get total => goal * 60;
  bool get done => goal > 0 ? seconds >= total : seconds >= 300;
  double get progress => goal > 0 ? (seconds / total).clamp(0.0, 1.0) : 0;

  /// Com tempo escolhido, conta para trás (e passa a "+" depois do fim); sem limite, conta para a frente.
  String get label {
    final remaining = goal > 0 ? total - seconds : seconds;
    final shown = remaining.abs();
    final sign = goal > 0 && remaining < 0 ? '+' : '';
    return '$sign${(shown ~/ 60).toString().padLeft(2, '0')}:${(shown % 60).toString().padLeft(2, '0')}';
  }

  /// Avança um segundo. Devolve true no instante em que o tempo escolhido termina.
  bool tick() {
    seconds++;
    final ring = goal > 0 && !alarmed && seconds >= total;
    if (ring) alarmed = true;
    notifyListeners();
    return ring;
  }

  void restart({int? goal}) {
    if (goal != null) this.goal = goal;
    seconds = 0;
    alarmed = false;
    notifyListeners();
  }

  void setGoal(int minutes) {
    goal = minutes;
    alarmed = minutes > 0 && seconds >= minutes * 60;
    notifyListeners();
  }

  /// "Mais N minutos" depois do alarme.
  void extend(int minutes) {
    goal = seconds ~/ 60 + minutes;
    alarmed = false;
    notifyListeners();
  }
}

/// Onde o relógio pode ficar: dentro de [area], abaixo de [top], com folga nas bordas.
Offset clampFocusClock(Offset p, Size area, Size pill, double top, {double margin = 8}) {
  final maxX = (area.width - pill.width - margin).clamp(margin, double.infinity);
  final minY = top + margin;
  final maxY = (area.height - pill.height - margin).clamp(minY, double.infinity);
  return Offset(p.dx.clamp(margin, maxX), p.dy.clamp(minY, maxY));
}

/// Passou da borda: anda só uma fração (resistência), em vez de parar seco.
Offset rubberBandFocusClock(Offset p, Size area, Size pill, double top, {double elastic = 0.22}) {
  final c = clampFocusClock(p, area, pill, top);
  return c + (p - c) * elastic;
}

/// Relógio do modo foco: uma pastilha pequena com o tempo. Arrastar muda de lugar (acompanha o
/// dedo ponto a ponto); tocar abre as opções (tempo, concluir, sair).
class FocusClock extends StatefulWidget {
  final FocusSession session;
  final SharedPreferences prefs;

  /// Espaço em que o relógio pode andar.
  final Size area;

  /// Altura reservada no topo (faixa com a hora e o capítulo).
  final double top;
  final VoidCallback onGoal;
  final VoidCallback onFinish;
  final VoidCallback onExit;

  const FocusClock({
    super.key,
    required this.session,
    required this.prefs,
    required this.area,
    required this.top,
    required this.onGoal,
    required this.onFinish,
    required this.onExit,
  });

  static const size = Size(104, 44);

  @override
  State<FocusClock> createState() => _FocusClockState();
}

class _FocusClockState extends State<FocusClock> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 38);

  late final ValueNotifier<Offset> _pos;
  late final AnimationController _settle;
  final _dragging = ValueNotifier<bool>(false);
  Offset _raw = Offset.zero; // posição do dedo, sem a resistência das bordas
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  Offset _clamp(Offset p) => clampFocusClock(p, widget.area, FocusClock.size, widget.top);

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    final saved = p.containsKey('focus.px')
        ? Offset(p.getDouble('focus.px') ?? 0, p.getDouble('focus.py') ?? 0)
        : Offset(widget.area.width, widget.area.height); // canto de baixo, à direita
    _pos = ValueNotifier(_clamp(saved));
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => _pos.value = Offset.lerp(_from, _to, _settle.value)!);
  }

  @override
  void didUpdateWidget(FocusClock old) {
    super.didUpdateWidget(old);
    // A tela girou ou mudou de tamanho: mantém o relógio dentro dela.
    if (old.area != widget.area || old.top != widget.top) {
      if (!_dragging.value) {
        _settle.stop();
        _pos.value = _clamp(_pos.value);
      }
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _pos.dispose();
    _dragging.dispose();
    super.dispose();
  }

  void _start(DragStartDetails d) {
    _settle.stop(); // dá para pegar o relógio no meio do movimento
    _raw = _pos.value;
    _dragging.value = true;
  }

  void _update(DragUpdateDetails d) {
    _raw += d.delta;
    _pos.value = rubberBandFocusClock(_raw, widget.area, FocusClock.size, widget.top);
  }

  void _end([DragEndDetails? d]) {
    _dragging.value = false;
    _from = _pos.value;
    _to = _clamp(_from);
    widget.prefs.setDouble('focus.px', _to.dx);
    widget.prefs.setDouble('focus.py', _to.dy);
    final distance = (_to - _from).distance;
    if (distance < 0.5) {
      _pos.value = _to;
      return;
    }
    // Só volta (rápido) se foi solto fora da tela; a velocidade do dedo entra na mola.
    final v = d == null ? 0.0 : (d.velocity.pixelsPerSecond.dx * (_to.dx - _from.dx) + d.velocity.pixelsPerSecond.dy * (_to.dy - _from.dy)) / (distance * distance);
    _settle.animateWith(SpringSimulation(_spring, 0, 1, v));
  }

  Future<void> _menu() async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(_pos.value, ancestor: overlay);
    final rect = origin & FocusClock.size;
    final s = widget.session;
    final choice = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_outlined),
            title: Text(s.goal == 0 ? 'Tempo: sem limite' : 'Tempo: ${s.goal} min'),
          ),
        ),
        const PopupMenuItem(
          value: 1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline),
            title: Text('Concluir leitura'),
          ),
        ),
        const PopupMenuItem(
          value: 2,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.close),
            title: Text('Sair do modo foco'),
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 0:
        widget.onGoal();
      case 1:
        widget.onFinish();
      case 2:
        widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onInverseSurface;
    // O conteúdo da pastilha só muda uma vez por segundo, e sozinho (sem reconstruir a leitura).
    final pill = RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _dragging,
        builder: (context, dragging, child) => AnimatedScale(
          scale: dragging ? 1.06 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Material(
            elevation: dragging ? 10 : 3,
            shadowColor: Colors.black54,
            color: scheme.inverseSurface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            child: child,
          ),
        ),
        child: SizedBox.fromSize(
          size: FocusClock.size,
          child: ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) {
              final s = widget.session;
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (s.done)
                  const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent)
                else if (s.goal > 0)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      value: s.progress,
                      strokeWidth: 2.2,
                      color: Colors.greenAccent,
                      backgroundColor: fg.withValues(alpha: 0.22),
                    ),
                  )
                else
                  Icon(Icons.timer_outlined, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(s.label,
                    style: TextStyle(
                        color: fg,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]);
            },
          ),
        ),
      ),
    );

    return Positioned(
      left: 0,
      top: 0,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _pos,
        // Mover = só trocar o deslocamento na pintura: nada é reconstruído nem medido de novo.
        builder: (context, p, child) => Transform.translate(offset: p, child: child),
        child: Semantics(
          button: true,
          label: 'Relógio do modo foco. Toque para ver as opções; arraste para mudar de lugar.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: _start,
            onPanUpdate: _update,
            onPanEnd: _end,
            onPanCancel: _end,
            onTap: _menu,
            child: pill,
          ),
        ),
      ),
    );
  }
}

/// A hora do dia (HH:MM), atualizada sozinha.
class WallClock extends StatefulWidget {
  final TextStyle? style;
  const WallClock({super.key, this.style});

  @override
  State<WallClock> createState() => _WallClockState();
}

class _WallClockState extends State<WallClock> {
  Timer? _timer;
  String _text = '';

  String _now() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _text = _now();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final t = _now();
      if (t != _text && mounted) setState(() => _text = t);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(_text, style: widget.style);
}
