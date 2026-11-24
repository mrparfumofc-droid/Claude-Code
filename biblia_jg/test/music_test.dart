import 'package:biblia_jg/screens/music_screen.dart';
import 'package:biblia_jg/services/music_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formato de duração', () {
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('lista de músicas da nuvem', () {
    final t = Track.fromJson({
      'file': 'agnus-dei-instrumental.ogg',
      'title': 'Agnus Dei - Instrumental',
      'seconds': 300,
      'bytes': 1800000,
      'url': 'https://exemplo/assinado',
    });
    expect(t.title, 'Agnus Dei - Instrumental');
    expect(t.toJson().containsKey('url'), isFalse); // link expira, não é guardado
    expect(MusicPlayer().currentTrack, isNull);
  });
}
