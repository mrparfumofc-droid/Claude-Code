import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bible.dart';
import '../models/reader_settings.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/note_editor.dart';
import '../widgets/xrefs_sheet.dart';
import 'ai_chat_screen.dart';
import 'maps_screen.dart';
import 'verse_image_screen.dart';
import 'voice_screen.dart';

/// Texto do capítulo atual com seleção de versículos e ações.
class ReaderView extends StatefulWidget {
  /// Chamado com `true` quando o usuário rola para baixo (para esconder menus).
  final ValueChanged<bool>? onScrollDirection;
  const ReaderView({super.key, this.onScrollDirection});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final _scroll = ScrollController();
  final Set<int> _selected = {};
  final Map<int, GlobalKey> _keys = {};
  final List<TapGestureRecognizer> _recognizers = [];
  String _lastChapterKey = '';
  int? _flashVerse;
  int? _ttsVerse;

  @override
  void dispose() {
    _scroll.dispose();
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  GlobalKey _keyFor(int verse) => _keys.putIfAbsent(verse, GlobalKey.new);

  void _toggle(int verse) => setState(() {
        if (!_selected.remove(verse)) _selected.add(verse);
      });

  void _handleChapterChange(AppState app) {
    final key = '${app.bible?.id}:${app.book}:${app.chapter}';
    if (key != _lastChapterKey) {
      if (_lastChapterKey.isNotEmpty) {
        final tts = context.read<ReadAloud>();
        if (tts.speaking) tts.stop();
      }
      _lastChapterKey = key;
      _selected.clear();
      _keys.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    final target = app.scrollToVerse;
    if (target != null) {
      app.consumeScrollTarget();
      _flashVerse = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[target]?.currentContext ?? _blockContextFor(target);
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350), alignment: 0.15);
        }
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _flashVerse = null);
        });
      });
    }
  }

  // No layout clássico as chaves são por bloco; procura o bloco que contém o versículo.
  BuildContext? _blockContextFor(int verse) {
    final starts = _keys.keys.where((k) => k <= verse).toList()..sort();
    return starts.isEmpty ? null : _keys[starts.last]?.currentContext;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final book = app.currentBook;
    if (book == null) return const SizedBox();
    _handleChapterChange(app);
    _disposeRecognizers();

    // Leitura em voz alta: destaca e acompanha o versículo lido.
    final tts = context.watch<ReadAloud>();
    if (tts.currentVerse != _ttsVerse) {
      _ttsVerse = tts.currentVerse;
      final v = _ttsVerse;
      if (v != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _keys[v]?.currentContext ?? _blockContextFor(v);
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3);
          }
        });
      }
    }

    final verses = app.currentVerses;
    final textStyle = TextStyle(
      fontSize: s.fontSize,
      height: s.lineHeight,
      fontFamily: s.fontFamily,
      color: s.foreground,
    );

    final content = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 16),
        child: Column(children: [
          Text(book.name,
              style: textStyle.copyWith(
                  fontSize: s.fontSize * 0.9, height: 1.2, letterSpacing: 1)),
          Text('${app.chapter}',
              style: textStyle.copyWith(
                  fontSize: s.fontSize * 2.4, height: 1.1, fontWeight: FontWeight.w300)),
        ]),
      ),
      if (s.verseByVerse)
        ..._verseByVerse(app, book, verses, textStyle)
      else
        ..._classic(app, book, verses, textStyle),
      const SizedBox(height: 24),
      _ChapterFooter(app: app, textStyle: textStyle),
    ];

    return Container(
      color: s.background,
      child: Stack(children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.direction == ScrollDirection.reverse) {
              widget.onScrollDirection?.call(true);
            } else if (n.direction == ScrollDirection.forward) {
              widget.onScrollDirection?.call(false);
            }
            return false;
          },
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -500) app.nextChapter();
              if (v > 500) app.previousChapter();
            },
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(24, 0, 24, _selected.isEmpty ? 48 : 160),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (tts.speaking)
          Positioned(
            top: 8,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.volume_up, size: 18),
                  const SizedBox(width: 4),
                  Text('Lendo v. ${tts.currentVerse ?? ''}'),
                  PopupMenuButton<double>(
                    tooltip: 'Velocidade',
                    icon: const Icon(Icons.speed, size: 20),
                    onSelected: tts.setRate,
                    itemBuilder: (_) => [
                      for (final (r, l) in const [(0.3, '0,6x'), (0.4, '0,8x'), (0.5, '1x'), (0.6, '1,25x'), (0.75, '1,5x'), (0.9, '2x')])
                        CheckedPopupMenuItem(value: r, checked: tts.rate == r, child: Text(l)),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Escolher voz',
                    icon: const Icon(Icons.record_voice_over, size: 20),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const VoiceScreen())),
                  ),
                  IconButton(
                    tooltip: 'Parar leitura',
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: tts.stop,
                  ),
                ]),
              ),
            ),
          ),
        if (_selected.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VerseActionBar(
              app: app,
              selected: (_selected.toList()..sort()),
              onClear: () => setState(_selected.clear),
            ),
          ),
      ]),
    );
  }

  /// Fundo opaco do versículo selecionado.
  Color _selectionBg(ReaderSettings s) =>
      (s.isDarkPage ? jgGold : s.themeColor).withValues(alpha: s.isDarkPage ? 0.22 : 0.12);

  Color? _highlightBg(AppState app, int verse) {
    final c = app.highlights[verse];
    if (c == null) return null;
    final color = Color(c);
    return app.settings.isDarkPage ? color.withValues(alpha: 0.35) : color;
  }

  Widget? _title(Book book, int chapter, int verse, ReaderSettings s, TextStyle base) {
    if (s.hideTitles) return null;
    final t = book.titleBefore(chapter, verse);
    if (t == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(t,
          textAlign: TextAlign.center,
          style: base.copyWith(
              fontWeight: FontWeight.bold, fontSize: s.fontSize * 0.95, height: 1.3)),
    );
  }

  InlineSpan _number(int n, ReaderSettings s, TextStyle base) {
    final color = s.themeColor.computeLuminance() < 0.2 && s.isDarkPage
        ? jgGold
        : (s.isDarkPage ? jgGold : s.themeColor);
    if (s.verseNumberStyle == VerseNumberStyle.inline) {
      return TextSpan(
          text: '$n ',
          style: base.copyWith(color: color, fontWeight: FontWeight.bold));
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Text('$n',
            style: TextStyle(
                fontSize: s.fontSize * 0.6,
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: s.fontFamily)),
      ),
    );
  }

  List<InlineSpan> _verseSpans(AppState app, int verse, String raw, TextStyle base,
      {TapGestureRecognizer? recognizer, Color? background}) {
    final s = app.settings;
    final text = s.trimLeadingSpace ? raw.trimLeft() : raw;
    final selected = _selected.contains(verse);
    final flash = _flashVerse == verse || _ttsVerse == verse;
    final style = base.copyWith(
      backgroundColor: selected
          ? _selectionBg(s)
          : background ?? (flash ? s.themeColor.withValues(alpha: 0.18) : null),
      decoration: selected ? TextDecoration.underline : null,
      decorationThickness: 1.6,
      decorationColor: s.isDarkPage ? jgGold : s.themeColor,
    );
    final spans = <InlineSpan>[];
    for (final seg in splitJesusWords(text)) {
      spans.add(TextSpan(
        text: seg.text,
        recognizer: recognizer,
        style: seg.jesus && s.jesusWordsInColor ? style.copyWith(color: s.jesusColor) : style,
      ));
    }
    if (app.favorites.contains(verse)) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.bookmark, size: s.fontSize * 0.8, color: jgGold),
      ));
    }
    if (app.notes.containsKey(verse)) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InkWell(
          onTap: () => showVerseNotes(
              context, app, VerseRef(app.book, app.chapter, verse)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.sticky_note_2, size: s.fontSize * 0.85, color: s.themeColor),
          ),
        ),
      ));
    }
    return spans;
  }

  List<Widget> _verseByVerse(
      AppState app, Book book, List<String> verses, TextStyle base) {
    final s = app.settings;
    final out = <Widget>[];
    for (var i = 0; i < verses.length; i++) {
      final v = i + 1;
      final title = _title(book, app.chapter, v, s, base);
      if (title != null) out.add(title);
      final bg = _highlightBg(app, v);
      out.add(GestureDetector(
        key: _keyFor(v),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(v),
        child: Container(
          margin: EdgeInsets.only(bottom: 2 + s.verseSpacing),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _selected.contains(v)
                ? _selectionBg(s)
                : _ttsVerse == v
                    ? const Color(0xFFFFC107).withValues(alpha: 0.30)
                    : bg ?? (_flashVerse == v ? s.themeColor.withValues(alpha: 0.15) : null),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text.rich(
            TextSpan(children: [
              _number(v, s, base),
              ..._verseSpans(app, v, verses[i], base, background: Colors.transparent),
            ]),
            textAlign: s.align,
          ),
        ),
      ));
    }
    return out;
  }

  List<Widget> _classic(AppState app, Book book, List<String> verses, TextStyle base) {
    final s = app.settings;
    final out = <Widget>[];
    var spans = <InlineSpan>[];
    var blockStart = 1;

    void flush() {
      if (spans.isEmpty) return;
      out.add(Padding(
        key: _keyFor(blockStart),
        padding: EdgeInsets.only(bottom: 8 + s.verseSpacing),
        child: Text.rich(TextSpan(children: spans), textAlign: s.align),
      ));
      spans = <InlineSpan>[];
    }

    for (var i = 0; i < verses.length; i++) {
      final v = i + 1;
      final title = _title(book, app.chapter, v, s, base);
      if (title != null) {
        flush();
        out.add(title);
        blockStart = v;
      }
      final r = TapGestureRecognizer()..onTap = () => _toggle(v);
      _recognizers.add(r);
      spans.add(_number(v, s, base));
      spans.addAll(_verseSpans(app, v, verses[i], base,
          recognizer: r, background: _highlightBg(app, v)));
      spans.add(TextSpan(text: ' ', style: base));
    }
    flush();
    return out;
  }
}

class _ChapterFooter extends StatelessWidget {
  final AppState app;
  final TextStyle textStyle;
  const _ChapterFooter({required this.app, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final read = app.chapterRead;
    return Column(children: [
      Center(
        child: FilledButton.tonalIcon(
          onPressed: app.toggleChapterRead,
          icon: Icon(read ? Icons.check_circle : Icons.radio_button_unchecked),
          label: Text(read ? 'CAPÍTULO LIDO' : 'MARCAR CAPÍTULO COMO LIDO'),
        ),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        OutlinedButton.icon(
          onPressed: app.previousChapter,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Anterior'),
        ),
        OutlinedButton.icon(
          onPressed: app.nextChapter,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Próximo'),
          iconAlignment: IconAlignment.end,
        ),
      ]),
      if ((app.bible?.copyright ?? '').isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(app.bible!.copyright,
            textAlign: TextAlign.center,
            style: textStyle.copyWith(
                fontSize: 12, height: 1.3, color: s.foreground.withValues(alpha: 0.6))),
      ],
    ]);
  }
}

/// Junta versículos em intervalos: [1,2,3,5] -> "1-3, 5".
String verseRanges(List<int> verses) {
  final parts = <String>[];
  var i = 0;
  while (i < verses.length) {
    var j = i;
    while (j + 1 < verses.length && verses[j + 1] == verses[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${verses[i]}' : '${verses[i]}-${verses[j]}');
    i = j + 1;
  }
  return parts.join(', ');
}

class _VerseActionBar extends StatelessWidget {
  final AppState app;
  final List<int> selected;
  final VoidCallback onClear;
  const _VerseActionBar(
      {required this.app, required this.selected, required this.onClear});

  String _shareText() {
    final verses = app.currentVerses;
    final text = selected
        .map((v) => '$v ${plainVerse(verses[v - 1]).trim()}')
        .join(' ');
    final ref = '${app.currentBook!.name} ${app.chapter}:${verseRanges(selected)}';
    return '$text\n— $ref (${app.bible!.abbrev})';
  }

  String get _reference => '${app.currentBook!.name} ${app.chapter}:${verseRanges(selected)}';

  String get _plainText {
    final verses = app.currentVerses;
    return selected.map((v) => plainVerse(verses[v - 1]).trim()).join(' ');
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final allFav = selected.every(app.favorites.contains);
    final tts = context.read<ReadAloud>();
    Widget action(IconData icon, String label, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        );
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text(
                  _reference,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(onPressed: onClear, icon: const Icon(Icons.close), tooltip: 'Fechar'),
            ]),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                action(Icons.auto_awesome, 'Estudo bíblico', () {
                  final ref = _reference, text = _plainText;
                  onClear();
                  _push(
                    context,
                    AiChatScreen(
                      title: 'Estudo bíblico',
                      task: 'explain',
                      reference: ref,
                      version: app.bible!.abbrev,
                      verseText: text,
                      initialPrompt: 'Explique este trecho em detalhes.',
                      quickActions: const [
                        ('Comentário', 'commentary', 'Faça um comentário versículo a versículo deste trecho.'),
                        ('Esboço de pregação', 'sermon', 'Prepare um esboço de pregação sobre este trecho.'),
                        ('Palavras no original', 'explain', 'Explique as principais palavras deste trecho no original hebraico ou grego.'),
                        ('Aplicação para hoje', 'explain', 'Como aplicar este trecho na minha vida hoje?'),
                      ],
                    ),
                  );
                }),
                action(Icons.image_outlined, 'Imagem', () {
                  final ref = '$_reference (${app.bible!.abbrev})', text = _plainText;
                  onClear();
                  _push(context, VerseImageScreen(text: text, reference: ref));
                }),
                action(Icons.volume_up_outlined, 'Ouvir', () {
                  final verses = app.currentVerses;
                  final start = selected.first;
                  onClear();
                  tts.speak([
                    for (var v = start; v <= verses.length; v++) (v, plainVerse(verses[v - 1]).trim()),
                  ], lang: app.bible!.id == 'kjv' || app.bible!.id == 'niv'
                      ? 'en-US'
                      : app.bible!.id == 'rvr1960'
                          ? 'es-ES'
                          : 'pt-BR');
                }),
                action(Icons.link, 'Referências', () {
                  final ref = VerseRef(app.book, app.chapter, selected.first);
                  onClear();
                  showCrossReferences(context, app, ref);
                }),
                action(Icons.map_outlined, 'Mapa', () {
                  final ref = _reference, book = app.book, chapter = app.chapter, verse = selected.first;
                  onClear();
                  openVersePlaces(context, book, chapter, verse, ref);
                }),
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in highlightColors)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        app.setHighlight(selected, c.toARGB32());
                        onClear();
                      },
                      child: CircleAvatar(radius: 16, backgroundColor: c),
                    ),
                  ),
                IconButton(
                  tooltip: 'Remover marcação',
                  icon: const Icon(Icons.format_color_reset),
                  onPressed: () {
                    app.setHighlight(selected, null);
                    onClear();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: allFav ? 'Remover dos favoritos' : 'Favoritar',
                  icon: Icon(allFav ? Icons.bookmark_remove : Icons.bookmark_add),
                  onPressed: () {
                    app.setFavorite(selected, !allFav);
                    onClear();
                  },
                ),
                IconButton(
                  tooltip: 'Anotação',
                  icon: const Icon(Icons.edit_note),
                  onPressed: () async {
                    final ref = VerseRef(app.book, app.chapter, selected.first);
                    onClear();
                    await showNoteEditor(context, app, ref);
                  },
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _shareText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Versículos copiados')));
                    }
                    onClear();
                  },
                ),
                IconButton(
                  tooltip: 'Compartilhar',
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: _shareText()));
                    onClear();
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
