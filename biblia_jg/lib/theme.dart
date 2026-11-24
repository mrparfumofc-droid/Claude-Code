import 'package:flutter/material.dart';

/// Cores da marca JG Company.
const jgNavy = Color(0xFF1B2A49);
const jgGold = Color(0xFFC9A227);

/// Cores de marcação de versículos.
const highlightColors = <Color>[
  Color(0xFFFFF176), // amarelo
  Color(0xFFA5D6A7), // verde
  Color(0xFF90CAF9), // azul
  Color(0xFFF48FB1), // rosa
  Color(0xFFFFCC80), // laranja
  Color(0xFFCE93D8), // roxo
];

ThemeData buildTheme(Color seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    secondary: jgGold,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light ? seed : scheme.surface,
      foregroundColor: brightness == Brightness.light ? Colors.white : scheme.onSurface,
    ),
    // Abas dentro da barra superior: no tema claro a barra é escura, então o texto é claro.
    tabBarTheme: brightness == Brightness.light
        ? const TabBarThemeData(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: jgGold,
            dividerColor: Colors.transparent,
          )
        : null,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
