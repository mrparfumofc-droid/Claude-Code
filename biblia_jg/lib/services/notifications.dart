import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/bible.dart';
import '../models/daily.dart';
import '../models/reader_settings.dart';

/// Agenda o versículo do dia e a passagem do domingo.
/// Como o texto muda a cada dia, agendamos os próximos 14 dias
/// e reagendamos sempre que o app é aberto.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyBase = 1000;
  static const _sundayBase = 2000;
  static const _days = 14;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('Fuso horário não detectado: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'versiculo_do_dia',
      'Versículo do dia',
      channelDescription: 'Um versículo por dia e a passagem do domingo',
      importance: Importance.defaultImportance,
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  Future<void> reschedule(ReaderSettings s, Bible? bible) async {
    if (!_ready) await init();
    for (var i = 0; i < _days; i++) {
      await _plugin.cancel(id: _dailyBase + i);
      await _plugin.cancel(id: _sundayBase + i);
    }
    if (bible == null) return;
    final now = tz.TZDateTime.now(tz.local);

    if (s.verseOfDayEnabled) {
      for (var i = 0; i < _days; i++) {
        final day = now.add(Duration(days: i));
        final when = tz.TZDateTime(tz.local, day.year, day.month, day.day,
            s.verseOfDayTime.hour, s.verseOfDayTime.minute);
        if (when.isBefore(now)) continue;
        final ref = verseOfDay(when);
        final text = verseText(bible, ref);
        if (text == null) continue;
        await _schedule(_dailyBase + i, when, 'Versículo do dia · ${ref.label(bible)}', text);
      }
    }

    if (s.sundayPassage) {
      for (var i = 0; i < _days; i++) {
        final day = now.add(Duration(days: i));
        if (day.weekday != DateTime.sunday) continue;
        final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, 8);
        if (when.isBefore(now)) continue;
        final (book, chapter) = sundayPassageFor(when);
        if (book >= bible.books.length) continue;
        await _schedule(_sundayBase + i, when, 'Passagem do domingo',
            'Leia hoje ${bible.books[book].name} $chapter. Bom domingo!');
      }
    }
  }

  Future<void> _schedule(int id, tz.TZDateTime when, String title, String body) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Falha ao agendar notificação: $e');
    }
  }
}
