import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/panorama.dart';
import '../widgets/portrait.dart';
import 'panorama_tree.dart' show RefChip, openPanoramaRef;

const _ppy = 4.2; // pontos por ano na linha do tempo
const _first = 930; // divisão do reino
const _last = 586; // queda de Jerusalém
const _axisWidth = 156.0;

double _y(int year) => (_first - year) * _ppy;

Color ratingColor(String rating) => switch (rating) {
      'bom' => const Color(0xFF2E7D32),
      'misto' => const Color(0xFFB7791F),
      _ => const Color(0xFFB03A3A),
    };

String ratingLabel(String rating) => switch (rating) {
      'bom' => 'Fez o que era reto diante do Senhor',
      'misto' => 'Começou bem, mas não foi até o fim',
      _ => 'Fez o que era mau diante do Senhor',
    };

class _Bar {
  final King king;
  final double top;
  final double height;
  final int lane;
  const _Bar(this.king, this.top, this.height, this.lane);
}

/// Distribui os reis em duas faixas por reino: reinados que se sobrepõem (corregências)
/// ou muito curtos vão para a faixa ao lado.
List<_Bar> _layout(List<King> kings) {
  final bottoms = [double.negativeInfinity, double.negativeInfinity];
  final out = <_Bar>[];
  for (final k in kings) {
    var top = _y(k.start);
    final h = math.max((k.start - k.end) * _ppy, 30.0);
    final lane = bottoms[0] <= top + 0.5 ? 0 : (bottoms[1] <= top + 0.5 ? 1 : (bottoms[0] <= bottoms[1] ? 0 : 1));
    if (bottoms[lane] > top) top = bottoms[lane] + 2;
    bottoms[lane] = top + h;
    out.add(_Bar(k, top, h - 2, lane));
  }
  return out;
}

/// Linha do tempo dos reis: o reino unido e, depois da divisão, Israel e Judá lado a lado,
/// em escala, com a cor mostrando como cada rei andou diante de Deus.
class KingsScreen extends StatefulWidget {
  const KingsScreen({super.key});

  @override
  State<KingsScreen> createState() => _KingsScreenState();
}

class _KingsScreenState extends State<KingsScreen> {
  KingsData? _data;

  @override
  void initState() {
    super.initState();
    PanoramaData.load().then((d) {
      if (mounted) setState(() => _data = d.kings);
    });
  }

  void _open(King k, String kingdom) {
    final color = ratingColor(k.rating);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PortraitAvatar(
                  name: 'Rei ${k.name}',
                  radius: 38,
                  hideWhenMissing: true,
                  ring: color,
                  zoomable: true,
                  margin: const EdgeInsets.only(right: 14)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.name,
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  Text('$kingdom · ${k.dates} · ${k.years}', style: Theme.of(ctx).textTheme.bodyMedium),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text(ratingLabel(k.rating), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Text(k.note, style: const TextStyle(fontSize: 16, height: 1.4)),
            if (k.prophets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Profetas da época: ${k.prophets}', style: Theme.of(ctx).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            RefChip(k.ref, color: color),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reis de Israel e Judá')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final width = math.max(box.maxWidth, 700.0);
              final israel = _layout(d.israel);
              final judah = _layout(d.judah);
              final height = [
                    _y(_last) + 70,
                    ...israel.map((b) => b.top + b.height + 30),
                    ...judah.map((b) => b.top + b.height + 30),
                  ].reduce(math.max) +
                  10;
              final goodJudah = d.judah.where((k) => k.rating == 'bom').length;

              Widget barBody(_Bar b, String kingdom) => Material(
                      color: ratingColor(b.king.rating),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _open(b.king, kingdom),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: b.height >= 48
                              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(b.king.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('${b.king.dates.replaceAll(' a.C.', '')} · ${b.king.years}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                                ])
                              : Row(children: [
                                  Flexible(
                                    child: Text(b.king.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(b.king.years,
                                      maxLines: 1, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ]),
                        ),
                      ),
                    );

              Widget header(String title, String subtitle, Color color) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  );

              return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
                Text('De Saul até o exílio', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Toque num rei para ver o resumo e a passagem. As datas são aproximadas; quando dois reinados se sobrepõem, pai e filho reinaram juntos por um tempo.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  for (final r in const ['bom', 'misto', 'mau'])
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: ratingColor(r), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 6),
                      Text(ratingLabel(r), style: theme.textTheme.bodySmall),
                    ]),
                ]),
                const SizedBox(height: 14),
                Text('O reino unido · 1050–930 a.C.', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final k in d.united)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Material(
                          color: ratingColor(k.rating),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _open(k, 'Reino unido'),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(children: [
                                PortraitAvatar(
                                    name: 'Rei ${k.name}',
                                    radius: 24,
                                    hideWhenMissing: true,
                                    ring: Colors.white54,
                                    margin: const EdgeInsets.only(right: 10)),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(k.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                                    Text('${k.dates.replaceAll(' a.C.', '')} · ${k.years}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width - 24,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        header('ISRAEL · NORTE', 'Capital Samaria · ${d.israel.length} reis, nenhum aprovado', const Color(0xFF37474F)),
                        const SizedBox(width: _axisWidth - 30),
                        header('JUDÁ · SUL', 'Capital Jerusalém · ${d.judah.length} reis, $goodJudah aprovados', const Color(0xFF1B2A4A)),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: height,
                        child: LayoutBuilder(builder: (context, inner) {
                          final w = inner.maxWidth;
                          final c = (w - _axisWidth) / 2;
                          final l = c / 2 - 6;
                          Widget b(_Bar x, double left, String kingdom) => Positioned(
                                left: left + x.lane * (l + 6) + 3,
                                top: x.top,
                                width: l,
                                height: x.height,
                                child: barBody(x, kingdom),
                              );
                          return Stack(clipBehavior: Clip.none, children: [
                            // Eixo do tempo e anos.
                            Positioned(
                              left: w / 2 - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 2, color: theme.colorScheme.outlineVariant),
                            ),
                            for (var year = 900; year >= 600; year -= 50)
                              Positioned(
                                left: w / 2 - _axisWidth / 2,
                                top: _y(year) - 8,
                                width: _axisWidth,
                                child: Center(
                                  child: Container(
                                    color: theme.scaffoldBackgroundColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('$year', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                  ),
                                ),
                              ),
                            // Israel no cativeiro (depois de 722).
                            Positioned(
                              left: 3,
                              top: _y(722) + 44,
                              width: c - 6,
                              height: math.max(40, _y(_last) - _y(722) - 44),
                              child: Container(
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Text('Israel no cativeiro assírio.\nO reino do norte não volta a ter rei.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35)),
                              ),
                            ),
                            for (final x in israel) b(x, 0, 'Israel (norte)'),
                            for (final x in judah) b(x, c + _axisWidth, 'Judá (sul)'),
                            // Marcos da história, no eixo.
                            for (final m in d.marks)
                              Positioned(
                                left: w / 2 - _axisWidth / 2 + 6,
                                top: _y(m.year) - (m.year == _first ? 0 : 16),
                                width: _axisWidth - 12,
                                child: Material(
                                  color: const Color(0xFF0E1626),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: m.ref.isEmpty ? null : () => openPanoramaRef(context, m.ref),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      child: Column(children: [
                                        Text('${m.year} a.C.',
                                            style: const TextStyle(color: Color(0xFFD4A017), fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(m.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2)),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ]);
                        }),
                      ),
                    ]),
                  ),
                ),
              ]);
            }),
    );
  }
}
