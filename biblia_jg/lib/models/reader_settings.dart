import 'package:flutter/material.dart';

enum FontKind { normal, monospace, sansSerif, serif }

enum PageColor { white, sepia, green, dark, black }

enum VerseNumberStyle { superscript, inline }

class ReaderSettings {
  final double fontSize;
  final TextAlign align;
  final FontKind font;
  final double verseSpacing; // espaço extra entre versículos (px)
  final double lineHeight; // 0.7 .. 3.0
  final PageColor pageColor;
  final bool nightMode;
  final Color themeColor;
  final bool verseByVerse; // false = layout clássico (parágrafo corrido)
  final bool trimLeadingSpace;
  final VerseNumberStyle verseNumberStyle;
  final bool hideTitles;
  final bool jesusWordsInColor;
  final Color jesusColor;
  final bool hideMenusOnScroll;
  final bool keepScreenOn;
  final bool fullScreen;
  final bool verseOfDayEnabled;
  final TimeOfDay verseOfDayTime;
  final bool sundayPassage;
  final bool planReminders;

  const ReaderSettings({
    this.fontSize = 21,
    this.align = TextAlign.left,
    this.font = FontKind.serif,
    this.verseSpacing = 0,
    this.lineHeight = 1.5,
    this.pageColor = PageColor.white,
    this.nightMode = false,
    this.themeColor = const Color(0xFF1B2A49),
    this.verseByVerse = true,
    this.trimLeadingSpace = true,
    this.verseNumberStyle = VerseNumberStyle.superscript,
    this.hideTitles = false,
    this.jesusWordsInColor = true,
    this.jesusColor = const Color(0xFFC62828),
    this.hideMenusOnScroll = false,
    this.keepScreenOn = true,
    this.fullScreen = false,
    this.verseOfDayEnabled = true,
    this.verseOfDayTime = const TimeOfDay(hour: 8, minute: 0),
    this.sundayPassage = false,
    this.planReminders = false,
  });

  static const jesusColorOptions = <String, Color>{
    'Vermelho clássico': Color(0xFFC62828),
    'Vinho': Color(0xFF7B1F3A),
    'Azul': Color(0xFF1565C0),
    'Verde-azulado': Color(0xFF00897B),
    'Roxo': Color(0xFF6A1B9A),
    'Âmbar': Color(0xFFFF8F00),
    'Grafite': Color(0xFF455A64),
  };

  static const themeColorOptions = <String, Color>{
    'JG Azul-marinho': Color(0xFF1B2A49),
    'Dourado': Color(0xFFB8860B),
    'Verde': Color(0xFF2E7D32),
    'Vinho': Color(0xFF7B1F3A),
    'Roxo': Color(0xFF5E35B1),
    'Preto': Color(0xFF212121),
  };

  String? get fontFamily => switch (font) {
        FontKind.normal => null,
        FontKind.monospace => 'monospace',
        FontKind.sansSerif => 'sans-serif',
        FontKind.serif => 'serif',
      };

  Color get background => nightMode
      ? const Color(0xFF121212)
      : switch (pageColor) {
          PageColor.white => Colors.white,
          PageColor.sepia => const Color(0xFFF4ECD8),
          PageColor.green => const Color(0xFFE3F0E0),
          PageColor.dark => const Color(0xFF2B2B2B),
          PageColor.black => Colors.black,
        };

  Color get foreground {
    if (nightMode) return const Color(0xFFE0E0E0);
    return switch (pageColor) {
      PageColor.dark || PageColor.black => const Color(0xFFE6E6E6),
      PageColor.sepia => const Color(0xFF3E2F1C),
      _ => const Color(0xFF1A1A1A),
    };
  }

  bool get isDarkPage =>
      nightMode || pageColor == PageColor.dark || pageColor == PageColor.black;

  ReaderSettings copyWith({
    double? fontSize,
    TextAlign? align,
    FontKind? font,
    double? verseSpacing,
    double? lineHeight,
    PageColor? pageColor,
    bool? nightMode,
    Color? themeColor,
    bool? verseByVerse,
    bool? trimLeadingSpace,
    VerseNumberStyle? verseNumberStyle,
    bool? hideTitles,
    bool? jesusWordsInColor,
    Color? jesusColor,
    bool? hideMenusOnScroll,
    bool? keepScreenOn,
    bool? fullScreen,
    bool? verseOfDayEnabled,
    TimeOfDay? verseOfDayTime,
    bool? sundayPassage,
    bool? planReminders,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        align: align ?? this.align,
        font: font ?? this.font,
        verseSpacing: verseSpacing ?? this.verseSpacing,
        lineHeight: lineHeight ?? this.lineHeight,
        pageColor: pageColor ?? this.pageColor,
        nightMode: nightMode ?? this.nightMode,
        themeColor: themeColor ?? this.themeColor,
        verseByVerse: verseByVerse ?? this.verseByVerse,
        trimLeadingSpace: trimLeadingSpace ?? this.trimLeadingSpace,
        verseNumberStyle: verseNumberStyle ?? this.verseNumberStyle,
        hideTitles: hideTitles ?? this.hideTitles,
        jesusWordsInColor: jesusWordsInColor ?? this.jesusWordsInColor,
        jesusColor: jesusColor ?? this.jesusColor,
        hideMenusOnScroll: hideMenusOnScroll ?? this.hideMenusOnScroll,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        fullScreen: fullScreen ?? this.fullScreen,
        verseOfDayEnabled: verseOfDayEnabled ?? this.verseOfDayEnabled,
        verseOfDayTime: verseOfDayTime ?? this.verseOfDayTime,
        sundayPassage: sundayPassage ?? this.sundayPassage,
        planReminders: planReminders ?? this.planReminders,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'align': align.index,
        'font': font.index,
        'verseSpacing': verseSpacing,
        'lineHeight': lineHeight,
        'pageColor': pageColor.index,
        'nightMode': nightMode,
        'themeColor': themeColor.toARGB32(),
        'verseByVerse': verseByVerse,
        'trimLeadingSpace': trimLeadingSpace,
        'verseNumberStyle': verseNumberStyle.index,
        'hideTitles': hideTitles,
        'jesusWordsInColor': jesusWordsInColor,
        'jesusColor': jesusColor.toARGB32(),
        'hideMenusOnScroll': hideMenusOnScroll,
        'keepScreenOn': keepScreenOn,
        'fullScreen': fullScreen,
        'verseOfDayEnabled': verseOfDayEnabled,
        'verseOfDayTime': verseOfDayTime.hour * 60 + verseOfDayTime.minute,
        'sundayPassage': sundayPassage,
        'planReminders': planReminders,
      };

  static ReaderSettings fromJson(Map<String, dynamic> j) {
    const d = ReaderSettings();
    T pick<T>(String k, T def) => j[k] is T ? j[k] as T : def;
    E pickEnum<E>(String k, List<E> values, E def) {
      final i = j[k];
      return i is int && i >= 0 && i < values.length ? values[i] : def;
    }

    final vt = j['verseOfDayTime'];
    return ReaderSettings(
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? d.fontSize,
      align: pickEnum('align', TextAlign.values, d.align),
      font: pickEnum('font', FontKind.values, d.font),
      verseSpacing: (j['verseSpacing'] as num?)?.toDouble() ?? d.verseSpacing,
      lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? d.lineHeight,
      pageColor: pickEnum('pageColor', PageColor.values, d.pageColor),
      nightMode: pick('nightMode', d.nightMode),
      themeColor: j['themeColor'] is int ? Color(j['themeColor']) : d.themeColor,
      verseByVerse: pick('verseByVerse', d.verseByVerse),
      trimLeadingSpace: pick('trimLeadingSpace', d.trimLeadingSpace),
      verseNumberStyle:
          pickEnum('verseNumberStyle', VerseNumberStyle.values, d.verseNumberStyle),
      hideTitles: pick('hideTitles', d.hideTitles),
      jesusWordsInColor: pick('jesusWordsInColor', d.jesusWordsInColor),
      jesusColor: j['jesusColor'] is int ? Color(j['jesusColor']) : d.jesusColor,
      hideMenusOnScroll: pick('hideMenusOnScroll', d.hideMenusOnScroll),
      keepScreenOn: pick('keepScreenOn', d.keepScreenOn),
      fullScreen: pick('fullScreen', d.fullScreen),
      verseOfDayEnabled: pick('verseOfDayEnabled', d.verseOfDayEnabled),
      verseOfDayTime: vt is int
          ? TimeOfDay(hour: vt ~/ 60, minute: vt % 60)
          : d.verseOfDayTime,
      sundayPassage: pick('sundayPassage', d.sundayPassage),
      planReminders: pick('planReminders', d.planReminders),
    );
  }
}
