import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cronômetro de leitura do topo da Bíblia: conta para trás o tempo escolhido e avisa no fim.
/// Fica fora das telas (continua contando ao trocar de aba ou de capítulo).
class ReadingTimer extends ChangeNotifier {
  ReadingTimer._();
  static final instance = ReadingTimer._();

  SharedPreferences? _prefs;
  Timer? _timer;

  /// Minutos escolhidos.
  int minutes = 15;
  int remaining = 0; // segundos
  bool running = false;

  /// Cor do relógio e fundo (opaco = pastilha colorida; transparente = só o texto colorido).
  int color = -1; // -1 = automática (a cor do texto da barra)
  bool opaque = false;

  /// Avisado quando o tempo acaba (a tela de leitura toca o alarme).
  final finished = StreamController<int>.broadcast();

  static const colors = <Color>[
    Color(0xFF7A1F2B), Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFFE65100), Color(0xFF00838F), Color(0xFF424242), Color(0xFFC9A227),
    Color(0xFFFFFFFF), Color(0xFFFFD54F), Color(0xFF80DEEA), Color(0xFFFF8A80),
  ];
  static const choices = [5, 10, 15, 20, 30, 45, 60, 90];

  /// Cor escolhida; na automática, [auto] (a cor do texto de onde o relógio está).
  Color tintOr(Color auto) => color < 0 ? auto : colors[color.clamp(0, colors.length - 1)];
  bool get active => running || remaining > 0;
  double get progress => minutes == 0 ? 0 : (1 - remaining / (minutes * 60)).clamp(0.0, 1.0);

  String get label {
    final r = active ? remaining : minutes * 60;
    return '${(r ~/ 60).toString().padLeft(2, '0')}:${(r % 60).toString().padLeft(2, '0')}';
  }

  void load(SharedPreferences prefs) {
    if (_prefs != null) return;
    _prefs = prefs;
    minutes = prefs.getInt('crono.min') ?? 15;
    color = prefs.getInt('crono.cor') ?? -1;
    opaque = prefs.getBool('crono.opaco') ?? false;
  }

  void _save() {
    _prefs?.setInt('crono.min', minutes);
    _prefs?.setInt('crono.cor', color);
    _prefs?.setBool('crono.opaco', opaque);
  }

  void setMinutes(int m) {
    minutes = m.clamp(1, 240);
    if (!running) remaining = 0;
    _save();
    notifyListeners();
  }

  void setLook({int? color, bool? opaque}) {
    if (color != null) this.color = color;
    if (opaque != null) this.opaque = opaque;
    _save();
    notifyListeners();
  }

  void start() {
    if (remaining <= 0) remaining = minutes * 60;
    running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    running = false;
    _timer?.cancel();
    notifyListeners();
  }

  void reset() {
    running = false;
    _timer?.cancel();
    remaining = 0;
    notifyListeners();
  }

  /// Mais N minutos depois do alarme.
  void extend(int m) {
    remaining = m * 60;
    start();
  }

  void _tick() {
    if (remaining > 0) remaining--;
    if (remaining <= 0) {
      running = false;
      _timer?.cancel();
      finished.add(minutes);
    }
    notifyListeners();
  }
}

/// Relógio + cronômetro do topo da leitura (lado esquerdo, junto do nome do livro).
/// Toque para escolher o tempo, iniciar/pausar e mudar cor e fundo.
class ReadingTimerChip extends StatefulWidget {
  final SharedPreferences prefs;
  const ReadingTimerChip({super.key, required this.prefs});

  @override
  State<ReadingTimerChip> createState() => _ReadingTimerChipState();
}

class _ReadingTimerChipState extends State<ReadingTimerChip> {
  final t = ReadingTimer.instance;
  Timer? _clock;
  String _now = '';

  String _hm() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    t.load(widget.prefs);
    _now = _hm();
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      final v = _hm();
      if (v != _now && mounted) setState(() => _now = v);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: t,
        builder: (context, _) {
          final bar = IconTheme.of(context).color ?? scheme.onSurface;
          final tint = t.tintOr(bar);
          final autoColor = t.color < 0;
          final Color bg = autoColor ? bar.withValues(alpha: 0.16) : tint;
          final fg = !t.opaque || autoColor ? tint : (tint.computeLuminance() > 0.5 ? Colors.black : Colors.white);
          final dim = fg.withValues(alpha: 0.72);
          const figs = [FontFeature.tabularFigures()];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Material(
              color: t.opaque ? bg : Colors.transparent,
              shape: StadiumBorder(side: t.opaque ? BorderSide.none : BorderSide(color: tint.withValues(alpha: 0.45))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showReadingTimerSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_now, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dim, fontFeatures: figs)),
                    const SizedBox(width: 8),
                    if (t.active)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          value: t.progress,
                          strokeWidth: 2.2,
                          color: fg,
                          backgroundColor: fg.withValues(alpha: 0.2),
                        ),
                      )
                    else
                      Icon(Icons.timer_outlined, size: 16, color: fg),
                    const SizedBox(width: 5),
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.active ? fg : fg.withValues(alpha: 0.7),
                            fontFeatures: figs)),
                    if (t.active && !t.running) Icon(Icons.pause, size: 14, color: fg),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Opções do cronômetro: tempo, iniciar/pausar/zerar, cor e fundo.
Future<void> showReadingTimerSheet(BuildContext context) {
  final t = ReadingTimer.instance;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: t,
      builder: (ctx, _) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Cronômetro de leitura', style: theme.textTheme.titleLarge)),
                Text(t.label,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: t.tintOr(theme.colorScheme.primary), fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 4),
              const Text('Escolha o tempo de leitura. Quando acabar, toca um alarme.'),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in ReadingTimer.choices)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: t.minutes == m,
                    onSelected: t.running ? null : (_) => t.setMinutes(m),
                  ),
              ]),
              Row(children: [
                const SizedBox(width: 92, child: Text('Outro tempo')),
                Expanded(
                  child: Slider(
                    value: t.minutes.toDouble().clamp(1, 120),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    label: '${t.minutes} min',
                    onChanged: t.running ? null : (v) => t.setMinutes(v.round()),
                  ),
                ),
                SizedBox(width: 56, child: Text('${t.minutes} min', textAlign: TextAlign.end)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(t.running ? Icons.pause : Icons.play_arrow),
                    label: Text(t.running ? 'Pausar' : (t.active ? 'Continuar' : 'Iniciar')),
                    onPressed: t.running ? t.pause : t.start,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Zerar'),
                  onPressed: t.active ? t.reset : null,
                ),
              ]),
              const SizedBox(height: 18),
              Text('Cor', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                ChoiceChip(
                  label: const Text('Automática'),
                  selected: t.color < 0,
                  onSelected: (_) => t.setLook(color: -1),
                ),
                for (var i = 0; i < ReadingTimer.colors.length; i++)
                  GestureDetector(
                    onTap: () => t.setLook(color: i),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ReadingTimer.colors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                            width: t.color == i ? 3.5 : 1, color: t.color == i ? theme.colorScheme.primary : Colors.black26),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Text('Fundo', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.opacity), label: Text('Transparente')),
                  ButtonSegment(value: true, icon: Icon(Icons.circle), label: Text('Opaco')),
                ],
                selected: {t.opaque},
                onSelectionChanged: (v) => t.setLook(opaque: v.first),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
