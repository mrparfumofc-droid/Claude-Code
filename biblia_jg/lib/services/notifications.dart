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

  /// Aviso imediato com som e vibração (fim do tempo do modo foco).
  Future<void> alarm(String title, String body) async {
    try {
      await init();
      await _plugin.show(
        id: 4001,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarme_leitura',
            'Alarme do tempo de leitura',
            channelDescription: 'Toca quando o tempo escolhido no modo foco termina',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Falha no alarme: $e');
    }
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

  static const _ebdBase = 3000;

  /// Lembretes da EBD: [(domingo, título, texto)] — substitui os anteriores.
  Future<void> scheduleEbd(List<(DateTime, String, String)> items) async {
    if (!_ready) await init();
    for (var i = 0; i < 14; i++) {
      await _plugin.cancel(id: _ebdBase + i);
    }
    final now = tz.TZDateTime.now(tz.local);
    var i = 0;
    for (final (day, title, body) in items) {
      final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, 7);
      if (when.isBefore(now) || i >= 14) continue;
      await _schedule(_ebdBase + i, when, title, body);
      i++;
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
