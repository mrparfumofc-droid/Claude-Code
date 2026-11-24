import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reader_settings.dart';
import '../state/app_state.dart';

/// Painel rápido de leitura (botão "TT"): fonte, alinhamento, layout e cor da página.
Future<void> showQuickSettings(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ReadingControls(),
        ),
      ),
    );

/// Controles de leitura, usados no painel rápido e nas Configurações.
class ReadingControls extends StatelessWidget {
  const ReadingControls({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    void set(ReaderSettings n) => app.updateSettings(n);
    final label = Theme.of(context).textTheme.titleSmall;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tamanho da fonte: ${s.fontSize.round()}', style: label),
      Row(children: [
        IconButton(
          onPressed: s.fontSize > 12 ? () => set(s.copyWith(fontSize: s.fontSize - 1)) : null,
          icon: const Icon(Icons.text_decrease),
        ),
        Expanded(
          child: Slider(
            min: 12,
            max: 48,
            divisions: 36,
            value: s.fontSize.clamp(12, 48),
            onChanged: (v) => set(s.copyWith(fontSize: v)),
          ),
        ),
        IconButton(
          onPressed: s.fontSize < 48 ? () => set(s.copyWith(fontSize: s.fontSize + 1)) : null,
          icon: const Icon(Icons.text_increase),
        ),
      ]),
      Text('Alinhamento do texto', style: label),
      const SizedBox(height: 6),
      SegmentedButton<TextAlign>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left)),
          ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center)),
          ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right)),
          ButtonSegment(value: TextAlign.justify, icon: Icon(Icons.format_align_justify)),
        ],
        selected: {s.align},
        onSelectionChanged: (v) => set(s.copyWith(align: v.first)),
      ),
      const SizedBox(height: 12),
      Text('Tipo de fonte', style: label),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final (f, name) in const [
          (FontKind.normal, 'Normal'),
          (FontKind.monospace, 'Monospace'),
          (FontKind.sansSerif, 'Sans Serif'),
          (FontKind.serif, 'Serif'),
        ])
          ChoiceChip(
            label: Text(name),
            selected: s.font == f,
            onSelected: (_) => set(s.copyWith(font: f)),
          ),
      ]),
      const SizedBox(height: 12),
      Text('Layout', style: label),
      const SizedBox(height: 6),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Layout clássico')),
          ButtonSegment(value: true, label: Text('Versículo por versículo')),
        ],
        selected: {s.verseByVerse},
        onSelectionChanged: (v) => set(s.copyWith(verseByVerse: v.first)),
      ),
      const SizedBox(height: 12),
      Text('Cor da página', style: label),
      const SizedBox(height: 6),
      Wrap(spacing: 10, children: [
        for (final (c, name, bg) in const [
          (PageColor.white, 'Branco', Colors.white),
          (PageColor.sepia, 'Sépia', Color(0xFFF4ECD8)),
          (PageColor.green, 'Verde', Color(0xFFE3F0E0)),
          (PageColor.dark, 'Escuro', Color(0xFF2B2B2B)),
          (PageColor.black, 'Preto', Colors.black),
        ])
          Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => set(s.copyWith(pageColor: c)),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: CircleAvatar(
                  radius: s.pageColor == c ? 16 : 19,
                  backgroundColor: bg,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 12)),
          ]),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Modo noturno do app'),
        subtitle: const Text('Deixa menus e telas escuros. A cor da página da Bíblia é escolhida acima.'),
        value: s.nightMode,
        onChanged: (v) => set(s.copyWith(nightMode: v)),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: s.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          'No princípio criou Deus os céus e a terra.',
          textAlign: s.align,
          style: TextStyle(
            fontSize: s.fontSize,
            height: s.lineHeight,
            fontFamily: s.fontFamily,
            color: s.foreground,
          ),
        ),
      ),
    ]);
  }
}
