import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'content_screens.dart' show openDevotional;

/// O que a pessoa contou sobre si para o devocional ser montado sob medida.
class DevotionalProfile {
  String goal;
  String day;
  String time; // "06:30"
  int minutes;
  List<String> habits;
  String habitsNote;
  String season;
  String tone;
  String favorites;

  DevotionalProfile({
    this.goal = '',
    this.day = '',
    this.time = '',
    this.minutes = 10,
    List<String>? habits,
    this.habitsNote = '',
    this.season = '',
    this.tone = 'Acolhedor',
    this.favorites = '',
  }) : habits = habits ?? [];

  static const prefKey = 'devocional.perfil';

  bool get isEmpty =>
      goal.trim().isEmpty && day.trim().isEmpty && season.trim().isEmpty && habits.isEmpty && habitsNote.trim().isEmpty && favorites.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'objetivo': goal,
        'dia': day,
        'horario': time,
        'minutos': minutes,
        'habitos': habits,
        'habitos_nota': habitsNote,
        'momento': season,
        'tom': tone,
        'favoritos': favorites,
      };

  static DevotionalProfile load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(prefKey);
      if (raw == null) return DevotionalProfile();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DevotionalProfile(
        goal: j['objetivo'] as String? ?? '',
        day: j['dia'] as String? ?? '',
        time: j['horario'] as String? ?? '',
        minutes: (j['minutos'] as num?)?.toInt() ?? 10,
        habits: [for (final h in j['habitos'] as List? ?? const []) '$h'],
        habitsNote: j['habitos_nota'] as String? ?? '',
        season: j['momento'] as String? ?? '',
        tone: j['tom'] as String? ?? 'Acolhedor',
        favorites: j['favoritos'] as String? ?? '',
      );
    } catch (_) {
      return DevotionalProfile();
    }
  }

  Future<void> save(SharedPreferences prefs) => prefs.setString(prefKey, jsonEncode(toJson()));

  /// Muda quando o perfil muda (o devocional do dia é refeito).
  String get signature => jsonEncode(toJson()).hashCode.toUnsigned(32).toRadixString(36);

  /// Pedido enviado à IA.
  String prompt(String today) {
    final lines = <String>[
      if (goal.trim().isNotEmpty) '- Meu objetivo agora: ${goal.trim()}',
      if (day.trim().isNotEmpty) '- Como é o meu dia: ${day.trim()}',
      '- Faço o devocional${time.isEmpty ? '' : ' às $time'} e tenho cerca de $minutes minutos.',
      if (habits.isNotEmpty || habitsNote.trim().isNotEmpty)
        '- Meus hábitos: ${[...habits, if (habitsNote.trim().isNotEmpty) habitsNote.trim()].join('; ')}',
      if (season.trim().isNotEmpty) '- O que estou vivendo: ${season.trim()}',
      '- Tom que prefiro: $tone.',
      if (favorites.trim().isNotEmpty) '- Livros ou temas de que gosto: ${favorites.trim()}',
    ];
    final journal = habits.any((h) => h.toLowerCase().contains('anot'));
    return 'Monte o meu devocional de hoje ($today), feito sob medida para mim. Sobre mim:\n${lines.join('\n')}\n\n'
        'Use o versículo do dia como base; se outro trecho curto combinar melhor com o meu objetivo, use-o e diga a referência. '
        'Estrutura: 1) um título curto; 2) a leitura (referência e o texto); 3) uma reflexão ligada ao meu objetivo e ao que estou vivendo; '
        '4) uma aplicação prática que caiba no meu dia de hoje, dizendo em que momento fazer; 5) uma oração curta; '
        '6) um desafio para as próximas 24 horas${journal ? '; 7) uma pergunta para eu responder no meu caderno' : ''}. '
        'O tamanho deve caber em cerca de $minutes minutos de leitura e oração. Não repita a lista que eu informei: fale comigo a partir do que eu vivo.';
  }
}

const _goalIdeas = [
  'Ter constância na oração',
  'Vencer a ansiedade',
  'Ler a Bíblia inteira',
  'Cuidar melhor da família',
  'Preparar-me para ensinar e pregar',
  'Tomar uma decisão importante',
];
const _habitIdeas = [
  'Gosto de anotar',
  'Oro em voz alta',
  'Ouço louvor enquanto leio',
  'Faço com a família',
  'Leio no intervalo do trabalho',
  'Gosto de memorizar versículos',
];
const _tones = ['Acolhedor', 'Direto', 'Profundo', 'Prático'];

/// Devocional sob medida: a pessoa conta o objetivo, a rotina e os hábitos, e a IA monta o devocional do dia.
class DevotionalScreen extends StatefulWidget {
  const DevotionalScreen({super.key});

  @override
  State<DevotionalScreen> createState() => _DevotionalScreenState();
}

class _DevotionalScreenState extends State<DevotionalScreen> {
  late final AppState _app = context.read<AppState>();
  late final DevotionalProfile _p = DevotionalProfile.load(_app.prefs);
  late final _goal = TextEditingController(text: _p.goal);
  late final _day = TextEditingController(text: _p.day);
  late final _habits = TextEditingController(text: _p.habitsNote);
  late final _season = TextEditingController(text: _p.season);
  late final _favorites = TextEditingController(text: _p.favorites);

  @override
  void dispose() {
    for (final c in [_goal, _day, _habits, _season, _favorites]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() {
    _p
      ..goal = _goal.text
      ..day = _day.text
      ..habitsNote = _habits.text
      ..season = _season.text
      ..favorites = _favorites.text;
    return _p.save(_app.prefs);
  }

  Future<void> _pickTime() async {
    final parts = _p.time.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 6, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 6, minute: 0);
    final t = await showTimePicker(context: context, initialTime: initial, helpText: 'Horário do seu devocional');
    if (t == null) return;
    setState(() => _p.time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    _save();
  }

  Future<void> _openToday() async {
    await _save();
    if (mounted) openDevotional(context, _app);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text, [String? hint]) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (hint != null) Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        );
    Widget field(TextEditingController c, String hint, {int lines = 2}) => TextField(
          controller: c,
          minLines: lines,
          maxLines: lines + 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _save(),
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Devocional sob medida')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Conte um pouco sobre você', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Com o seu objetivo, a sua rotina e os seus hábitos, a IA monta todo dia um devocional só seu. '
                      'Preencha o que quiser; dá para mudar quando a vida mudar.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text(_p.isEmpty && _goal.text.trim().isEmpty ? 'Abrir o devocional de hoje' : 'Montar o meu devocional de hoje'),
                    onPressed: _openToday,
                  ),
                ]),
              ),
            ),
            label('Qual é o seu objetivo agora?', 'O que você quer que mude na sua vida com Deus.'),
            field(_goal, 'Ex.: quero voltar a orar todos os dias e ter mais paz para decidir'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final g in _goalIdeas)
                ActionChip(
                  label: Text(g),
                  onPressed: () {
                    setState(() => _goal.text = _goal.text.trim().isEmpty ? g : '${_goal.text.trim()}; ${g.toLowerCase()}');
                    _save();
                  },
                ),
            ]),
            label('Como é o seu dia?', 'Trabalho, família, horários apertados, deslocamento…'),
            field(_day, 'Ex.: acordo às 5h30, trabalho na loja até as 18h e à noite fico com as crianças'),
            label('Quando e por quanto tempo?'),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(_p.time.isEmpty ? 'Escolher o horário' : 'Às ${_p.time}'),
                onPressed: _pickTime,
              ),
              for (final m in const [5, 10, 15, 20, 30])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _p.minutes == m,
                  onSelected: (_) {
                    setState(() => _p.minutes = m);
                    _save();
                  },
                ),
            ]),
            label('Seus hábitos', 'Marque o que combina com você e acrescente o que quiser.'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in _habitIdeas)
                FilterChip(
                  label: Text(h),
                  selected: _p.habits.contains(h),
                  onSelected: (on) {
                    setState(() => on ? _p.habits.add(h) : _p.habits.remove(h));
                    _save();
                  },
                ),
            ]),
            const SizedBox(height: 8),
            field(_habits, 'Outros hábitos (opcional)', lines: 1),
            label('O que você está vivendo?', 'Uma fase, um desafio, uma gratidão. Fica só no seu aparelho e na sua conta.'),
            field(_season, 'Ex.: começando um negócio; cuidando da minha mãe; preparando uma aula da EBD'),
            label('Como você prefere que fale com você?'),
            Wrap(spacing: 8, children: [
              for (final t in _tones)
                ChoiceChip(
                  label: Text(t),
                  selected: _p.tone == t,
                  onSelected: (_) {
                    setState(() => _p.tone = t);
                    _save();
                  },
                ),
            ]),
            label('Livros ou temas de que você gosta', 'Opcional.'),
            field(_favorites, 'Ex.: Salmos, cartas de Paulo, fé e trabalho', lines: 1),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Salvar e montar o devocional de hoje'),
              onPressed: _openToday,
            ),
            const SizedBox(height: 8),
            Text('O devocional é escrito por IA a partir do que você informou e do versículo do dia. Confira sempre com a Bíblia.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
