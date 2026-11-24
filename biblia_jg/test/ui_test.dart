import 'package:biblia_jg/data/bible_repository.dart';
import 'package:biblia_jg/data/user_db.dart';
import 'package:biblia_jg/main.dart';
import 'package:biblia_jg/models/bible.dart';
import 'package:biblia_jg/models/reader_settings.dart';
import 'package:biblia_jg/screens/home_shell.dart';
import 'package:biblia_jg/screens/settings_screen.dart';
import 'package:biblia_jg/screens/today_screen.dart';
import 'package:biblia_jg/services/notifications.dart';
import 'package:biblia_jg/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NoNotifications extends NotificationService {
  @override
  Future<void> reschedule(ReaderSettings s, Bible? bible) async {}
  @override
  Future<bool> requestPermission() async => true;
}

Bible _bible() => Bible(
      id: 'tst',
      name: 'Teste',
      abbrev: 'TST',
      copyright: 'Texto de teste',
      books: [
        for (var i = 0; i < canonicalBooks.length; i++)
          Book(
            index: i,
            abbrev: canonicalBooks[i].abbrev,
            name: canonicalBooks[i].name,
            titles: const {'1:1': 'Título de seção'},
            chapters: List.generate(
                3,
                (c) => List.generate(
                    20, (v) => 'Texto do versículo ${v + 1}, <J>palavras de Jesus</J>, capítulo ${c + 1}.')),
          ),
      ],
    );

Future<AppState> _state() async {
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  final db = await UserDb.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  final app = AppState(
    repo: BibleRepository(),
    db: db,
    prefs: await SharedPreferences.getInstance(),
    notifications: _NoNotifications(),
  );
  app.bible = _bible();
  app.loading = false;
  return app;
}

Future<void> _pump(WidgetTester tester, AppState app, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      ChangeNotifierProvider.value(value: app, child: const BibliaJgApp()));
  await tester.pump();
}

void main() {
  HomeShell.autoCheckUpdates = false;
  TodayScreen.loadData = false;
  for (final (name, size) in [('tablet', Size(1280, 800)), ('celular', Size(400, 860))]) {
    testWidgets('tela de leitura no $name', (tester) async {
      final app = await tester.runAsync(_state);
      await _pump(tester, app!, size);

      // O app abre na aba Hoje; a leitura fica na aba Bíblia.
      expect(find.text('VERSÍCULO DO DIA'), findsOneWidget);
      await tester.tap(find.text('Bíblia').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Gênesis 1'), findsOneWidget);
      expect(find.text('Título de seção'), findsOneWidget);
      // Painel de livros só no tablet.
      expect(find.text('Antigo Testamento'), size.width > 840 ? findsOneWidget : findsNothing);

      // Selecionar versículo abre a barra de ações.
      await tester.tap(find.textContaining('Texto do versículo 2,').first);
      await tester.pump();
      expect(find.byTooltip('Favoritar'), findsOneWidget);

      // Layout clássico também renderiza.
      await tester.runAsync(() => app.updateSettings(app.settings.copyWith(
          verseByVerse: false, pageColor: PageColor.sepia, verseNumberStyle: VerseNumberStyle.inline)));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Painel rápido de ajustes.
      await tester.tap(find.byTooltip('Ajustes de leitura'));
      await tester.pumpAndSettle();
      expect(find.text('Cor da página'), findsOneWidget);
    });
  }

  testWidgets('abas e configurações', (tester) async {
    final app = await tester.runAsync(_state);
    await _pump(tester, app!, const Size(1280, 800));
    expect(find.text('VERSÍCULO DO DIA'), findsOneWidget);
    Future<void> openTab(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await openTab('Estudo');
    expect(find.text('Memorização'), findsOneWidget);
    expect(find.text('Diário de oração'), findsOneWidget);
    await openTab('Biblioteca');
    expect(find.text('Favoritos e marcações'), findsOneWidget);
    await openTab('Mais');
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.textContaining('Produzido por Joabe Gonçalves'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app, child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Leitura da Bíblia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Passagem do domingo'), 400);
    expect(tester.takeException(), isNull);
  });
}
