import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../services/ai_service.dart' show supabaseUrl;

/// Fundos em degradê do cartão de versículo.
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
  CardBackground('Amanhecer', [Color(0xFFF6D365), Color(0xFFFDA085)], Color(0xFF3B1F0E)),
  CardBackground('Céu', [Color(0xFF89F7FE), Color(0xFF66A6FF)], Colors.white),
  CardBackground('Lavanda', [Color(0xFFE0C3FC), Color(0xFF8EC5FC)], Color(0xFF2A2350)),
  CardBackground('Esmeralda', [Color(0xFF0BA360), Color(0xFF3CBA92)], Colors.white),
  CardBackground('Fogo', [Color(0xFFF83600), Color(0xFFF9D423)], Colors.white),
  CardBackground('Real', [Color(0xFF141E30), Color(0xFF243B55)], Color(0xFFE8C872)),
  CardBackground('Pêssego', [Color(0xFFFFECD2), Color(0xFFFCB69F)], Color(0xFF4A2A1A)),
  CardBackground('Meia-noite', [Color(0xFF232526), Color(0xFF414345)], Colors.white),
  CardBackground('Graça', [Color(0xFFA18CD1), Color(0xFFFBC2EB)], Colors.white),
  CardBackground('Deserto', [Color(0xFFC79081), Color(0xFFDFA579)], Colors.white),
  CardBackground('Galileia', [Color(0xFF1D976C), Color(0xFF93F9B9)], Color(0xFF0B2E1F)),
  CardBackground('Glória', [Color(0xFFFFD700), Color(0xFFB8860B)], Color(0xFF2B1B00)),
];

/// Paleta de cores (fundo liso, degradê próprio e cor do texto).
const palette = <Color>[
  Colors.white, Color(0xFFF4ECD8), Color(0xFFFFF3C4), Color(0xFFF3D58A), Color(0xFFC9A227),
  Color(0xFFFFB199), Color(0xFFFF7E5F), Color(0xFFE53935), Color(0xFF8E2236), Color(0xFF5A0F1E),
  Color(0xFFF8BBD0), Color(0xFFEC407A), Color(0xFFCE93D8), Color(0xFF7B1FA2), Color(0xFF41295A),
  Color(0xFF90CAF9), Color(0xFF2196F3), Color(0xFF1565C0), Color(0xFF0D2B52), Color(0xFF0F2027),
  Color(0xFF80CBC4), Color(0xFF00897B), Color(0xFFA5D6A7), Color(0xFF2E7D32), Color(0xFF134E5E),
  Color(0xFFD7CCC8), Color(0xFF8D6E63), Color(0xFF4E342E), Color(0xFF9E9E9E), Color(0xFF424242),
  Color(0xFF1C1C1C), Colors.black,
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

enum BgKind { photo, gradient, solid, gallery }

/// Direções do degradê próprio.
const _directions = <(String, IconData, Alignment, Alignment)>[
  ('Diagonal', Icons.south_east, Alignment.topLeft, Alignment.bottomRight),
  ('Vertical', Icons.south, Alignment.topCenter, Alignment.bottomCenter),
  ('Horizontal', Icons.east, Alignment.centerLeft, Alignment.centerRight),
  ('Diagonal inversa', Icons.south_west, Alignment.topRight, Alignment.bottomLeft),
];

/// Foto da biblioteca de fundos (bucket público "fundos", fotos CC0/domínio público).
class BgPhoto {
  final String theme;
  final String file;
  final String thumb;
  final String author;
  const BgPhoto(this.theme, this.file, this.thumb, this.author);

  static const _base = '$supabaseUrl/storage/v1/object/public/fundos';
  String get url => '$_base/$file';
  String get thumbUrl => '$_base/$thumb';

  static List<BgPhoto>? _cache;

  static Future<List<BgPhoto>> load() async {
    if (_cache != null) return _cache!;
    final res = await http.get(Uri.parse('$_base/fundos.json')).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw 'erro ${res.statusCode}';
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .map((e) => BgPhoto(e['tema'] as String, e['file'] as String,
            e['thumb'] as String, (e['autor'] as String?) ?? ''))
        .toList();
    return _cache = list;
  }
}

double _luminance(Color c) => c.computeLuminance();

/// Editor de imagem do versículo: fundo (foto, degradê, cor, galeria), fonte, tamanho etc.
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

  BgKind _kind = BgKind.photo;
  CardBackground _bg = cardBackgrounds.first;
  bool _customGradient = false;
  Color _g1 = const Color(0xFF0F2027);
  Color _g2 = const Color(0xFFC9A227);
  int _dir = 0;
  Color _solid = const Color(0xFF0D2B52);
  BgPhoto? _photo;
  Uint8List? _gallery;
  double _dim = 0.35;
  double _blur = 0;

  Color? _textColor; // null = automático
  bool _shadow = true;

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

  List<BgPhoto>? _photos;
  String? _photosError;
  String? _theme;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final list = await BgPhoto.load();
      if (!mounted) return;
      setState(() {
        _photos = list;
        _photosError = null;
        _theme ??= list.isEmpty ? null : list.first.theme;
        if (_photo == null && list.isNotEmpty && _kind == BgKind.photo) _photo = list.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photosError = 'Sem internet para carregar as fotos.';
        if (_photo == null && _kind == BgKind.photo) _kind = BgKind.gradient;
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _isPhoto =>
      (_kind == BgKind.photo && _photo != null) || (_kind == BgKind.gallery && _gallery != null);

  Color get _autoText {
    if (_isPhoto) return Colors.white;
    return switch (_kind) {
      BgKind.solid => _luminance(_solid) > 0.5 ? const Color(0xFF1A1A1A) : Colors.white,
      _ when _customGradient =>
        (_luminance(_g1) + _luminance(_g2)) / 2 > 0.5 ? const Color(0xFF1A1A1A) : Colors.white,
      _ => _bg.text,
    };
  }

  Color get _text => _textColor ?? _autoText;

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

  Future<void> _pickGallery() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    if (!mounted) return;
    setState(() {
      _gallery = bytes;
      _kind = BgKind.gallery;
    });
  }

  Widget _background() {
    Widget? photo;
    if (_kind == BgKind.photo && _photo != null) {
      photo = Image.network(_photo!.url, fit: BoxFit.cover, gaplessPlayback: true,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Stack(fit: StackFit.expand, children: [
                  Image.network(_photo!.thumbUrl, fit: BoxFit.cover),
                  const Center(child: CircularProgressIndicator()),
                ]),
          errorBuilder: (context, e, s) => const ColoredBox(color: Colors.black));
    } else if (_kind == BgKind.gallery && _gallery != null) {
      photo = Image.memory(_gallery!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    if (photo != null) {
      return Stack(fit: StackFit.expand, children: [
        if (_blur > 0)
          ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur), child: photo)
        else
          photo,
        if (_dim > 0) ColoredBox(color: Colors.black.withValues(alpha: _dim)),
      ]);
    }
    if (_kind == BgKind.solid) return ColoredBox(color: _solid);
    final d = _directions[_dir];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _customGradient ? [_g1, _g2] : _bg.colors,
          begin: _customGradient ? d.$3 : Alignment.topLeft,
          end: _customGradient ? d.$4 : Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _card() {
    final text = _quotes ? '“${_textCtrl.text.trim()}”' : _textCtrl.text.trim();
    final len = text.length;
    final base = len < 120 ? 30.0 : len < 250 ? 24.0 : len < 450 ? 19.0 : 15.0;
    final color = _text;
    return RepaintBoundary(
      key: _boundary,
      child: AspectRatio(
        aspectRatio: _ratio.value,
        child: ClipRect(
          child: Stack(fit: StackFit.expand, children: [
            _background(),
            LayoutBuilder(builder: (context, c) {
              final s = c.maxWidth / 360; // escala proporcional ao tamanho do cartão
              final shadows = _shadow
                  ? [
                      Shadow(
                        color: (_luminance(color) > 0.5 ? Colors.black : Colors.white)
                            .withValues(alpha: 0.55),
                        blurRadius: 6 * s,
                        offset: Offset(0, 1.5 * s),
                      ),
                    ]
                  : null;
              return Container(
                margin: EdgeInsets.all(_frame ? 14 * s : 0),
                decoration: _frame
                    ? BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5 * s))
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
                        color: color,
                        fontFamily: _fonts[_font],
                        fontSize: base * _fontScale * s,
                        height: 1.35,
                        fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
                        shadows: shadows,
                      ),
                    ),
                    if (_showRef) ...[
                      SizedBox(height: 16 * s),
                      Text(
                        widget.reference,
                        textAlign: _align,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.9),
                          fontFamily: _fonts[_font],
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          shadows: shadows,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_watermark)
                      Text('Bíblia JG',
                          style: TextStyle(
                              color: color.withValues(alpha: 0.6),
                              fontSize: 10 * s,
                              letterSpacing: 2,
                              shadows: shadows)),
                  ],
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }

  Widget _swatch({
    required Widget child,
    required bool selected,
    required VoidCallback onTap,
    String? tooltip,
    double size = 42,
  }) {
    final cs = Theme.of(context).colorScheme;
    final box = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(width: selected ? 3 : 1, color: selected ? cs.primary : Colors.grey),
        ),
        child: child,
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip, child: box);
  }

  Widget _colorRow(Color? selected, ValueChanged<Color> onPick, {bool withAuto = false}) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (withAuto)
        _swatch(
          size: 34,
          tooltip: 'Automática',
          selected: selected == null,
          onTap: () => setState(() => _textColor = null),
          child: const Center(child: Text('A', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
      for (final c in palette)
        _swatch(
          size: 34,
          selected: selected == c,
          onTap: () => onPick(c),
          child: ColoredBox(color: c),
        ),
    ]);
  }

  Widget _photoPicker() {
    final photos = _photos;
    if (photos == null) {
      return _photosError == null
          ? const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
          : Row(children: [
              Expanded(child: Text(_photosError!)),
              TextButton(onPressed: _loadPhotos, child: const Text('Tentar de novo')),
            ]);
    }
    final themes = <String>{for (final p in photos) p.theme}.toList();
    final shown = photos.where((p) => p.theme == _theme).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final t in themes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(t),
                selected: _theme == t,
                onSelected: (_) => setState(() => _theme = t),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in shown)
          _swatch(
            size: 64,
            tooltip: p.author.isEmpty ? null : 'Foto: ${p.author}',
            selected: _kind == BgKind.photo && _photo == p,
            onTap: () => setState(() {
              _photo = p;
              _kind = BgKind.photo;
            }),
            child: Image.network(p.thumbUrl, fit: BoxFit.cover,
                errorBuilder: (context, e, s) => const Icon(Icons.image_not_supported_outlined)),
          ),
      ]),
    ]);
  }

  Widget _gradientPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final b in cardBackgrounds)
          _swatch(
            tooltip: b.name,
            selected: !_customGradient && _bg == b,
            onTap: () => setState(() {
              _bg = b;
              _customGradient = false;
            }),
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: b.colors))),
          ),
      ]),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Criar meu degradê'),
        value: _customGradient,
        onChanged: (v) => setState(() => _customGradient = v),
      ),
      if (_customGradient) ...[
        const Text('Cor 1'),
        const SizedBox(height: 4),
        _colorRow(_g1, (c) => setState(() => _g1 = c)),
        const SizedBox(height: 8),
        const Text('Cor 2'),
        const SizedBox(height: 4),
        _colorRow(_g2, (c) => setState(() => _g2 = c)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (var i = 0; i < _directions.length; i++)
            ChoiceChip(
              avatar: Icon(_directions[i].$2, size: 18),
              label: Text(_directions[i].$1),
              selected: _dir == i,
              onSelected: (_) => setState(() => _dir = i),
            ),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      Text('Fundo', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<BgKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: BgKind.photo, icon: Icon(Icons.landscape), label: Text('Fotos')),
          ButtonSegment(value: BgKind.gradient, icon: Icon(Icons.gradient), label: Text('Degradê')),
          ButtonSegment(value: BgKind.solid, icon: Icon(Icons.palette), label: Text('Cores')),
          ButtonSegment(value: BgKind.gallery, icon: Icon(Icons.photo_library), label: Text('Galeria')),
        ],
        selected: {_kind},
        onSelectionChanged: (v) {
          final k = v.first;
          if (k == BgKind.gallery && _gallery == null) {
            _pickGallery();
            return;
          }
          setState(() {
            _kind = k;
            if (k == BgKind.photo && _photo == null && (_photos?.isNotEmpty ?? false)) {
              _photo = _photos!.first;
            }
          });
        },
      ),
      const SizedBox(height: 12),
      switch (_kind) {
        BgKind.photo => _photoPicker(),
        BgKind.gradient => _gradientPicker(),
        BgKind.solid => _colorRow(_solid, (c) => setState(() => _solid = c)),
        BgKind.gallery => Row(children: [
            const Expanded(child: Text('Foto escolhida da galeria do tablet.')),
            TextButton.icon(
              onPressed: _pickGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Trocar foto'),
            ),
          ]),
      },
      if (_isPhoto) ...[
        const SizedBox(height: 8),
        Text('Escurecer foto', style: theme.textTheme.titleSmall),
        Slider(min: 0, max: 0.8, value: _dim, onChanged: (v) => setState(() => _dim = v)),
        Text('Desfocar foto', style: theme.textTheme.titleSmall),
        Slider(min: 0, max: 12, value: _blur, onChanged: (v) => setState(() => _blur = v)),
      ],
      const SizedBox(height: 12),
      Text('Cor do texto', style: theme.textTheme.titleSmall),
      const SizedBox(height: 4),
      _colorRow(_textColor, (c) => setState(() => _textColor = c), withAuto: true),
      const SizedBox(height: 16),
      Text('Formato', style: theme.textTheme.titleSmall),
      Wrap(spacing: 8, children: [
        for (final r in _ratios)
          ChoiceChip(label: Text(r.name), selected: _ratio == r, onSelected: (_) => setState(() => _ratio = r)),
      ]),
      const SizedBox(height: 12),
      Text('Fonte', style: theme.textTheme.titleSmall),
      Wrap(spacing: 8, children: [
        for (final f in _fonts.keys)
          ChoiceChip(label: Text(f), selected: _font == f, onSelected: (_) => setState(() => _font = f)),
      ]),
      const SizedBox(height: 12),
      Text('Tamanho do texto', style: theme.textTheme.titleSmall),
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
        FilterChip(label: const Text('Sombra no texto'), selected: _shadow, onSelected: (v) => setState(() => _shadow = v)),
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
      if (_kind == BgKind.photo && _photo != null && _photo!.author.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Foto: ${_photo!.author} (licença livre)', style: theme.textTheme.bodySmall),
        ),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Imagem do versículo')),
      body: wide
          ? Row(children: [Expanded(flex: 3, child: preview), SizedBox(width: 400, child: controls)])
          : Column(children: [SizedBox(height: 360, child: preview), Expanded(child: controls)]),
    );
  }
}
