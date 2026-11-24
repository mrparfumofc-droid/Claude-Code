import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Fundos do cartão de versículo.
class CardBackground {
  final String name;
  final List<Color> colors;
  final Color text;
  const CardBackground(this.name, this.colors, this.text);
}

const cardBackgrounds = <CardBackground>[
  CardBackground('JG Dourado', [Color(0xFF110605), Color(0xFF3A2410)], Color(0xFFF3D58A)),
  CardBackground('Pôr do sol', [Color(0xFFFF7E5F), Color(0xFFFEB47B)], Colors.white),
  CardBackground('Oceano', [Color(0xFF2193B0), Color(0xFF6DD5ED)], Colors.white),
  CardBackground('Noite', [Color(0xFF0F2027), Color(0xFF2C5364)], Colors.white),
  CardBackground('Roxo', [Color(0xFF41295A), Color(0xFF2F0743)], Colors.white),
  CardBackground('Floresta', [Color(0xFF134E5E), Color(0xFF71B280)], Colors.white),
  CardBackground('Rosa', [Color(0xFFEE9CA7), Color(0xFFFFDDE1)], Color(0xFF4A1C24)),
  CardBackground('Aurora', [Color(0xFF00C9FF), Color(0xFF92FE9D)], Color(0xFF0B2E2A)),
  CardBackground('Papiro', [Color(0xFFF4ECD8), Color(0xFFE3D3B0)], Color(0xFF3E2F1C)),
  CardBackground('Branco', [Colors.white, Color(0xFFF2F2F2)], Color(0xFF1A1A1A)),
  CardBackground('Preto', [Colors.black, Color(0xFF1C1C1C)], Colors.white),
  CardBackground('Vinho', [Color(0xFF5A0F1E), Color(0xFF8E2236)], Color(0xFFFFE9C7)),
];

class _Ratio {
  final String name;
  final double value; // largura / altura
  const _Ratio(this.name, this.value);
}

const _ratios = [
  _Ratio('Story 9:16', 9 / 16),
  _Ratio('Post 1:1', 1),
  _Ratio('Retrato 4:5', 4 / 5),
  _Ratio('Paisagem 16:9', 16 / 9),
];

const _fonts = <String, String?>{
  'Serifada': 'serif',
  'Moderna': 'sans-serif',
  'Condensada': 'sans-serif-condensed',
  'Máquina': 'monospace',
  'Cursiva': 'cursive',
};

/// Editor de imagem do versículo: fundo, fonte, tamanho, alinhamento, formato etc.
class VerseImageScreen extends StatefulWidget {
  final String text;
  final String reference;
  const VerseImageScreen({super.key, required this.text, required this.reference});

  @override
  State<VerseImageScreen> createState() => _VerseImageScreenState();
}

class _VerseImageScreenState extends State<VerseImageScreen> {
  final _boundary = GlobalKey();
  late final TextEditingController _textCtrl = TextEditingController(text: widget.text);
  CardBackground _bg = cardBackgrounds.first;
  _Ratio _ratio = _ratios.first;
  String _font = 'Serifada';
  double _fontScale = 1.0;
  TextAlign _align = TextAlign.center;
  bool _bold = false;
  bool _italic = false;
  bool _quotes = true;
  bool _showRef = true;
  bool _watermark = true;
  bool _frame = false;
  bool _busy = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List> _render() async {
    final obj = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await obj.toImage(pixelRatio: 1080 / obj.size.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  String get _fileName =>
      'versiculo-${widget.reference.replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ]+'), '-')}.png';

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _render();
      final uri = await FilePicker.saveFile(fileName: _fileName, bytes: bytes, mimeType: 'image/png');
      if (uri != null) messenger.showSnackBar(const SnackBar(content: Text('Imagem salva')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: _fileName, mimeType: 'image/png')],
        fileNameOverrides: [_fileName],
        text: widget.reference,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card() {
    final text = _quotes ? '“${_textCtrl.text.trim()}”' : _textCtrl.text.trim();
    final len = text.length;
    final base = len < 120 ? 30.0 : len < 250 ? 24.0 : len < 450 ? 19.0 : 15.0;
    return RepaintBoundary(
      key: _boundary,
      child: AspectRatio(
        aspectRatio: _ratio.value,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _bg.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: LayoutBuilder(builder: (context, c) {
            final s = c.maxWidth / 360; // escala proporcional ao tamanho do cartão
            return Container(
              margin: EdgeInsets.all(_frame ? 14 * s : 0),
              decoration: _frame
                  ? BoxDecoration(border: Border.all(color: _bg.text.withValues(alpha: 0.6), width: 1.5 * s))
                  : null,
              padding: EdgeInsets.all(28 * s),
              child: Column(
                crossAxisAlignment: switch (_align) {
                  TextAlign.left => CrossAxisAlignment.start,
                  TextAlign.right => CrossAxisAlignment.end,
                  _ => CrossAxisAlignment.center,
                },
                children: [
                  const Spacer(),
                  Text(
                    text,
                    textAlign: _align,
                    style: TextStyle(
                      color: _bg.text,
                      fontFamily: _fonts[_font],
                      fontSize: base * _fontScale * s,
                      height: 1.35,
                      fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  if (_showRef) ...[
                    SizedBox(height: 16 * s),
                    Text(
                      widget.reference,
                      textAlign: _align,
                      style: TextStyle(
                        color: _bg.text.withValues(alpha: 0.85),
                        fontFamily: _fonts[_font],
                        fontSize: 14 * s,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_watermark)
                    Text('Bíblia JG',
                        style: TextStyle(
                            color: _bg.text.withValues(alpha: 0.55),
                            fontSize: 10 * s,
                            letterSpacing: 2)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final preview = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _ratio.value >= 1 ? 560 : 360),
          child: Material(elevation: 6, child: _card()),
        ),
      ),
    );
    final controls = ListView(padding: const EdgeInsets.all(16), children: [
      Text('Fundo', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final b in cardBackgrounds)
          Tooltip(
            message: b.name,
            child: InkWell(
              onTap: () => setState(() => _bg = b),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: b.colors),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      width: _bg == b ? 3 : 1,
                      color: _bg == b ? Theme.of(context).colorScheme.primary : Colors.grey),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Formato', style: Theme.of(context).textTheme.titleSmall),
      Wrap(spacing: 8, children: [
        for (final r in _ratios)
          ChoiceChip(label: Text(r.name), selected: _ratio == r, onSelected: (_) => setState(() => _ratio = r)),
      ]),
      const SizedBox(height: 12),
      Text('Fonte', style: Theme.of(context).textTheme.titleSmall),
      Wrap(spacing: 8, children: [
        for (final f in _fonts.keys)
          ChoiceChip(label: Text(f), selected: _font == f, onSelected: (_) => setState(() => _font = f)),
      ]),
      const SizedBox(height: 12),
      Text('Tamanho do texto', style: Theme.of(context).textTheme.titleSmall),
      Slider(min: 0.6, max: 1.6, value: _fontScale, onChanged: (v) => setState(() => _fontScale = v)),
      SegmentedButton<TextAlign>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left)),
          ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center)),
          ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right)),
        ],
        selected: {_align},
        onSelectionChanged: (v) => setState(() => _align = v.first),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        FilterChip(label: const Text('Negrito'), selected: _bold, onSelected: (v) => setState(() => _bold = v)),
        FilterChip(label: const Text('Itálico'), selected: _italic, onSelected: (v) => setState(() => _italic = v)),
        FilterChip(label: const Text('Aspas'), selected: _quotes, onSelected: (v) => setState(() => _quotes = v)),
        FilterChip(label: const Text('Referência'), selected: _showRef, onSelected: (v) => setState(() => _showRef = v)),
        FilterChip(label: const Text('Moldura'), selected: _frame, onSelected: (v) => setState(() => _frame = v)),
        FilterChip(label: const Text('Marca Bíblia JG'), selected: _watermark, onSelected: (v) => setState(() => _watermark = v)),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _textCtrl,
        minLines: 2,
        maxLines: 8,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Texto (pode editar)', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.download),
            label: const Text('Salvar imagem'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share),
            label: const Text('Postar / enviar'),
          ),
        ),
      ]),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Imagem do versículo')),
      body: wide
          ? Row(children: [Expanded(flex: 3, child: preview), SizedBox(width: 380, child: controls)])
          : Column(children: [SizedBox(height: 360, child: preview), Expanded(child: controls)]),
    );
  }
}
