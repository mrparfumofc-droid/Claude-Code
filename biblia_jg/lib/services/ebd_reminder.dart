import 'books_service.dart';
import 'notifications.dart';

/// Primeiro domingo do trimestre (jan, abr, jul, out).
DateTime firstSundayOfQuarter(int year, int quarter) {
  var d = DateTime(year, (quarter - 1) * 3 + 1, 1);
  while (d.weekday != DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// Lição de cada domingo: a k-ésima lição marcada cai no k-ésimo domingo do trimestre.
List<(DateTime, Lesson, Book)> ebdSchedule(List<Book> books) {
  final out = <(DateTime, Lesson, Book)>[];
  for (final b in books) {
    if (!b.isEbd || b.year == null || b.quarter == null || b.lessons.isEmpty) continue;
    final first = firstSundayOfQuarter(b.year!, b.quarter!);
    for (var k = 0; k < b.lessons.length; k++) {
      out.add((first.add(Duration(days: 7 * k)), b.lessons[k], b));
    }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// Agenda o lembrete de domingo de manhã com a lição do dia.
Future<void> scheduleEbdReminders(NotificationService n, List<Book> books) async {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final items = [
    for (final (day, lesson, book) in ebdSchedule(books))
      if (!day.isBefore(start) && day.difference(start).inDays <= 42)
        (day, 'EBD hoje: ${lesson.title}', '${book.title} · página ${lesson.page}. Bom estudo!'),
  ];
  try {
    await n.scheduleEbd(items);
  } catch (_) {}
}
