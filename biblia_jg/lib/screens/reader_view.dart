import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bible.dart';
import '../models/reader_settings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/note_editor.dart';

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
    final flash = _flashVerse == verse;
    final style = base.copyWith(
      backgroundColor: background ??
          (flash ? s.themeColor.withValues(alpha: 0.18) : null),
      decoration: selected ? TextDecoration.underline : null,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: s.foreground,
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
            color: bg ?? (_flashVerse == v ? s.themeColor.withValues(alpha: 0.15) : null),
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

  @override
  Widget build(BuildContext context) {
    final allFav = selected.every(app.favorites.contains);
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
                  '${app.currentBook!.name} ${app.chapter}:${verseRanges(selected)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(onPressed: onClear, icon: const Icon(Icons.close), tooltip: 'Fechar'),
            ]),
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
