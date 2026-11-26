import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/bible_repository.dart';
import 'data/user_db.dart';
import 'screens/home_shell.dart';
import 'services/account_service.dart';
import 'services/books_service.dart';
import 'services/dictionary_service.dart';
import 'services/hymn_service.dart';
import 'services/music_player.dart';
import 'services/notifications.dart';
import 'services/palm_guard.dart';
import 'services/tts.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  PalmBinding.init();
  final prefs = await SharedPreferences.getInstance();
  PalmGuard.load(prefs);
  final state = AppState(
    repo: BibleRepository(),
    db: await UserDb.open(),
    prefs: prefs,
    notifications: NotificationService(),
  );
  runApp(ChangeNotifierProvider.value(value: state, child: const BibliaJgApp()));
  await state.init();
}

class BibliaJgApp extends StatelessWidget {
  const BibliaJgApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AppState, (Color, bool)>(
        (a) => (a.settings.themeColor, a.settings.nightMode));
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReadAloud()),
        ChangeNotifierProvider(create: (_) => MusicPlayer()),
        ChangeNotifierProvider(create: (_) => AccountService()..load()),
        ChangeNotifierProvider(create: (ctx) => BooksService(ctx.read<AccountService>())),
        ChangeNotifierProvider(create: (_) => DictionaryService()),
        ChangeNotifierProvider(create: (ctx) => HymnService(ctx.read<AccountService>())),
      ],
      child: MaterialApp(
        title: 'Bíblia - JG Company',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(s.$1, Brightness.light),
        darkTheme: buildTheme(s.$1, Brightness.dark),
        themeMode: s.$2 ? ThemeMode.dark : ThemeMode.light,
        home: const HomeShell(),
      ),
    );
  }
}
