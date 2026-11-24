// Pré-visualização só dos mapas no navegador (para conferir o visual):
//   flutter build web -t tool/maps_preview.dart
import 'package:biblia_jg/screens/maps_screen.dart';
import 'package:biblia_jg/services/places.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await PlacesData.load();
  final id = Uri.base.queryParameters['story'] ?? 'imperios';
  final story = data.stories.firstWhere((s) => s.id == id, orElse: () => data.stories.first);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Uri.base.queryParameters['explore'] != null
        ? PlacesMapScreen(data: data)
        : AtlasMapScreen(story: story),
  ));
}
