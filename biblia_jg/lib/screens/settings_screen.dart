import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reader_settings.dart';
import '../services/palm_guard.dart';
import '../state/app_state.dart';
import '../widgets/quick_settings_sheet.dart';
import 'versions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    void set(ReaderSettings n) => app.updateSettings(n);
    final section = Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold);

    Widget header(String t) =>
        Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 8), child: Text(t, style: section));

    Widget sw(String title, String? sub, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: sub == null ? null : Text(sub),
          value: value,
          onChanged: onChanged,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            header('Leitura da Bíblia'),
            const ReadingControls(),
            const SizedBox(height: 16),
            Text('Espaço entre versículos: ${s.verseSpacing.round()}'),
            Slider(
              min: 0,
              max: 24,
              divisions: 24,
              value: s.verseSpacing.clamp(0, 24),
              onChanged: (v) => set(s.copyWith(verseSpacing: v)),
            ),
            Text('Espaço entre linhas: ${s.lineHeight.toStringAsFixed(1)}x'),
            Slider(
              min: 0.7,
              max: 3.0,
              divisions: 23,
              value: s.lineHeight.clamp(0.7, 3.0),
              onChanged: (v) =>
                  set(s.copyWith(lineHeight: double.parse(v.toStringAsFixed(1)))),
            ),
            header('Cor do tema'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final e in ReaderSettings.themeColorOptions.entries)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: e.value),
                  label: Text(e.key),
                  selected: s.themeColor.toARGB32() == e.value.toARGB32(),
                  onSelected: (_) => set(s.copyWith(themeColor: e.value)),
                ),
            ]),
            header('Texto'),
            sw('Remover espaço inicial', 'Remove o espaço no começo de cada versículo',
                s.trimLeadingSpace, (v) => set(s.copyWith(trimLeadingSpace: v))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Estilo do número do versículo'),
              subtitle: const Text('Pequeno (sobrescrito) ou do tamanho do texto'),
              trailing: SegmentedButton<VerseNumberStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: VerseNumberStyle.superscript, label: Text('¹ Pequeno')),
                  ButtonSegment(value: VerseNumberStyle.inline, label: Text('1 Normal')),
                ],
                selected: {s.verseNumberStyle},
                onSelectionChanged: (v) => set(s.copyWith(verseNumberStyle: v.first)),
              ),
            ),
            sw('Remover títulos', 'Esconde os títulos de seção da Bíblia', s.hideTitles,
                (v) => set(s.copyWith(hideTitles: v))),
            sw('Palavras de Jesus em cor',
                'Mostra em destaque as palavras de Jesus quando a versão tiver essa marcação',
                s.jesusWordsInColor, (v) => set(s.copyWith(jesusWordsInColor: v))),
            if (s.jesusWordsInColor)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in ReaderSettings.jesusColorOptions.entries)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: e.value),
                    label: Text(e.key),
                    selected: s.jesusColor.toARGB32() == e.value.toARGB32(),
                    onSelected: (_) => set(s.copyWith(jesusColor: e.value)),
                  ),
              ]),
            header('Tela'),
            sw('Ocultar menus ao rolar', 'Esconde a barra de cima enquanto você lê',
                s.hideMenusOnScroll, (v) => set(s.copyWith(hideMenusOnScroll: v))),
            sw('Tela ligada', 'Mantém a tela ligada enquanto o app estiver aberto',
                s.keepScreenOn, (v) => set(s.copyWith(keepScreenOn: v))),
            sw('Tela cheia', 'Esconde as barras do sistema', s.fullScreen,
                (v) => set(s.copyWith(fullScreen: v))),
            header('Caneta'),
            const PalmModeSelector(),
            header('Notificações'),
            sw('Versículo do dia', 'Receber um versículo por dia', s.verseOfDayEnabled,
                (v) => set(s.copyWith(verseOfDayEnabled: v))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: s.verseOfDayEnabled,
              title: const Text('Hora do versículo do dia'),
              trailing: Text(s.verseOfDayTime.format(context),
                  style: Theme.of(context).textTheme.titleMedium),
              onTap: () async {
                final t = await showTimePicker(
                    context: context, initialTime: s.verseOfDayTime);
                if (t != null) set(s.copyWith(verseOfDayTime: t));
              },
            ),
            sw('Passagem do domingo', 'Um texto bíblico todo domingo de manhã',
                s.sundayPassage, (v) => set(s.copyWith(sundayPassage: v))),
            header('Traduções da Bíblia'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.translate),
              title: const Text('Versões'),
              subtitle: Text(app.bible?.name ?? 'Nenhuma instalada'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const VersionsScreen())),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
