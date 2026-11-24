import 'package:flutter/material.dart';

import '../models/daily.dart';
import '../state/app_state.dart';
import 'ai_chat_screen.dart';

String _today() {
  final d = DateTime.now();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Devocional do dia, escrito pela IA a partir do versículo do dia (fica guardado no aparelho).
void openDevotional(BuildContext context, AppState app) {
  final now = DateTime.now();
  final ref = verseOfDay(now);
  final bible = app.bible;
  final text = bible == null ? null : verseText(bible, ref);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AiChatScreen(
      title: 'Devocional diário',
      task: 'devotional',
      reference: ref.label(bible),
      version: bible?.abbrev,
      verseText: text,
      cacheKey: 'devo_${now.year}-${now.month}-${now.day}',
      initialPrompt: 'Escreva o devocional de hoje (${_today()}) usando este versículo como base.',
      quickActions: const [
        ('Oração mais longa', 'chat', 'Escreva uma oração mais longa baseada neste devocional.'),
        ('Para a família', 'chat', 'Adapte este devocional para ler em família, com crianças.'),
      ],
    ),
  ));
}

/// Assistente de IA livre (conversa sobre a Bíblia).
void openAssistant(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => const AiChatScreen(title: 'Assistente bíblico (IA)', task: 'chat'),
  ));
}

class _Story {
  final String title;
  final String reference;
  const _Story(this.title, this.reference);
}

const _oldTestamentStories = [
  _Story('A Criação', 'Gênesis 1–2'),
  _Story('Adão e Eva e a queda', 'Gênesis 3'),
  _Story('Caim e Abel', 'Gênesis 4'),
  _Story('Noé e o dilúvio', 'Gênesis 6–9'),
  _Story('A Torre de Babel', 'Gênesis 11'),
  _Story('O chamado de Abraão', 'Gênesis 12'),
  _Story('Abraão e Isaque no monte Moriá', 'Gênesis 22'),
  _Story('Jacó e Esaú', 'Gênesis 25–27'),
  _Story('A escada de Jacó', 'Gênesis 28'),
  _Story('José e seus irmãos', 'Gênesis 37–45'),
  _Story('Moisés e a sarça ardente', 'Êxodo 3'),
  _Story('As dez pragas do Egito', 'Êxodo 7–12'),
  _Story('A travessia do Mar Vermelho', 'Êxodo 14'),
  _Story('Os Dez Mandamentos', 'Êxodo 20'),
  _Story('As muralhas de Jericó', 'Josué 6'),
  _Story('Gideão e os 300', 'Juízes 7'),
  _Story('Sansão', 'Juízes 13–16'),
  _Story('Rute e Noemi', 'Rute 1–4'),
  _Story('O chamado de Samuel', '1 Samuel 3'),
  _Story('Davi e Golias', '1 Samuel 17'),
  _Story('Davi e Jônatas', '1 Samuel 18–20'),
  _Story('A sabedoria de Salomão', '1 Reis 3'),
  _Story('Elias no monte Carmelo', '1 Reis 18'),
  _Story('Eliseu e a viúva', '2 Reis 4'),
  _Story('Naamã é curado', '2 Reis 5'),
  _Story('A rainha Ester', 'Ester 1–10'),
  _Story('Jó: fé na provação', 'Jó 1–2; 42'),
  _Story('Daniel na cova dos leões', 'Daniel 6'),
  _Story('A fornalha ardente', 'Daniel 3'),
  _Story('Jonas e o grande peixe', 'Jonas 1–4'),
  _Story('Neemias reconstrói os muros', 'Neemias 1–6'),
];

const _newTestamentStories = [
  _Story('O nascimento de Jesus', 'Lucas 2'),
  _Story('Os magos do Oriente', 'Mateus 2'),
  _Story('O batismo de Jesus', 'Mateus 3'),
  _Story('A tentação no deserto', 'Mateus 4'),
  _Story('As bodas de Caná', 'João 2'),
  _Story('Nicodemos', 'João 3'),
  _Story('A mulher samaritana', 'João 4'),
  _Story('O Sermão do Monte', 'Mateus 5–7'),
  _Story('Jesus acalma a tempestade', 'Marcos 4'),
  _Story('A multiplicação dos pães', 'João 6'),
  _Story('Jesus anda sobre as águas', 'Mateus 14'),
  _Story('O bom samaritano', 'Lucas 10'),
  _Story('O filho pródigo', 'Lucas 15'),
  _Story('Zaqueu', 'Lucas 19'),
  _Story('A ressurreição de Lázaro', 'João 11'),
  _Story('A entrada triunfal', 'Mateus 21'),
  _Story('A Santa Ceia', 'Lucas 22'),
  _Story('A crucificação', 'Mateus 27'),
  _Story('A ressurreição', 'João 20'),
  _Story('O caminho de Emaús', 'Lucas 24'),
  _Story('Pentecostes', 'Atos 2'),
  _Story('A conversão de Saulo', 'Atos 9'),
  _Story('Pedro e Cornélio', 'Atos 10'),
  _Story('Paulo e Silas na prisão', 'Atos 16'),
  _Story('O naufrágio de Paulo', 'Atos 27'),
];

/// Lista antiga: histórias contadas na hora pela IA (as ilustradas ficam em stories_screen.dart).
class AiStoriesScreen extends StatelessWidget {
  const AiStoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget section(String title, List<_Story> list, int offset) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (var i = 0; i < list.length; i++)
              ListTile(
                leading: const Icon(Icons.auto_stories),
                title: Text(list[i].title),
                subtitle: Text(list[i].reference),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AiChatScreen(
                    title: list[i].title,
                    task: 'story',
                    cacheKey: 'story_${offset + i}',
                    initialPrompt: 'Conte a história "${list[i].title}" (${list[i].reference}).',
                    quickActions: const [
                      ('Versão para crianças', 'story', 'Conte esta mesma história de forma simples para crianças de 6 a 10 anos.'),
                      ('Perguntas para discussão', 'chat', 'Sugira 5 perguntas para discutir esta história em grupo.'),
                    ],
                  ),
                )),
              ),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Histórias contadas pela IA')),
      body: ListView(children: [
        section('Antigo Testamento', _oldTestamentStories, 0),
        section('Novo Testamento', _newTestamentStories, 100),
      ]),
    );
  }
}
