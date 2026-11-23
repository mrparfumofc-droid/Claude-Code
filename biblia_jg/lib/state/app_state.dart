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

  // Dados do capítulo atual.
  Map<int, int> highlights = {};
  Set<int> favorites = {};
  Map<int, List<Note>> notes = {};
  Set<String> readChapters = {};

  /// Incrementa sempre que marcações/anotações mudam (para as listas recarregarem).
  int userDataRevision = 0;

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
    await _loadChapterData();
    _applyWakelock();
    loading = false;
    notifyListeners();
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

  Future<void> goTo(int newBook, int newChapter, {int? verse}) async {
    book = newBook;
    chapter = newChapter;
    _clampPosition();
    scrollToVerse = verse;
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
    notifyListeners();
  }

  Future<void> resetProgress() async {
    for (final k in readChapters.toList()) {
      final p = k.split(':').map(int.parse).toList();
      await db.setChapterRead(p[0], p[1], false);
    }
    readChapters = await db.readChapters();
    notifyListeners();
  }

  Future<void> restoreBackup(Map<String, dynamic> data) async {
    await db.importAll(data);
    readChapters = await db.readChapters();
    await _changed();
  }

  Future<void> _changed() async {
    await _loadChapterData();
    userDataRevision++;
    notifyListeners();
  }
}
