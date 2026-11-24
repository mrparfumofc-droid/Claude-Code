import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/bible_repository.dart';
import '../data/user_db.dart';
import '../models/bible.dart';
import '../models/reader_settings.dart';
import '../services/notifications.dart';

/// Estado global do app.
class AppState extends ChangeNotifier {
  final BibleRepository repo;
  final UserDb db;
  final SharedPreferences prefs;
  final NotificationService notifications;

  AppState({
    required this.repo,
    required this.db,
    required this.prefs,
    required this.notifications,
  });

  ReaderSettings settings = const ReaderSettings();
  Bible? bible;
  List<VersionInfo> versions = [];
  String? loadError;
  bool loading = true;

  int book = 0;
  int chapter = 1;
  int? scrollToVerse;

  /// Muda a cada pedido de rolagem; cada leitor guarda o último que atendeu.
  int scrollSerial = 0;

  void rescheduleNotifications() => _rescheduleNotifications();

  // Dados do capítulo atual.
  Map<int, int> highlights = {};
  Set<int> favorites = {};
  Map<int, List<Note>> notes = {};
  Set<String> readChapters = {};

  /// Incrementa sempre que marcações/anotações mudam (para as listas recarregarem).
  int userDataRevision = 0;

  /// Aba que a tela principal deve mostrar (1 = Bíblia); -1 = nenhuma pedida.
  int tabRequest = -1;

  /// Modo foco (leitura sem distrações) pedido por outra tela.
  bool focusRequest = false;

  // ---------- Constância ----------
  /// dia (aaaa-mm-dd) -> (capítulos lidos, segundos de leitura).
  Map<String, (int, int)> activity = {};

  int get goalMinutes => prefs.getInt('goal_minutes') ?? 10;

  Future<void> setGoalMinutes(int m) async {
    await prefs.setInt('goal_minutes', m);
    notifyListeners();
  }

  (int, int) get todayActivity => activity[UserDb.dayKey(DateTime.now())] ?? (0, 0);

  bool activeOn(DateTime d) {
    final a = activity[UserDb.dayKey(d)];
    return a != null && (a.$1 > 0 || a.$2 >= 60);
  }

  /// Dias seguidos com leitura (hoje ainda sem leitura não quebra a sequência).
  int get streak {
    var d = DateTime.now();
    if (!activeOn(d)) d = d.subtract(const Duration(days: 1));
    var s = 0;
    while (activeOn(d) && s < 5000) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  /// Registra leitura de hoje (capítulos concluídos e/ou tempo lendo).
  Future<void> logReading({int chapters = 0, int seconds = 0}) async {
    final key = UserDb.dayKey(DateTime.now());
    final before = activity[key] ?? (0, 0);
    await db.addActivity(chapters: chapters, seconds: seconds);
    final c = before.$1 + chapters;
    final after = (c < 0 ? 0 : c, before.$2 + seconds);
    activity = {...activity, key: after};
    // Só redesenha quando muda algo visível (capítulo ou minuto).
    if (chapters != 0 || before.$2 ~/ 60 != after.$2 ~/ 60) notifyListeners();
  }

  void requestTab(int tab, {bool focus = false}) {
    tabRequest = tab;
    if (focus) focusRequest = true;
    notifyListeners();
  }

  Future<void> init() async {
    final raw = prefs.getString('settings');
    if (raw != null) {
      try {
        settings = ReaderSettings.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    book = prefs.getInt('book') ?? 0;
    chapter = prefs.getInt('chapter') ?? 1;
    try {
      versions = await repo.versions();
      bible = await repo.load(prefs.getString('version') ?? '');
    } catch (e) {
      loadError = '$e';
    }
    _clampPosition();
    readChapters = await db.readChapters();
    try {
      activity = await db.activity();
    } catch (_) {}
    await _loadChapterData();
    _applyWakelock();
    loading = false;
    notifyListeners();
    // No Android 13+ as notificações só aparecem depois de pedir a permissão (uma vez).
    if ((settings.verseOfDayEnabled || settings.sundayPassage) && !(prefs.getBool('notif_asked') ?? false)) {
      await prefs.setBool('notif_asked', true);
      try {
        await notifications.requestPermission();
      } catch (_) {}
    }
    _rescheduleNotifications();
  }

  void _clampPosition() {
    final b = bible;
    if (b == null || b.books.isEmpty) {
      book = 0;
      chapter = 1;
      return;
    }
    book = book.clamp(0, b.books.length - 1);
    chapter = chapter.clamp(1, b.books[book].chapters.length);
  }

  Book? get currentBook => bible == null || bible!.books.isEmpty ? null : bible!.books[book];

  List<String> get currentVerses => currentBook?.chapters[chapter - 1] ?? const [];

  bool get chapterRead => readChapters.contains('$book:$chapter');

  Future<void> _loadChapterData() async {
    highlights = await db.highlightsForChapter(book, chapter);
    favorites = await db.favoritesForChapter(book, chapter);
    notes = await db.notesForChapter(book, chapter);
  }

  /// Vai para o capítulo. Com [show], a tela principal muda para a aba Bíblia.
  Future<void> openAt(int newBook, int newChapter, {int? verse}) =>
      goTo(newBook, newChapter, verse: verse, show: true);

  Future<void> goTo(int newBook, int newChapter, {int? verse, bool show = false}) async {
    book = newBook;
    chapter = newChapter;
    _clampPosition();
    scrollToVerse = verse;
    if (verse != null) scrollSerial++;
    if (show) tabRequest = 1;
    await prefs.setInt('book', book);
    await prefs.setInt('chapter', chapter);
    await db.addHistory(book, chapter);
    await _loadChapterData();
    notifyListeners();
  }

  Future<void> nextChapter() async {
    final b = bible;
    if (b == null) return;
    if (chapter < b.books[book].chapters.length) {
      await goTo(book, chapter + 1);
    } else if (book < b.books.length - 1) {
      await goTo(book + 1, 1);
    }
  }

  Future<void> previousChapter() async {
    final b = bible;
    if (b == null) return;
    if (chapter > 1) {
      await goTo(book, chapter - 1);
    } else if (book > 0) {
      await goTo(book - 1, b.books[book - 1].chapters.length);
    }
  }

  void consumeScrollTarget() => scrollToVerse = null;

  // ---------- Versões ----------
  Future<void> selectVersion(String id) async {
    final b = await repo.load(id);
    if (b == null) return;
    bible = b;
    await prefs.setString('version', b.id);
    _clampPosition();
    await _loadChapterData();
    notifyListeners();
    _rescheduleNotifications();
  }

  Future<void> importVersion(String text, String fileName) async {
    final v = await repo.import(text, fileName);
    versions = await repo.versions();
    await selectVersion(v.id);
  }

  Future<void> removeVersion(VersionInfo v) async {
    await repo.remove(v);
    versions = await repo.versions();
    if (bible?.id == v.id) {
      bible = versions.isEmpty ? null : await repo.load(versions.first.id);
      _clampPosition();
      await _loadChapterData();
    }
    notifyListeners();
  }

  // ---------- Configurações ----------
  Future<void> updateSettings(ReaderSettings s) async {
    final notifChanged = s.verseOfDayEnabled != settings.verseOfDayEnabled ||
        s.verseOfDayTime != settings.verseOfDayTime ||
        s.sundayPassage != settings.sundayPassage;
    settings = s;
    notifyListeners();
    await prefs.setString('settings', jsonEncode(s.toJson()));
    _applyWakelock();
    if (notifChanged) {
      if (s.verseOfDayEnabled || s.sundayPassage) {
        await notifications.requestPermission();
      }
      _rescheduleNotifications();
    }
  }

  void _applyWakelock() {
    WakelockPlus.toggle(enable: settings.keepScreenOn).catchError((_) {});
  }

  void _rescheduleNotifications() {
    notifications.reschedule(settings, bible).catchError((e) {
      debugPrint('Notificações: $e');
    });
  }

  // ---------- Dados do usuário ----------
  Future<void> setHighlight(Iterable<int> verses, int? color) async {
    for (final v in verses) {
      await db.setHighlight(VerseRef(book, chapter, v), color);
    }
    await _changed();
  }

  Future<void> setFavorite(Iterable<int> verses, bool fav) async {
    for (final v in verses) {
      await db.setFavorite(VerseRef(book, chapter, v), fav);
    }
    await _changed();
  }

  Future<void> saveNote(Note n) async {
    await db.saveNote(n);
    await _changed();
  }

  Future<void> deleteNote(int id) async {
    await db.deleteNote(id);
    await _changed();
  }

  Future<void> removeHighlightAt(VerseRef r) async {
    await db.setHighlight(r, null);
    await _changed();
  }

  Future<void> removeFavoriteAt(VerseRef r) async {
    await db.setFavorite(r, false);
    await _changed();
  }

  Future<void> toggleChapterRead() async {
    final read = !chapterRead;
    await db.setChapterRead(book, chapter, read);
    readChapters = await db.readChapters();
    await logReading(chapters: read ? 1 : -1);
    notifyListeners();
  }

  /// Marca o capítulo atual como lido (sem desmarcar se já estava).
  Future<void> markChapterRead() async {
    if (!chapterRead) await toggleChapterRead();
  }

  Future<void> resetProgress() async {
    for (final k in readChapters.toList()) {
      final p = k.split(':').map(int.parse).toList();
      await db.setChapterRead(p[0], p[1], false);
    }
    readChapters = await db.readChapters();
    notifyListeners();
  }

  /// Restaura um backup. Com [merge], junta com o que já existe em vez de substituir.
  Future<void> restoreBackup(Map<String, dynamic> data, {bool merge = false}) async {
    await db.importAll(data, replace: !merge);
    readChapters = await db.readChapters();
    activity = await db.activity();
    await _changed();
  }

  Future<void> _changed() async {
    await _loadChapterData();
    userDataRevision++;
    notifyListeners();
  }
}
