import 'bible.dart';

/// Versículos escolhidos para o "Versículo do dia" (livro 0..65, capítulo, versículo).
const List<VerseRef> dailyVerses = [
  VerseRef(42, 3, 16), VerseRef(18, 23, 1), VerseRef(49, 4, 13), VerseRef(44, 8, 28),
  VerseRef(19, 3, 5), VerseRef(22, 41, 10), VerseRef(23, 29, 11), VerseRef(39, 11, 28),
  VerseRef(5, 1, 9), VerseRef(18, 46, 1), VerseRef(54, 1, 7), VerseRef(57, 11, 1),
  VerseRef(45, 13, 4), VerseRef(47, 5, 22), VerseRef(39, 6, 33), VerseRef(18, 119, 105),
  VerseRef(44, 12, 2), VerseRef(48, 2, 8), VerseRef(61, 4, 8), VerseRef(44, 5, 8),
  VerseRef(18, 37, 5), VerseRef(24, 3, 22), VerseRef(22, 40, 31), VerseRef(39, 5, 9),
  VerseRef(42, 14, 6), VerseRef(42, 8, 32), VerseRef(19, 16, 3), VerseRef(18, 91, 1),
  VerseRef(48, 6, 10), VerseRef(49, 4, 6), VerseRef(50, 3, 23), VerseRef(59, 5, 7),
  VerseRef(58, 1, 5), VerseRef(57, 13, 8), VerseRef(65, 21, 4), VerseRef(18, 27, 1),
  VerseRef(18, 121, 1), VerseRef(42, 16, 33), VerseRef(46, 5, 17), VerseRef(44, 15, 13),
];

/// Passagens para a "Passagem do domingo": (livro, capítulo).
const List<(int, int)> sundayPassages = [
  (18, 23), (18, 91), (42, 15), (45, 13), (39, 5), (22, 53), (44, 8), (48, 6),
  (18, 1), (57, 11), (42, 1), (49, 4), (18, 103), (39, 6), (24, 3), (50, 3),
];

int _dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

VerseRef verseOfDay(DateTime date) =>
    dailyVerses[_dayNumber(date) % dailyVerses.length];

(int, int) sundayPassageFor(DateTime date) =>
    sundayPassages[(_dayNumber(date) ~/ 7) % sundayPassages.length];

String? verseText(Bible bible, VerseRef r) {
  if (r.book >= bible.books.length) return null;
  final b = bible.books[r.book];
  if (r.chapter < 1 || r.chapter > b.chapters.length) return null;
  final c = b.chapters[r.chapter - 1];
  if (r.verse < 1 || r.verse > c.length) return null;
  return plainVerse(c[r.verse - 1]).trim();
}
