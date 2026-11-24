import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reference_parser.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import 'dictionary_screen.dart' show showBiblePassage;

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correct;
  final String reference;
  final String explanation;
  QuizQuestion(this.question, this.options, this.correct, this.reference, this.explanation);
}

List<QuizQuestion> parseQuiz(String raw) {
  var text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) text = text.substring(start, end + 1);
  final data = jsonDecode(text) as Map<String, dynamic>;
  final list = (data['perguntas'] as List).cast<Map<String, dynamic>>();
  return [
    for (final q in list)
      if (q['opcoes'] is List && (q['opcoes'] as List).length >= 2)
        QuizQuestion(
          q['pergunta'].toString(),
          (q['opcoes'] as List).map((e) => e.toString()).toList(),
          (q['correta'] as num?)?.toInt() ?? 0,
          (q['referencia'] ?? '').toString(),
          (q['explicacao'] ?? '').toString(),
        ),
  ];
}

const _themes = [
  'Conhecimentos gerais da Bíblia',
  'Gênesis',
  'Êxodo e Moisés',
  'Reis de Israel',
  'Profetas',
  'Salmos e Provérbios',
  'Vida de Jesus',
  'Parábolas de Jesus',
  'Milagres de Jesus',
  'Atos dos Apóstolos',
  'Cartas de Paulo',
  'Apocalipse',
  'Mulheres da Bíblia',
  'Personagens do Antigo Testamento',
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _theme = _themes.first;
  String _level = 'médio';
  List<QuizQuestion>? _questions;
  final Map<int, int> _answers = {};
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _questions = null;
      _answers.clear();
    });
    try {
      final raw = await AiService.ask(
        task: 'quiz',
        messages: [
          AiTurn(true,
              'Crie 10 perguntas de nível $_level sobre o tema "$_theme". Varie o tipo de pergunta e indique a referência bíblica de cada resposta.'),
        ],
      );
      final q = parseQuiz(raw);
      if (q.isEmpty) throw const FormatException('sem perguntas');
      setState(() => _questions = q);
    } on AiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'A IA respondeu num formato inesperado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final questions = _questions;
    final score = questions == null
        ? 0
        : _answers.entries.where((e) => questions[e.key].correct == e.value).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Perguntas bíblicas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Tema', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _themes)
                ChoiceChip(label: Text(t), selected: _theme == t, onSelected: (_) => setState(() => _theme = t)),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fácil', label: Text('Fácil')),
                ButtonSegment(value: 'médio', label: Text('Médio')),
                ButtonSegment(value: 'difícil', label: Text('Difícil')),
              ],
              selected: {_level},
              onSelectionChanged: (v) => setState(() => _level = v.first),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.quiz),
              label: Text(questions == null ? 'Gerar 10 perguntas' : 'Gerar novas perguntas'),
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            if (questions != null) ...[
              const SizedBox(height: 16),
              Text('Acertos: $score de ${_answers.length} respondidas (${questions.length} perguntas)',
                  style: Theme.of(context).textTheme.titleMedium),
              for (var i = 0; i < questions.length; i++) _card(i, questions[i], app),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _card(int i, QuizQuestion q, AppState app) {
    final answered = _answers[i];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q.question}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (var o = 0; o < q.options.length; o++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: answered == null
                      ? null
                      : o == q.correct
                          ? Colors.green.withValues(alpha: 0.25)
                          : o == answered
                              ? Colors.red.withValues(alpha: 0.25)
                              : null,
                ),
                onPressed: answered == null ? () => setState(() => _answers[i] = o) : null,
                child: Text('${String.fromCharCode(65 + o)}) ${q.options[o]}'),
              ),
            ),
          if (answered != null) ...[
            Text(answered == q.correct ? '✔ Correto!' : '✘ Resposta certa: ${String.fromCharCode(65 + q.correct)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: answered == q.correct ? Colors.green : Colors.red)),
            if (q.explanation.isNotEmpty) Text(q.explanation),
            if (q.reference.isNotEmpty)
              Builder(builder: (context) {
                final p = parseReference(q.reference) ?? findReferences(q.reference).firstOrNull;
                return TextButton.icon(
                  onPressed: p == null
                      ? null
                      : () => showBiblePassage(context, p), // painel: não perde o quiz respondido
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: Text(q.reference),
                );
              }),
          ],
        ]),
      ),
    );
  }
}
