import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/stories.dart';
import '../theme.dart';
import '../widgets/parallax_image.dart';
import 'content_screens.dart' show AiStoriesScreen;
import 'story_player_screen.dart';

/// Histórias bíblicas ilustradas e narradas, por coleção.
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  StoriesData? _data;
  Set<String> _done = const {};
  (List<String>, String)? _voices; // amostras de voz do narrador (quando houver)

  @override
  void initState() {
    super.initState();
    StoriesData.revision.addListener(_reload);
    _reload().then((_) => StoriesData.refreshIfStale());
    NarratorVoices.load().then((v) {
      if (mounted && v != null) setState(() => _voices = v);
    });
  }

  Future<void> _pickVoice() async {
    final voices = _voices;
    if (voices == null) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _VoiceSheet(voices: voices.$1, current: voices.$2),
    );
    if (chosen == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await NarratorVoices.choose(chosen);
    if (!mounted) return;
    if (ok) setState(() => _voices = (voices.$1, chosen));
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Voz escolhida. As narrações passam a ser gravadas com ela, cerca de 40 por dia.'
          : 'Não consegui guardar a escolha. Confira a internet e tente de novo.'),
    ));
  }

  @override
  void dispose() {
    StoriesData.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final data = await StoriesData.load();
    final done = await StoriesData.finished();
    if (mounted) {
      setState(() {
        _data = data;
        _done = done;
      });
    }
  }

  Future<void> _open(BibleStory story) async {
    final list = _data!.byCategory(story.category);
    final i = list.indexOf(story);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BibleStoryPlayer(story: story, next: i + 1 < list.length ? list[i + 1] : null),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórias bíblicas')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 720;
              final cardW = wide ? 300.0 : 232.0;
              // Destaque: a primeira história ainda não ouvida.
              final featured = data.stories.firstWhere((s) => s.hasCover && !_done.contains(s.id),
                  orElse: () => data.stories.firstWhere((s) => s.hasCover, orElse: () => data.stories.first));
              return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _Featured(story: featured, wide: wide, onTap: () => _open(featured)),
                ),
                for (final (cat, title, sub) in storyCategories)
                  if (data.byCategory(cat).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 2),
                      child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$sub · ${data.byCategory(cat).length} histórias',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    SizedBox(
                      height: cardW * 9 / 16 + 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        itemCount: data.byCategory(cat).length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final s = data.byCategory(cat)[i];
                          return SizedBox(
                            width: cardW,
                            child: _StoryCard(story: s, done: _done.contains(s.id), onTap: () => _open(s)),
                          );
                        },
                      ),
                    ),
                  ],
                const SizedBox(height: 12),
                if (_voices != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.record_voice_over),
                        title: const Text('Voz do narrador'),
                        subtitle: Text('Em uso: ${_voices!.$2}. Ouça as amostras e escolha a que preferir.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickVoice,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: const Text('Outras histórias, contadas pela IA'),
                      subtitle: const Text('Peça qualquer história; a IA conta na hora (precisa de internet).'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiStoriesScreen())),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                    'Ilustrações e narração criadas com inteligência artificial como reconstituição artística; '
                    'não são retratos históricos. O texto segue as passagens indicadas em cada cena.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ]);
            }),
    );
  }
}

/// Lista as vozes com amostra: tocar para ouvir, escolher para usar nas próximas gravações.
class _VoiceSheet extends StatefulWidget {
  final List<String> voices;
  final String current;
  const _VoiceSheet({required this.voices, required this.current});

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final _player = AudioPlayer();
  String? _playing;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String voice) async {
    if (_playing == voice) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    setState(() => _playing = voice);
    try {
      await _player.setUrl(NarratorVoices.sampleUrl(voice));
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
              title: Text('Escolha a voz do narrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('São vozes masculinas de locução. A escolhida vale para as próximas gravações; '
                  'as cenas já gravadas são refeitas aos poucos.'),
            ),
            for (final v in widget.voices)
              ListTile(
                leading: IconButton.filledTonal(
                  tooltip: 'Ouvir a amostra',
                  icon: Icon(_playing == v ? Icons.stop : Icons.play_arrow),
                  onPressed: () => _toggle(v),
                ),
                title: Text('Voz $v'),
                subtitle: v == widget.current ? const Text('em uso agora') : null,
                trailing: FilledButton(
                  onPressed: v == widget.current ? null : () => Navigator.pop(context, v),
                  child: const Text('Escolher'),
                ),
              ),
          ]),
        ),
      );
}

String _meta(BibleStory s) => '${s.scenes.length} cenas · ${s.minutes} min${s.hasMap ? ' · com mapa' : ''}';

class _Featured extends StatelessWidget {
  final BibleStory story;
  final bool wide;
  final VoidCallback onTap;
  const _Featured({required this.story, required this.wide, required this.onTap});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: wide ? 300 : 220,
            child: Stack(fit: StackFit.expand, children: [
              StoryThumb(imageKey: story.hasCover ? story.cover : null, tint: story.color, large: true),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xD9000000)],
                    stops: [0.3, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('OUVIR AGORA',
                        style: TextStyle(color: story.color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(story.title,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: wide ? 30 : 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                            height: 1.1)),
                    const SizedBox(height: 4),
                    Text(story.summary.isEmpty ? story.subtitle : story.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.3)),
                    const SizedBox(height: 10),
                    Row(children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: jgGold, foregroundColor: Colors.black),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Tocar'),
                        onPressed: onTap,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text('${story.reference} · ${_meta(story)}',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class _StoryCard extends StatelessWidget {
  final BibleStory story;
  final bool done;
  final VoidCallback onTap;
  const _StoryCard({required this.story, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              StoryThumb(imageKey: story.hasCover ? story.cover : null, tint: story.color),
              Positioned(
                left: 8,
                bottom: 8,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow, color: story.color, size: 20),
                ),
              ),
              if (!story.hasCover)
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_stories, color: story.color, size: 34),
                    const SizedBox(height: 4),
                    const Text('ilustrações a caminho', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              if (done)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                      radius: 12, backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 16)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(story.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(story.subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(_meta(story),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}
