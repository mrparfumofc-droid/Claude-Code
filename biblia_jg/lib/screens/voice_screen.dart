import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tts.dart';

const _sample =
    'No princípio era o Verbo, e o Verbo estava com Deus, e o Verbo era Deus.';

String engineName(String e) => switch (e) {
      'com.google.android.tts' => 'Google (mais natural)',
      'com.samsung.SMT' => 'Samsung',
      _ when e.contains('google') => 'Google',
      _ when e.contains('samsung') => 'Samsung',
      _ => e,
    };

/// Escolha do mecanismo de fala, da voz, da velocidade e do tom da leitura.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  List<String>? _engines;
  List<TtsVoice>? _voices;
  late final ReadAloud _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<ReadAloud>();
    _load();
  }

  Future<void> _load() async {
    final tts = _tts;
    final engines = await tts.engines();
    final voices = await tts.voices('pt');
    if (!mounted) return;
    setState(() {
      _engines = engines;
      _voices = voices;
    });
  }

  @override
  void dispose() {
    // Para a amostra ao sair.
    if (!_tts.speaking) _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<ReadAloud>();
    final theme = Theme.of(context);
    final engines = _engines;
    final voices = _voices;
    final hasGoogle = engines?.contains('com.google.android.tts') ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Voz da leitura')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text('Ouvir amostra'),
                subtitle: const Text('Com a voz, velocidade e tom escolhidos'),
                trailing: const Icon(Icons.play_circle_outline),
                onTap: () => tts.preview(_sample),
              ),
            ),
            const SizedBox(height: 12),
            Text('Mecanismo de fala', style: theme.textTheme.titleSmall),
            if (engines == null)
              const LinearProgressIndicator()
            else ...[
              RadioGroup<String?>(
                groupValue: tts.engine,
                onChanged: (e) async {
                  await tts.setEngine(e);
                  await _load();
                },
                child: Column(children: [
                  const RadioListTile<String?>(value: null, title: Text('Padrão do tablet')),
                  for (final e in engines)
                    RadioListTile<String?>(value: e, title: Text(engineName(e))),
                ]),
              ),
              if (!hasGoogle)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Para vozes mais naturais, instale "Serviços de fala do Google" pela Play Store e volte aqui.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text('Voz (português)', style: theme.textTheme.titleSmall),
            Text('As vozes "online" são as mais naturais (precisam de internet).',
                style: theme.textTheme.bodySmall),
            if (voices == null)
              const LinearProgressIndicator()
            else if (voices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Este mecanismo não informou vozes. Use o padrão ou troque o mecanismo.'),
              )
            else
              RadioGroup<String?>(
                groupValue: tts.voiceName,
                onChanged: (name) =>
                    tts.setVoice(name == null ? null : voices.firstWhere((v) => v.name == name)),
                child: Column(children: [
                  const RadioListTile<String?>(value: null, title: Text('Automática')),
                  for (var i = 0; i < voices.length; i++)
                    RadioListTile<String?>(
                      value: voices[i].name,
                      title: Text(voices[i].label(i)),
                      subtitle: Text(voices[i].locale),
                      secondary: IconButton(
                        tooltip: 'Ouvir esta voz',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => tts.preview(_sample, v: voices[i]),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 12),
            Text('Velocidade', style: theme.textTheme.titleSmall),
            Slider(
              min: 0.25,
              max: 1.0,
              divisions: 15,
              value: tts.rate.clamp(0.25, 1.0),
              label: '${(tts.rate * 2).toStringAsFixed(2)}x',
              onChanged: tts.setRate,
            ),
            Text('Tom', style: theme.textTheme.titleSmall),
            Slider(
              min: 0.6,
              max: 1.6,
              divisions: 10,
              value: tts.pitch.clamp(0.6, 1.6),
              label: tts.pitch.toStringAsFixed(1),
              onChanged: tts.setPitch,
            ),
          ]),
        ),
      ),
    );
  }
}
